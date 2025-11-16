import SwiftUI

struct HeroCard: View {
	let title: String
	let subtitle: String
	let colors: [Color]
	let emoji: String

	var body: some View {
		ZStack(alignment: .leading) {
			LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
				.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
			VStack(alignment: .leading, spacing: 6) {
				Text(emoji)
					.font(.system(size: 32))
					.shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
				Text(title)
					.font(.system(size: 26, weight: .bold, design: .rounded))
					.foregroundColor(.white)
				Text(subtitle)
					.font(.subheadline)
					.foregroundColor(.white.opacity(0.9))
			}
			.padding(18)
		}
		.frame(maxWidth: .infinity, minHeight: 110)
		.shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
	}
}

struct GradientProgressBar: View {
	let value: Double // 0...1
	var body: some View {
		GeometryReader { geo in
			let width = geo.size.width * CGFloat(max(0.0, min(1.0, value)))
			ZStack(alignment: .leading) {
				RoundedRectangle(cornerRadius: 12).fill(UITheme.card)
				RoundedRectangle(cornerRadius: 12)
					.fill(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
					.frame(width: width)
					.animation(.easeOut(duration: 0.5), value: width)
			}
		}
		.frame(height: 18)
	}
}

enum Haptics {
	static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

// MARK: - Arc Gauge
struct ArcSegment: Shape {
	let startAngle: Angle
	let endAngle: Angle
	func path(in rect: CGRect) -> Path {
		var p = Path()
		let radius = min(rect.width, rect.height) / 2
		let center = CGPoint(x: rect.midX, y: rect.maxY)
		p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
		return p.strokedPath(.init(lineWidth: radius, lineCap: .butt))
	}
}

struct ArcGaugeView: View {
	let value: Double // 0...1
	private let colors: [Color] = [.red.opacity(0.8), .orange, .yellow, .green, .green.opacity(0.8)]

	private var angle: Angle {
		// map 0..1 -> -90..+90 degrees
		Angle(degrees: -90 + 180 * value)
	}

	var body: some View {
		GeometryReader { geo in
			let w = geo.size.width
			let h = geo.size.height
			let radius = min(w, h) / 2
			ZStack {
				// segments
				ForEach(0..<5, id: \.self) { i in
					let start = -90 + Double(i) * 36
					let end = start + 36
					ArcSegment(startAngle: .degrees(start), endAngle: .degrees(end))
						.fill(colors[i])
						.opacity(0.85)
				}
				// needle
				Rectangle()
					.fill(Color.black.opacity(0.8))
					.frame(width: 4, height: radius)
					.offset(y: -radius/2)
					.rotationEffect(angle, anchor: .bottom)
				Circle().fill(Color.black.opacity(0.8)).frame(width: 18, height: 18)
			}
			.frame(width: w, height: h, alignment: .center)
		}
	}
}
