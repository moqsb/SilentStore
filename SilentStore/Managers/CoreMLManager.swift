import Foundation
import Vision
import CoreML

final class CoreMLManager {
    static let shared = CoreMLManager()

    func classifyImage(_ imageData: Data) async -> String? {
        guard let modelURL = Bundle.main.url(forResource: "ImageClassifier", withExtension: "mlmodelc") else {
            return nil
        }
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, _ in
                let results = request.results as? [VNClassificationObservation]
                let identifier = results?.first?.identifier
                continuation.resume(returning: self.normalizedCategory(from: identifier))
            }
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try? handler.perform([request])
        }
    }

    private func normalizedCategory(from identifier: String?) -> String? {
        guard let identifier else { return nil }
        let lower = identifier.lowercased()
        if lower.contains("person") || lower.contains("face") || lower.contains("people") {
            return "People"
        }
        if lower.contains("food") || lower.contains("meal") || lower.contains("drink") {
            return "Food"
        }
        if lower.contains("document") || lower.contains("paper") || lower.contains("text") {
            return "Documents"
        }
        if lower.contains("receipt") || lower.contains("invoice") {
            return "Receipts"
        }
        if lower.contains("animal") || lower.contains("pet") || lower.contains("dog") || lower.contains("cat") {
            return "Pets"
        }
        if lower.contains("plant") || lower.contains("tree") || lower.contains("mountain") || lower.contains("sky") || lower.contains("sea") {
            return "Nature"
        }
        if lower.contains("car") || lower.contains("vehicle") || lower.contains("transport") {
            return "Vehicles"
        }
        if lower.contains("screenshot") || lower.contains("screen") || lower.contains("display") {
            return "Screenshots"
        }
        return identifier
    }
}
