/// Everything the game says out loud (with the system voice or VoiceOver), kept here so it can be tested.
public enum Phrases {
    /// "3 steps ahead and 2 to your right", seen from the player.
    public static func whereIs(_ target: Cell, from cell: Cell, facing: Facing) -> String {
        let r = facing.relative(dx: target.x - cell.x, dy: target.y - cell.y)
        func steps(_ n: Int) -> String { n == 1 ? "1 step" : "\(n) steps" }
        var parts: [String] = []
        if r.ahead > 0 { parts.append("\(steps(r.ahead)) ahead") }
        if r.ahead < 0 { parts.append("\(steps(-r.ahead)) behind you") }
        if r.right > 0 { parts.append(parts.isEmpty ? "\(steps(r.right)) to your right" : "\(steps(r.right)) to the right") }
        if r.right < 0 { parts.append(parts.isEmpty ? "\(steps(-r.right)) to your left" : "\(steps(-r.right)) to the left") }
        return parts.isEmpty ? "right here" : parts.joined(separator: " and ")
    }

    /// Rough direction only: "ahead and to the left".
    public static func direction(of target: Cell, from cell: Cell, facing: Facing) -> String {
        let r = facing.relative(dx: target.x - cell.x, dy: target.y - cell.y)
        let ahead = r.ahead > 0 ? "ahead" : (r.ahead < 0 ? "behind you" : "")
        let side = r.right > 0 ? "to the right" : (r.right < 0 ? "to the left" : "")
        switch (ahead.isEmpty, side.isEmpty) {
        case (true, true): return "right next to you"
        case (false, true): return ahead
        case (true, false): return side == "to the right" ? "to your right" : "to your left"
        case (false, false): return "\(ahead) and \(side)"
        }
    }

    public static func doorName(_ door: Cell, in plan: FloorPlan, from room: Room?) -> String {
        let other = plan.roomsBeside(door: door).first { $0 != room }
        return other.map { "Door to \($0.spokenName)" } ?? "Door"
    }

    /// "Describe": where you are, which way you face, and what's around you.
    public static func describe(_ game: Game) -> String {
        let plan = game.plan, p = game.player
        var sentences: [String] = []
        if let spot = p.hidingIn {
            sentences.append("You're hiding in the \(spot.name).")
            sentences.append("Double tap to come out.")
            return sentences.joined(separator: " ")
        }
        guard let room = plan.room(at: p.cell) else {
            let rooms = plan.roomsBeside(door: p.cell).map(\.spokenName)
            return "You're in the doorway between \(rooms.joined(separator: " and ")), facing \(p.facing.name)."
        }
        sentences.append("\(room.name), \(room.surface.spokenName). Facing \(p.facing.name).")
        if game.hunterRoom == room && game.hunterHasLineOfSight {
            sentences.append("The Hunter is here, \(whereIs(game.hunter.cell, from: p.cell, facing: p.facing))!")
        }
        if let here = plan.feature(at: p.cell) {
            sentences.append("You're at the \(here.name). \(hint(for: here, game: game))")
        }
        for feature in plan.features(in: room) where feature.cell != p.cell {
            sentences.append("\(capitalized(feature.name)), \(whereIs(feature.cell, from: p.cell, facing: p.facing)).")
        }
        for door in plan.doors(of: room) {
            sentences.append("\(doorName(door, in: plan, from: room)), \(whereIs(door, from: p.cell, facing: p.facing)).")
        }
        return sentences.joined(separator: " ")
    }

    /// What double tap would do here.
    public static func hint(for feature: Feature, game: Game) -> String {
        switch feature.kind {
        case .searchable:
            return game.searched.contains(feature.id) ? "Already searched." : "Double tap to search."
        case .hidingSpot:
            return "Double tap to hide."
        case .frontDoor:
            return game.player.items.contains(.frontDoorKey) ? "Double tap to unlock it." : "It's locked."
        case .landmark:
            return ""
        }
    }

    /// "Listen": roughly where the Hunter is, as far as you can tell by ear.
    public static func listen(_ game: Game) -> String {
        let p = game.player, h = game.hunter
        guard let distance = game.plan.walkingDistance(from: p.cell, to: h.cell) else { return "You can't hear him." }
        let how: String
        switch distance {
        case 0...3: how = "very close"
        case 4...8: how = "close"
        case 9...16: how = "not far"
        default: how = "far away"
        }
        let place = game.hunterRoom.map { " in \($0.spokenName)" } ?? " in a doorway"
        let sameRoom = game.hunterRoom != nil && game.hunterRoom == game.playerRoom
        var text = "The Hunter is \(how)\(place)"
        text += sameRoom ? ", with you, \(direction(of: h.cell, from: p.cell, facing: p.facing))." :
            ", \(direction(of: h.cell, from: p.cell, facing: p.facing))."
        switch h.mode {
        case .patrol: text += " He's wandering."
        case .investigate: text += " He's coming to check a noise."
        case .chase: text += " He's after you!"
        case .search: text += " He's looking around."
        }
        return text
    }

    /// The short spoken line for an event, or nil if the event is only a sound.
    public static func speech(for event: GameEvent, game: Game) -> String? {
        switch event {
        case let .enteredRoom(room):
            return room.name
        case let .enteredDoorway(rooms):
            return rooms.count == 2 ? "Doorway" : nil
        case let .facingDoor(room):
            return room.map { "Door to \($0.spokenName) ahead" } ?? "Door ahead"
        case let .arrivedAt(feature):
            let h = hint(for: feature, game: game)
            return h.isEmpty ? capitalized(feature.name) : "\(capitalized(feature.name)). \(h)"
        case let .searchStarted(feature):
            return "Searching the \(feature.name)…"
        case let .searched(_, item):
            guard let item else { return "Nothing here." }
            switch item {
            case .frontDoorKey: return "You found the front door key! Get to the front door in the foyer."
            case .tape: return "You found a cassette tape. It's playing."
            }
        case let .alreadySearched(feature):
            return "You already searched the \(feature.name)."
        case let .hid(feature):
            return "Hiding in the \(feature.name). Stay quiet."
        case .leftHiding:
            return "You climb out."
        case .cantHideNow:
            return "He's too close to hide!"
        case .frontDoorLocked:
            return "The front door is locked. You need the key."
        case .unlockStarted:
            return "Unlocking the door… hold still."
        case .unlockInterrupted:
            return "You stopped unlocking."
        case .escaped:
            return "The door swings open. You're out!"
        case .caught:
            return "He caught you."
        case let .turned(facing):
            return capitalized(facing.name)
        case .bump:
            return "Wall"
        case .footstep, .creak, .voice, .hunterStateChanged:
            return nil
        }
    }

    public static func capitalized(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
