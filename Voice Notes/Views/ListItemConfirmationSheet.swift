import SwiftUI

struct ListItemConfirmationSheet: View {
    let detectionResult: DetectionResult
    let onConfirm: ([DetectedListItem]) -> Void
    let onDismiss: () -> Void

    @State private var editableItems: [EditableItem] = []
    @State private var showingAddItem = false
    @State private var newItemText = ""

    struct EditableItem: Identifiable {
        let id: UUID
        var text: String
        let originalItem: DetectedListItem

        init(from item: DetectedListItem) {
            self.id = item.id
            self.text = item.text
            self.originalItem = item
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: detectionResult.listType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient)

                    Text("List Items Detected!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("I noticed you mentioned a \(detectionResult.listType.rawValue.lowercased()). Would you like to save these items?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // List items
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($editableItems) { $item in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)

                                TextField("Item", text: $item.text)
                                    .textFieldStyle(.plain)
                                    .font(.body)

                                Button {
                                    withAnimation {
                                        editableItems.removeAll { $0.id == item.id }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.body)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        // Add new item button
                        if showingAddItem {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)

                                TextField("New item", text: $newItemText, onCommit: addNewItem)
                                    .textFieldStyle(.plain)
                                    .font(.body)

                                Button(action: addNewItem) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.body)
                                }
                                .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        } else {
                            Button {
                                withAnimation {
                                    showingAddItem = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add Another Item")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        confirmItems()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save \(editableItems.count) Item\(editableItems.count == 1 ? "" : "s")")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(editableItems.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(editableItems.isEmpty)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            editableItems = detectionResult.items.map { EditableItem(from: $0) }
        }
    }

    private func addNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Create a new detected item
        let newItem = DetectedListItem(
            text: trimmed,
            listType: detectionResult.listType,
            confidence: .high
        )

        withAnimation {
            editableItems.append(EditableItem(from: newItem))
            newItemText = ""
            showingAddItem = false
        }
    }

    private func confirmItems() {
        let confirmedItems = editableItems.map { editable in
            DetectedListItem(
                text: editable.text,
                listType: editable.originalItem.listType,
                confidence: editable.originalItem.confidence
            )
        }
        onConfirm(confirmedItems)
    }
}

#Preview {
    ListItemConfirmationSheet(
        detectionResult: DetectionResult(
            items: [
                DetectedListItem(text: "Buy milk", listType: .shopping, confidence: .high),
                DetectedListItem(text: "Call dentist", listType: .todo, confidence: .high),
                DetectedListItem(text: "Research new laptop", listType: .ideas, confidence: .medium)
            ],
            listType: .todo,
            hasListIntent: true
        ),
        onConfirm: { items in
            print("Confirmed \(items.count) items")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
