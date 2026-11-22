import MapKit
import SwiftUI
import TourKit
import UIKit

// MARK: - Editorial tokens (ported 1:1 from the web app's index.css)

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// A colour that switches with Light/Dark Mode, like the web's `html.light` token overrides.
    static func adaptive(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        }
    }
}

/// UIKit flavour of the tokens (tab bar / navigation bar appearance need UIColor).
enum EdUI {
    static let bg = UIColor.adaptive(light: 0xF7F3EC, dark: 0x1A1714)
    static let surface = UIColor.adaptive(light: 0xFFFDF9, dark: 0x211D19)
    static let surfaceAlt = UIColor.adaptive(light: 0xEFE9DD, dark: 0x2A241F)
    static let border = UIColor.adaptive(light: 0x28221B, dark: 0xF5EEE2, lightAlpha: 0.14, darkAlpha: 0.13)
    static let text = UIColor.adaptive(light: 0x2C2722, dark: 0xE7E1D6)
    static let textStrong = UIColor.adaptive(light: 0x1B1712, dark: 0xFAF6EF)
    static let textMuted = UIColor.adaptive(light: 0x6B6356, dark: 0xA59C8D)
    static let accent = UIColor.adaptive(light: 0xA9711A, dark: 0xE0A83E)
}

/// SwiftUI flavour. Warm cream / near-black canvas, one gold accent, WMATA line colours as the only
/// saturated colour. The hero band is **always dark**, independent of the theme (as on the web).
enum Ed {
    static let bg = Color(EdUI.bg)
    static let surface = Color(EdUI.surface)
    static let surfaceAlt = Color(EdUI.surfaceAlt)
    static let border = Color(EdUI.border)
    static let borderSubtle = Color(UIColor.adaptive(light: 0x28221B, dark: 0xF5EEE2, lightAlpha: 0.08, darkAlpha: 0.07))
    static let text = Color(EdUI.text)
    static let textStrong = Color(EdUI.textStrong)
    static let textMuted = Color(EdUI.textMuted)
    static let textDim = Color(UIColor.adaptive(light: 0x9C9486, dark: 0x6F685B))
    static let accent = Color(EdUI.accent)
    static let accentStrong = Color(UIColor.adaptive(light: 0x8C5D12, dark: 0xEAB64F))
    /// Ink that sits on an accent fill.
    static let onAccent = Color(UIColor.adaptive(light: 0xFFFDF9, dark: 0x1A1714))
    static let success = Color(UIColor.adaptive(light: 0x1F7A4C, dark: 0x3FB950))

    // Hero band (always dark)
    static let heroBg = Color(hex: 0x1A1714)
    static let heroBg2 = Color(hex: 0x221D18)
    static let heroText = Color(hex: 0xFAF6EF)
    static let heroMuted = Color(hex: 0xB3AA9B)
    static let heroDim = Color(hex: 0x756D5F)
    static let heroAccent = Color(hex: 0xE6B34D)
    static let heroLine = Color(hex: 0xF5EEE2).opacity(0.14)
}

// MARK: - Type

enum EdFont {
    /// Playfair Display, the web's serif for headlines. Scales with Dynamic Type.
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title, semibold: Bool = false) -> Font {
        .custom(semibold ? "PlayfairDisplay-SemiBold" : "PlayfairDisplay-Medium", size: size, relativeTo: style)
    }

    /// Italic serif used for row index numbers ("02").
    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        .custom("PlayfairDisplay-Italic", size: size, relativeTo: style)
    }
}

// MARK: - Per-tour / per-line colour

enum Theme {
    static let cardRadius: CGFloat = 16

    static func color(_ line: MetroLine) -> Color { Color(hex: line.hex) }
    static func ink(on line: MetroLine) -> Color { line.prefersDarkText ? Color(hex: 0x1A1714) : .white }

    /// The tour's brand dot colour (web: TOUR_ACCENTS), falling back to the gold accent.
    static func dot(for tour: Tour) -> Color { tour.accentRGB.map { Color(hex: $0) } ?? Ed.accent }

    /// Colour of a tour's primary Metro line — used for stop numbers and the Next button.
    static func color(for tour: Tour) -> Color { tour.themeLine.map(color) ?? Ed.accent }
    static func ink(for tour: Tour) -> Color { tour.themeLine.map(ink(on:)) ?? Ed.onAccent }
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

// MARK: - Surfaces

extension View {
    /// Bordered surface card (the web's `bg-surface` + 1 px border).
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Ed.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Ed.border, lineWidth: 1))
    }
}

enum Haptics {
    static func arrival() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

/// Applies the editorial look to the system bars once at launch.
enum Appearance {
    static func apply() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = EdUI.surface
        tab.shadowColor = EdUI.border
        let label: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .semibold)]
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = EdUI.textMuted
            item.normal.titleTextAttributes = label.merging([.foregroundColor: EdUI.textMuted]) { $1 }
            item.selected.iconColor = EdUI.accent
            item.selected.titleTextAttributes = label.merging([.foregroundColor: EdUI.accent]) { $1 }
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = EdUI.bg
        nav.shadowColor = EdUI.border
        let serif = UIFont(name: "PlayfairDisplay-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        nav.titleTextAttributes = [.foregroundColor: EdUI.textStrong, .font: serif]
        nav.largeTitleTextAttributes = [.foregroundColor: EdUI.textStrong,
                                        .font: UIFont(name: "PlayfairDisplay-Medium", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
