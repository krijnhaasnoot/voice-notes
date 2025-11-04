import Foundation
import Combine

enum ModelQuality: String, CaseIterable, Identifiable {
    case lightweight, base, medium, advanced
    var id: String { rawValue }
}

struct WhisperModel: Identifiable {
    let id: String
    let name: String
    let quality: ModelQuality
    let approxSizeMB: Int
    let remoteURL: URL
    var localURL: URL? = nil
}

@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()

    @Published var models: [WhisperModel] = []
    @Published var progress: [String: Double] = [:] // id -> 0...1
    @Published var selectedModelID: String? {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: "selectedWhisperModelID")
        }
    }

    private let modelsDir: URL
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var progressProxies: [String: ProgressProxy] = [:]

    init() {
        // Stel de modellen directory in binnen Application Support
        modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)

        // Maak directory aan indien nodig
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Laad geselecteerde model
        selectedModelID = UserDefaults.standard.string(forKey: "selectedWhisperModelID")
        if selectedModelID == nil {
            selectedModelID = "base"
        }

        // Definieer beschikbare modellen
        models = [
            WhisperModel(
                id: "tiny",
                name: "Lichtgewicht",
                quality: .lightweight,
                approxSizeMB: 75,
                remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!
            ),
            WhisperModel(
                id: "base",
                name: "Basis",
                quality: .base,
                approxSizeMB: 142,
                remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
            ),
            WhisperModel(
                id: "small",
                name: "Gemiddeld",
                quality: .medium,
                approxSizeMB: 466,
                remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!
            ),
            WhisperModel(
                id: "large-v3",
                name: "Gevorderd",
                quality: .advanced,
                approxSizeMB: 3090,
                remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
            )
        ]

        // Herstel lokale URLs voor reeds gedownloade modellen
        restoreLocalURLs()
    }

    private func restoreLocalURLs() {
        for i in models.indices {
            let localPath = modelsDir.appendingPathComponent("ggml-\(models[i].id).bin")
            if FileManager.default.fileExists(atPath: localPath.path) {
                models[i].localURL = localPath
            }
        }
    }

    func downloadModel(id: String, allowCellular: Bool) async throws -> URL {
        guard let idx = models.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "ModelStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model niet gevonden"])
        }

        // Check of het model al gedownload is
        if let existing = models[idx].localURL {
            return existing
        }

        let remote = models[idx].remoteURL
        let localPath = modelsDir.appendingPathComponent("ggml-\(id).bin")

        print("📥 Downloading model \(id) from \(remote)")

        // Maak URLSession configuratie
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = allowCellular

        // Maak progress proxy
        let proxy = ProgressProxy(modelID: id, store: self)
        progressProxies[id] = proxy

        let session = URLSession(configuration: config, delegate: proxy, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: remote)
            tasks[id] = task
            proxy.continuation = continuation
            proxy.destination = localPath
            task.resume()
        }
    }

    func cancelDownload(id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        progressProxies.removeValue(forKey: id)
        progress.removeValue(forKey: id)
    }

    func deleteModel(id: String) throws {
        guard let idx = models.firstIndex(where: { $0.id == id }) else { return }
        guard let localURL = models[idx].localURL else { return }

        try FileManager.default.removeItem(at: localURL)
        models[idx].localURL = nil

        print("🗑️ Deleted model: \(id)")
    }

    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0

        for model in models {
            if let url = model.localURL,
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }

        return total
    }

    // Helper om geselecteerde model te krijgen
    var selectedModel: WhisperModel? {
        models.first(where: { $0.id == selectedModelID })
    }
}

// URLSessionDownloadDelegate voor progress tracking
final class ProgressProxy: NSObject, URLSessionDownloadDelegate {
    let modelID: String
    weak var store: ModelStore?
    var continuation: CheckedContinuation<URL, Error>?
    var destination: URL?

    init(modelID: String, store: ModelStore) {
        self.modelID = modelID
        self.store = store
        super.init()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            self.store?.progress[self.modelID] = progress
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let destination = destination else {
            continuation?.resume(throwing: NSError(domain: "ModelStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Geen bestemming ingesteld"]))
            return
        }

        do {
            // Verwijder bestaand bestand indien aanwezig
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            // Verplaats gedownload bestand naar bestemming
            try FileManager.default.moveItem(at: location, to: destination)

            Task { @MainActor in
                // Update model met lokale URL
                if let idx = self.store?.models.firstIndex(where: { $0.id == self.modelID }) {
                    self.store?.models[idx].localURL = destination

                    // Notify user of download completion
                    let model = self.store?.models[idx]
                    NotificationManager.shared.notifyModelDownloadComplete(
                        modelName: model?.name ?? "Model",
                        modelSize: "\(model?.approxSizeMB ?? 0) MB"
                    )
                }
                self.store?.progress.removeValue(forKey: self.modelID)
            }

            continuation?.resume(returning: destination)
            print("✅ Model \(modelID) downloaded successfully")

        } catch {
            continuation?.resume(throwing: error)
            print("❌ Failed to move downloaded model: \(error)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.store?.progress.removeValue(forKey: self.modelID)

                // Notify user of download failure
                if let model = self.store?.models.first(where: { $0.id == self.modelID }) {
                    NotificationManager.shared.notifyModelDownloadFailed(
                        modelName: model.name,
                        error: error.localizedDescription
                    )
                }
            }
            continuation?.resume(throwing: error)
            print("❌ Download failed for \(modelID): \(error)")
        }
    }
}
