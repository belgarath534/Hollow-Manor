import ManorCore
import QuartzCore
import SwiftUI
import UIKit

/// Runs one night: ticks the game, turns its events into sound, speech and haptics, and reads touch input.
final class GameController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case intro, playing, paused, ended(Outcome)
    }

    @Published private(set) var phase: Phase = .intro
    /// The last thing said, shown at the bottom of the screen.
    @Published private(set) var caption = ""

    let settings: AppSettings
    private(set) var game: Game
    weak var view: GameTouchView?

    private let audio = ManorAudio()
    private let announcer = Announcer()
    private let haptics = Haptics()
    private let hardware = HardwareInput()
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var touchInput = MoveInput()
    private var nextHeartbeat: CFTimeInterval = 0
    private var introWork: [DispatchWorkItem] = []
    private var started = false
    private var stopped = false
    private var nextThunder: CFTimeInterval = 0
    private let music = MusicPlayer.shared

    init(settings: AppSettings) {
        self.settings = settings
        game = Game(difficulty: settings.difficulty)
        super.init()
        announcer.output = settings.speechOutput
        haptics.enabled = settings.haptics
        announcer.onCaption = { [weak self] text in self?.showCaption(text) }
        announcer.onSpeakingChanged = { speaking in MusicPlayer.shared.duck(speaking) }
        hardware.onCommand = { [weak self] in self?.handle($0) }
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        audio.setWeatherVolume(Float(settings.weatherVolume))
        audio.start()
        haptics.start()
        hardware.start()
        audio.setListener(at: game.player.cell, facing: game.player.facing)
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        music.stop(fade: 2)
        playIntro()
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        if case .ended = phase {} else { music.stop() }
        introWork.forEach { $0.cancel() }
        displayLink?.invalidate()
        displayLink = nil
        hardware.stop()
        haptics.stop()
        audio.stop()
        announcer.stop()
    }

    func pause() {
        guard phase == .playing || phase == .intro else { return }
        if phase == .intro { finishIntro(announce: false) }
        phase = .paused
        touchInput = MoveInput()
        audio.pause()
        music.pause()
        announcer.speak("Paused", priority: .high)
    }

    func resume() {
        guard phase == .paused else { return }
        audio.resume()
        music.resume()
        lastTimestamp = 0
        phase = .playing
        announcer.speak("Back in the house.", priority: .high)
    }

    // MARK: Intro

    private func playIntro() {
        phase = .intro
        var at = 0.5
        func later(_ delay: Double, _ block: @escaping () -> Void) {
            let item = DispatchWorkItem(block: block)
            introWork.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
        if !settings.skipIntro {
            later(at) { [weak self] in
                self?.showCaption("A letter came for you, in your friend's handwriting.")
                self?.announcer.speak("A letter came for you, in your friend's handwriting.", priority: .high)
            }
            at += 3.5
            later(at) { [weak self] in self?.playVoice(.friendLetter, from: nil) }
            at += audio.duration(of: .friendLetter) + 1
            later(at) { [weak self] in
                self?.announcer.speak("So you came. Behind you, the gates of Hollow Manor slam shut.", priority: .high)
            }
            at += 4
            later(at) { [weak self] in self?.audio.effect("gate_slam") }
            at += 2
        }
        later(at) { [weak self] in self?.playVoice(.hostWelcome, from: nil) }
        at += audio.duration(of: .hostWelcome) + 0.6
        later(at) { [weak self] in self?.finishIntro(announce: true) }
    }

    private func finishIntro(announce: Bool) {
        guard phase == .intro else { return }
        introWork.forEach { $0.cancel() }
        introWork.removeAll()
        audio.stopNarration()
        phase = .playing
        lastTimestamp = 0
        music.play(.explore, fade: 4)
        nextThunder = CACurrentMediaTime() + Double.random(in: 15...30)
        if announce {
            announcer.speak(
                "You're in the foyer. The front door is locked behind you. Find the key and get out. "
                    + "Swipe up to walk, and tap to stop. Swipe left or right to turn. "
                    + "Two-finger tap any time to hear what's around you.",
                priority: .high)
        }
    }

    // MARK: Frame loop

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastTimestamp = now }
        guard phase == .playing, lastTimestamp > 0 else { return }
        let dt = min(0.1, now - lastTimestamp)

        let pad = hardware.poll()
        var input = touchInput
        if pad.direction != 0 { input.direction = pad.direction }
        input.run = input.run || pad.run
        game.input = input

        handle(game.update(dt: dt))
        audio.setListener(at: game.player.cell, facing: game.player.facing)
        audio.setHunterOcclusion(hunterOcclusion())
        updateHeartbeat(now: now)
        if now >= nextThunder {
            audio.thunder()
            nextThunder = now + Double.random(in: 35...80)
        }
        view?.setNeedsDisplay()
    }

    private func hunterOcclusion() -> Int {
        if game.plan.hasLineOfSight(from: game.player.cell, to: game.hunter.cell) { return 0 }
        let d = game.plan.walkingDistance(from: game.player.cell, to: game.hunter.cell) ?? 99
        return d <= 8 ? 1 : 2
    }

    private func updateHeartbeat(now: CFTimeInterval) {
        guard now >= nextHeartbeat else { return }
        let d = game.plan.walkingDistance(from: game.player.cell, to: game.hunter.cell) ?? 99
        let interval: Double
        let strength: Float
        if game.hunter.mode == .chase {
            interval = 0.42; strength = 1
        } else if d <= 4 {
            interval = 0.5; strength = 0.9
        } else if d <= 8 {
            interval = 0.7; strength = 0.6
        } else if d <= 14 {
            interval = 0.95; strength = 0.35
        } else {
            nextHeartbeat = now + 0.5
            return
        }
        audio.heartbeat(volume: strength * 0.8)
        haptics.heartbeat(intensity: strength)
        nextHeartbeat = now + interval
    }

    // MARK: Events

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case let .footstep(actor, cell, surface, running):
                if actor == .player {
                    audio.playerStep(surface, running: running)
                } else {
                    audio.hunterStep(surface, at: cell, running: running)
                }
            case .creak:
                audio.creak()
            case .bump:
                audio.effect("bump", volume: 0.7)
                haptics.bump()
            case .facingDoor:
                audio.effect("door_cue", volume: 0.6)
            case .searchStarted:
                audio.effect("search")
            case let .searched(_, item):
                if item == .frontDoorKey {
                    audio.effect("key_found")
                    haptics.found()
                } else if case .tape? = item {
                    audio.effect("tape_click")
                }
            case .hid:
                audio.effect("hide", volume: 0.7)
                audio.setHiding(true)
            case .leftHiding:
                audio.effect("unhide", volume: 0.7)
                audio.setHiding(false)
            case .frontDoorLocked:
                audio.effect("door_locked")
            case .unlockStarted:
                audio.effect("unlock")
            case .unlockInterrupted:
                audio.stopEffects()
            case .escaped:
                audio.setHiding(false)
                audio.effect("door_open")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.audio.effect("escaped") }
                music.stop(fade: 0.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if self?.stopped == false { self?.music.play(.escaped, fade: 1) }
                }
                end(.escaped)
            case .caught:
                audio.setHiding(false)
                audio.effect("caught")
                haptics.caught()
                music.stop(fade: 0.3)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    if self?.stopped == false { self?.music.play(.caught, fade: 2) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.playVoice(.hostCaught, from: nil)
                }
                end(.caught)
            case let .voice(line, from):
                playVoice(line, from: from)
            case let .hunterStateChanged(mode):
                if mode == .chase {
                    haptics.spotted()
                    music.play(.chase, fade: 0.4)
                } else if music.current == .chase {
                    // Back to sneaking music once he's lost you.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        guard let self, self.phase == .playing, self.game.hunter.mode != .chase else { return }
                        self.music.play(.explore, fade: 4)
                    }
                }
            case .turned, .enteredRoom, .enteredDoorway, .arrivedAt, .alreadySearched, .cantHideNow:
                break
            }
            autoStop(for: event)
            speak(for: event)
        }
    }

    private func speak(for event: GameEvent) {
        if case .turned = event, !settings.announceTurns { return }
        guard let text = Phrases.speech(for: event, game: game) else { return }
        let priority: SpeechPriority
        switch event {
        case .bump, .facingDoor, .enteredDoorway: priority = .low
        case .turned, .searched, .caught, .escaped, .cantHideNow: priority = .high
        default: priority = .normal
        }
        announcer.speak(text, priority: priority)
    }

    private func playVoice(_ line: VoiceLine, from cell: Cell?) {
        audio.voice(line, from: cell)
        let who: String
        switch line.speaker {
        case .hunter: who = "The Hunter"
        case .host: who = "The Host"
        case .friend: who = "Your friend"
        }
        showCaption("\(who): “\(line.text)”")
    }

    private func showCaption(_ text: String) {
        caption = text
    }

    private func end(_ outcome: Outcome) {
        touchInput = MoveInput()
        phase = .ended(outcome)
        view?.setNeedsDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    // MARK: Commands

    func handle(_ command: GameCommand) {
        if phase == .intro {
            // Any button skips the intro.
            if command == .pause { pause() } else { finishIntro(announce: true) }
            return
        }
        guard phase == .playing else {
            if command == .pause, phase == .paused { resume() }
            return
        }
        switch command {
        case .turnLeft: handle(game.perform(.turnLeft))
        case .turnRight: handle(game.perform(.turnRight))
        case .turnAround: handle(game.perform(.turnAround))
        case .interact: handle(game.perform(.interact))
        case .describe: announcer.speak(Phrases.describe(game), priority: .high)
        case .listen: announcer.speak(Phrases.listen(game), priority: .high)
        case .pause: pause()
        }
        audio.setListener(at: game.player.cell, facing: game.player.facing)
        view?.setNeedsDisplay()
    }

    // MARK: Touch

    private struct Gesture {
        var start: CGPoint
        var startTime: CFTimeInterval
        var maxTouches: Int
        var current: CGPoint
    }

    private var gesture: Gesture?
    private var lastTapTime: CFTimeInterval = 0

    private var isWalking: Bool { touchInput.direction != 0 }

    /// Touch: swipe up to walk (you keep walking), swipe up again to run, tap to stop, swipe down to stop or turn
    /// around, swipe left or right to turn, double tap to use, two-finger tap to describe, three-finger tap to listen,
    /// two-finger swipe down to pause. Walking stops by itself at doorways, furniture and walls.
    func touchesChanged(_ event: UIEvent?, in view: UIView) {
        let active = (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }
        let now = CACurrentMediaTime()
        let points = active.map { $0.location(in: view) }
        let centroid = points.isEmpty ? nil : CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                                                      y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
        if var g = gesture {
            if let centroid {
                if active.count > g.maxTouches {
                    g.maxTouches = active.count
                    g.start = centroid
                }
                g.current = centroid
                gesture = g
            } else {
                finishGesture(g, now: now)
                gesture = nil
            }
        } else if let centroid {
            gesture = Gesture(start: centroid, startTime: now, maxTouches: active.count, current: centroid)
        }
    }

    private func finishGesture(_ g: Gesture, now: CFTimeInterval) {
        let dx = g.current.x - g.start.x, dy = g.current.y - g.start.y
        let moved = (dx * dx + dy * dy).squareRoot()
        let duration = now - g.startTime
        switch g.maxTouches {
        case 1:
            let swipe = moved > 40 && duration < 0.8
            if swipe && abs(dy) > abs(dx) * 1.2 {
                if dy < 0 { swipeUp() } else { swipeDown() }
            } else if swipe && abs(dx) > abs(dy) * 1.2 {
                stopWalking(announce: false)
                handle(dx > 0 ? .turnRight : .turnLeft)
            } else if moved < 20 && duration < 0.35 {
                if isWalking {
                    stopWalking(announce: true)
                    lastTapTime = 0
                } else if now - lastTapTime < 0.4 {
                    lastTapTime = 0
                    handle(.interact)
                } else {
                    lastTapTime = now
                }
            }
        case 2:
            if dy > 60 && abs(dy) > abs(dx) {
                handle(.pause)
            } else if moved < 30 && duration < 0.5 {
                handle(.describe)
            }
        default:
            if moved < 40 && duration < 0.6 { handle(.listen) }
        }
    }

    private func swipeUp() {
        guard phase == .playing else {
            if phase == .intro { finishIntro(announce: true) }
            return
        }
        if game.player.hidingIn != nil {
            announcer.speak("You're hiding. Double tap to come out first.", priority: .high)
            return
        }
        if isWalking && !touchInput.run {
            touchInput = MoveInput(direction: 1, run: true)
            announcer.speak("Running", priority: .high)
        } else if !isWalking {
            touchInput = MoveInput(direction: 1)
            announcer.speak("Walking", priority: .high)
        }
    }

    private func swipeDown() {
        guard phase == .playing else { return }
        if isWalking {
            stopWalking(announce: true)
        } else {
            handle(.turnAround)
        }
    }

    private func stopWalking(announce: Bool) {
        guard isWalking else { return }
        touchInput = MoveInput()
        if announce { announcer.speak("Stopped", priority: .high) }
    }

    /// Walking with touch stops by itself where there's something to know about. Running only stops at walls,
    /// so you can get away.
    private func autoStop(for event: GameEvent) {
        guard isWalking else { return }
        switch event {
        case .bump, .hid, .searchStarted, .unlockStarted, .caught, .escaped:
            touchInput = MoveInput()
        case .arrivedAt, .enteredDoorway:
            if !touchInput.run { touchInput = MoveInput() }
        default:
            break
        }
    }
}
