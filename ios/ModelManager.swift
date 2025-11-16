import CoreML
import Vision

final class ModelManager {
	static let shared = ModelManager()
	private init() {}

	private var vnModel: VNCoreMLModel?

	func loadModel(named modelName: String = "NomaClassifier") throws -> VNCoreMLModel {
		if let cached = vnModel {
			return cached
		}
		// Load dynamically to avoid compile-time generated class requirement
		guard let modelUrl = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") ??
			Bundle.main.url(forResource: modelName, withExtension: "mlmodel") else {
			throw NSError(domain: "Model", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model not found in bundle"])
		}
		let compiledUrl: URL
		if modelUrl.pathExtension == "mlmodel" {
			compiledUrl = try MLModel.compileModel(at: modelUrl)
		} else {
			compiledUrl = modelUrl
		}
		let mlModel = try MLModel(contentsOf: compiledUrl)
		let vn = try VNCoreMLModel(for: mlModel)
		self.vnModel = vn
		return vn
	}
}
