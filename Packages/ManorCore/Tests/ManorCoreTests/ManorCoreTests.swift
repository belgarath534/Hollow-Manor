import XCTest
@testable import ManorCore

final class FloorPlanTests: XCTestCase {
    let plan = Mansion.groundFloor

    func testMapRowsAreTheSameWidth() {
        XCTAssertEqual(Set(Mansion.map.map(\.count)).count, 1)
        XCTAssertEqual(plan.width, 25)
        XCTAssertEqual(plan.height, 14)
    }

    func testEveryFeatureIsOnTheFloor() {
        for f in plan.features {
            XCTAssertNotNil(plan.room(at: f.cell), "\(f.name) at \(f.cell) is not in a room")
        }
        XCTAssertEqual(Set(plan.features.map(\.cell)).count, plan.features.count, "two features share a cell")
    }

    func testEveryRoomCanReachEveryOther() {
        let start = Mansion.playerStart
        for room in plan.rooms {
            let cell = plan.cells(in: room)[0]
            XCTAssertNotNil(plan.path(from: start, to: cell), "can't reach \(room.name)")
        }
    }

    func testEveryDoorJoinsTwoRooms() {
        for room in plan.rooms {
            for door in plan.doors(of: room) {
                XCTAssertEqual(plan.roomsBeside(door: door).count, 2, "door at \(door)")
            }
        }
    }

    func testWallsBlockSightButDoorwaysDont() {
        // Kitchen to dining room through the wall: no.
        XCTAssertFalse(plan.hasLineOfSight(from: Cell(6, 1), to: Cell(8, 1)))
        // Straight through the kitchen-dining doorway: yes.
        XCTAssertTrue(plan.hasLineOfSight(from: Cell(5, 3), to: Cell(9, 3)))
        // Along the hallway: yes.
        XCTAssertTrue(plan.hasLineOfSight(from: Cell(1, 6), to: Cell(23, 7)))
    }

    func testPathGoesThroughDoors() {
        let path = plan.path(from: Cell(1, 1), to: Cell(1, 10))!
        XCTAssertTrue(path.contains(Cell(3, 5)))
        XCTAssertTrue(path.contains(Cell(3, 8)))
    }
}

final class PhraseTests: XCTestCase {
    func testRelativeDirections() {
        let me = Cell(5, 5)
        XCTAssertEqual(Phrases.whereIs(Cell(5, 2), from: me, facing: .north), "3 steps ahead")
        XCTAssertEqual(Phrases.whereIs(Cell(7, 2), from: me, facing: .north), "3 steps ahead and 2 steps to the right")
        XCTAssertEqual(Phrases.whereIs(Cell(4, 5), from: me, facing: .north), "1 step to your left")
        XCTAssertEqual(Phrases.whereIs(Cell(5, 6), from: me, facing: .north), "1 step behind you")
        // Facing east, north is to the left.
        XCTAssertEqual(Phrases.whereIs(Cell(5, 3), from: me, facing: .east), "2 steps to your left")
        XCTAssertEqual(Phrases.whereIs(me, from: me, facing: .west), "right here")
    }

    func testDescribeMentionsRoomDoorsAndFurniture() {
        let game = Game(seed: 1)
        let text = Phrases.describe(game)
        XCTAssertTrue(text.hasPrefix("Foyer, marble floor. Facing north."), text)
        XCTAssertTrue(text.contains("Front door, 1 step behind you."), text)
        XCTAssertTrue(text.contains("Door to the hallway"), text)
        XCTAssertTrue(text.contains("Coat closet"), text)
    }

    func testListenSaysWhereHeIs() {
        let game = Game(seed: 1)
        let text = Phrases.listen(game)
        XCTAssertTrue(text.contains("far away in the kitchen"), text)
    }
}

final class GameTests: XCTestCase {
    /// Runs the game for a while and returns everything that happened.
    @discardableResult
    func run(_ game: Game, seconds: Double, step: Double = 0.05) -> [GameEvent] {
        var events: [GameEvent] = []
        var t = 0.0
        while t < seconds {
            events += game.update(dt: step)
            t += step
        }
        return events
    }

    func testWalkingMovesOneStepAtATimeAndAnnouncesRooms() {
        let game = Game(seed: 2)
        game.debugPlace(hunter: Cell(1, 1))
        game.input = MoveInput(direction: 1)
        let events = run(game, seconds: 2)
        XCTAssertEqual(game.player.cell.x, 16)
        XCTAssertLessThan(game.player.cell.y, 11)
        XCTAssertTrue(events.contains { if case .footstep(.player, _, .marble, false) = $0 { return true } else { return false } })
    }

    func testWalkingIntoAWallBumps() {
        let game = Game(seed: 2)
        game.debugPlace(player: Cell(13, 9), facing: .west)
        game.input = MoveInput(direction: 1)
        let events = run(game, seconds: 0.3)
        XCTAssertEqual(game.player.cell, Cell(13, 9))
        XCTAssertTrue(events.contains(.bump(Cell(12, 9))))
    }

    func testFrontDoorNeedsTheKey() {
        let game = Game(seed: 3)
        game.debugPlace(player: Cell(16, 12), facing: .south)
        XCTAssertEqual(game.perform(.interact), [.frontDoorLocked])
        game.debugGive(.frontDoorKey)
        XCTAssertTrue(game.perform(.interact).contains(.unlockStarted))
        let events = run(game, seconds: 3)
        XCTAssertTrue(events.contains(.escaped))
        XCTAssertEqual(game.outcome, .escaped)
    }

    func testTheKeyIsSomewhereSearchableAndFindingItWorks() {
        for seed in 0..<20 {
            let game = Game(seed: UInt64(seed))
            let spot = try! XCTUnwrap(game.keyLocation)
            XCTAssertEqual(spot.kind, .searchable)
            XCTAssertNotEqual(spot.id, Mansion.tapeSpot)
            // Keep him busy far away.
            game.debugPlace(hunter: spot.cell.x < 12 ? Cell(23, 12) : Cell(1, 1))
            game.debugPlace(player: spot.cell)
            XCTAssertTrue(game.perform(.interact).contains(.searchStarted(spot)))
            let events = run(game, seconds: 1.5)
            if game.outcome == nil {
                XCTAssertTrue(events.contains(.searched(spot, found: .frontDoorKey)))
                XCTAssertTrue(game.player.items.contains(.frontDoorKey))
            }
        }
    }

    func testStudyDeskHasTheTape() {
        let game = Game(seed: 4)
        let desk = Mansion.groundFloor.feature(id: Mansion.tapeSpot)!
        game.debugPlace(hunter: Cell(23, 1))
        game.debugPlace(player: desk.cell)
        _ = game.perform(.interact)
        let events = run(game, seconds: 1.5)
        XCTAssertTrue(events.contains(.searched(desk, found: .tape(1))))
        XCTAssertTrue(events.contains(.voice(.friendTape1, from: nil)))
    }

    func testRunningInTheHallwayIsHeardFromTheKitchen() {
        let game = Game(seed: 5)
        game.debugPlace(hunter: Cell(3, 3))
        game.debugPlace(player: Cell(10, 6), facing: .east)
        game.input = MoveInput(direction: 1, run: true)
        let events = run(game, seconds: 0.6)
        XCTAssertTrue(events.contains(.hunterStateChanged(.investigate)), "\(events)")
    }

    func testWalkingOnCarpetFarAwayIsNotHeard() {
        let game = Game(seed: 6)
        game.debugPlace(hunter: Cell(1, 12))
        game.debugPlace(player: Cell(17, 2), facing: .east)
        game.input = MoveInput(direction: 1)
        let events = run(game, seconds: 1.5)
        XCTAssertFalse(events.contains(.hunterStateChanged(.investigate)))
    }

    func testHeSeesYouAndCatchesYouIfYouStand() {
        let game = Game(seed: 7)
        game.debugPlace(hunter: Cell(14, 6))
        game.debugPlace(player: Cell(20, 6), facing: .west)
        let events = run(game, seconds: 5)
        XCTAssertTrue(events.contains(.hunterStateChanged(.chase)))
        XCTAssertTrue(events.contains(.caught))
        XCTAssertEqual(game.outcome, .caught)
    }

    func testHidingOutOfSightKeepsYouSafe() {
        let game = Game(seed: 8)
        let wardrobe = Mansion.groundFloor.feature(id: "wardrobe")!
        game.debugPlace(player: wardrobe.cell)
        game.debugPlace(hunter: Cell(20, 1))
        XCTAssertEqual(game.perform(.interact).first, .hid(wardrobe))
        // Even if he wanders right past.
        game.debugPlace(hunter: Cell(6, 12), mode: .search)
        run(game, seconds: 20)
        XCTAssertNil(game.outcome)
        XCTAssertFalse(game.hunter.sawPlayerHide)
    }

    func testHidingWhileHeWatchesDoesntWork() {
        let game = Game(seed: 9)
        let table = Mansion.groundFloor.feature(id: "diningTable")!
        game.debugPlace(player: table.cell)
        game.debugPlace(hunter: Cell(8, 2))
        run(game, seconds: 0.05) // he spots you
        XCTAssertEqual(game.hunter.mode, .chase)
        XCTAssertEqual(game.perform(.interact).first, .hid(table))
        XCTAssertTrue(game.hunter.sawPlayerHide)
        run(game, seconds: 5)
        XCTAssertEqual(game.outcome, .caught)
    }

    func testRunningAwayIsFasterThanHisChase() {
        XCTAssertLessThan(Game.runStep, Game.hunterChaseStep)
        XCTAssertGreaterThan(Game.walkStep, Game.hunterChaseStep)
    }

    func testHeWandersOnHisOwn() {
        let game = Game(seed: 10)
        let start = game.hunter.cell
        game.debugPlace(player: Cell(23, 12)) // out of the way
        run(game, seconds: 20)
        XCTAssertNotEqual(game.hunter.cell, start)
    }

    func testEverySpeechEventHasText() {
        let game = Game(seed: 11)
        let f = Mansion.groundFloor.features[0]
        let events: [GameEvent] = [.searched(f, found: nil), .hid(f), .frontDoorLocked, .escaped, .caught]
        for e in events { XCTAssertNotNil(Phrases.speech(for: e, game: game)) }
    }
}

final class VoiceLineTests: XCTestCase {
    /// The game's lines and tools/voices/lines.json must list the same ids and text.
    func testLinesFileMatches() throws {
        let here = URL(fileURLWithPath: #filePath)
        let file = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("tools/voices/lines.json")
        let data = try Data(contentsOf: file)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let lines = json["lines"] as! [[String: Any]]
        var byID: [String: String] = [:]
        for line in lines { byID[line["id"] as! String] = line["text"] as? String }
        for line in VoiceLine.allCases {
            XCTAssertEqual(byID[line.rawValue], line.text, "\(line.rawValue) differs between the game and lines.json")
        }
    }
}
