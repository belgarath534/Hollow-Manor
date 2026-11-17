/// Hollow Manor, ground floor.
///
///     x: 0         1         2
///        0123456789012345678901234
///      0 #########################
///      1 #KKKKKK#DDDDDDD#LLLLLLLL#    Kitchen, Dining room, Library
///      2 #KKKKKK#DDDDDDD#LLLLLLLL#
///      3 #KKKKKK+DDDDDDD#LLLLLLLL#
///      4 #KKKKKK#DDDDDDD#LLLLLLLL#
///      5 ###+#######+#######+#####
///      6 #HHHHHHHHHHHHHHHHHHHHHHH#    Hallway
///      7 #HHHHHHHHHHHHHHHHHHHHHHH#
///      8 ###+#######+#######+#####
///      9 #PPP#SSSSSSS#FFFFFFFFFFF#    Pantry, Study, Foyer
///     10 #PPP#SSSSSSS#FFFFFFFFFFF#
///     11 #PPP#SSSSSSS#FFFFFFFFFFF#
///     12 #PPP#SSSSSSS#FFFFFFFFFFF#
///     13 ################=########    = is the front door
public enum Mansion {
    public static let map = [
        "#########################",
        "#KKKKKK#DDDDDDD#LLLLLLLL#",
        "#KKKKKK#DDDDDDD#LLLLLLLL#",
        "#KKKKKK+DDDDDDD#LLLLLLLL#",
        "#KKKKKK#DDDDDDD#LLLLLLLL#",
        "###+#######+#######+#####",
        "#HHHHHHHHHHHHHHHHHHHHHHH#",
        "#HHHHHHHHHHHHHHHHHHHHHHH#",
        "###+#######+#######+#####",
        "#PPP#SSSSSSS#FFFFFFFFFFF#",
        "#PPP#SSSSSSS#FFFFFFFFFFF#",
        "#PPP#SSSSSSS#FFFFFFFFFFF#",
        "#PPP#SSSSSSS#FFFFFFFFFFF#",
        "################=########",
    ]

    public static let rooms = [
        Room(code: "K", name: "Kitchen", spokenName: "the kitchen", surface: .tile),
        Room(code: "D", name: "Dining room", spokenName: "the dining room", surface: .wood),
        Room(code: "L", name: "Library", spokenName: "the library", surface: .carpet),
        Room(code: "H", name: "Hallway", spokenName: "the hallway", surface: .creakyWood),
        Room(code: "P", name: "Pantry", spokenName: "the pantry", surface: .stone),
        Room(code: "S", name: "Study", spokenName: "the study", surface: .carpet),
        Room(code: "F", name: "Foyer", spokenName: "the foyer", surface: .marble),
    ]

    public static let features = [
        // Kitchen
        Feature("kitchenDrawers", "kitchen drawers", Cell(1, 1), .searchable),
        Feature("sinkCupboard", "cupboard under the sink", Cell(5, 1), .searchable),
        // Dining room
        Feature("sideboard", "sideboard", Cell(13, 1), .searchable),
        Feature("diningTable", "dining table", Cell(11, 2), .hidingSpot),
        // Library
        Feature("writingDesk", "writing desk", Cell(17, 1), .searchable),
        Feature("bookshelf", "bookshelf", Cell(21, 1), .searchable),
        Feature("libraryCupboard", "tall cupboard", Cell(23, 3), .hidingSpot),
        // Hallway
        Feature("clock", "grandfather clock", Cell(12, 6), .landmark),
        // Pantry
        Feature("pantryShelves", "pantry shelves", Cell(1, 10), .searchable),
        Feature("flourSacks", "flour sacks", Cell(2, 12), .hidingSpot),
        // Study
        Feature("studyDesk", "study desk", Cell(8, 10), .searchable),
        Feature("filingCabinet", "filing cabinet", Cell(11, 12), .searchable),
        Feature("wardrobe", "wardrobe", Cell(5, 12), .hidingSpot),
        // Foyer
        Feature("sideTable", "side table", Cell(14, 10), .searchable),
        Feature("coatCloset", "coat closet", Cell(23, 10), .hidingSpot),
        Feature("frontDoor", "front door", Cell(16, 12), .frontDoor),
    ]

    public static let groundFloor = FloorPlan(map: map, rooms: rooms, features: features)

    /// Where the player starts: just inside the front door, facing into the house.
    public static let playerStart = Cell(16, 11)
    /// Where the Hunter starts: the kitchen, far from the front door.
    public static let hunterStart = Cell(3, 2)
    /// The friend's first tape is always here, so new players find the story early.
    public static let tapeSpot = "studyDesk"
}
