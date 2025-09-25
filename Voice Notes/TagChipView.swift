import SwiftUI

// MARK: - Tag Chip View

struct TagChipView: View {
    let tag: String
    let isRemovable: Bool
    let onRemove: (() -> Void)?
    
    @StateObject private var tagStore = TagStore.shared
    
    init(tag: String, isRemovable: Bool = false, onRemove: (() -> Void)? = nil) {
        self.tag = tag
        self.isRemovable = isRemovable
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.poppins.medium(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            
            if isRemovable, onRemove != nil {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tagColor.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tagColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tagColor: Color {
        tagStore.colorForTag(tag)
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tags: [String]
    let maxVisible: Int
    let isRemovable: Bool
    let onRemove: ((String) -> Void)?
    let onAddTag: (() -> Void)?
    
    init(tags: [String], maxVisible: Int = 3, isRemovable: Bool = false, onRemove: ((String) -> Void)? = nil, onAddTag: (() -> Void)? = nil) {
        self.tags = tags
        self.maxVisible = maxVisible
        self.isRemovable = isRemovable
        self.onRemove = onRemove
        self.onAddTag = onAddTag
    }
    
    var body: some View {
        if !tags.isEmpty || onAddTag != nil {
            LazyVStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 120))], alignment: .leading, spacing: 6) {
                    ForEach(visibleTags, id: \.self) { tag in
                        TagChipView(
                            tag: tag,
                            isRemovable: isRemovable,
                            onRemove: isRemovable ? { onRemove?(tag) } : nil
                        )
                        .contextMenu {
                            if isRemovable {
                                Button("Remove Tag", role: .destructive) {
                                    onRemove?(tag)
                                }
                            }
                        }
                    }
                    
                    if hiddenTagsCount > 0 {
                        Text("+\(hiddenTagsCount)")
                            .font(.poppins.medium(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if let onAddTag = onAddTag {
                        Button(action: onAddTag) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Add Tag")
                                    .font(.poppins.medium(size: 12))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.blue.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var visibleTags: [String] {
        Array(tags.prefix(maxVisible))
    }
    
    private var hiddenTagsCount: Int {
        max(0, tags.count - maxVisible)
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    @Binding var isPresented: Bool
    let onAddTag: (String) -> Void
    
    @StateObject private var tagStore = TagStore.shared
    @State private var newTagText = ""
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // New tag input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add New Tag")
                        .font(.poppins.semiBold(size: 16))
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter tag name", text: $newTagText)
                            .font(.poppins.regular(size: 16))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                addNewTag()
                            }
                        
                        Button("Add") {
                            addNewTag()
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // Suggestions
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions")
                            .font(.poppins.semiBold(size: 16))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 140))], alignment: .leading, spacing: 8) {
                            ForEach(suggestions, id: \.self) { tag in
                                Button(action: { addExistingTag(tag) }) {
                                    TagChipView(tag: tag)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // All available tags
                if !availableTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Tags")
                            .font(.poppins.semiBold(size: 16))
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 140))], alignment: .leading, spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button(action: { addExistingTag(tag) }) {
                                        TagChipView(tag: tag)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onChange(of: newTagText) { oldValue, newValue in
            searchText = newValue
        }
    }
    
    private var suggestions: [String] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return tagStore.suggest(prefix: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private var availableTags: [String] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allTags = tagStore.all()
        
        if search.isEmpty {
            return allTags
        }
        
        return allTags.filter { tag in
            tag.lowercased().contains(search) && !suggestions.contains(tag)
        }
    }
    
    private func addNewTag() {
        let cleanTag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTag.isEmpty && cleanTag.count <= 32 else { return }
        
        onAddTag(cleanTag)
        newTagText = ""
        isPresented = false
    }
    
    private func addExistingTag(_ tag: String) {
        onAddTag(tag)
        isPresented = false
    }
}

// MARK: - Tag Filter Sheet

struct TagFilterSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedTags: Set<String>
    
    @StateObject private var tagStore = TagStore.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
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
                
                // Selected tags
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected (\(selectedTags.count))")
                            .font(.poppins.semiBold(size: 16))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 140))], alignment: .leading, spacing: 8) {
                            ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                TagChipView(
                                    tag: tag,
                                    isRemovable: true,
                                    onRemove: { selectedTags.remove(tag) }
                                )
                            }
                        }
                    }
                }
                
                // Available tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Tags")
                        .font(.poppins.semiBold(size: 16))
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 140))], alignment: .leading, spacing: 8) {
                            ForEach(filteredTags, id: \.self) { tag in
                                Button(action: { 
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }) {
                                    TagChipView(tag: tag)
                                        .opacity(selectedTags.contains(tag) ? 0.5 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filter by Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedTags.removeAll()
                    }
                    .disabled(selectedTags.isEmpty)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var filteredTags: [String] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allTags = tagStore.all()
        
        if search.isEmpty {
            return allTags.filter { !selectedTags.contains($0) }
        }
        
        return allTags.filter { tag in
            tag.lowercased().contains(search) && !selectedTags.contains(tag)
        }
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 20) {
        TagChipView(tag: "client")
        TagChipView(tag: "urgent", isRemovable: true) {
            print("Remove tag")
        }
        
        TagRowView(
            tags: ["client", "urgent", "meeting", "follow-up", "design"],
            maxVisible: 3,
            isRemovable: true,
            onRemove: { tag in print("Remove \(tag)") },
            onAddTag: { print("Add tag") }
        )
    }
    .padding()
}