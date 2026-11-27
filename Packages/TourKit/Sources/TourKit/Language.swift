import Foundation

/// The eight narration/UI languages shipped by DC Audio Tours.
public enum TourLanguage: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case en, es, fr, de, ja, ko, zh, pt

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .en: "English"
        case .es: "Español"
        case .fr: "Français"
        case .de: "Deutsch"
        case .ja: "日本語"
        case .ko: "한국어"
        case .zh: "中文"
        case .pt: "Português"
        }
    }

    public var flag: String {
        switch self {
        case .en: "🇺🇸"
        case .es: "🇪🇸"
        case .fr: "🇫🇷"
        case .de: "🇩🇪"
        case .ja: "🇯🇵"
        case .ko: "🇰🇷"
        case .zh: "🇨🇳"
        case .pt: "🇧🇷"
        }
    }

    /// Locale / localization identifier — matches the app's `.lproj` folders (zh = Simplified, pt = Brazilian).
    public var localeIdentifier: String {
        switch self {
        case .en: "en"
        case .es: "es"
        case .fr: "fr"
        case .de: "de"
        case .ja: "ja"
        case .ko: "ko"
        case .zh: "zh-Hans"
        case .pt: "pt-BR"
        }
    }

    /// Picks the first supported language from a preference list such as
    /// `Locale.preferredLanguages` ("zh-Hans-CN" → zh, "pt_BR" → pt). Falls back to English.
    public static func resolve(preferred: [String] = Locale.preferredLanguages) -> TourLanguage {
        for tag in preferred {
            let code = tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { String($0).lowercased() }
            if let code, let language = TourLanguage(rawValue: code) { return language }
        }
        return .en
    }
}

/// A string available in several languages, stored as `{ "en": "...", "es": "..." }`.
public struct LocalizedText: Codable, Hashable, Sendable {
    public let values: [String: String]

    public init(_ values: [String: String]) { self.values = values }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    /// Requested language, else English, else the alphabetically first available value.
    public func resolve(_ language: TourLanguage) -> String {
        if let text = values[language.rawValue], !text.isEmpty { return text }
        if let text = values["en"], !text.isEmpty { return text }
        return values.sorted { $0.key < $1.key }.first?.value ?? ""
    }

    public subscript(language: TourLanguage) -> String { resolve(language) }
}
