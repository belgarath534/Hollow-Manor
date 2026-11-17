/// What a floor is made of. Each one sounds different underfoot and makes a different amount of noise.
public enum Surface: String, CaseIterable, Codable, Sendable {
    case wood, creakyWood, carpet, tile, stone, marble

    /// How far a normal walking step can be heard, in steps along the path through the house.
    public var walkNoise: Int {
        switch self {
        case .carpet, .stone: return 1
        case .wood, .tile, .marble: return 2
        case .creakyWood: return 3
        }
    }

    /// Spoken name, for "Describe".
    public var spokenName: String {
        switch self {
        case .wood: return "wooden floor"
        case .creakyWood: return "creaky old floorboards"
        case .carpet: return "thick carpet"
        case .tile: return "tile floor"
        case .stone: return "stone floor"
        case .marble: return "marble floor"
        }
    }
}

public struct Room: Equatable, Sendable {
    public let code: Character
    public let name: String
    /// "the kitchen", for sentences.
    public let spokenName: String
    public let surface: Surface
}

public enum FeatureKind: Equatable, Sendable {
    /// Can be searched once for an item (or nothing).
    case searchable
    /// The player can hide inside.
    case hidingSpot
    /// The way out. Needs the key.
    case frontDoor
    /// Makes a steady sound (like a clock) so players can find their way by ear.
    case landmark
}

/// Something in a room the player can use or hear.
public struct Feature: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let cell: Cell
    public let kind: FeatureKind

    public init(_ id: String, _ name: String, _ cell: Cell, _ kind: FeatureKind) {
        self.id = id
        self.name = name
        self.cell = cell
        self.kind = kind
    }
}

public enum Tile: Equatable, Sendable {
    case wall
    case floor(room: Int)
    case door
}

/// A floor of the house, made from a text map. `#` is a wall, `+` is a doorway, letters are rooms.
public struct FloorPlan: Sendable {
    public let width: Int
    public let height: Int
    public let rooms: [Room]
    public let features: [Feature]
    private let tiles: [Tile]

    public init(map: [String], rooms: [Room], features: [Feature]) {
        let rows = map.map(Array.init)
        height = rows.count
        width = rows.map(\.count).max() ?? 0
        self.rooms = rooms
        self.features = features
        var tiles: [Tile] = []
        tiles.reserveCapacity(width * height)
        for row in rows {
            for x in 0..<width {
                let c: Character = x < row.count ? row[x] : "#"
                if c == "+" {
                    tiles.append(.door)
                } else if let i = rooms.firstIndex(where: { $0.code == c }) {
                    tiles.append(.floor(room: i))
                } else {
                    tiles.append(.wall)
                }
            }
        }
        self.tiles = tiles
    }

    public func contains(_ cell: Cell) -> Bool {
        cell.x >= 0 && cell.y >= 0 && cell.x < width && cell.y < height
    }

    public func tile(at cell: Cell) -> Tile {
        contains(cell) ? tiles[cell.y * width + cell.x] : .wall
    }

    public func isWalkable(_ cell: Cell) -> Bool { tile(at: cell) != .wall }

    public func isDoor(_ cell: Cell) -> Bool { tile(at: cell) == .door }

    public func room(at cell: Cell) -> Room? {
        if case let .floor(i) = tile(at: cell) { return rooms[i] }
        return nil
    }

    /// The rooms on either side of a doorway.
    public func roomsBeside(door cell: Cell) -> [Room] {
        var result: [Room] = []
        for n in cell.neighbors {
            if let r = room(at: n), !result.contains(r) { result.append(r) }
        }
        return result
    }

    /// What's underfoot. Doorways are wooden thresholds.
    public func surface(at cell: Cell) -> Surface {
        room(at: cell)?.surface ?? .wood
    }

    public func cells(in room: Room) -> [Cell] {
        var result: [Cell] = []
        for y in 0..<height {
            for x in 0..<width {
                let c = Cell(x, y)
                if self.room(at: c) == room { result.append(c) }
            }
        }
        return result
    }

    /// Doorways leading out of a room.
    public func doors(of room: Room) -> [Cell] {
        var result: [Cell] = []
        for y in 0..<height {
            for x in 0..<width {
                let c = Cell(x, y)
                if isDoor(c), roomsBeside(door: c).contains(room) { result.append(c) }
            }
        }
        return result
    }

    public func features(in room: Room) -> [Feature] {
        features.filter { self.room(at: $0.cell) == room }
    }

    public func feature(at cell: Cell) -> Feature? {
        features.first { $0.cell == cell }
    }

    public func feature(id: String) -> Feature? {
        features.first { $0.id == id }
    }

    /// Shortest walking route from one cell to another (not including the start), or nil if there is none.
    public func path(from start: Cell, to goal: Cell) -> [Cell]? {
        guard isWalkable(start), isWalkable(goal) else { return nil }
        if start == goal { return [] }
        var previous: [Cell: Cell] = [start: start]
        var queue: [Cell] = [start]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            if current == goal { break }
            for n in current.neighbors where isWalkable(n) && previous[n] == nil {
                previous[n] = current
                queue.append(n)
            }
        }
        guard previous[goal] != nil else { return nil }
        var route: [Cell] = []
        var c = goal
        while c != start {
            route.append(c)
            c = previous[c]!
        }
        return route.reversed()
    }

    /// Walking distance in steps, or nil if unreachable.
    public func walkingDistance(from a: Cell, to b: Cell) -> Int? {
        path(from: a, to: b)?.count
    }

    /// True if nothing solid is between the two cells (a straight line through floor and doorways only).
    public func hasLineOfSight(from a: Cell, to b: Cell) -> Bool {
        var x0 = a.x, y0 = a.y
        let dx = abs(b.x - a.x), dy = -abs(b.y - a.y)
        let sx = a.x < b.x ? 1 : -1, sy = a.y < b.y ? 1 : -1
        var err = dx + dy
        while true {
            if !isWalkable(Cell(x0, y0)) { return false }
            if x0 == b.x && y0 == b.y { return true }
            let e2 = 2 * err
            var stepX = false, stepY = false
            if e2 >= dy { err += dy; x0 += sx; stepX = true }
            if e2 <= dx { err += dx; y0 += sy; stepY = true }
            // A diagonal step squeezing between two walls (around a corner) doesn't count as seeing through.
            if stepX && stepY && !isWalkable(Cell(x0 - sx, y0)) && !isWalkable(Cell(x0, y0 - sy)) { return false }
        }
    }
}
