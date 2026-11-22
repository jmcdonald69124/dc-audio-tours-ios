import AVFoundation
import MediaPlayer
import Observation

struct NowPlaying: Equatable {
    let id: String
    let title: String
    let subtitle: String
    /// Candidate URLs in preference order; the next one is tried if a URL fails to load.
    let urls: [URL]
}

/// Streams narration with the behaviour people expect from a spoken-word app: it keeps playing
/// with the screen locked, shows lock-screen / Control Center / CarPlay-style controls, pauses
/// when headphones are unplugged, and yields to phone calls and navigation prompts.
@MainActor @Observable
final class AudioPlayerService {
    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var position: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?
    private(set) var rate: Float = 1.0

    /// Wired by `AppModel` so lock-screen next/previous move through the tour.
    var onFinished: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    static let rates: [Float] = [0.8, 1.0, 1.25, 1.5, 2.0]

    private let player = AVPlayer()
    private var pending: [URL] = []
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var controlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var resumeAfterInterruption = false

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        configureSession()
        observePlayer()
        installRemoteCommands()
        observeSystem()
    }

    // MARK: Playback

    func play(_ item: NowPlaying, startAt: TimeInterval = 0) {
        guard !item.urls.isEmpty else { errorMessage = "No audio is available for this stop."; return }
        if nowPlaying?.id == item.id, player.currentItem != nil, errorMessage == nil {
            resume()
            return
        }
        nowPlaying = item
        pending = item.urls
        errorMessage = nil
        position = 0
        duration = 0
        loadNextCandidate(startAt: startAt)
    }

    func resume() {
        activateSession()
        player.defaultRate = rate
        player.play()
    }

    func pause() {
        player.pause()
        updateNowPlayingInfo()
    }

    func toggle() {
        player.timeControlStatus == .paused ? resume() : pause()
    }

    func seek(to seconds: TimeInterval) {
        let target = max(0, duration > 0 ? min(seconds, duration) : seconds)
        position = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    func skip(by seconds: TimeInterval) { seek(to: position + seconds) }

    func setRate(_ newRate: Float) {
        rate = newRate
        player.defaultRate = newRate
        if isPlaying { player.rate = newRate }
        updateNowPlayingInfo()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        nowPlaying = nil
        position = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: Loading

    private func loadNextCandidate(startAt: TimeInterval) {
        guard !pending.isEmpty else {
            isPlaying = false
            errorMessage = "Audio isn't available for this stop yet."
            return
        }
        let url = pending.removeFirst()
        let item = AVPlayerItem(url: url)

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.didFinish() }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in self?.itemStatusChanged(item, startAt: startAt) }
        }

        player.replaceCurrentItem(with: item)
        activateSession()
        player.defaultRate = rate
        player.play()
    }

    private func itemStatusChanged(_ item: AVPlayerItem, startAt: TimeInterval) {
        switch item.status {
        case .readyToPlay:
            let seconds = item.duration.seconds
            duration = seconds.isFinite ? seconds : 0
            if startAt > 0 { seek(to: startAt) }
            updateNowPlayingInfo()
        case .failed:
            // A locked or missing file fails here; fall through to the next candidate URL.
            loadNextCandidate(startAt: startAt)
        default:
            break
        }
    }

    private func didFinish() {
        position = duration
        updateNowPlayingInfo()
        onFinished?()
    }

    // MARK: Observation

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, time.seconds.isFinite else { return }
                self.position = time.seconds
            }
        }
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = status != .paused
                self.isLoading = status == .waitingToPlayAtSpecifiedRate
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: Audio session

    private func configureSession() {
        // .spokenAudio lets the system pause (not duck) narration for navigation prompts and
        // resume it afterwards, and marks the app as a spoken-word source.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in self?.handleInterruption(typeRaw: raw, optionsRaw: optionsRaw) }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                // Headphones unplugged → pause, like every other audio app.
                if let raw, AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable { self?.pause() }
            }
        }
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if resumeAfterInterruption, options.contains(.shouldResume) { resume() }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    // MARK: Lock screen

    private func updateNowPlayingInfo() {
        guard let item = nowPlaying else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyAlbumTitle: item.subtitle,
            MPMediaItemPropertyArtist: "DC Audio Tours",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
    }

    private func installRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }

        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.skip(by: interval) }
            return .success
        }
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.skip(by: -interval) }
            return .success
        }

        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let target = event.positionTime
            Task { @MainActor in self?.seek(to: target) }
            return .success
        }

        commands.changePlaybackRateCommand.supportedPlaybackRates = Self.rates.map { NSNumber(value: $0) }
        commands.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            let newRate = event.playbackRate
            Task { @MainActor in self?.setRate(newRate) }
            return .success
        }

        // Next / previous track move between stops on the tour.
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onNextTrack?() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPreviousTrack?() }
            return .success
        }
    }
}
