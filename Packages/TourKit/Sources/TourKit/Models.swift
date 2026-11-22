import Foundation

// MARK: - Metro lines

public enum MetroLine: String, Codable, CaseIterable, Sendable, Hashable {
    case red = "Red", blue = "Blue", orange = "Orange", silver = "Silver", green = "Green", yellow = "Yellow"

    /// WMATA line colors (same values as the web app).
    public var hex: UInt32 {
        switch self {
        case .red: 0xE51636
        case .blue: 0x0076A8
        case .orange: 0xED8B00
        case .silver: 0x9EA2A2
        case .green: 0x00B140
        case .yellow: 0xFFD100
        }
    }

    /// Yellow and silver need dark text for contrast.
    public var prefersDarkText: Bool { self == .yellow || self == .silver }

    public var letter: String { String(rawValue.prefix(1)) }
}

// MARK: - Geography

public struct StopLocation: Codable, Hashable, Sendable {
    public let lat: Double
    public let lon: Double
    /// Where the coordinate came from (e.g. "nominatim"). Geocoded values are not yet human-reviewed.
    public let source: String
    public let reviewed: Bool

    public init(lat: Double, lon: Double, source: String = "manual", reviewed: Bool = true) {
        self.lat = lat; self.lon = lon; self.source = source; self.reviewed = reviewed
    }

    public var coordinate: Coordinate { Coordinate(lat: lat, lon: lon) }
}

// MARK: - Catalog

public struct SubStopRef: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: LocalizedText
    public init(id: String, name: LocalizedText) { self.id = id; self.name = name }
}

public struct Stop: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let order: Int
    /// Key into the per-language content file (`<ownerTourId>/<stopId>`). Area tours reuse a themed tour's text.
    public let contentKey: String
    public let station: String
    public let lines: [MetroLine]
    public let exit: String
    public let walkMin: Int
    public let name: LocalizedText
    public let duration: LocalizedText
    /// Where the Metro station for this stop is; routes "walk from the station" start here.
    public let stationLocation: Coordinate?
    public let location: StopLocation?
    /// Audio file stems in preference order; the app appends `-<lang>.mp3`.
    public let audioKeys: [String]
    public let subStops: [SubStopRef]

    public init(
        id: String, order: Int, contentKey: String, station: String, lines: [MetroLine] = [],
        exit: String = "", walkMin: Int = 0, name: LocalizedText, duration: LocalizedText = LocalizedText([:]),
        stationLocation: Coordinate? = nil, location: StopLocation? = nil, audioKeys: [String]? = nil,
        subStops: [SubStopRef] = []
    ) {
        self.id = id; self.order = order; self.contentKey = contentKey; self.station = station
        self.lines = lines; self.exit = exit; self.walkMin = walkMin; self.name = name
        self.duration = duration; self.stationLocation = stationLocation; self.location = location; self.audioKeys = audioKeys ?? [id]
        self.subStops = subStops
    }

    private enum CodingKeys: String, CodingKey {
        case id, order, contentKey, station, lines, exit, walkMin, name, duration, stationLocation, location, audioKeys, subStops
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        contentKey = try c.decode(String.self, forKey: .contentKey)
        station = try c.decodeIfPresent(String.self, forKey: .station) ?? ""
        // Unknown line names are dropped instead of failing the whole catalog.
        lines = (try c.decodeIfPresent([String].self, forKey: .lines) ?? []).compactMap(MetroLine.init(rawValue:))
        exit = try c.decodeIfPresent(String.self, forKey: .exit) ?? ""
        walkMin = try c.decodeIfPresent(Int.self, forKey: .walkMin) ?? 0
        name = try c.decode(LocalizedText.self, forKey: .name)
        duration = try c.decodeIfPresent(LocalizedText.self, forKey: .duration) ?? LocalizedText([:])
        stationLocation = try c.decodeIfPresent(Coordinate.self, forKey: .stationLocation)
        location = try c.decodeIfPresent(StopLocation.self, forKey: .location)
        audioKeys = try c.decodeIfPresent([String].self, forKey: .audioKeys) ?? [id]
        subStops = try c.decodeIfPresent([SubStopRef].self, forKey: .subStops) ?? []
    }
}

public enum TourKind: String, Codable, Sendable, Hashable {
    /// A story told across the Metro system (museums, spies, civil rights…).
    case themed
    /// A compact on-foot walk around one neighborhood.
    case area
}

public struct RouteLeg: Codable, Hashable, Sendable {
    public let from: String
    public let to: String
    public let meters: Int
    public let seconds: Int
    public let minutes: Int
}

public struct ComfortStop: Codable, Hashable, Sendable {
    public let afterStopId: String
    public let name: String
    public let category: String
    public let note: String
}

public struct RouteDetails: Codable, Hashable, Sendable {
    public let start: String
    public let finish: String
    public let pace: String
    public let comfortStops: [ComfortStop]
}

public struct WalkingRoute: Codable, Hashable, Sendable {
    public let details: RouteDetails?
    /// `true` when leg times are a street-grid estimate rather than provider-routed. The app prefers MapKit routes.
    public let metricsEstimated: Bool
    public let totalMeters: Int
    public let totalSeconds: Int
    public let legs: [RouteLeg]
}

public struct Tour: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let kind: TourKind
    public let isFree: Bool
    public let title: LocalizedText
    public let tagline: LocalizedText
    public let marketing: LocalizedText?
    public let accentLine: MetroLine?
    /// Brand colour for this tour as `#rrggbb` (list dot, glow). Matches the web app's tour accents.
    public let accentHex: String?
    public let stops: [Stop]
    public let route: WalkingRoute?

    public init(
        id: String, kind: TourKind = .themed, isFree: Bool = false, title: LocalizedText,
        tagline: LocalizedText = LocalizedText([:]), marketing: LocalizedText? = nil,
        accentLine: MetroLine? = nil, accentHex: String? = nil, stops: [Stop], route: WalkingRoute? = nil
    ) {
        self.id = id; self.kind = kind; self.isFree = isFree; self.title = title; self.tagline = tagline
        self.marketing = marketing; self.accentLine = accentLine; self.accentHex = accentHex; self.stops = stops; self.route = route
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, isFree, title, tagline, marketing, accentLine, accentHex, stops, route
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(TourKind.self, forKey: .kind)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        title = try c.decode(LocalizedText.self, forKey: .title)
        tagline = try c.decodeIfPresent(LocalizedText.self, forKey: .tagline) ?? LocalizedText([:])
        marketing = try c.decodeIfPresent(LocalizedText.self, forKey: .marketing)
        accentLine = try c.decodeIfPresent(String.self, forKey: .accentLine).flatMap(MetroLine.init(rawValue:))
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex)
        stops = try c.decode([Stop].self, forKey: .stops)
        route = try c.decodeIfPresent(WalkingRoute.self, forKey: .route)
    }

    /// `accentHex` parsed to 0xRRGGBB, or nil if absent/malformed.
    public var accentRGB: UInt32? {
        guard let hex = accentHex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")), hex.count == 6 else { return nil }
        return UInt32(hex, radix: 16)
    }

    /// Colour the tour is themed with: its declared line, else the first stop's first line.
    public var themeLine: MetroLine? { accentLine ?? stops.first?.lines.first }

    /// The legs of an area tour keyed by the stop they start at.
    public func leg(from stopId: String) -> RouteLeg? { route?.legs.first { $0.from == stopId } }
}

public struct Catalog: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let freeTourId: String
    public let languages: [String]
    public let tours: [Tour]

    public init(schemaVersion: Int = 1, generatedAt: String = "", freeTourId: String = "", languages: [String] = [], tours: [Tour]) {
        self.schemaVersion = schemaVersion; self.generatedAt = generatedAt
        self.freeTourId = freeTourId; self.languages = languages; self.tours = tours
    }

    public var themedTours: [Tour] { tours.filter { $0.kind == .themed } }
    public var areaTours: [Tour] { tours.filter { $0.kind == .area } }

    public func tour(id: String) -> Tour? { tours.first { $0.id == id } }

    public func toursContaining(stopId: String) -> [Tour] {
        tours.filter { tour in tour.stops.contains { $0.id == stopId } }
    }

    public static func decode(from data: Data) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: data)
    }
}

// MARK: - Per-language content

public struct SubStopContent: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let directions: String
    public let narration: String
    public let tips: String
}

public struct StopContent: Codable, Hashable, Sendable {
    public let narration: String
    public let tips: String
    public let subStops: [SubStopContent]
}

/// All stop text for one language (`content/<lang>.json`), keyed by `Stop.contentKey`.
public struct LanguageContent: Codable, Sendable {
    public let stops: [String: StopContent]

    public init(stops: [String: StopContent]) { self.stops = stops }

    public init(from decoder: Decoder) throws {
        stops = try decoder.singleValueContainer().decode([String: StopContent].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stops)
    }

    public func content(for stop: Stop) -> StopContent? { stops[stop.contentKey] }

    public static func decode(from data: Data) throws -> LanguageContent {
        try JSONDecoder().decode(LanguageContent.self, from: data)
    }
}
