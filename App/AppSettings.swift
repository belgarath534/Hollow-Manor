import Combine
import Foundation
import ManorCore

/// The player's choices, saved between launches.
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var speechOutput: SpeechOutput {
        didSet { defaults.set(speechOutput.rawValue, forKey: "speechOutput") }
    }
    @Published var difficulty: Difficulty {
        didSet { defaults.set(difficulty.rawValue, forKey: "difficulty") }
    }
    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: "haptics") }
    }
    @Published var captions: Bool {
        didSet { defaults.set(captions, forKey: "captions") }
    }
    @Published var skipIntro: Bool {
        didSet { defaults.set(skipIntro, forKey: "skipIntro") }
    }
    /// Say north, east, south or west after every turn.
    @Published var announceTurns: Bool {
        didSet { defaults.set(announceTurns, forKey: "announceTurns") }
    }

    init() {
        speechOutput = SpeechOutput(rawValue: defaults.string(forKey: "speechOutput") ?? "") ?? .gameVoice
        difficulty = Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .normal
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        captions = defaults.object(forKey: "captions") as? Bool ?? true
        skipIntro = defaults.bool(forKey: "skipIntro")
        announceTurns = defaults.object(forKey: "announceTurns") as? Bool ?? true
    }
}

extension Difficulty {
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    var summary: String {
        switch self {
        case .easy: return "He's slower, hears less and can't see as far."
        case .normal: return "The way it's meant to be played."
        case .hard: return "He's faster, hears more and sees further."
        }
    }
}
