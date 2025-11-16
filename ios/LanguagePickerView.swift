import SwiftUI

struct LanguagePickerView: View {
	@EnvironmentObject private var app: AppState
	@Binding var isPresented: Bool

	var body: some View {
		VStack(spacing: 14) {
			Text("Choose Language")
				.font(.system(size: 20, weight: .semibold))
				.foregroundColor(.primary)
				.padding(.top, 6)
			ScrollView {
				VStack(spacing: 10) {
					ForEach(AppLanguage.allCases) { lang in
						Button {
							app.language = lang
							isPresented = false
						} label: {
							HStack {
								Text(lang.displayName)
									.font(.headline)
									.foregroundColor(.primary)
								Spacer()
								if app.language == lang {
									Image(systemName: "checkmark.circle.fill")
										.foregroundColor(UITheme.green)
								}
							}
							.padding()
							.background(Color(.secondarySystemBackground))
							.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
						}
					}
				}
			}
			Button {
				isPresented = false
			} label: {
				Text(L.t(.done, app.language))
			}
			.buttonStyle(FilledCapsuleButtonStyle())
			.padding(.bottom, 10)
		}
		.padding(.horizontal, 16)
		.frame(maxWidth: 520)
	}
}
