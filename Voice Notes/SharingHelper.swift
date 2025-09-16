import Foundation
import SwiftUI
import UIKit

extension Recording {
    func makeShareText() -> String {
        return Voice_Notes.makeShareText(for: self)
    }
    
    var hasContentToShare: Bool {
        return (transcript != nil && !transcript!.isEmpty) || (summary != nil && !summary!.isEmpty)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct ShareButton: View {
    let recording: Recording
    @State private var showingShareSheet = false
    
    var body: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(!recording.hasContentToShare)
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: [recording.makeShareText()])
        }
    }
}

struct CopyButton: View {
    let recording: Recording
    @State private var showingCopiedFeedback = false
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = recording.makeShareText()
            showingCopiedFeedback = true
            
            // Hide feedback after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingCopiedFeedback = false
            }
        }) {
            Label(showingCopiedFeedback ? "Copied!" : "Copy", systemImage: showingCopiedFeedback ? "checkmark" : "doc.on.doc")
                .foregroundColor(showingCopiedFeedback ? .green : .primary)
        }
        .disabled(!recording.hasContentToShare)
    }
}
