import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct PhotoPickerSheet: UIViewControllerRepresentable {
    let onComplete: ([ImportResult]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
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
        private let onComplete: ([ImportResult]) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping ([ImportResult]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onCancel()
                return
            }
            let group = DispatchGroup()
            let lock = NSLock()
            var collected: [ImportResult] = []

            for result in results {
                let provider = result.itemProvider
                let assetId = result.assetIdentifier

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }
                        guard let image = object as? UIImage,
                              let data = image.jpegData(compressionQuality: 0.9) else {
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
                        lock.lock()
                        collected.append(result)
                        lock.unlock()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        defer { group.leave() }
                        guard let url = url,
                              let data = try? Data(contentsOf: url) else {
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
                        lock.lock()
                        collected.append(result)
                        lock.unlock()
                    }
                }
            }

            group.notify(queue: .main) {
                if collected.isEmpty {
                    self.onCancel()
                } else {
                    self.onComplete(collected)
                }
            }
        }
    }
}

struct DocumentPickerSheet: UIViewControllerRepresentable {
    let onComplete: ([ImportResult]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onComplete: ([ImportResult]) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping ([ImportResult]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else {
                onCancel()
                return
            }
            var results: [ImportResult] = []
            for url in urls {
                let securityEnabled = url.startAccessingSecurityScopedResource()
                defer {
                    if securityEnabled {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                guard let data = try? Data(contentsOf: url) else {
                    continue
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
                results.append(result)
            }
            if results.isEmpty {
                onCancel()
            } else {
                onComplete(results)
            }
        }
    }
}
