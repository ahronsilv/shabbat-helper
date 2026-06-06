import Foundation

enum HebcalLanguageMapper {
    static func hebcalLanguageCode(for locale: Locale = .autoupdatingCurrent) -> String? {
        let languageCode = locale.language.languageCode?.identifier

        switch languageCode {
        case "fr":
            return "fr"
        case "ru":
            return "ru"
        case "he":
            return "he-x-NoNikud"
        case "en", "am":
            return nil
        default:
            return nil
        }
    }
}
