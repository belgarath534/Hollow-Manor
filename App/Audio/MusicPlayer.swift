import AVFoundation

/// Background music. Crossfades between tracks and dips while the game is speaking, so speech and footsteps
/// always come through.
final class MusicPlayer {
    static let shared = MusicPlayer()

    enum Track: String {
        /// A spooky music-box waltz.
        case menu
        /// Dark and quiet, while you sneak around.
        case explore
        /// When the Hunter has seen you.
        case chase
        /// After getting caught.
        case caught
        /// After escaping.
        case escaped

        /// How loud each track sits under the game, before the player's music volume.
        var level: Float {
            switch self {
            case .menu: return 0.8
            case .explore: return 0.35
            case .chase: return 0.6
            case .caught, .escaped: return 0.8
            }
        }
    }

    /// The player's music volume, 0 to 1.
    var volume: Float = 0.6 {
        didSet { applyVolume(fade: 0.3) }
    }

    private(set) var current: Track?
    private var player: AVAudioPlayer?
    private var ducked = false

    func play(_ track: Track, fade: TimeInterval = 1.5) {
        guard track != current else { return }
        current = track
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        if let old = player {
            old.setVolume(0, fadeDuration: fade)
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { old.stop() }
        }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a"),
              let next = try? AVAudioPlayer(contentsOf: url) else {
            player = nil
            return
        }
        next.numberOfLoops = (track == .caught || track == .escaped) ? 0 : -1
        next.volume = 0
        next.prepareToPlay()
        next.play()
        player = next
        applyVolume(fade: fade)
    }

    func stop(fade: TimeInterval = 1) {
        guard let old = player else { return }
        current = nil
        player = nil
        old.setVolume(0, fadeDuration: fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + fade) { old.stop() }
    }

    func pause() { player?.pause() }
    func resume() { player?.play() }

    /// Turns the music down while speech is playing.
    func duck(_ on: Bool) {
        guard on != ducked else { return }
        ducked = on
        applyVolume(fade: on ? 0.15 : 0.8)
    }

    private func applyVolume(fade: TimeInterval) {
        guard let player, let current else { return }
        let target = current.level * volume * (ducked ? 0.4 : 1)
        player.setVolume(target, fadeDuration: fade)
    }
}
