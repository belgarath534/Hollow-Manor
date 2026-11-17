public enum Speaker: String, Codable, Sendable {
    case hunter, host, friend
}

/// The recorded lines the game can play. The ids match the audio files made by `tools/voices/generate.sh`
/// from `tools/voices/lines.json`, and the text here is used for captions. A test checks the two lists agree.
public enum VoiceLine: String, CaseIterable, Sendable {
    case hunterPatrol1 = "hunter_patrol_1"
    case hunterPatrol2 = "hunter_patrol_2"
    case hunterPatrol3 = "hunter_patrol_3"
    case hunterPatrol4 = "hunter_patrol_4"
    case hunterLaugh = "hunter_laugh_1"
    case hunterHeard1 = "hunter_heard_1"
    case hunterHeard2 = "hunter_heard_2"
    case hunterHeard3 = "hunter_heard_3"
    case hunterSpotted1 = "hunter_spotted_1"
    case hunterSpotted2 = "hunter_spotted_2"
    case hunterLost1 = "hunter_lost_1"
    case hunterLost2 = "hunter_lost_2"
    case hunterCaught = "hunter_caught_1"
    case hostWelcome = "host_welcome"
    case hostHeard1 = "host_heard_1"
    case hostHeard2 = "host_heard_2"
    case hostTaunt1 = "host_taunt_1"
    case hostTaunt2 = "host_taunt_2"
    case hostCaught = "host_caught"
    case hostEscaped = "host_escaped"
    case friendLetter = "friend_letter"
    case friendTape1 = "friend_tape_1"

    public var speaker: Speaker {
        if rawValue.hasPrefix("hunter") { return .hunter }
        if rawValue.hasPrefix("host") { return .host }
        return .friend
    }

    public var text: String {
        switch self {
        case .hunterPatrol1: return "Where are you hiding, guest?"
        case .hunterPatrol2: return "Come out, come out. I won't bite. Much."
        case .hunterPatrol3: return "This house has a lot of rooms. I know every one of them."
        case .hunterPatrol4: return "I can smell the rain on you."
        case .hunterLaugh: return "Heh. Heh heh heh."
        case .hunterHeard1: return "What was that?"
        case .hunterHeard2: return "I heard you."
        case .hunterHeard3: return "Somebody's walking on my floors."
        case .hunterSpotted1: return "There you are!"
        case .hunterSpotted2: return "Found you, guest!"
        case .hunterLost1: return "Hiding again? You can't hide forever."
        case .hunterLost2: return "Fine. I'll find you later."
        case .hunterCaught: return "Got you. Welcome home."
        case .hostWelcome: return "Welcome to Hollow Manor, sweetheart. We've been expecting you."
        case .hostHeard1: return "Did you hear that, darling? I think our guest is downstairs."
        case .hostHeard2: return "Darling, go and look. Somebody is walking around down there."
        case .hostTaunt1: return "Come out, sweetheart. Dinner's getting cold."
        case .hostTaunt2: return "Your friend asked about you. Isn't that sweet?"
        case .hostCaught: return "Oh, don't cry. You're part of the family now."
        case .hostEscaped: return "Leaving so soon? You'll be back. They always come back."
        case .friendLetter:
            return "Hey. It's me. I know it's been a while. I'm at a big house called Hollow Manor, and I need you. "
                + "Please come. Come alone."
        case .friendTape1:
            return "If you found this tape, don't trust the letter. They made me write it. "
                + "The front door key is always hidden somewhere downstairs, in a drawer or a cupboard. "
                + "Search quietly. He hears everything. And stay off the hallway floorboards if he's close."
        }
    }

    static let hunterPatrol: [VoiceLine] = [.hunterPatrol1, .hunterPatrol2, .hunterPatrol3, .hunterPatrol4, .hunterLaugh]
    static let hunterHeard: [VoiceLine] = [.hunterHeard1, .hunterHeard2, .hunterHeard3]
    static let hunterSpotted: [VoiceLine] = [.hunterSpotted1, .hunterSpotted2]
    static let hunterLost: [VoiceLine] = [.hunterLost1, .hunterLost2]
    static let hostHeard: [VoiceLine] = [.hostHeard1, .hostHeard2]
    static let hostTaunts: [VoiceLine] = [.hostTaunt1, .hostTaunt2]
}
