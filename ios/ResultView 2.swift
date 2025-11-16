import SwiftUI

struct ResultView: View {
	let risk: Double
	var onDone: (() -> Void)?
	@EnvironmentObject private var app: AppState

	private var clamped: Double { max(0.0, min(1.0, risk)) }

	private var verdict: String {
		switch clamped {
		case ..<0.2: return "Very not likely"
		case ..<0.4: return "Not likely"
		case ..<0.6: return "Neutral"
		case ..<0.8: return "Likely"
		default: return "Very likely"
		}
	}

	private var suggestion: String? {
		return clamped >= 0.6 ? "Suggestion: consider seeing a clinician for evaluation." : nil
	}

	private var barColor: Color {
		switch clamped {
		case ..<0.2: return Color.green.opacity(0.8)
		case ..<0.4: return Color.green
		case ..<0.6: return Color.yellow
		case ..<0.8: return Color.orange
		default: return Color.red
		}
	}

	var body: some View {
		GeometryReader { proxy in
			ZStack {
				UITheme.background().ignoresSafeArea()
				VStack(spacing: 26) {
					// Hero card with large gradient and emoji
					ZStack(alignment: .leading) {
						LinearGradient(colors: [UITheme.sky, UITheme.violet],
									   startPoint: .topLeading, endPoint: .bottomTrailing)
							.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
						VStack(alignment: .leading, spacing: 8) {
							Text(clamped >= 0.6 ? "🧑‍⚕️" : "😊")
								.font(.system(size: 34))
								.shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
							Text(L.t(.screeningResult, app.language))
								.font(.system(size: 28, weight: .bold))
								.foregroundColor(.white)
							Text(clamped >= 0.6 ? L.t(.seeClinician, app.language) : L.t(.lowRisk, app.language))
								.font(.title3.weight(.medium))
								.foregroundColor(.white.opacity(0.92))
						}
						.padding(22)
					}
					.frame(width: proxy.size.width - 32, height: min(280, proxy.size.height * 0.35))
					.shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)

					// Combined risk card
					VStack(alignment: .leading, spacing: 14) {
						Text(L.t(.combinedRisk, app.language))
							.font(.headline)
							.foregroundColor(UITheme.textPrimary)
						GradientProgressBar(value: clamped)
							.frame(width: proxy.size.width - 32)
						HStack(spacing: 8) {
							Text("\(Int(clamped * 100))%")
								.font(.headline).foregroundColor(UITheme.textPrimary)
							Text("•")
								.foregroundColor(UITheme.textSecondary)
							Text(verdict)
								.font(.subheadline).foregroundColor(UITheme.textSecondary)
						}
					}
					.padding(16)
					.themedCard()
					.frame(width: proxy.size.width - 32)

					Spacer()

					Button {
						Haptics.tap()
						onDone?()
					} label: {
						Text(L.t(.done, app.language))
					}
					.buttonStyle(FilledCapsuleButtonStyle())
					.padding(.bottom, 24)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
			}
		}
	}
}
