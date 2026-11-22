import MapKit
import UIKit
import SwiftUI
import TourKit

/// Visual language: the same editorial feel as the web app (serif display type, a warm gold accent,
/// WMATA line colours as the only saturated colour) built on system materials so it picks up
/// Dark Mode, Dynamic Type and — when built with the newest SDK — Liquid Glass automatically.
enum Theme {
    static let cardRadius: CGFloat = 20

    static func color(_ line: MetroLine) -> Color { Color(hex: line.hex) }
    static func ink(on line: MetroLine) -> Color { line.prefersDarkText ? .black : .white }
    static func color(for tour: Tour) -> Color { tour.themeLine.map(color) ?? .accentColor }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    /// Serif display face for headlines.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .serif) }
}

extension Coordinate {
    var clLocation: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

extension MKCoordinateRegion {
    /// A region that fits all coordinates with some breathing room.
    init?(fitting coordinates: [Coordinate], padding: Double = 1.35) {
        guard let box = coordinates.bounds else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (box.southWest.lat + box.northEast.lat) / 2,
            longitude: (box.southWest.lon + box.northEast.lon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((box.northEast.lat - box.southWest.lat) * padding, 0.006),
            longitudeDelta: max((box.northEast.lon - box.southWest.lon) * padding, 0.006))
        self.init(center: center, span: span)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

enum Haptics {
    static func arrival() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
