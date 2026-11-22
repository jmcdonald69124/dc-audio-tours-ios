import Foundation
import TourKit

/// Catalog and per-language text shipped inside the app. The same JSON schema is what the
/// Firestore backend serves (see docs/firestore-schema.md), so switching sources later is a
/// matter of swapping this loader, not touching the UI.
enum BundledContent {
    static func catalog() throws -> Catalog {
        try Catalog.decode(from: data(named: "catalog", in: "Content"))
    }

    static func content(for language: TourLanguage) throws -> LanguageContent {
        try LanguageContent.decode(from: data(named: language.rawValue, in: "Content/content"))
    }

    private static func data(named name: String, in directory: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: directory) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Missing bundled file \(directory)/\(name).json"])
        }
        return try Data(contentsOf: url)
    }
}
