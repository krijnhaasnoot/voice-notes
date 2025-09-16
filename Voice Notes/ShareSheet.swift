import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {
        // Update activity items when they change
        // Note: UIActivityViewController doesn't support updating items after creation
        // But SwiftUI will recreate the controller when items change
    }
}