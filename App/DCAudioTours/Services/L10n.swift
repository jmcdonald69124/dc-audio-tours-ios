import Foundation
import TourKit

/// Looks a string up in the language the listener chose *in the app* (not the phone's language).
/// SwiftUI views get this from `.environment(\.locale)`; code that builds plain Strings
/// (notifications) goes through here.
enum L10n {
    static func string(_ key: String, language: TourLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
