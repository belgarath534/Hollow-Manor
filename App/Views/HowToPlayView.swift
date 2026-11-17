import SwiftUI

struct HowToPlayView: View {
    var body: some View {
        List {
            TitledSection(title: "The story") {
                Text("Your friend went missing. Then a letter arrived in their handwriting, asking you to come to Hollow Manor. "
                    + "Now the doors are locked, and the two people who live here want you to stay. Forever.")
            }
            TitledSection(title: "Your goal") {
                Text("Find the front door key. It's hidden in a drawer or cupboard somewhere downstairs, in a different place every time. "
                    + "Then get back to the front door in the foyer and unlock it. Unlocking takes a few seconds, so make sure he isn't close.")
            }
            TitledSection(title: "The Hunter") {
                Text("He walks the house in heavy boots. Listen for his footsteps and his voice: they come from where he really is. "
                    + "Through walls, he sounds muffled. Your heartbeat speeds up as he gets closer.")
                Text("If he says something like \"What was that?\", he heard you and is coming to check. "
                    + "If he shouts \"There you are!\", he can see you. Run, or break his line of sight and hide.")
            }
            TitledSection(title: "The Host") {
                Text("She's somewhere upstairs. You'll hear her talking to him, and to you. When she says \"Did you hear that, darling?\", he's on his way.")
                Text("Sometimes she whispers right in your ear. Don't always believe her.")
            }
            TitledSection(title: "Noise") {
                Text("Every step makes noise. Carpet and stone are quiet. Tile and marble are louder. "
                    + "The hallway floorboards are old and creak. Running is much louder than walking, but faster than he can chase. "
                    + "Searching makes noise too.")
            }
            TitledSection(title: "Hiding") {
                Text("Wardrobes, cupboards, the coat closet, under the dining table and behind the flour sacks. "
                    + "If he watched you get in, he'll drag you out.")
                Text("When he's searching, he opens hiding spots. If you hear him stop close by and ask \"Are you in here?\", "
                    + "hold your breath. He might pick yours. Sometimes it's better to sneak away than to hide.")
            }
            TitledSection(title: "Touch controls") {
                control("Walk", "Swipe up. You keep walking until you stop")
                control("Run", "Swipe up again while walking")
                control("Stop", "Tap once")
                control("Turn", "Swipe left or right")
                control("Turn around", "Swipe down while standing still")
                control("Search, hide, come out, unlock", "Double tap")
                control("Describe the room", "Two-finger tap")
                control("Listen for the Hunter", "Three-finger tap")
                control("Pause", "Two-finger swipe down")
                Text("Walking stops by itself at doorways, at things you can use, and at walls, and tells you what's there. "
                    + "Running only stops at walls, so you can get away.")
            }
            TitledSection(title: "Keyboard") {
                control("Walk, step back", "W and S, or Up and Down")
                control("Run", "Hold Shift")
                control("Turn", "A and D, or Left and Right. X turns around")
                control("Search, hide, use", "Space, E or Return")
                control("Describe", "Q or Tab")
                control("Listen", "L")
                control("Pause", "Escape")
            }
            TitledSection(title: "Game controller") {
                control("Walk, run", "Left stick, hold right trigger to run")
                control("Turn", "D-pad or shoulder buttons. D-pad down turns around")
                control("Use", "A")
                control("Describe, listen", "X and Y")
                control("Pause", "Menu")
            }
            TitledSection(title: "VoiceOver") {
                Text("The play area passes your touches straight to the game, so the gestures above work with VoiceOver on. "
                    + "The magic tap describes the room, and the scrub gesture pauses.")
            }
        }
        .navigationTitle("How to Play")
    }

    private func control(_ action: String, _ how: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(action).font(.headline)
            Text(how).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
