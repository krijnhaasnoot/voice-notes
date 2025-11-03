import SwiftUI

struct TranscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var modelStore: ModelStore = .shared

    let audioURL: URL
    let onComplete: (String) -> Void

    @State private var language: TranscriptionLanguage = .nl_NL
    @State private var isDownloading = false
    @State private var isTranscribing = false
    @State private var progress: Double = 0
    @State private var partialText: String = ""
    @State private var errorMsg: String?
    @State private var allowCellular = false

    private var selectedModel: WhisperModel? {
        modelStore.models.first(where: { $0.id == modelStore.selectedModelID })
    }

    private var downloadProgress: Double {
        guard let id = modelStore.selectedModelID else { return 0 }
        return modelStore.progress[id] ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Model sectie
                Section {
                    Picker("Model", selection: Binding(
                        get: { modelStore.selectedModelID ?? "base" },
                        set: { modelStore.selectedModelID = $0 }
                    )) {
                        ForEach(modelStore.models) { model in
                            HStack {
                                Text(model.name)
                                Spacer()
                                Text("\(model.approxSizeMB) MB")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                if model.localURL != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)

                    // Download sectie - alleen zichtbaar als model niet gedownload is
                    if let model = selectedModel, model.localURL == nil {
                        if isDownloading {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Downloaden...")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(downloadProgress * 100))%")
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: downloadProgress)
                                    .progressViewStyle(.linear)

                                Button("Annuleer download", role: .destructive) {
                                    modelStore.cancelDownload(id: model.id)
                                    isDownloading = false
                                }
                                .font(.caption)
                            }
                        } else {
                            Toggle("Download via mobiele data toestaan", isOn: $allowCellular)
                                .font(.caption)

                            Button {
                                Task { await download() }
                            } label: {
                                Label("Download model (\(model.approxSizeMB) MB)", systemImage: "arrow.down.circle")
                            }
                            .disabled(isDownloading)
                        }
                    }

                    // Model info
                    if let model = selectedModel, model.localURL != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Model gedownload en klaar voor gebruik")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Whisper Model")
                } footer: {
                    if let model = selectedModel {
                        Text("Grotere modellen zijn nauwkeuriger maar langzamer. \(model.name) (\(model.approxSizeMB) MB) is geselecteerd.")
                    }
                }

                // Taal sectie
                Section {
                    Picker("Taal", selection: $language) {
                        ForEach(TranscriptionLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Transcriptie Taal")
                } footer: {
                    Text("Selecteer de taal van de opname voor betere nauwkeurigheid.")
                }

                // Progress sectie - alleen tijdens transcriptie
                if isTranscribing {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Transcriberen...")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress)
                                .progressViewStyle(.linear)

                            if !partialText.isEmpty {
                                Text(partialText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    } header: {
                        Text("Voortgang")
                    }
                }

                // Error sectie
                if let error = errorMsg {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                        }
                    } header: {
                        Text("Fout")
                    }
                }

                // Storage info
                Section {
                    HStack {
                        Text("Totale opslag gebruikt")
                        Spacer()
                        Text(formatBytes(modelStore.totalStorageUsed()))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } header: {
                    Text("Opslag")
                }
            }
            .navigationTitle("Transcriberen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit") {
                        dismiss()
                    }
                    .disabled(isTranscribing || isDownloading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isTranscribing {
                        Button("Annuleer", role: .destructive) {
                            cancelTranscription()
                        }
                    } else {
                        Button("Start") {
                            Task { await startTranscription() }
                        }
                        .disabled(selectedModel?.localURL == nil || isDownloading)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func download() async {
        guard let model = selectedModel else { return }

        isDownloading = true
        errorMsg = nil

        do {
            _ = try await modelStore.downloadModel(id: model.id, allowCellular: allowCellular)
            isDownloading = false
        } catch {
            errorMsg = "Download mislukt: \(error.localizedDescription)"
            isDownloading = false
        }
    }

    private func startTranscription() async {
        guard let model = selectedModel,
              let modelURL = model.localURL else {
            errorMsg = "Model niet gedownload"
            return
        }

        isTranscribing = true
        errorMsg = nil
        progress = 0
        partialText = ""

        do {
            // Maak transcription worker met whisper.cpp engine
            let engine = WhisperCppEngine()
            let worker = TranscriptionWorker(engine: engine)

            // Laad model
            try await worker.ensureModelLoaded(url: modelURL, language: language)

            // Start transcriptie
            let result = try await worker.run(
                fileURL: audioURL,
                language: language
            ) { chunk in
                Task { @MainActor in
                    self.progress = chunk.progress
                    self.partialText = chunk.text
                }
            }

            // Voltooid
            await MainActor.run {
                isTranscribing = false
                onComplete(result)
                dismiss()
            }

        } catch {
            await MainActor.run {
                errorMsg = "Transcriptie mislukt: \(error.localizedDescription)"
                isTranscribing = false
            }
        }
    }

    private func cancelTranscription() {
        // TODO: Implementeer annulering via worker
        isTranscribing = false
        errorMsg = "Transcriptie geannuleerd"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#Preview {
    TranscriptionSheet(
        audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        onComplete: { text in
            print("Transcribed: \(text)")
        }
    )
}
