import GameController
import ManorCore

enum GameCommand {
    case turnLeft, turnRight, turnAround, interact, describe, listen, pause
}

/// Game controllers (Xbox, PlayStation, MFi) and Bluetooth keyboards.
///
/// Keyboard: W / Up walk (hold), S / Down step back, Shift run, A / D or Left / Right turn, X turn around,
/// Space / E / Return search, hide or use, Q / Tab describe, L listen, Escape pause.
///
/// Controller: left stick walk, right trigger run, D-pad left / right or shoulders turn, D-pad down turn around,
/// A use, X describe, Y listen, Menu pause.
final class HardwareInput {
    var onCommand: ((GameCommand) -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.attachKeyboard()
        })
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            if let controller = note.object as? GCController { self?.attach(controller) }
        })
        attachKeyboard()
        GCController.controllers().forEach { attach($0) }
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = nil
    }

    private func attachKeyboard() {
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { [weak self] _, _, key, pressed in
            guard pressed, let command = HardwareInput.command(for: key) else { return }
            DispatchQueue.main.async { self?.onCommand?(command) }
        }
    }

    private static func command(for key: GCKeyCode) -> GameCommand? {
        switch key {
        case .keyA, .leftArrow: return .turnLeft
        case .keyD, .rightArrow: return .turnRight
        case .keyX: return .turnAround
        case .spacebar, .keyE, .returnOrEnter: return .interact
        case .keyQ, .tab: return .describe
        case .keyL: return .listen
        case .escape: return .pause
        default: return nil
        }
    }

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        func bind(_ button: GCControllerButtonInput, _ command: GameCommand) {
            button.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { DispatchQueue.main.async { self?.onCommand?(command) } }
            }
        }
        bind(pad.dpad.left, .turnLeft)
        bind(pad.dpad.right, .turnRight)
        bind(pad.leftShoulder, .turnLeft)
        bind(pad.rightShoulder, .turnRight)
        bind(pad.dpad.down, .turnAround)
        bind(pad.buttonA, .interact)
        bind(pad.buttonX, .describe)
        bind(pad.buttonY, .listen)
        bind(pad.buttonMenu, .pause)
    }

    /// Walking and running, polled every frame.
    func poll() -> MoveInput {
        var input = MoveInput()
        if let kb = GCKeyboard.coalesced?.keyboardInput {
            func down(_ keys: GCKeyCode...) -> Bool { keys.contains { kb.button(forKeyCode: $0)?.isPressed == true } }
            if down(.upArrow, .keyW) { input.direction = 1 }
            if down(.downArrow, .keyS) { input.direction = -1 }
            if down(.leftShift, .rightShift) { input.run = true }
        }
        for controller in GCController.controllers() {
            guard let pad = controller.extendedGamepad else { continue }
            let y = pad.leftThumbstick.yAxis.value
            if y > 0.4 { input.direction = 1 }
            if y < -0.4 { input.direction = -1 }
            if pad.rightTrigger.value > 0.3 { input.run = true }
        }
        return input
    }
}
