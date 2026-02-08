import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct PhotoPickerSheet: UIViewControllerRepresentable {
    let onComplete: (ImportResult) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: (ImportResult) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping (ImportResult) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onCancel()
                return
            }

            let provider = result.itemProvider
            let assetId = result.assetIdentifier

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.9) else {
                        self.onCancel()
                        return
                    }
                    let name = (provider.suggestedName ?? "Photo") + ".jpg"
                    let result = ImportResult(
                        data: data,
                        originalName: name,
                        mimeType: "image/jpeg",
                        isImage: true,
                        assetIdentifier: assetId
                    )
                    DispatchQueue.main.async { self.onComplete(result) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url = url,
                          let data = try? Data(contentsOf: url) else {
                        self.onCancel()
                        return
                    }
                    let name = provider.suggestedName ?? url.lastPathComponent
                    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "video/mp4"
                    let result = ImportResult(
                        data: data,
                        originalName: name,
                        mimeType: mime,
                        isImage: false,
                        assetIdentifier: assetId
                    )
                    DispatchQueue.main.async { self.onComplete(result) }
                }
            } else {
                onCancel()
            }
        }
    }
}

struct DocumentPickerSheet: UIViewControllerRepresentable {
    let onComplete: (ImportResult) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onComplete: (ImportResult) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping (ImportResult) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }

            let securityEnabled = url.startAccessingSecurityScopedResource()
            defer {
                if securityEnabled {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else {
                onCancel()
                return
            }

            let name = url.lastPathComponent
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let result = ImportResult(
                data: data,
                originalName: name,
                mimeType: mime,
                isImage: false,
                assetIdentifier: nil
            )
            onComplete(result)
        }
    }
}
