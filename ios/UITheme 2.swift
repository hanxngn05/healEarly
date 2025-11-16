import SwiftUI

enum UITheme {
	static let navyDark = Color(red: 0.03, green: 0.10, blue: 0.18)
	static let navy = Color(red: 0.04, green: 0.15, blue: 0.25)
	static let mint = Color(red: 0.74, green: 0.93, blue: 0.90)
	static let sky = Color(red: 0.42, green: 0.78, blue: 0.98)
	static let violet = Color(red: 0.58, green: 0.54, blue: 0.98)
	static let green = Color(red: 0.17, green: 0.74, blue: 0.36)
	static let greenDark = Color(red: 0.09, green: 0.55, blue: 0.24)
	static let card = Color.white.opacity(0.14)
	static let cardStroke = Color.white.opacity(0.22)
	static let textPrimary = Color.white
	static let textSecondary = Color.white.opacity(0.85)

	static func background() -> some View {
		LinearGradient(colors: [navy, navyDark], startPoint: .top, endPoint: .bottom)
	}
}

struct FilledCapsuleButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.foregroundColor(.white)
			.padding(.horizontal, 22)
			.padding(.vertical, 12)
			.background(configuration.isPressed ? UITheme.greenDark : UITheme.green)
			.clipShape(Capsule())
			.shadow(color: UITheme.green.opacity(0.35), radius: configuration.isPressed ? 2 : 8, x: 0, y: configuration.isPressed ? 1 : 6)
			.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
			.animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
	}
}

struct CardStyle: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding()
			.background(UITheme.card)
			.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.stroke(UITheme.cardStroke, lineWidth: 1)
			)
			.shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
	}
}

extension View {
	func themedCard() -> some View { modifier(CardStyle()) }
}
