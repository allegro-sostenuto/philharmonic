import SwiftUI
import UIKit

/// Native share presentation adapted from the user's recovered diagnostics bundle.
struct DiagnosticsShareSheet: UIViewControllerRepresentable {
    let reportURL: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [reportURL], applicationActivities: nil)
        controller.view.accessibilityIdentifier = "debug-share-sheet"
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct DiagnosticsSaveSheet: UIViewControllerRepresentable {
    let reportURL: URL
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [reportURL], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onDismiss() }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onDismiss() }
    }
}
