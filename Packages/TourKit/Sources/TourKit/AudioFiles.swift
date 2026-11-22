import Foundation

/// Audio file naming shared with the web app and the audio server (`/audio/:file`).
public enum AudioFiles {
    /// Candidate files for a stop's narration, best first. Stop ids used by more than one
    /// tour have a tour-prefixed file; the plain file is always the fallback.
    public static func stopFiles(for stop: Stop, language: TourLanguage) -> [String] {
        stop.audioKeys.map { "\($0)-\(language.rawValue).mp3" }
    }

    public static func subStopNarration(stopId: String, subStopId: String, language: TourLanguage) -> String {
        "\(stopId)-sub-\(subStopId)-\(language.rawValue).mp3"
    }

    public static func subStopDirections(stopId: String, subStopId: String, language: TourLanguage) -> String {
        "\(stopId)-sub-\(subStopId)-directions-\(language.rawValue).mp3"
    }

    /// `https://host/audio/<file>[?t=<entitlement token>]`. Free stops need no token.
    public static func url(base: URL, file: String, token: String? = nil) -> URL {
        var url = base.appendingPathComponent("audio").appendingPathComponent(file)
        if let token, !token.isEmpty, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.queryItems = [URLQueryItem(name: "t", value: token)]
            url = parts.url ?? url
        }
        return url
    }
}
