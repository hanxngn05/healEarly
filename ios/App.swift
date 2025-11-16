import SwiftUI

@main
struct NomaApp: App {
	@StateObject private var appState = AppState()
	var body: some Scene {
		WindowGroup {
			CameraView()
				.environmentObject(appState)
		}
	}
}
