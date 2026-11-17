import AVFoundation
import ManorCore

/// All of the game's sound. Things in the house (footsteps, the Hunter's voice, the clock) are placed in 3D around
/// the listener with HRTF, so with headphones you can hear where they are. One map cell is one metre.
final class ManorAudio {
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    /// Muffles everything while you're hiding inside something.
    private let hidingFilter = AVAudioUnitEQ(numberOfBands: 1)
    private let mono = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    // In the house (3D).
    private let playerSteps = AVAudioPlayerNode()
    private let creaks = AVAudioPlayerNode()
    private let hunterSteps = AVAudioPlayerNode()
    private let hunterVoice = AVAudioPlayerNode()
    private let hostVoice = AVAudioPlayerNode()
    private let clock = AVAudioPlayerNode()
    // Not in the house (plain stereo).
    private let narration = AVAudioPlayerNode()
    private let effects = AVAudioPlayerNode()
    private let heart = AVAudioPlayerNode()
    private let thunderNode = AVAudioPlayerNode()
    private let ambience = AVAudioPlayerNode()

    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var running = false
    private var configObserver: NSObjectProtocol?
    private var stepVariant = 0

    /// Where the Host's voice comes from: upstairs, above the hallway.
    private let hostPosition = AVAudio3DPoint(x: 12, y: 5, z: 6.5)

    private var spatial: [AVAudioPlayerNode] { [playerSteps, creaks, hunterSteps, hunterVoice, hostVoice, clock] }
    private var flat: [AVAudioPlayerNode] { [narration, effects, heart, thunderNode] }

    init() {
        engine.attach(environment)
        engine.attach(hidingFilter)
        let band = hidingFilter.bands[0]
        band.filterType = .lowPass
        band.frequency = 900
        band.bypass = false
        hidingFilter.bypass = true

        engine.connect(environment, to: hidingFilter, format: nil)
        engine.connect(hidingFilter, to: engine.mainMixerNode, format: nil)

        for node in spatial {
            engine.attach(node)
            engine.connect(node, to: environment, format: mono)
            node.renderingAlgorithm = .HRTFHQ
            node.reverbBlend = 0.3
        }
        playerSteps.reverbBlend = 0.15
        hostVoice.reverbBlend = 0.5
        hostVoice.occlusion = -8
        hostVoice.position = hostPosition

        for node in flat {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: mono)
        }
        engine.attach(ambience)
        if let rain = buffer("amb_rain", "wav") {
            engine.connect(ambience, to: engine.mainMixerNode, format: rain.format)
        } else {
            engine.connect(ambience, to: engine.mainMixerNode, format: mono)
        }
        ambience.volume = 0.1
        heart.volume = 0

        let distance = environment.distanceAttenuationParameters
        distance.distanceAttenuationModel = .inverse
        distance.referenceDistance = 1.5
        distance.maximumDistance = 40
        distance.rolloffFactor = 1.1

        let reverb = environment.reverbParameters
        reverb.enable = true
        reverb.loadFactoryReverbPreset(.mediumHall)
        reverb.level = -4

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self, self.running else { return }
            self.running = false
            self.start()
        }
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    }

    func start() {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        engine.prepare()
        do { try engine.start() } catch { return }
        running = true
        for node in spatial + flat + [ambience] { node.play() }
        if let rain = buffer("amb_rain", "wav") { ambience.scheduleBuffer(rain, at: nil, options: .loops) }
        if let tick = buffer("clock", "wav") {
            clock.position = point(Mansion.groundFloor.feature(id: "clock")?.cell ?? Cell(12, 6))
            clock.volume = 0.6
            clock.scheduleBuffer(tick, at: nil, options: .loops)
        }
    }

    func pause() {
        engine.pause()
        running = false
    }

    func resume() {
        guard !running else { return }
        do { try engine.start() } catch { return }
        running = true
    }

    func stop() {
        for node in spatial + flat + [ambience] { node.stop() }
        engine.stop()
        running = false
    }

    // MARK: Listener

    func setListener(at cell: Cell, facing: Facing) {
        environment.listenerPosition = point(cell)
        let f: AVAudio3DVector
        switch facing {
        case .north: f = AVAudio3DVector(x: 0, y: 0, z: -1)
        case .east: f = AVAudio3DVector(x: 1, y: 0, z: 0)
        case .south: f = AVAudio3DVector(x: 0, y: 0, z: 1)
        case .west: f = AVAudio3DVector(x: -1, y: 0, z: 0)
        }
        environment.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: f, up: AVAudio3DVector(x: 0, y: 1, z: 0))
        // Your own steps come from just below and slightly in front of you.
        let p = point(cell)
        playerSteps.position = AVAudio3DPoint(x: p.x + Float(facing.dx) * 0.3, y: -1.2, z: p.z + Float(facing.dy) * 0.3)
        creaks.position = playerSteps.position
    }

    /// Muffles the Hunter when walls are between you. 0 is clear, 1 is through a wall, 2 is far through the house.
    func setHunterOcclusion(_ level: Int) {
        let db: Float = level == 0 ? 0 : (level == 1 ? -10 : -18)
        hunterSteps.occlusion = db
        hunterVoice.occlusion = db
    }

    func setHiding(_ hiding: Bool) {
        hidingFilter.bypass = !hiding
    }

    // MARK: Sounds

    /// How loud a floor is underfoot. Matches how far the Hunter can hear it, so you learn which floors are risky.
    private func loudness(_ surface: Surface) -> Float {
        switch surface {
        case .carpet: return 0.45
        case .stone: return 0.65
        case .wood: return 0.8
        case .tile: return 0.85
        case .creakyWood: return 0.9
        case .marble: return 1
        }
    }

    func playerStep(_ surface: Surface, running: Bool) {
        stepVariant = (stepVariant + 1) % 3
        guard let b = buffer("step_\(surface.rawValue)_\(stepVariant + 1)", "wav") else { return }
        playerSteps.volume = loudness(surface) * (running ? 1 : 0.65)
        playerSteps.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    func hunterStep(_ surface: Surface, at cell: Cell, running: Bool) {
        guard let b = buffer("boot_\(surface.rawValue)_\(Int.random(in: 1...3))", "wav") else { return }
        hunterSteps.position = point(cell)
        hunterVoice.position = point(cell, height: 0.6)
        hunterSteps.volume = min(1, loudness(surface) + 0.15) * (running ? 1 : 0.85)
        hunterSteps.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    func creak() {
        guard let b = buffer("creak_\(Int.random(in: 1...3))", "wav") else { return }
        creaks.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    /// A one-shot effect that isn't in the house: searching, the key, hiding, the door, stings.
    func effect(_ name: String, volume: Float = 1) {
        guard let b = buffer(name, "wav") else { return }
        effects.volume = volume
        effects.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    func stopEffects() {
        effects.stop()
        effects.play()
    }

    /// Rain and thunder volume, 0 to 1 (the player's setting). The clock isn't affected: it helps you find your way.
    private var weatherLevel: Float = 0.5

    func setWeatherVolume(_ level: Float) {
        weatherLevel = level
        ambience.volume = 0.2 * level
    }

    /// Distant thunder, outside.
    func thunder() {
        guard let b = buffer("thunder_\(Int.random(in: 1...2))", "wav") else { return }
        guard weatherLevel > 0 else { return }
        thunderNode.volume = Float.random(in: 0.35...0.8) * min(1, weatherLevel * 1.5)
        thunderNode.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    func heartbeat(volume: Float) {
        guard let b = buffer("heartbeat", "wav") else { return }
        heart.volume = volume
        heart.scheduleBuffer(b, at: nil, options: .interrupts)
    }

    /// Plays a recorded line and returns how long it is, in seconds.
    @discardableResult
    func voice(_ line: VoiceLine, from cell: Cell?) -> Double {
        guard let b = buffer(line.rawValue, "m4a") else { return 0 }
        let node: AVAudioPlayerNode
        switch line.speaker {
        case .hunter:
            node = hunterVoice
            if let cell { hunterVoice.position = point(cell, height: 0.6) }
        case .host: node = hostVoice
        case .friend: node = narration
        }
        node.scheduleBuffer(b, at: nil, options: .interrupts)
        return Double(b.frameLength) / b.format.sampleRate
    }

    func stopNarration() {
        narration.stop()
        narration.play()
    }

    func duration(of line: VoiceLine) -> Double {
        guard let b = buffer(line.rawValue, "m4a") else { return 0 }
        return Double(b.frameLength) / b.format.sampleRate
    }

    // MARK: Helpers

    private func point(_ cell: Cell, height: Float = 0) -> AVAudio3DPoint {
        AVAudio3DPoint(x: Float(cell.x), y: height, z: Float(cell.y))
    }

    /// Loads a sound from the app bundle once, converted to the format its player expects.
    private func buffer(_ name: String, _ ext: String) -> AVAudioPCMBuffer? {
        if let b = buffers[name] { return b }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let file = try? AVAudioFile(forReading: url),
              let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }
        do { try file.read(into: raw) } catch { return nil }
        var result = raw
        // Everything except the stereo rain plays through mono players; convert anything that doesn't match.
        if raw.format.channelCount == 1, raw.format != mono, let converted = convert(raw, to: mono) {
            result = converted
        }
        buffers[name] = result
        return result
    }

    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}
