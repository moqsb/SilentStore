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
                continuation.resume(returning: results?.first?.identifier)
            }
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try? handler.perform([request])
        }
    }
}
