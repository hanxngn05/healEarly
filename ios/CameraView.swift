import AVFoundation
import SwiftUI
import Vision
import CoreImage

struct CameraView: View {
	@StateObject private var model = CameraViewModel()
	@State private var showQuestionnaire = false
	@State private var showResult = false
	@State private var showLanguage = false
	@EnvironmentObject private var app: AppState

	var body: some View {
		ZStack {
			LinearGradient(colors: [Color(red: 0.04, green: 0.15, blue: 0.25), Color(red: 0.03, green: 0.10, blue: 0.18)], startPoint: .top, endPoint: .bottom)
				.ignoresSafeArea()
			CameraPreview(session: model.session)
				.ignoresSafeArea()
				.onAppear { model.start() }
				.onDisappear { model.stop() }

			VStack {
				HStack {
					Button {
						showLanguage = true
					} label: {
						Image(systemName: "globe")
							.font(.system(size: 18, weight: .semibold))
							.padding(10)
							.background(.ultraThinMaterial)
							.clipShape(Circle())
					}
					.padding(.top, 16)
					.padding(.leading, 16)
					Spacer()
					if !model.isCollecting && model.finalUlcerationScore == 0 {
						Button {
							Haptics.tap()
							model.beginFiveSecondCapture()
						} label: {
							HStack(spacing: 8) {
								Image(systemName: "camera.viewfinder")
								Text(L.t(.startScan, app.language))
							}
							.font(.system(size: 16, weight: .semibold))
							.foregroundColor(.white)
							.padding(.horizontal, 14)
							.padding(.vertical, 10)
							.background(Color(red: 0.05, green: 0.25, blue: 0.45))
							.clipShape(Capsule())
						}
						.padding(.top, 16)
						.padding(.trailing, 16)
					}
				}
				Spacer()
				VStack(spacing: 8) {
					if model.isCollecting {
						Text(L.t(.holdSteady, app.language))
							.font(.headline)
							.foregroundColor(.white)
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.background(Color.white.opacity(0.15))
							.clipShape(Capsule())
						ProgressView(value: model.captureProgress)
							.progressViewStyle(.linear)
							.frame(maxWidth: 320)
							.tint(.white)
							.padding(.top, 6)
					} else if model.finalUlcerationScore > 0 && !showResult && !showQuestionnaire {
						Button {
							Haptics.tap()
							showQuestionnaire = true
						} label: {
							Text(L.t(.answerQuestions, app.language))
								.font(.headline)
								.foregroundColor(.white)
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
								.background(Color(red: 0.05, green: 0.25, blue: 0.45))
								.clipShape(Capsule())
						}
					} else {
						Text("Ready")
							.font(.headline)
							.foregroundColor(.white)
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.background(Color.white.opacity(0.15))
							.clipShape(Capsule())
					}
				}
				.padding(.bottom, 24)
			}
		}
		// status bar kept visible for classic iOS look
		.fullScreenCover(isPresented: $showQuestionnaire, onDismiss: {
			showResult = true
		}) {
			QuestionnaireView(model: model, onDone: {
				showQuestionnaire = false
				showResult = true
			})
			.environmentObject(app)
			.ignoresSafeArea()
			.presentationBackground(.clear)
			.presentationCornerRadius(0)
		}
		.fullScreenCover(isPresented: $showResult) {
			ResultView(risk: model.riskScore) {
				showResult = false
				model.resetFlow()
			}
			.environmentObject(app)
			.ignoresSafeArea()
			.presentationBackground(.clear)
			.presentationCornerRadius(0)
		}
		.sheet(isPresented: $showLanguage) {
			LanguagePickerView(isPresented: $showLanguage)
				.environmentObject(app)
				.presentationDetents([.fraction(0.35), .medium])
				.presentationDragIndicator(.visible)
				.presentationCornerRadius(16)
		}
	}
}

final class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
	let session = AVCaptureSession()
	private let videoOutput = AVCaptureVideoDataOutput()
	private let queue = DispatchQueue(label: "camera.queue")
	private let ciContext = CIContext()

	@Published var predictionLabel: String = "—"
	@Published var predictionConfidence: Double = 0.0
	@Published var riskScore: Double = 0.0
	@Published var visionNomaProbability: Double = 0.0
	@Published var finalUlcerationScore: Double = 0.0
	@Published var isCollecting: Bool = false
	@Published var captureProgress: Double = 0.0

	private var request: VNCoreMLRequest?
	private var throttle = false
	private var demoMode = false
	private var answers = QuestionnaireAnswers()
	private var accumProbSum: Double = 0.0
	private var accumProbCount: Int = 0
	private var progressTimer: Timer?

	override init() {
		super.init()
		configureSession()
		do {
			let vnModel = try ModelManager.shared.loadModel(named: "NomaClassifier")
			request = VNCoreMLRequest(model: vnModel) { [weak self] request, _ in
				self?.handle(results: request.results)
			}
			request?.imageCropAndScaleOption = .centerCrop
		} catch {
			print("Model load error:", error)
			demoMode = true
			DispatchQueue.main.async {
				self.predictionLabel = "Demo mode (no model)"
				self.predictionConfidence = 0.0
			}
		}
	}

	func start() {
		let status = AVCaptureDevice.authorizationStatus(for: .video)
		switch status {
		case .authorized:
			queue.async { [weak self] in self?.session.startRunning() }
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
				guard let self = self else { return }
				if granted {
					self.queue.async { self.session.startRunning() }
				} else {
					DispatchQueue.main.async {
						self.predictionLabel = "Enable Camera in Settings to continue"
						self.predictionConfidence = 0.0
					}
				}
			}
		default:
			DispatchQueue.main.async {
				self.predictionLabel = "Enable Camera in Settings to continue"
				self.predictionConfidence = 0.0
			}
		}
	}

	func stop() {
		queue.async { [weak self] in self?.session.stopRunning() }
	}

	func resetFlow() {
		finalUlcerationScore = 0.0
		riskScore = 0.0
		answers = QuestionnaireAnswers()
	}

	private func configureSession() {
		session.beginConfiguration()
		session.sessionPreset = .hd1280x720

		guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
			  let input = try? AVCaptureDeviceInput(device: device),
			  session.canAddInput(input) else {
			print("Failed to create camera input")
			session.commitConfiguration()
			return
		}
		session.addInput(input)

		videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
		videoOutput.setSampleBufferDelegate(self, queue: queue)
		videoOutput.alwaysDiscardsLateVideoFrames = true
		guard session.canAddOutput(videoOutput) else {
			print("Cannot add video output")
			session.commitConfiguration()
			return
		}
		session.addOutput(videoOutput)
		if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
			connection.videoOrientation = .portrait
		}

		session.commitConfiguration()
	}

	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
		// Basic throttling to reduce compute
		if throttle { return }
		throttle = true
		defer { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.throttle = false } }

		if demoMode || request == nil {
			demoPredict(pixelBuffer: pixelBuffer)
			return
		}

		if let request = request {
			let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
			do {
				try handler.perform([request])
			} catch {
				print("Vision error:", error)
			}
		}
	}

	private func handle(results: [Any]?) {
		guard let observations = results as? [VNClassificationObservation], let top = observations.first else { return }
		let nomaProb: Double
		if top.identifier.lowercased() == "noma" {
			nomaProb = Double(top.confidence)
		} else {
			nomaProb = Double(1.0 - top.confidence)
		}
		DispatchQueue.main.async {
			let safeConf = max(0.0, min(1.0, Double(top.confidence)))
			self.predictionLabel = "\(top.identifier) \(String(format: "%.0f%%", safeConf * 100))"
			self.predictionConfidence = safeConf
			self.visionNomaProbability = max(0.0, min(1.0, nomaProb))
			if self.isCollecting {
				self.accumProbSum += self.visionNomaProbability
				self.accumProbCount += 1
			}
			self.updateRiskScore()
		}
	}

	private func demoPredict(pixelBuffer: CVPixelBuffer) {
		let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
		let extent = ciImage.extent
		guard let filter = CIFilter(name: "CIAreaAverage") else { return }
		filter.setValue(ciImage, forKey: kCIInputImageKey)
		filter.setValue(CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height), forKey: kCIInputExtentKey)
		guard let outputImage = filter.outputImage else { return }

		var bitmap = [UInt8](repeating: 0, count: 4)
		ciContext.render(outputImage,
						 toBitmap: &bitmap,
						 rowBytes: 4,
						 bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
						 format: .RGBA8,
						 colorSpace: CGColorSpaceCreateDeviceRGB())
		let r = Double(bitmap[0]) / 255.0
		let g = Double(bitmap[1]) / 255.0
		let b = Double(bitmap[2]) / 255.0
		// Approximate brightness
		let brightness = 0.299 * r + 0.587 * g + 0.114 * b
		let isNoma = brightness < 0.5
		let confidence = isNoma ? min(0.9, 1.0 - brightness) : min(0.9, brightness)

		DispatchQueue.main.async {
			let safeConf = max(0.0, min(1.0, confidence))
			self.predictionLabel = isNoma ? "noma \(String(format: "%.0f%%", safeConf * 100))" : "normal \(String(format: "%.0f%%", safeConf * 100))"
			self.predictionConfidence = safeConf
			self.visionNomaProbability = isNoma ? safeConf : (1.0 - safeConf)
			if self.isCollecting {
				self.accumProbSum += self.visionNomaProbability
				self.accumProbCount += 1
			}
			self.updateRiskScore()
		}
	}

	func applyQuestionnaire(_ newAnswers: QuestionnaireAnswers) {
		answers = newAnswers
		updateRiskScore()
	}

	func beginFiveSecondCapture(duration: TimeInterval = 5.0) {
		accumProbSum = 0.0
		accumProbCount = 0
		captureProgress = 0.0
		isCollecting = true
		progressTimer?.invalidate()
		let start = Date()
		progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
			guard let self = self else { return }
			let elapsed = Date().timeIntervalSince(start)
			self.captureProgress = min(1.0, elapsed / duration)
			if elapsed >= duration {
				t.invalidate()
				self.isCollecting = false
				self.finalUlcerationScore = self.accumProbCount > 0 ? (self.accumProbSum / Double(self.accumProbCount)) : 0.0
				self.updateRiskScore()
			}
		}
		RunLoop.main.add(progressTimer!, forMode: .common)
	}

	private func updateRiskScore() {
		// Use the final 5s ulceration score when available; otherwise fall back to live estimate.
		let baseProb = finalUlcerationScore > 0 ? finalUlcerationScore : visionNomaProbability
		let p = max(0.0, min(1.0, baseProb))

		// Conservative fusion: questionnaire only influences when ulceration is reasonably high.
		var score = p
		if p >= 0.6 {
			let scale = max(0.0, p - 0.5) // 0..0.5
			if answers.badBreath { score += 0.20 * scale }
			if answers.badBreath && answers.feverRespOrDiarrhea { score += 0.25 * scale }
			if answers.badBreath && answers.mealsPerDay < 3 { score += 0.15 * scale }
			if answers.gumPain { score += 0.05 * scale }
			if answers.excessiveSalivation { score += 0.02 * scale }
		}
		riskScore = max(0.0, min(1.0, score))
	}
}

struct CameraPreview: UIViewRepresentable {
	let session: AVCaptureSession

	func makeUIView(context: Context) -> PreviewView {
		let view = PreviewView()
		view.videoPreviewLayer.session = session
		view.videoPreviewLayer.videoGravity = .resizeAspectFill
		return view
	}

	func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
	override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
	var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
