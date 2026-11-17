public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, normal, hard

    /// Multiplies the time between the Hunter's steps (bigger is slower).
    var hunterStepScale: Double {
        switch self {
        case .easy: return 1.3
        case .normal: return 1
        case .hard: return 0.85
        }
    }

    /// Multiplies how far he can hear.
    var hearingScale: Double {
        switch self {
        case .easy: return 0.75
        case .normal: return 1
        case .hard: return 1.3
        }
    }

    /// How far he can see, in steps.
    var sightRange: Double {
        switch self {
        case .easy: return 5
        case .normal: return 7
        case .hard: return 9
        }
    }
}

public enum Item: Equatable, Hashable, Sendable {
    case frontDoorKey
    case tape(Int)

    public var name: String {
        switch self {
        case .frontDoorKey: return "the front door key"
        case let .tape(n): return n == 1 ? "a cassette tape" : "cassette tape \(n)"
        }
    }
}

public enum Actor: Equatable, Sendable { case player, hunter }

public enum Outcome: Equatable, Sendable { case caught, escaped }

public enum PlayerAction: Equatable, Sendable {
    case turnLeft, turnRight, turnAround
    /// Search, hide, come out, or unlock, depending on where the player is standing.
    case interact
}

/// Everything that happens in the game, for the app to turn into sound, speech, haptics and pictures.
public enum GameEvent: Equatable, Sendable {
    case footstep(Actor, Cell, Surface, running: Bool)
    /// A loud floorboard creak under the player.
    case creak(Cell)
    case bump(Cell)
    case turned(Facing)
    case enteredRoom(Room)
    case enteredDoorway([Room])
    /// The cell straight ahead is a doorway into this room.
    case facingDoor(Room?)
    case arrivedAt(Feature)
    case searchStarted(Feature)
    case searched(Feature, found: Item?)
    case alreadySearched(Feature)
    case hid(Feature)
    case leftHiding(Feature)
    case cantHideNow(Feature)
    case frontDoorLocked
    case unlockStarted
    case unlockInterrupted
    case escaped
    case caught
    /// A recorded line. `from` is where the speaker is; nil for the Host, who is somewhere upstairs.
    case voice(VoiceLine, from: Cell?)
    case hunterStateChanged(HunterMode)
}

public enum HunterMode: Equatable, Sendable {
    /// Wandering from room to room.
    case patrol
    /// Going to check a noise.
    case investigate
    /// Can see the player and is running at them.
    case chase
    /// Lost the player; looking around nearby.
    case search
}

public struct Player: Sendable {
    public var cell: Cell
    public var facing: Facing
    public var hidingIn: Feature?
    public var items: Set<Item> = []
    public var isRunning = false
}

public struct Hunter: Sendable {
    public var cell: Cell
    public var mode: HunterMode = .patrol
    public var target: Cell?
    public var lastSeenPlayer: Cell?
    /// He watched the player get into a hiding spot, so he knows where they are.
    public var sawPlayerHide = false
    var stepTimer: Double = 0
    var waitUntil: Double = 0
    var searchUntil: Double = 0
}

/// Continuous movement input, set every frame by the app from touch, keyboard or controller.
public struct MoveInput: Equatable, Sendable {
    /// 1 walks forward, -1 steps backward, 0 stands still.
    public var direction: Int = 0
    public var run = false

    public init(direction: Int = 0, run: Bool = false) {
        self.direction = direction
        self.run = run
    }
}

/// One night in Hollow Manor.
public final class Game {
    public let plan: FloorPlan
    public let difficulty: Difficulty
    public private(set) var player: Player
    public private(set) var hunter: Hunter
    public private(set) var time: Double = 0
    public private(set) var outcome: Outcome?
    /// Which searchable things have been searched already.
    public private(set) var searched: Set<String> = []
    public var input = MoveInput()

    /// Seconds per step.
    public static let walkStep = 0.45
    public static let runStep = 0.26
    static let hunterPatrolStep = 0.85
    static let hunterInvestigateStep = 0.55
    static let hunterChaseStep = 0.36
    static let searchTime = 1.2
    static let unlockTime = 2.5

    private var rng: SeededRandom
    private let hiddenItems: [String: Item]
    private var stepCooldown: Double = 0
    private var busyUntil: Double?
    private var busyAction: BusyAction?
    private var lastRoom: Room?
    private var nextHunterBark: Double
    private var nextHostTaunt: Double
    private var speakerFreeAt: [Speaker: Double] = [:]

    private enum BusyAction { case search(Feature), unlock }

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max), difficulty: Difficulty = .normal,
                plan: FloorPlan = Mansion.groundFloor) {
        self.plan = plan
        self.difficulty = difficulty
        rng = SeededRandom(seed: seed)
        player = Player(cell: Mansion.playerStart, facing: .north)
        hunter = Hunter(cell: Mansion.hunterStart)
        lastRoom = plan.room(at: Mansion.playerStart)

        // The key goes in a random drawer or cupboard. The tape is always in the study desk.
        let spots = plan.features.filter { $0.kind == .searchable && $0.id != Mansion.tapeSpot }
        var items: [String: Item] = [Mansion.tapeSpot: .tape(1)]
        if let keySpot = spots.randomElement(using: &rng) { items[keySpot.id] = .frontDoorKey }
        hiddenItems = items
        nextHunterBark = 15
        nextHostTaunt = 50
    }

    public var playerRoom: Room? { plan.room(at: player.cell) }
    public var hunterRoom: Room? { plan.room(at: hunter.cell) }
    public var isBusy: Bool { busyUntil != nil }

    /// Where the key is hidden (for tests and the sighted map after the game).
    public var keyLocation: Feature? {
        hiddenItems.first { $0.value == .frontDoorKey }.flatMap { plan.feature(id: $0.key) }
    }

    /// True when the Hunter could see the player right now if they weren't hiding.
    public var hunterHasLineOfSight: Bool {
        hunter.cell.distance(to: player.cell) <= difficulty.sightRange
            && plan.hasLineOfSight(from: hunter.cell, to: player.cell)
    }

    // MARK: Player actions

    public func perform(_ action: PlayerAction) -> [GameEvent] {
        guard outcome == nil else { return [] }
        var events: [GameEvent] = []
        switch action {
        case .turnLeft, .turnRight, .turnAround:
            guard player.hidingIn == nil, !isBusy else { return [] }
            switch action {
            case .turnLeft: player.facing = player.facing.left
            case .turnRight: player.facing = player.facing.right
            default: player.facing = player.facing.opposite
            }
            events.append(.turned(player.facing))
            events.append(contentsOf: facingEvents())
        case .interact:
            events.append(contentsOf: interact())
        }
        return events
    }

    private func interact() -> [GameEvent] {
        if let spot = player.hidingIn {
            player.hidingIn = nil
            hunter.sawPlayerHide = false
            var events: [GameEvent] = [.leftHiding(spot)]
            events.append(contentsOf: makeNoise(at: player.cell, loudness: 2))
            return events
        }
        guard !isBusy, let feature = plan.feature(at: player.cell) else { return [] }
        switch feature.kind {
        case .searchable:
            if searched.contains(feature.id) { return [.alreadySearched(feature)] }
            busyUntil = time + Self.searchTime
            busyAction = .search(feature)
            return [.searchStarted(feature)] + makeNoise(at: player.cell, loudness: 4)
        case .hidingSpot:
            // Can't get in with him standing right there.
            if hunter.cell.manhattan(to: player.cell) <= 1 { return [.cantHideNow(feature)] }
            player.hidingIn = feature
            hunter.sawPlayerHide = hunterHasLineOfSight
            var events: [GameEvent] = [.hid(feature)]
            events.append(contentsOf: makeNoise(at: player.cell, loudness: 2))
            return events
        case .frontDoor:
            guard player.items.contains(.frontDoorKey) else { return [.frontDoorLocked] }
            busyUntil = time + Self.unlockTime
            busyAction = .unlock
            return [.unlockStarted] + makeNoise(at: player.cell, loudness: 6)
        case .landmark:
            return [.arrivedAt(feature)]
        }
    }

    // MARK: Time

    public func update(dt: Double) -> [GameEvent] {
        guard outcome == nil else { return [] }
        time += dt
        var events: [GameEvent] = []

        if let until = busyUntil, time >= until {
            events.append(contentsOf: finishBusyAction())
            if outcome != nil { return events }
        }

        events.append(contentsOf: updatePlayerMovement(dt: dt))
        events.append(contentsOf: updateHunter(dt: dt))
        events.append(contentsOf: updateChatter())
        if checkCaught() {
            outcome = .caught
            busyUntil = nil
            events.append(.voice(.hunterCaught, from: hunter.cell))
            events.append(.caught)
        }
        return events
    }

    private func finishBusyAction() -> [GameEvent] {
        let action = busyAction
        busyUntil = nil
        busyAction = nil
        switch action {
        case let .search(feature):
            searched.insert(feature.id)
            let item = hiddenItems[feature.id]
            if let item { player.items.insert(item) }
            var events: [GameEvent] = [.searched(feature, found: item)]
            if item == .tape(1) { events.append(.voice(.friendTape1, from: nil)) }
            return events
        case .unlock:
            outcome = .escaped
            return [.escaped, .voice(.hostEscaped, from: nil)]
        case nil:
            return []
        }
    }

    private func updatePlayerMovement(dt: Double) -> [GameEvent] {
        stepCooldown = max(0, stepCooldown - dt)
        player.isRunning = input.run && input.direction > 0
        guard input.direction != 0, player.hidingIn == nil, stepCooldown == 0 else { return [] }
        if isBusy {
            // Walking away stops searching or unlocking.
            let wasUnlocking = { if case .unlock = busyAction { return true } else { return false } }()
            busyUntil = nil
            busyAction = nil
            if wasUnlocking { return [.unlockInterrupted] }
        }
        let dir = input.direction > 0 ? player.facing : player.facing.opposite
        let next = player.cell.moved(dir)
        let running = player.isRunning
        stepCooldown = running ? Self.runStep : (input.direction > 0 ? Self.walkStep : Self.walkStep * 1.3)
        guard plan.isWalkable(next) else {
            // Hold off the next bump so walking into a wall isn't a rattle of bumps.
            stepCooldown = 0.6
            return [.bump(next)] + makeNoise(at: player.cell, loudness: 2)
        }
        player.cell = next
        let surface = plan.surface(at: next)
        var events: [GameEvent] = [.footstep(.player, next, surface, running: running)]
        var loudness = surface.walkNoise
        if running { loudness = loudness * 3 + 2 }
        if surface == .creakyWood && Double.random(in: 0..<1, using: &rng) < (running ? 0.5 : 0.25) {
            events.append(.creak(next))
            loudness += 3
        }
        events.append(contentsOf: makeNoise(at: next, loudness: loudness))

        if let room = plan.room(at: next) {
            if room != lastRoom { events.append(.enteredRoom(room)) }
            lastRoom = room
        } else if plan.isDoor(next) {
            events.append(.enteredDoorway(plan.roomsBeside(door: next)))
        }
        if let feature = plan.feature(at: next) { events.append(.arrivedAt(feature)) }
        events.append(contentsOf: facingEvents())
        return events
    }

    private func facingEvents() -> [GameEvent] {
        let ahead = player.cell.moved(player.facing)
        guard plan.isDoor(ahead) else { return [] }
        let beyond = ahead.moved(player.facing)
        return [.facingDoor(plan.room(at: beyond))]
    }

    // MARK: Noise and the Hunter

    /// A noise the Hunter may hear. Loudness is how many steps away (along the route through the house) it carries.
    private func makeNoise(at cell: Cell, loudness: Int) -> [GameEvent] {
        guard hunter.mode != .chase else { return [] }
        let range = Double(loudness) * difficulty.hearingScale
        guard let distance = plan.walkingDistance(from: hunter.cell, to: cell), Double(distance) <= range else { return [] }
        var events: [GameEvent] = []
        let wasInvestigating = hunter.mode == .investigate
        hunter.target = cell
        hunter.waitUntil = 0
        if !wasInvestigating {
            events.append(contentsOf: setHunterMode(.investigate))
            if let line = pick(VoiceLine.hunterHeard), claim(.hunter, for: 3) {
                events.append(.voice(line, from: hunter.cell))
            }
            // When he's far away, the Host sends him.
            if distance > 6, Double.random(in: 0..<1, using: &rng) < 0.5,
               let line = pick(VoiceLine.hostHeard), claim(.host, for: 5) {
                events.append(.voice(line, from: nil))
            }
        }
        return events
    }

    private func setHunterMode(_ mode: HunterMode) -> [GameEvent] {
        guard hunter.mode != mode else { return [] }
        hunter.mode = mode
        if mode == .search { hunter.searchUntil = time + 6 }
        return [.hunterStateChanged(mode)]
    }

    private func updateHunter(dt: Double) -> [GameEvent] {
        var events: [GameEvent] = []

        // Eyes first.
        if player.hidingIn == nil && hunterHasLineOfSight {
            hunter.lastSeenPlayer = player.cell
            hunter.target = player.cell
            hunter.waitUntil = 0
            if hunter.mode != .chase {
                events.append(contentsOf: setHunterMode(.chase))
                if let line = pick(VoiceLine.hunterSpotted), claim(.hunter, for: 2) {
                    events.append(.voice(line, from: hunter.cell))
                }
            }
        } else if hunter.mode == .chase, let spot = player.hidingIn, hunter.sawPlayerHide {
            // He saw where you went.
            hunter.target = spot.cell
        }

        hunter.stepTimer -= dt
        guard hunter.stepTimer <= 0, time >= hunter.waitUntil else { return events }

        if hunter.target == nil || hunter.target == hunter.cell {
            events.append(contentsOf: hunterArrived())
            if time < hunter.waitUntil { return events }
        }
        guard let target = hunter.target, let route = plan.path(from: hunter.cell, to: target), let next = route.first
        else { return events }

        hunter.cell = next
        let interval: Double
        switch hunter.mode {
        case .patrol: interval = Self.hunterPatrolStep
        case .investigate, .search: interval = Self.hunterInvestigateStep
        case .chase: interval = Self.hunterChaseStep
        }
        hunter.stepTimer = interval * difficulty.hunterStepScale
        events.append(.footstep(.hunter, next, plan.surface(at: next), running: hunter.mode == .chase))
        return events
    }

    /// He got where he was going (or has nowhere to go). Decide what's next.
    private func hunterArrived() -> [GameEvent] {
        var events: [GameEvent] = []
        switch hunter.mode {
        case .chase:
            if player.hidingIn != nil && hunter.sawPlayerHide {
                // Standing at your hiding spot; checkCaught handles the rest.
                return events
            }
            if player.hidingIn == nil && hunterHasLineOfSight { return events }
            events.append(contentsOf: setHunterMode(.search))
            if let line = pick(VoiceLine.hunterLost), claim(.hunter, for: 3) {
                events.append(.voice(line, from: hunter.cell))
            }
            hunter.target = nearbyCell()
        case .investigate:
            events.append(contentsOf: setHunterMode(.search))
            hunter.waitUntil = time + 1.5
            hunter.target = nearbyCell()
        case .search:
            if time >= hunter.searchUntil {
                events.append(contentsOf: setHunterMode(.patrol))
                hunter.target = patrolTarget()
            } else {
                hunter.target = nearbyCell()
            }
        case .patrol:
            hunter.waitUntil = time + Double.random(in: 1.5...4, using: &rng)
            hunter.target = patrolTarget()
        }
        return events
    }

    private func nearbyCell() -> Cell {
        let candidates = (0..<12).compactMap { _ -> Cell? in
            let c = Cell(hunter.cell.x + Int.random(in: -3...3, using: &rng),
                         hunter.cell.y + Int.random(in: -3...3, using: &rng))
            return plan.isWalkable(c) && c != hunter.cell ? c : nil
        }
        return candidates.first ?? hunter.cell
    }

    private func patrolTarget() -> Cell {
        let others = plan.rooms.filter { $0 != hunterRoom }
        guard let room = others.randomElement(using: &rng) else { return hunter.cell }
        return plan.cells(in: room).randomElement(using: &rng) ?? hunter.cell
    }

    private func checkCaught() -> Bool {
        let near = hunter.cell.manhattan(to: player.cell) <= 1
        guard near else { return false }
        if player.hidingIn != nil { return hunter.sawPlayerHide && hunter.mode == .chase }
        return true
    }

    // MARK: Chatter

    private func updateChatter() -> [GameEvent] {
        var events: [GameEvent] = []
        if hunter.mode == .patrol && time >= nextHunterBark {
            nextHunterBark = time + Double.random(in: 18...32, using: &rng)
            if let line = pick(VoiceLine.hunterPatrol), claim(.hunter, for: 4) {
                events.append(.voice(line, from: hunter.cell))
            }
        }
        if time >= nextHostTaunt {
            nextHostTaunt = time + Double.random(in: 45...80, using: &rng)
            if let line = pick(VoiceLine.hostTaunts), claim(.host, for: 5) {
                events.append(.voice(line, from: nil))
            }
        }
        return events
    }

    private func pick(_ lines: [VoiceLine]) -> VoiceLine? { lines.randomElement(using: &rng) }

    /// Keeps one speaker from talking over themselves.
    private func claim(_ speaker: Speaker, for seconds: Double) -> Bool {
        if let free = speakerFreeAt[speaker], time < free { return false }
        speakerFreeAt[speaker] = time + seconds
        return true
    }

    // MARK: Testing hooks

    /// Moves the player directly (tests only).
    public func debugPlace(player cell: Cell, facing: Facing? = nil) {
        player.cell = cell
        if let facing { player.facing = facing }
        lastRoom = plan.room(at: cell)
    }

    /// Moves the Hunter directly (tests only).
    public func debugPlace(hunter cell: Cell, mode: HunterMode = .patrol) {
        hunter.cell = cell
        hunter.mode = mode
        hunter.target = nil
        hunter.stepTimer = 0
        hunter.waitUntil = 0
    }

    /// Gives the player an item (tests only).
    public func debugGive(_ item: Item) { player.items.insert(item) }
}
