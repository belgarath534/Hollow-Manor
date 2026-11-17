import ManorCore
import SwiftUI
import UIKit

/// The full-screen play area.
///
/// Accessibility: it is a single element with the "allows direct interaction" trait, so with VoiceOver on,
/// touches go straight to the game instead of being VoiceOver gestures. The game speaks for itself.
/// The drawing shows only the room you're in, top-down, for sighted players; it is never needed to play.
final class GameTouchView: UIView {
    weak var controller: GameController?
    private var lastRoom: Room?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = true
        backgroundColor = .black
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "Hollow Manor"
        accessibilityHint = "Touches go directly to the game. Swipe up to walk, tap to stop. Two-finger tap to describe the room."
        accessibilityTraits = .allowsDirectInteraction
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            UIAccessibility.post(notification: .screenChanged, argument: self)
        }
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { controller?.touchesChanged(event, in: self) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { controller?.touchesChanged(event, in: self) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { controller?.touchesChanged(event, in: self) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { controller?.touchesChanged(event, in: self) }

    override func accessibilityPerformMagicTap() -> Bool {
        controller?.handle(.describe)
        return true
    }

    override func accessibilityPerformEscape() -> Bool {
        controller?.handle(.pause)
        return true
    }

    // MARK: Drawing (for sighted players)

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let game = controller?.game else { return }
        let plan = game.plan
        let player = game.player
        if let room = plan.room(at: player.cell) { lastRoom = room }
        guard let room = lastRoom ?? plan.rooms.first else { return }
        let contrast = UIAccessibility.isDarkerSystemColorsEnabled

        // The room plus its walls fills the screen.
        let cells = plan.cells(in: room)
        let minX = (cells.map(\.x).min() ?? 0) - 1, maxX = (cells.map(\.x).max() ?? 0) + 1
        let minY = (cells.map(\.y).min() ?? 0) - 1, maxY = (cells.map(\.y).max() ?? 0) + 1
        let cols = CGFloat(maxX - minX + 1), rows = CGFloat(maxY - minY + 1)
        let top: CGFloat = 70, bottom: CGFloat = 110
        let size = min(bounds.width / cols, (bounds.height - top - bottom) / rows)
        let originX = (bounds.width - size * cols) / 2
        let originY = top + (bounds.height - top - bottom - size * rows) / 2
        func rect(_ c: Cell) -> CGRect {
            CGRect(x: originX + CGFloat(c.x - minX) * size, y: originY + CGFloat(c.y - minY) * size, width: size, height: size)
        }

        for y in minY...maxY {
            for x in minX...maxX {
                let c = Cell(x, y)
                let r = rect(c)
                switch plan.tile(at: c) {
                case .wall:
                    ctx.setFillColor(UIColor(white: contrast ? 0.6 : 0.18, alpha: 1).cgColor)
                case .door:
                    ctx.setFillColor(UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1).cgColor)
                case .floor:
                    ctx.setFillColor(floorColor(plan.surface(at: c), contrast: contrast).cgColor)
                }
                ctx.fill(r)
                if plan.isDoor(c), let other = plan.roomsBeside(door: c).first(where: { $0 != room }) {
                    drawText(other.name, in: r.insetBy(dx: -size * 2.5, dy: -size * 0.2), size: 11, color: .white)
                }
            }
        }

        // Furniture.
        for feature in plan.features(in: room) {
            let r = rect(feature.cell).insetBy(dx: size * 0.1, dy: size * 0.1)
            let searchedAlready = game.searched.contains(feature.id)
            let color: UIColor
            switch feature.kind {
            case .searchable: color = searchedAlready ? UIColor(white: 0.35, alpha: 1) : .systemOrange
            case .hidingSpot: color = .systemPurple
            case .frontDoor: color = .systemGreen
            case .landmark: color = .systemTeal
            }
            ctx.setFillColor(color.cgColor)
            ctx.fill(r)
            drawText(Phrases.capitalized(feature.name), in: r.insetBy(dx: -size * 0.6, dy: -size * 0.4), size: 11, color: .white)
        }

        // The Hunter, only if you could see him.
        if game.hunterHasLineOfSight && player.hidingIn == nil {
            let r = rect(game.hunter.cell).insetBy(dx: size * 0.12, dy: size * 0.12)
            ctx.setFillColor(UIColor.systemRed.cgColor)
            ctx.fillEllipse(in: r)
            drawText("Hunter", in: r.offsetBy(dx: 0, dy: -size * 0.7), size: 12, color: .systemRed)
        }

        // You: a triangle pointing the way you face.
        let pr = rect(player.cell)
        ctx.saveGState()
        ctx.translateBy(x: pr.midX, y: pr.midY)
        ctx.rotate(by: CGFloat(player.facing.rawValue) * .pi / 2)
        let s = size * 0.38
        ctx.move(to: CGPoint(x: 0, y: -s))
        ctx.addLine(to: CGPoint(x: s * 0.8, y: s * 0.8))
        ctx.addLine(to: CGPoint(x: -s * 0.8, y: s * 0.8))
        ctx.closePath()
        ctx.setFillColor((player.hidingIn == nil ? UIColor.white : UIColor(white: 1, alpha: 0.35)).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Room name and what you're carrying.
        var title = room.name
        if player.hidingIn != nil { title += " — hiding" }
        drawText(title, in: CGRect(x: 0, y: 20, width: bounds.width, height: 34), size: 24, color: .white)
        if player.items.contains(.frontDoorKey) {
            drawText("🔑 Front door key", in: CGRect(x: 0, y: 48, width: bounds.width, height: 20), size: 14, color: .systemYellow)
        }
    }

    private func floorColor(_ surface: Surface, contrast: Bool) -> UIColor {
        if contrast { return UIColor(white: 0.05, alpha: 1) }
        switch surface {
        case .wood: return UIColor(red: 0.28, green: 0.18, blue: 0.1, alpha: 1)
        case .creakyWood: return UIColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1)
        case .carpet: return UIColor(red: 0.25, green: 0.06, blue: 0.08, alpha: 1)
        case .tile: return UIColor(white: 0.32, alpha: 1)
        case .stone: return UIColor(white: 0.24, alpha: 1)
        case .marble: return UIColor(white: 0.42, alpha: 1)
        }
    }

    private func drawText(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor) {
        let scaled = min(size * 2, UIFontMetrics(forTextStyle: .body).scaledValue(for: size))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: scaled, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let h = str.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                 options: .usesLineFragmentOrigin, context: nil).height
        str.draw(in: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h))
    }
}

/// SwiftUI wrapper.
struct GameSurface: UIViewRepresentable {
    let controller: GameController
    let isActive: Bool

    func makeUIView(context: Context) -> GameTouchView {
        let view = GameTouchView(frame: .zero)
        view.controller = controller
        controller.view = view
        return view
    }

    func updateUIView(_ view: GameTouchView, context: Context) {
        view.accessibilityElementsHidden = !isActive
        view.isUserInteractionEnabled = isActive
    }
}
