import SwiftUI
import TourKit

/// Scrubber + transport + speed. Shared by the stop screen and the full-screen player.
struct PlayerControls: View {
    @Environment(AppModel.self) private var model
    @State private var dragging: Double?

    var body: some View {
        let audio = model.audio
        let shown = dragging ?? audio.position

        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { shown }, set: { dragging = $0 }),
                    in: 0...max(audio.duration, 1),
                    onEditingChanged: { editing in
                        if !editing, let target = dragging { audio.seek(to: target); dragging = nil }
                    })
                .tint(Ed.accent)
                HStack {
                    Text(Formatters.clock(shown))
                    Spacer()
                    Text("-" + Formatters.clock(max(audio.duration - shown, 0)))
                }
                .font(.caption.monospacedDigit()).foregroundStyle(Ed.textMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(Formatters.clock(shown)) of \(Formatters.clock(audio.duration))")
            .accessibilityAdjustableAction { direction in
                audio.skip(by: direction == .increment ? 15 : -15)
            }

            HStack(spacing: 34) {
                Button { audio.skip(by: -15) } label: { Image(systemName: "gobackward.15").font(.title2).foregroundStyle(Ed.textStrong) }
                    .accessibilityLabel("Back 15 seconds")

                Button { audio.toggle() } label: {
                    ZStack {
                        if audio.isLoading {
                            ProgressView().controlSize(.large)
                        } else {
                            Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 58))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Ed.onAccent, Ed.accent)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")

                Button { audio.skip(by: 15) } label: { Image(systemName: "goforward.15").font(.title2).foregroundStyle(Ed.textStrong) }
                    .accessibilityLabel("Forward 15 seconds")
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: audio.isPlaying)

            Menu {
                Picker("Speed", selection: Binding(get: { audio.rate }, set: { audio.setRate($0) })) {
                    ForEach(AudioPlayerService.rates, id: \.self) { Text(Self.label($0)).tag($0) }
                }
            } label: {
                Label(Self.label(audio.rate), systemImage: "speedometer")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Ed.textStrong)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .overlay(Capsule().stroke(Ed.border, lineWidth: 1))
            }
            .accessibilityLabel("Playback speed")
        }
    }

    static func label(_ rate: Float) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : String(format: "%g×", rate)
    }
}

/// Docked above the tab bar while something is playing; tap to expand.
struct MiniPlayerBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let item = model.audio.nowPlaying {
            let audio = model.audio
            HStack(spacing: 12) {
                Button { model.showFullPlayer = true } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(EdFont.serif(16, relativeTo: .subheadline)).foregroundStyle(Ed.textStrong).lineLimit(1)
                        Text(item.subtitle).font(.system(size: 12)).foregroundStyle(Ed.textMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the player")

                Button { audio.toggle() } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).foregroundStyle(Ed.accent)
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Ed.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Ed.border, lineWidth: 1))
            .overlay(alignment: .bottom) {
                ProgressView(value: audio.duration > 0 ? min(audio.position / audio.duration, 1) : 0)
                    .progressViewStyle(.linear)
                    .tint(Ed.accent)
                    .padding(.horizontal, 16)
                    .offset(y: 4)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12).padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct FullPlayerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            if let item = model.audio.nowPlaying {
                VStack(spacing: 6) {
                    Text(item.title).font(EdFont.serif(28, relativeTo: .title)).foregroundStyle(Ed.textStrong).multilineTextAlignment(.center)
                    Text(item.subtitle).font(.system(size: 14)).foregroundStyle(Ed.textMuted)
                }
                .padding(.top, 24)

                PlayerControls()

                HStack(spacing: 12) {
                    Button { model.openAdjacentStop(offset: -1) } label: {
                        Label("Previous stop", systemImage: "backward.end.fill").frame(maxWidth: .infinity)
                    }
                    Button { model.openAdjacentStop(offset: +1) } label: {
                        Label("Next stop", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.ghost)
                .disabled(model.nowPlayingRoute == nil)

                if let route = model.nowPlayingRoute {
                    Button("Show stop") {
                        dismiss()
                        model.open(tourId: route.tourId, stopId: route.stopId)
                    }
                }
                Spacer()
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "headphones")
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ed.bg.ignoresSafeArea())
        .tint(Ed.accent)
    }
}
