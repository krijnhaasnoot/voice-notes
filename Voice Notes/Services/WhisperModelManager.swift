import Foundation
import Network

// MARK: - Whisper Model Definitions

enum WhisperModelSize: String, CaseIterable, Codable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var estimatedSize: Int64 {
        switch self {
        case .tiny: return 75 * 1024 * 1024      // ~75 MB
        case .base: return 145 * 1024 * 1024     // ~145 MB
        case .small: return 466 * 1024 * 1024    // ~466 MB
        case .medium: return 1500 * 1024 * 1024  // ~1.5 GB
        case .large: return 2900 * 1024 * 1024   // ~2.9 GB
        }
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSize)
    }

    var description: String {
        switch self {
        case .tiny: return "Fastest, least accurate"
        case .base: return "Fast, good for quick notes"
        case .small: return "Balanced speed and accuracy"
        case .medium: return "High accuracy, slower"
        case .large: return "Best accuracy, slowest"
        }
    }
}

enum WhisperLanguage: String, CaseIterable, Codable {
    case auto = "auto"
    case english = "en"
    case dutch = "nl"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case polish = "pl"
    case turkish = "tr"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .dutch: return "Nederlands"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "中文"
        }
    }
}

// MARK: - Model Download State

enum ModelDownloadState {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(Error)
}

// MARK: - Whisper Model Manager

@MainActor
class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var downloadState: ModelDownloadState = .notDownloaded
    @Published var selectedModel: WhisperModelSize = .base
    @Published var selectedLanguage: WhisperLanguage = .dutch

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var currentNetworkPath: NWPath?

    private let modelsDirectory: URL

    private init() {
        // Set up models directory in app documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = documentsPath.appendingPathComponent("WhisperModels", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Load preferences
        loadPreferences()

        // Start network monitoring
        startNetworkMonitoring()

        // Check if current model is downloaded
        checkModelStatus()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.currentNetworkPath = path
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    var isOnCellular: Bool {
        currentNetworkPath?.usesInterfaceType(.cellular) ?? false
    }

    var isConnected: Bool {
        currentNetworkPath?.status == .satisfied
    }

    // MARK: - Preferences

    private func loadPreferences() {
        if let modelString = UserDefaults.standard.string(forKey: "whisper_model"),
           let model = WhisperModelSize(rawValue: modelString) {
            selectedModel = model
        }

        if let langString = UserDefaults.standard.string(forKey: "whisper_language"),
           let language = WhisperLanguage(rawValue: langString) {
            selectedLanguage = language
        }
    }

    func savePreferences() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "whisper_model")
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "whisper_language")
    }

    // MARK: - Model Management

    func modelPath(for model: WhisperModelSize) -> URL {
        return modelsDirectory.appendingPathComponent("whisper-\(model.rawValue)")
    }

    func isModelDownloaded(_ model: WhisperModelSize) -> Bool {
        let path = modelPath(for: model)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func checkModelStatus() {
        if isModelDownloaded(selectedModel) {
            downloadState = .downloaded
        } else {
            downloadState = .notDownloaded
        }
    }

    // MARK: - Model Download

    func shouldWarnAboutCellular(for model: WhisperModelSize) -> Bool {
        return isOnCellular && model.estimatedSize > 100 * 1024 * 1024
    }

    func downloadModel(_ model: WhisperModelSize) async throws {
        guard isConnected else {
            throw ModelDownloadError.noConnection
        }

        print("📥 WhisperModelManager: Starting download for \(model.displayName)")

        // Update state
        await MainActor.run {
            downloadState = .downloading(progress: 0.0)
            objectWillChange.send()
            print("📊 Download state set to: downloading(0.0)")
        }

        let destinationPath = modelPath(for: model)

        // Create destination directory
        try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)

        do {
            // Try to use WhisperKit's built-in model downloading
            // Uncomment this when WhisperKit package is added:
            /*
            let modelName = "openai/whisper-\(model.rawValue)"

            print("📥 Downloading WhisperKit model: \(modelName)")

            // WhisperKit has built-in downloading
            let downloadedModels = try await WhisperKit.download(
                model: modelName,
                downloadBase: modelsDirectory.path
            ) { progress in
                Task { @MainActor in
                    self.downloadState = .downloading(progress: progress)
                }
            }

            print("✅ WhisperKit model downloaded successfully")
            */

            // Fallback: Manual download from HuggingFace
            let modelURL = getModelDownloadURL(for: model)
            try await downloadModelFiles(from: modelURL, to: destinationPath) { progress in
                Task { @MainActor in
                    self.downloadState = .downloading(progress: progress)
                    self.objectWillChange.send()
                    if Int(progress * 100) % 10 == 0 {  // Log every 10%
                        print("📊 Download progress: \(Int(progress * 100))%")
                    }
                }
            }

            await MainActor.run {
                downloadState = .downloaded
                objectWillChange.send()
                savePreferences()
                print("✅ Download state set to: downloaded")
            }

            print("✅ Model \(model.rawValue) downloaded successfully")

        } catch {
            print("❌ Download error: \(error.localizedDescription)")
            await MainActor.run {
                downloadState = .failed(error)
                objectWillChange.send()
                print("📊 Download state set to: failed")
            }
            // Clean up partial download
            try? FileManager.default.removeItem(at: destinationPath)
            throw error
        }
    }

    private func getModelDownloadURL(for model: WhisperModelSize) -> URL {
        // WhisperKit CoreML models from Argmax on HuggingFace
        let baseURL = "https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main"
        return URL(string: "\(baseURL)/openai_whisper-\(model.rawValue)")!
    }

    private func downloadModelFiles(from baseURL: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        // WhisperKit models consist of multiple CoreML files
        // Required structure:
        // - AudioEncoder.mlmodelc/ (directory with compiled model)
        // - TextDecoder.mlmodelc/ (directory with compiled model)
        // - MelSpectrogram.mlmodelc/ (directory with compiled model)
        // - config.json
        // - generation_config.json (optional)

        print("📥 Starting model download from: \(baseURL)")

        // Files to download (simplified for now - real implementation would need to handle .mlmodelc directories)
        let filesToDownload = [
            "config.json",
            "generation_config.json"
        ]

        // Directories to download (these are CoreML compiled models)
        let directoriesToDownload = [
            "AudioEncoder.mlmodelc",
            "TextDecoder.mlmodelc",
            "MelSpectrogram.mlmodelc"
        ]

        var overallProgress: Double = 0.0
        let totalItems = filesToDownload.count + directoriesToDownload.count

        // Download simple files first
        for (index, file) in filesToDownload.enumerated() {
            let fileURL = baseURL.appendingPathComponent(file)
            let destinationFile = destination.appendingPathComponent(file)

            print("📥 Downloading \(file)...")

            do {
                try await downloadSingleFile(from: fileURL, to: destinationFile) { fileProgress in
                    let itemProgress = (Double(index) + fileProgress) / Double(totalItems)
                    progress(itemProgress)
                }
            } catch {
                print("⚠️ Failed to download \(file): \(error.localizedDescription)")
                // Config files are optional, continue
                continue
            }

            overallProgress = Double(index + 1) / Double(totalItems)
            progress(overallProgress)

            print("✅ Downloaded \(file)")
        }

        // Download CoreML model directories
        for (index, directory) in directoriesToDownload.enumerated() {
            let directoryURL = baseURL.appendingPathComponent(directory)
            let destinationDir = destination.appendingPathComponent(directory)

            print("📥 Downloading \(directory)...")

            do {
                try await downloadModelDirectory(from: directoryURL, to: destinationDir) { dirProgress in
                    let itemProgress = (Double(filesToDownload.count + index) + dirProgress) / Double(totalItems)
                    progress(itemProgress)
                }
            } catch {
                print("❌ Failed to download \(directory): \(error.localizedDescription)")
                throw ModelDownloadError.downloadFailed("Failed to download \(directory)")
            }

            overallProgress = Double(filesToDownload.count + index + 1) / Double(totalItems)
            progress(overallProgress)

            print("✅ Downloaded \(directory)")
        }

        // Create completion marker
        let markerFile = destination.appendingPathComponent(".downloaded")
        try "completed".write(to: markerFile, atomically: true, encoding: .utf8)

        progress(1.0)
        print("✅ Model download complete!")
    }

    private func downloadSingleFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        // Create a download task with progress tracking
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDownloadError.downloadFailed("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        // Move to destination
        try FileManager.default.moveItem(at: tempURL, to: destination)
        progress(1.0)
    }

    private func downloadModelDirectory(from baseURL: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        // CoreML .mlmodelc directories contain multiple files
        // For a production implementation, you would need to:
        // 1. Query the HuggingFace API to get directory contents
        // 2. Download each file in the directory structure

        // Simplified: Try to download common CoreML model files
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let commonFiles = [
            "model.mil",
            "metadata.json",
            "coremldata.bin",
            "weights/weight.bin"
        ]

        var downloadedFiles = 0
        for (index, file) in commonFiles.enumerated() {
            let fileURL = baseURL.appendingPathComponent(file)
            let destinationFile = destination.appendingPathComponent(file)

            // Create parent directory if needed
            let parentDir = destinationFile.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            do {
                try await downloadSingleFile(from: fileURL, to: destinationFile) { fileProgress in
                    let dirProgress = (Double(index) + fileProgress) / Double(commonFiles.count)
                    progress(dirProgress)
                }
                print("  ✅ Downloaded \(file)")
                downloadedFiles += 1
            } catch {
                print("  ⚠️ Skipped \(file) (may not exist): \(error.localizedDescription)")
                // Some files may not exist in all models, continue
                continue
            }
        }

        // If we couldn't download any files, the model structure might be different
        if downloadedFiles == 0 {
            throw ModelDownloadError.downloadFailed("Could not download model files. Model structure may have changed or WhisperKit package is not installed.")
        }

        progress(1.0)
    }

    func deleteModel(_ model: WhisperModelSize) throws {
        let path = modelPath(for: model)
        try FileManager.default.removeItem(at: path)

        if model == selectedModel {
            checkModelStatus()
        }
    }

    func deleteAllModels() throws {
        try FileManager.default.removeItem(at: modelsDirectory)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        checkModelStatus()
    }

    func totalDiskSpaceUsed() -> Int64 {
        var total: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                continue
            }
            total += Int64(fileSize)
        }

        return total
    }
}

// MARK: - Errors

enum ModelDownloadError: LocalizedError {
    case noConnection
    case cellularWarning
    case downloadFailed(String)
    case invalidModel

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .cellularWarning:
            return "Large download on cellular connection"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .invalidModel:
            return "Invalid model selected"
        }
    }
}
