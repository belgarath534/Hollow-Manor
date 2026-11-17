/// A square on the floor plan. x grows to the east, y grows to the south. One cell is one step.
public struct Cell: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ facing: Facing, by steps: Int = 1) -> Cell {
        Cell(x + facing.dx * steps, y + facing.dy * steps)
    }

    public func manhattan(to other: Cell) -> Int { abs(x - other.x) + abs(y - other.y) }

    public func distance(to other: Cell) -> Double {
        let dx = Double(x - other.x), dy = Double(y - other.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    public var neighbors: [Cell] { Facing.allCases.map { moved($0) } }

    public var description: String { "(\(x), \(y))" }
}

/// The four ways the player can face. North is the top of the map.
public enum Facing: Int, CaseIterable, Codable, Sendable {
    case north, east, south, west

    public var dx: Int {
        switch self {
        case .east: return 1
        case .west: return -1
        default: return 0
        }
    }

    public var dy: Int {
        switch self {
        case .south: return 1
        case .north: return -1
        default: return 0
        }
    }

    public var left: Facing { Facing(rawValue: (rawValue + 3) % 4)! }
    public var right: Facing { Facing(rawValue: (rawValue + 1) % 4)! }
    public var opposite: Facing { Facing(rawValue: (rawValue + 2) % 4)! }

    public var name: String {
        switch self {
        case .north: return "north"
        case .east: return "east"
        case .south: return "south"
        case .west: return "west"
        }
    }

    /// Where a world offset is, seen from someone facing this way: (steps ahead, steps to the right).
    public func relative(dx: Int, dy: Int) -> (ahead: Int, right: Int) {
        switch self {
        case .north: return (-dy, dx)
        case .east: return (dx, dy)
        case .south: return (dy, -dx)
        case .west: return (-dx, -dy)
        }
    }
}

/// Small, fast, seedable random numbers, so games can be replayed in tests.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
