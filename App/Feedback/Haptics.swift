import CoreHaptics

/// Heartbeat thumps, wall bumps and the big jolt when you're caught.
final class Haptics {
    var enabled = true
    private var engine: CHHapticEngine?

    var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func start() {
        guard enabled, isSupported, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in try? self?.engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    /// One heartbeat: two soft thumps.
    func heartbeat(intensity: Float) {
        play([
            transient(at: 0, intensity: intensity, sharpness: 0.1),
            transient(at: 0.26, intensity: intensity * 0.7, sharpness: 0.1),
        ])
    }

    func bump() {
        play([transient(at: 0, intensity: 0.6, sharpness: 0.6)])
    }

    func found() {
        play([transient(at: 0, intensity: 0.5, sharpness: 0.9), transient(at: 0.12, intensity: 0.7, sharpness: 0.9)])
    }

    func spotted() {
        play([transient(at: 0, intensity: 1, sharpness: 0.8), transient(at: 0.1, intensity: 1, sharpness: 0.8)])
    }

    func caught() {
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ],
            relativeTime: 0, duration: 1.2)
        play([transient(at: 0, intensity: 1, sharpness: 1), rumble])
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, max(0, intensity))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time)
    }

    private func play(_ events: [CHHapticEvent]) {
        guard enabled, let engine else { return }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }
}
