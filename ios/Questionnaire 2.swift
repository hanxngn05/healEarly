import SwiftUI

struct QuestionnaireAnswers {
	var badBreath: Bool = false
	var feverRespOrDiarrhea: Bool = false
	var mealsPerDay: Int = 3
	var gumPain: Bool = false
	var excessiveSalivation: Bool = false
}

struct QuestionnaireView: View {
	@Environment(\.dismiss) private var dismiss
	@ObservedObject var model: CameraViewModel
	@State private var answers = QuestionnaireAnswers()
	var onDone: (() -> Void)? = nil
	@EnvironmentObject private var app: AppState

	var body: some View {
		ZStack {
			UITheme.background()
				.ignoresSafeArea()
			ScrollView {
				VStack(spacing: 18) {
					HeroCard(title: L.t(.quickQuestions, app.language),
							 subtitle: L.t(.refineSubtitle, app.language),
							 colors: [UITheme.sky, UITheme.violet],
							 emoji: "🦷")
						.padding(.top, 6)

					CardToggle(title: L.t(.badBreath, app.language), subtitle: "Noticeable halitosis", emoji: "🫢", isOn: $answers.badBreath)
					CardToggle(title: L.t(.recentIllness, app.language), subtitle: "Within the last 3 months", emoji: "🤒", isOn: $answers.feverRespOrDiarrhea)
					CardToggle(title: L.t(.gumPain, app.language), subtitle: "Hurts when eating or touching", emoji: "😣", isOn: $answers.gumPain)
					CardToggle(title: L.t(.excessiveSalivation, app.language), subtitle: "Spontaneous drooling", emoji: "💧", isOn: $answers.excessiveSalivation)

					VStack(alignment: .leading, spacing: 10) {
						HStack {
							Text(L.t(.mealsPerDay, app.language))
								.font(.headline).foregroundColor(UITheme.textPrimary)
							Spacer()
							Text("\(answers.mealsPerDay)")
								.font(.headline).foregroundColor(UITheme.textPrimary)
						}
						Slider(value: Binding(get: { Double(answers.mealsPerDay) }, set: { answers.mealsPerDay = Int($0) }), in: 0...6, step: 1)
							.tint(UITheme.green)
						Text(answers.mealsPerDay < 3 ? L.t(.flaggedFewMeals, app.language) : L.t(.looksOkay, app.language))
							.font(.footnote)
							.foregroundColor(answers.mealsPerDay < 3 ? .yellow : UITheme.textSecondary)
					}
					.padding()
					.themedCard()

					Button {
						model.applyQuestionnaire(answers)
						dismiss()
						onDone?()
					} label: {
						HStack(spacing: 8) {
							Text(L.t(.continueBtn, app.language))
							Image(systemName: "arrow.right")
						}
					}
					.buttonStyle(FilledCapsuleButtonStyle())
					.padding(.bottom, 24)
				}
				.padding(.horizontal, 16)
			}
		}
	}
}

private struct CardToggle: View {
	let title: String
	let subtitle: String
	let emoji: String
	@Binding var isOn: Bool

	var body: some View {
		Button {
			withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
				isOn.toggle()
			}
		} label: {
			HStack(alignment: .center, spacing: 14) {
				Text(emoji)
					.font(.system(size: 28))
					.scaleEffect(isOn ? 1.05 : 1.0)
				VStack(alignment: .leading, spacing: 4) {
					Text(title)
						.font(.headline)
						.foregroundColor(UITheme.textPrimary)
					Text(subtitle)
						.font(.subheadline)
						.foregroundColor(UITheme.textSecondary)
				}
				Spacer()
				Image(systemName: isOn ? "checkmark.seal.fill" : "checkmark.seal")
					.foregroundColor(isOn ? UITheme.green : .white.opacity(0.6))
					.font(.system(size: 22, weight: .semibold))
					}
			.padding()
			.themedCard()
			.scaleEffect(isOn ? 1.01 : 1.0)
		}
	}
}
