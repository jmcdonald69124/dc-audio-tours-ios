import SwiftUI
import TourKit

struct LineBadge: View {
    let line: MetroLine
    var size: CGFloat = 22

    var body: some View {
        Text(line.letter)
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink(on: line))
            .frame(width: size, height: size)
            .background(Theme.color(line), in: Circle())
            .accessibilityLabel("\(line.rawValue) Line")
    }
}

struct LineStack: View {
    let lines: [MetroLine]
    var body: some View {
        HStack(spacing: 4) { ForEach(lines, id: \.self) { LineBadge(line: $0) } }
    }
}

struct AccessPill: View {
    let access: TourAccess
    var body: some View {
        switch access {
        case .free:
            pill("FREE", tint: .green)
        case .owned:
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint).accessibilityLabel("Owned")
        case .preview:
            pill("PREVIEW", tint: .secondary)
        }
    }

    private func pill(_ text: LocalizedStringKey, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
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
