# Hollow Manor

> *You're invited.*

An audio-first stealth horror game for iPhone and iPad, playable by blind and sighted players.
Your friend went missing. A letter in their handwriting brings you to Hollow Manor. The doors lock behind you,
and the Hunter and the Host want you to stay.

- [Design](docs/DESIGN.md): story, characters, how it plays, accessibility, milestones
- [TestFlight from GitHub](docs/GITHUB_TESTFLIGHT.md) (main route) and [with Codemagic](docs/CODEMAGIC.md)
- [Credits](CREDITS.md) for the music and sounds

## Status: first playable

The ground floor (kitchen, dining room, library, hallway, pantry, study and foyer). The Hunter wanders, hears your
footsteps and comes to check, chases you when he sees you, and searches when he loses you. The Host talks from
upstairs. Search drawers for the front door key (it's somewhere different every game), hide in wardrobes and
cupboards, and unlock the front door to escape. Your friend's first tape is in the study.

3D audio with headphones, spoken room descriptions, heartbeat haptics, touch, keyboard and controller controls.
See **How to Play** in the app.

## Layout

- `Packages/ManorCore`: the game itself (house, Hunter, rules, spoken phrases). Pure Swift, unit-tested,
  runs on Linux too: `cd Packages/ManorCore && swift test`.
- `App/`: the iOS app. SwiftUI menus, the play screen, 3D audio, speech, haptics, input.
- `App/Voices/`: voice lines made with Kokoro. `App/Sounds/`: sound effects. `App/Music/`: music.
- `tools/voices/`: makes the voice lines. Edit `lines.json`, then run `tools/voices/generate.sh`, or run the
  **Generate voices** action on GitHub. Only changed lines are made again.
- `tools/sfx/import_real_sounds.py`: downloads the real recorded sounds and music (all CC0) and prepares them.
  `tools/sfx/make_sounds.py` makes the few sounds that are still synthesized (clock, stings).
- `project.yml`: XcodeGen spec. The Xcode project is generated, not committed.

## Voices

| Character | Kokoro voice |
|---|---|
| The Hunter | `bm_lewis` (British, pitched down a little) |
| The Host | `af_heart` |
| Your friend | `am_michael` (sounds like an old cassette on the tapes) |

To add a line: add it to `tools/voices/lines.json` and to `VoiceLine` in
`Packages/ManorCore/Sources/ManorCore/VoiceLines.swift` (a test checks they match), then generate.

## Building without a Mac

GitHub Actions (`.github/workflows/build.yml`) runs the tests on Linux and builds the app on a macOS runner.
Every push uploads an unsigned `HollowManor-unsigned.ipa` artifact as a compile check.
Signed TestFlight builds: run the **Build** workflow by hand on GitHub (see
[docs/GITHUB_TESTFLIGHT.md](docs/GITHUB_TESTFLIGHT.md)), or use Codemagic (`codemagic.yaml`).
