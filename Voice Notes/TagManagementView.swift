import SwiftUI

// MARK: - Tag Management View

struct TagManagementView: View {
    @StateObject private var tagStore = TagStore.shared
    @ObservedObject private var recordingsManager = RecordingsManager.shared
    @EnvironmentObject private var documentStore: DocumentStore
    
    @State private var showingRenameAlert = false
    @State private var showingMergeSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedTag = ""
    @State private var newTagName = ""
    @State private var mergeIntoTag = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if tagStore.all().isEmpty {
                    emptyStateView
                } else {
                    tagListView
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Rename Tag", isPresented: $showingRenameAlert) {
            TextField("New name", text: $newTagName)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            Button("Cancel", role: .cancel) {
                resetAlertState()
            }
            
            Button("Rename") {
                renameTag()
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Rename '\(selectedTag)' to a new name. This will update all recordings and lists using this tag.")
        }
        .alert("Delete Tag", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                resetAlertState()
            }
            
            Button("Delete", role: .destructive) {
                deleteTag()
            }
        } message: {
            Text("Delete '\(selectedTag)'? This will remove it from \(tagUsageCount(selectedTag)) item(s). This action cannot be undone.")
        }
        .sheet(isPresented: $showingMergeSheet) {
            TagMergeSheet(
                sourceTag: selectedTag,
                availableTags: tagStore.all().filter { $0.lowercased() != selectedTag.lowercased() },
                onMerge: { fromTag, intoTag in
                    tagStore.merge(from: fromTag, into: intoTag)
                    resetAlertState()
                }
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tag.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Tags Yet")
                    .font(.poppins.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Tags will appear here as you add them to your recordings and lists. Use tags to organize and find your content quickly.")
                    .font(.poppins.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tagListView: some View {
        List {
            Section(header: Text("All Tags (\(tagStore.all().count))")) {
                ForEach(tagStore.all().sorted(), id: \.self) { tag in
                    TagManagementRow(
                        tag: tag,
                        usageCount: tagUsageCount(tag),
                        onRename: {
                            selectedTag = tag
                            newTagName = tag
                            showingRenameAlert = true
                        },
                        onMerge: {
                            selectedTag = tag
                            showingMergeSheet = true
                        },
                        onDelete: {
                            selectedTag = tag
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func tagUsageCount(_ tag: String) -> Int {
        let recordingCount = recordingsManager.recordings.filter { recording in
            recording.tags.contains { $0.lowercased() == tag.lowercased() }
        }.count
        
        let documentCount = documentStore.documents.filter { document in
            document.tags.contains { $0.lowercased() == tag.lowercased() }
        }.count
        
        return recordingCount + documentCount
    }
    
    private func renameTag() {
        let cleanName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        tagStore.rename(old: selectedTag, new: cleanName)
        resetAlertState()
    }
    
    private func deleteTag() {
        tagStore.remove(selectedTag)
        resetAlertState()
    }
    
    private func resetAlertState() {
        selectedTag = ""
        newTagName = ""
        mergeIntoTag = ""
    }
}

// MARK: - Tag Management Row

struct TagManagementRow: View {
    let tag: String
    let usageCount: Int
    let onRename: () -> Void
    let onMerge: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var tagStore = TagStore.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag chip
            TagChipView(tag: tag)
            
            Spacer()
            
            // Usage count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(usageCount)")
                    .font(.poppins.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(usageCount == 1 ? "item" : "items")
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                onRename()
            }
            
            if usageCount > 0 {
                Button("Merge Into...", systemImage: "arrow.triangle.merge") {
                    onMerge()
                }
            }
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Tag Merge Sheet

struct TagMergeSheet: View {
    let sourceTag: String
    let availableTags: [String]
    let onMerge: (String, String) -> Void
    
    @State private var selectedTargetTag = ""
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header info
                VStack(spacing: 8) {
                    Text("Merge Tag")
                        .font(.poppins.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        TagChipView(tag: sourceTag)
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        Text("Select target tag")
                            .font(.poppins.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("All items with '\(sourceTag)' will be tagged with the target tag instead.")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search tags", text: $searchText)
                        .font(.poppins.regular(size: 16))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                
                // Available tags
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 160))], spacing: 12) {
                        ForEach(filteredTags, id: \.self) { tag in
                            Button(action: { selectedTargetTag = tag }) {
                                TagChipView(tag: tag)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedTargetTag == tag ? .blue : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle("Merge Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        onMerge(sourceTag, selectedTargetTag)
                        dismiss()
                    }
                    .disabled(selectedTargetTag.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var filteredTags: [String] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if search.isEmpty {
            return availableTags.sorted()
        }
        
        return availableTags.filter { tag in
            tag.lowercased().contains(search)
        }.sorted()
    }
}

// MARK: - Preview

#Preview {
    TagManagementView()
        .environmentObject(DocumentStore())
}