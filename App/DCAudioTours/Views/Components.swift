import SwiftUI
import TourKit

/// Rounded-square line badge (B / O / S …), as on the web stop pages.
struct LineBadge: View {
    let line: MetroLine
    var size: CGFloat = 24

    var body: some View {
        Text(line.letter)
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink(on: line))
            .frame(width: size, height: size)
            .background(Theme.color(line), in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityLabel(Text(LocalizedStringKey("\(line.rawValue) Line")))
    }
}

struct LineStack: View {
    let lines: [MetroLine]
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: 4) { ForEach(lines, id: \.self) { LineBadge(line: $0, size: size) } }
    }
}

/// Small uppercase label that sits above serif headlines ("STOP OVERVIEW"), with an optional accent dot.
struct Eyebrow: View {
    let text: LocalizedStringKey
    var dot: Color?
    var onDark: Bool

    init(_ text: LocalizedStringKey, dot: Color? = nil, onDark: Bool = false) {
        self.text = text; self.dot = dot; self.onDark = onDark
    }

    var body: some View {
        HStack(spacing: 9) {
            if let dot { Circle().fill(dot).frame(width: 5, height: 5) }
            Text(text)
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(onDark ? Ed.heroMuted : Ed.textMuted)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct Hairline: View {
    var onDark = false
    var body: some View {
        Rectangle().fill(onDark ? Ed.heroLine : Ed.border).frame(height: 1 / UIScreen.main.scale)
    }
}

// MARK: - Buttons

/// Gold pill — the web's `.ed-cta`.
struct EditorialCTAStyle: ButtonStyle {
    var fill: Color = Ed.accent
    var ink: Color = Ed.onAccent
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 26).padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(fill, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// Hairline-bordered pill — the web's `.ed-ghost`.
struct GhostPillStyle: ButtonStyle {
    var onDark = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(onDark ? Ed.heroText : Ed.textStrong)
            .padding(.horizontal, 24).padding(.vertical, 14)
            .overlay(Capsule().stroke(onDark ? Ed.heroLine : Ed.border, lineWidth: 1))
            .background(configuration.isPressed ? (onDark ? Ed.heroText.opacity(0.08) : Ed.surfaceAlt) : .clear, in: Capsule())
    }
}

extension ButtonStyle where Self == EditorialCTAStyle {
    static var editorial: EditorialCTAStyle { EditorialCTAStyle() }
    static func editorial(fill: Color, ink: Color, fullWidth: Bool = false) -> EditorialCTAStyle {
        EditorialCTAStyle(fill: fill, ink: ink, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == GhostPillStyle {
    static var ghost: GhostPillStyle { GhostPillStyle() }
    static var ghostOnDark: GhostPillStyle { GhostPillStyle(onDark: true) }
}

// MARK: - Status

struct AccessPill: View {
    let access: TourAccess
    var body: some View {
        switch access {
        case .free: Text("Free").font(.system(size: 14, weight: .semibold)).foregroundStyle(Ed.success)
        case .owned: Text("Owned").font(.system(size: 14, weight: .semibold)).foregroundStyle(Ed.success)
        case .preview: EmptyView()
        }
    }
}

struct FreePill: View {
    var body: some View {
        Text("FREE")
            .font(.system(size: 10, weight: .bold)).tracking(0.8)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(Ed.success)
            .background(Ed.success.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(Ed.success.opacity(0.35), lineWidth: 1))
    }
}

enum Formatters {
    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
    }

    static func walkTime(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(60, (seconds / 60).rounded() * 60)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(max(0, seconds))).formatted(.time(pattern: .minuteSecond))
    }
}
