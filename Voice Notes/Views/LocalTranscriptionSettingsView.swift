import SwiftUI

struct LocalTranscriptionSettingsView: View {
    @ObservedObject private var modelManager = WhisperModelManager.shared
    @AppStorage("use_local_transcription") private var useLocalTranscription = false
    @State private var showingDownloadConfirmation = false
    @State private var showingCellularWarning = false
    @State private var showingDeleteConfirmation = false
    @State private var modelToDownload: WhisperModelSize?
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var downloadTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Form {
                // Transcription Mode Toggle
                Section {
                    Toggle(isOn: $useLocalTranscription) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use On-Device Transcription")
                                .font(.poppins.headline)
                            Text("Transcribe locally without internet")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Transcription Mode")
                } footer: {
                    if useLocalTranscription {
                        Text("Transcription runs on your device using AI. No data sent to servers. Requires a downloaded model.")
                    } else {
                        Text("Using cloud-based transcription (OpenAI Whisper API)")
                    }
                }

                if useLocalTranscription {
                    // Setup Notice
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Setup Required")
                                    .font(.poppins.subheadline)
                                    .fontWeight(.semibold)
                                Text("Add WhisperKit package to enable model downloads. See LOCAL_TRANSCRIPTION_SETUP.md for instructions.")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Model Selection
                    Section {
                        ForEach(WhisperModelSize.allCases, id: \.self) { model in
                            ModelRow(
                                model: model,
                                isSelected: model == modelManager.selectedModel,
                                isDownloaded: modelManager.isModelDownloaded(model),
                                onSelect: {
                                    selectModel(model)
                                },
                                onDownload: {
                                    initiateDownload(for: model)
                                },
                                onDelete: {
                                    deleteModel(model)
                                }
                            )
                        }
                    } header: {
                        Text("Model Selection")
                    } footer: {
                        Text("Larger models are more accurate but slower. Tiny/Base recommended for most use cases.")
                    }

                    // Download Status - Always visible when downloading
                    if case .downloading(let progress) = modelManager.downloadState,
                       let downloadingModel = modelToDownload {
                        Section {
                            VStack(spacing: 16) {
                                // Title and percentage
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Downloading Model")
                                            .font(.poppins.headline)
                                        Text("\(downloadingModel.displayName) • \(downloadingModel.formattedSize)")
                                            .font(.poppins.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(progress * 100))%")
                                        .font(.poppins.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }

                                // Progress bar
                                VStack(spacing: 8) {
                                    ProgressView(value: progress)
                                        .progressViewStyle(.linear)
                                        .tint(.blue)

                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("Downloading from HuggingFace...")
                                            .font(.poppins.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }

                                // Cancel button
                                Button(action: {
                                    downloadTask?.cancel()
                                    Task { @MainActor in
                                        modelManager.downloadState = .notDownloaded
                                        modelToDownload = nil
                                        showToast("Download cancelled")
                                    }
                                }) {
                                    Label("Cancel Download", systemImage: "xmark.circle.fill")
                                        .font(.poppins.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 8)
                        } header: {
                            Text("Download Progress")
                        }
                    }

                    // Language Selection
                    Section {
                        Picker("Language", selection: $modelManager.selectedLanguage) {
                            ForEach(WhisperLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .onChange(of: modelManager.selectedLanguage) { _, _ in
                            modelManager.savePreferences()
                        }
                    } header: {
                        Text("Language")
                    } footer: {
                        Text("Select the primary language of your recordings. Auto-detect works for most cases.")
                    }

                    // Storage Info
                    Section {
                        HStack {
                            Text("Storage Used")
                            Spacer()
                            Text(formatBytes(modelManager.totalDiskSpaceUsed()))
                                .foregroundColor(.secondary)
                        }

                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete All Models", systemImage: "trash")
                        }
                    } header: {
                        Text("Storage Management")
                    }

                    // Performance Info
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            LocalTranscriptionInfoRow(icon: "cpu", title: "On-Device AI", description: "Runs locally on your device's Neural Engine")
                            LocalTranscriptionInfoRow(icon: "lock.shield", title: "Private", description: "Your recordings never leave your device")
                            LocalTranscriptionInfoRow(icon: "wifi.slash", title: "Offline", description: "Works without internet connection")
                        }
                    } header: {
                        Text("Benefits")
                    }
                }
            }
            .navigationTitle("Local Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Download Model?", isPresented: $showingDownloadConfirmation, presenting: modelToDownload) { model in
                Button("Download \(model.formattedSize)") {
                    downloadModel(model)
                }
                Button("Cancel", role: .cancel) {}
            } message: { model in
                Text("This will download \(model.formattedSize) to your device.")
            }
            .alert("Cellular Connection", isPresented: $showingCellularWarning) {
                Button("Download Anyway") {
                    if let model = modelToDownload {
                        downloadModel(model)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You're on a cellular connection. This model is \(modelToDownload?.formattedSize ?? "large"). Consider using Wi-Fi to avoid data charges.")
            }
            .alert("Delete All Models?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    do {
                        try modelManager.deleteAllModels()
                        showToast("All models deleted")
                    } catch {
                        showToast("Failed to delete models")
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up \(formatBytes(modelManager.totalDiskSpaceUsed())) of storage.")
            }
            .overlay(alignment: .bottom) {
                if showingToast {
                    LocalTranscriptionToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Actions

    private func selectModel(_ model: WhisperModelSize) {
        modelManager.selectedModel = model
        modelManager.savePreferences()
        modelManager.checkModelStatus()
        showToast("\(model.displayName) selected")
    }

    private func initiateDownload(for model: WhisperModelSize) {
        modelToDownload = model

        // Check if should warn about cellular
        if modelManager.shouldWarnAboutCellular(for: model) {
            showingCellularWarning = true
        } else {
            showingDownloadConfirmation = true
        }
    }

    private func downloadModel(_ model: WhisperModelSize) {
        // Cancel any existing download
        downloadTask?.cancel()

        // Start new download
        downloadTask = Task {
            print("🎬 Starting download for \(model.displayName)")

            do {
                try await modelManager.downloadModel(model)

                // Check if cancelled
                guard !Task.isCancelled else {
                    print("⚠️ Download was cancelled")
                    return
                }

                await MainActor.run {
                    print("✅ Download completed successfully")
                    showToast("\(model.displayName) downloaded successfully")
                    downloadTask = nil
                    modelToDownload = nil

                    // Notify user
                    NotificationManager.shared.notifyModelDownloadComplete(
                        modelName: model.displayName,
                        modelSize: model.formattedSize
                    )
                }
            } catch {
                print("❌ Download failed: \(error.localizedDescription)")

                await MainActor.run {
                    showToast("Download failed: \(error.localizedDescription)")
                    downloadTask = nil

                    // Notify user of failure
                    if let modelToDownload = modelToDownload {
                        NotificationManager.shared.notifyModelDownloadFailed(
                            modelName: modelToDownload.displayName,
                            error: error.localizedDescription
                        )
                    }

                    modelToDownload = nil
                }
            }
        }
    }

    private func deleteModel(_ model: WhisperModelSize) {
        do {
            try modelManager.deleteModel(model)
            showToast("\(model.displayName) deleted")
        } catch {
            showToast("Failed to delete model")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showingToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingToast = false
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: WhisperModelSize
    let isSelected: Bool
    let isDownloaded: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    @ObservedObject private var modelManager = WhisperModelManager.shared

    private var isDownloading: Bool {
        if case .downloading = modelManager.downloadState,
           modelManager.selectedModel == model {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
                .onTapGesture {
                    if isDownloaded {
                        onSelect()
                    }
                }

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .font(.poppins.headline)

                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if isDownloading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                Text(model.description)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)

                Text(model.formattedSize)
                    .font(.poppins.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            if isDownloading {
                Text("Downloading...")
                    .font(.poppins.caption)
                    .foregroundColor(.blue)
            } else if isDownloaded {
                Menu {
                    if !isSelected {
                        Button("Select") {
                            onSelect()
                        }
                    }
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isDownloaded || !isSelected ? 1.0 : 0.6)
    }
}

// MARK: - Info Row

private struct LocalTranscriptionInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Toast View

private struct LocalTranscriptionToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.poppins.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.bottom, 50)
    }
}

// MARK: - Preview

#Preview {
    LocalTranscriptionSettingsView()
}
