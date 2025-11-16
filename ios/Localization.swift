import SwiftUI

final class AppState: ObservableObject {
	@Published var language: AppLanguage = .english
}

enum AppLanguage: String, CaseIterable, Identifiable {
	case english = "en"
	case hausa = "ha"
	case yoruba = "yo"
	case igbo = "ig"
	case vietnamese = "vi"
	case japanese = "ja"
	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .english: return "English"
		case .hausa: return "Hausa"
		case .yoruba: return "Yoruba"
		case .igbo: return "Igbo"
		case .vietnamese: return "Tiếng Việt"
		case .japanese: return "日本語"
		}
	}
}

struct L {
	static func t(_ key: Key, _ lang: AppLanguage) -> String {
		let m = strings[lang] ?? strings[.english]!
		return m[key] ?? strings[.english]![key]!
	}

	enum Key: Hashable {
		case startScan, holdSteady, answerQuestions, continueBtn, done
		case quickQuestions, refineSubtitle
		case badBreath, recentIllness, gumPain, excessiveSalivation, mealsPerDay
		case flaggedFewMeals, looksOkay
		case screeningResult, combinedRisk, seeClinician, lowRisk
	}

	private static let strings: [AppLanguage: [Key: String]] = [
		.english: [
			.startScan: "Start 5s Scan",
			.holdSteady: "Hold steady and show teeth",
			.answerQuestions: "Answer questions",
			.continueBtn: "Continue",
			.done: "Done",
			.quickQuestions: "Quick Questions",
			.refineSubtitle: "Helps refine the screening",
			.badBreath: "Bad breath",
			.recentIllness: "Recent fever / respiratory / diarrhoea",
			.gumPain: "Pain in gums",
			.excessiveSalivation: "Excessive salivation",
			.mealsPerDay: "Meals per day (past month)",
			.flaggedFewMeals: "Flagged: fewer than 3 meals/day",
			.looksOkay: "Looks okay",
			.screeningResult: "Screening Result",
			.combinedRisk: "Combined risk",
			.seeClinician: "Consider seeing a clinician",
			.lowRisk: "Low risk detected"
		],
		.hausa: [
			.startScan: "Fara daukar hoton sakan 5",
			.holdSteady: "Riƙe wayar lafiya, nuna haƙora",
			.answerQuestions: "Amsa tambayoyi",
			.continueBtn: "Ci gaba",
			.done: "An gama",
			.quickQuestions: "Tambayoyi masu sauri",
			.refineSubtitle: "Don ƙarin tantancewa",
			.badBreath: "Warinsu na baki",
			.recentIllness: "Zazzabi/numfashi/ciwon ciki kwanan nan",
			.gumPain: "Ciwo a gumi",
			.excessiveSalivation: "Yawan ruɓa a baki",
			.mealsPerDay: "Yawan abinci/rana (watan da ya gabata)",
			.flaggedFewMeals: "Gargaɗi: ƙasa da abinci 3/rana",
			.looksOkay: "Lafiya",
			.screeningResult: "Sakamakon tantancewa",
			.combinedRisk: "Haɗaɗɗen haɗari",
			.seeClinician: "A tuntuɓi likita",
			.lowRisk: "Haɗari ƙasa"
		],
		.yoruba: [
			.startScan: "Bẹrẹ ayewo aaya 5",
			.holdSteady: "Duro ṣinṣin, fi eyin han",
			.answerQuestions: "Dá ìbéèrè lóhùn",
			.continueBtn: "Tẹ̀síwájú",
			.done: "Pari",
			.quickQuestions: "Ìbéèrè kíákíá",
			.refineSubtitle: "Láti túbọ̀ mọ̀ ìtẹ̀numọ́",
			.badBreath: "Ìmí búburú",
			.recentIllness: "Ìbànújẹ/arun atẹgun/igbọnsẹ laipẹ",
			.gumPain: "Ìrora ní gọ́mù",
			.excessiveSalivation: "Ìmí omi púpọ̀",
			.mealsPerDay: "Ounjẹ lojoojúmọ́ (osù to kọja)",
			.flaggedFewMeals: "Ìkìlọ̀: kékeré ju 3 onjẹ/ọjọ́",
			.looksOkay: "Dára",
			.screeningResult: "Abajade ìtẹ̀numọ́",
			.combinedRisk: "Ẹ̀sùn apapọ̀",
			.seeClinician: "Ṣe ìmọ̀ràn kí o ri dókítà",
			.lowRisk: "Ẹ̀sùn kékeré"
		],
		.igbo: [
			.startScan: "Bido nyocha nkeji 5",
			.holdSteady: "Jide nke ọma, gosi ezé",
			.answerQuestions: "Zaa ajụjụ",
			.continueBtn: "Gaa n’ihu",
			.done: "Emezuru",
			.quickQuestions: "Ajụjụ ngwa ngwa",
			.refineSubtitle: "Iji mee ka nchọpụta doo anya",
			.badBreath: "Ọkụ ọnụ/isi ọjọọ",
			.recentIllness: "Ọrịa ọkụ ara/ọrịa ume/ afọ ọsịsa n’oge na-adịbeghị anya",
			.gumPain: "Ọrịa n’akpịrị ezé",
			.excessiveSalivation: "Mkpali imi mmiri nke ukwuu",
			.mealsPerDay: "Ọnwụnwụ nri kwa ụbọchị (ọnwa gara aga)",
			.flaggedFewMeals: "Ịdọ aka na ntị: Nri n’ụbọchị < 3",
			.looksOkay: "Ọ dị mma",
			.screeningResult: "Nsonaazụ nyocha",
			.combinedRisk: "Ihe ize ndụ jikọtara",
			.seeClinician: "Chọọ dọkịta hụ gị",
			.lowRisk: "Ihe ize ndụ dị ntakịrị"
		],
		.vietnamese: [
			.startScan: "Bắt đầu quét 5s",
			.holdSteady: "Giữ máy ổn định và mở răng",
			.answerQuestions: "Trả lời câu hỏi",
			.continueBtn: "Tiếp tục",
			.done: "Xong",
			.quickQuestions: "Câu hỏi nhanh",
			.refineSubtitle: "Giúp kết quả chính xác hơn",
			.badBreath: "Hơi thở hôi",
			.recentIllness: "Sốt/ hô hấp/ tiêu chảy gần đây",
			.gumPain: "Đau nướu",
			.excessiveSalivation: "Chảy nước dãi nhiều",
			.mealsPerDay: "Số bữa ăn mỗi ngày (tháng trước)",
			.flaggedFewMeals: "Cảnh báo: dưới 3 bữa/ngày",
			.looksOkay: "Có vẻ ổn",
			.screeningResult: "Kết quả sàng lọc",
			.combinedRisk: "Nguy cơ tổng hợp",
			.seeClinician: "Nên gặp nhân viên y tế",
			.lowRisk: "Nguy cơ thấp"
		],
		.japanese: [
			.startScan: "5秒スキャンを開始",
			.holdSteady: "端末を安定させて歯を見せてください",
			.answerQuestions: "質問に答える",
			.continueBtn: "続ける",
			.done: "完了",
			.quickQuestions: "クイック質問",
			.refineSubtitle: "判定をより正確にします",
			.badBreath: "口臭",
			.recentIllness: "最近の発熱・呼吸器疾患・下痢",
			.gumPain: "歯ぐきの痛み",
			.excessiveSalivation: "唾液が多い",
			.mealsPerDay: "1日の食事回数（過去1か月）",
			.flaggedFewMeals: "注意: 1日3回未満",
			.looksOkay: "問題なさそう",
			.screeningResult: "スクリーニング結果",
			.combinedRisk: "総合リスク",
			.seeClinician: "受診を検討してください",
			.lowRisk: "低リスク"
		]
	]
}
