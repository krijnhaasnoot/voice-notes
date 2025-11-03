import Foundation

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case nl_NL, en_US, de_DE, fr_FR, es_ES, it_IT

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nl_NL: return "Nederlands"
        case .en_US: return "English"
        case .de_DE: return "Deutsch"
        case .fr_FR: return "Français"
        case .es_ES: return "Español"
        case .it_IT: return "Italiano"
        }
    }

    var whisperCode: String {
        switch self {
        case .nl_NL: return "nl"
        case .en_US: return "en"
        case .de_DE: return "de"
        case .fr_FR: return "fr"
        case .es_ES: return "es"
        case .it_IT: return "it"
        }
    }
}
