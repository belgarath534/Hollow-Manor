# Hollow Manor — Design

> **Hollow Manor**
> *You're invited.*

An audio-first stealth horror game for iPhone and iPad. Fully playable by blind players, and playable by
sighted players too. You sneak through a mansion, find what you need and get out, while two people who live
there hunt you down.

This is our own game in the "trapped and hunted" genre. Everything here (the story, the characters, the house,
the name) is original.

## Story

Your friend went missing. Weeks later a letter arrives in their handwriting:

> *Hey. It's me. I know it's been a while. I'm at a big house called Hollow Manor, and I need you.
> Please come. Come alone.*

You go. The gates lock behind you. The front door closes on its own. Somebody upstairs says
"Welcome to Hollow Manor, sweetheart."

Around the house you find tapes your friend left behind. The first one says **don't trust the letter. They
made me write it.** The tapes give hints about where things are hidden and how the hunters behave, and
slowly tell what happened to your friend.

## The hunters

| | **The Hunter** | **The Host** |
|---|---|---|
| Voice | Kokoro `bm_lewis`, pitched down slightly, room echo | Kokoro `af_heart`, soft and sweet |
| Feet | Heavy boots, slow, loud | Light quick steps or heels (later) |
| Personality | Blunt, mean, laughs at you | Polite, sweet, calls you "sweetheart", which is worse |
| Role | Chases you | Sends him after noises, talks to you from somewhere else in the house |

**They talk to each other while you move.** That is the main way players learn where they are and what they're
about to do:

- Host: "Did you hear that, darling? I think our guest is downstairs." → he's coming to check.
- Hunter: "What was that?" → he heard you. Move or hide.
- Hunter: "There you are!" → he can see you. Run.
- Hunter: "Hiding again? You can't hide forever." → he lost you. Stay put.

Voices move around you in 3D and are muffled through walls, so every line also tells you *where* the speaker is.

## How it plays

- **The house is a grid of rooms.** You face one of four directions and walk step by step. Every room has a
  floor you can hear: creaky hallway boards, tile in the kitchen, soft carpet in the library.
- **Walking is quiet. Running is loud.** Your footsteps make noise. Noise travels through doors and corridors.
  If the Hunter hears it, he comes to look.
- **Searching** drawers, cupboards and desks makes a little noise. Items are hidden in different places every game.
- **Hiding** in wardrobes, cupboards and under tables keeps you safe, unless he saw you get in.
- **Getting caught** ends the night. (Later: a few "days" like lives, each one making the house harder.)
- **Escaping** means finding the way out. In the first version, that's the front door key.

## Accessibility

- **Everything important is a sound or a spoken line.** Nothing needs the screen.
- **3D audio** (HRTF) with headphones: the Hunter's steps and voice come from where he really is. Sounds in other
  rooms are muffled.
- **Spoken help on demand:** "Describe" says your room, which way you face, and the doors and furniture around you
  with directions ("Door to the hallway, 3 steps ahead and 2 to your right"). "Listen" says roughly where you last
  heard the Hunter.
- **VoiceOver friendly.** Menus are standard, the play area passes touches straight to the game, and speech can
  use the game's own voice or go through VoiceOver.
- **Haptics:** a heartbeat that speeds up as the Hunter gets closer.
- **Controls:** touch, keyboard and game controller.
- **For sighted players:** a top-down view of the room you're in. Only the current room is drawn, so sighted
  players aren't ahead of blind players.
- **Difficulty:** Hunter speed and hearing (Easy, Normal, Hard).

### Controls

| | Touch | Keyboard | Controller |
|---|---|---|---|
| Walk | Swipe up (keeps walking, stops by itself at doors, furniture and walls) | W / Up arrow (hold) | Left stick up |
| Run | Swipe up again while walking | Hold Shift while walking | Hold right trigger while walking |
| Stop | Tap once | Let go | Let go |
| Turn around | Swipe down while stopped | X | D-pad down |
| Turn left / right | Quick swipe left / right | A / D or Left / Right arrow | D-pad left / right or left shoulder / right shoulder |
| Search, hide, use | Double tap | Space or E | A |
| Describe | Two-finger tap | Q or Tab | X |
| Listen for the Hunter | Three-finger tap | L | Y |
| Pause | Two-finger swipe down (VoiceOver: scrub) | Escape | Menu |

## Voices

All lines are made ahead of time with [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) (Apache 2.0, free,
no credits) and shipped as audio files. The phone just plays them, so nothing heavy runs on the device.

- Lines live in `tools/voices/lines.json`. Change or add a line there, then run `tools/voices/generate.sh`.
  Only lines that changed are made again.
- The **Generate voices** GitHub Action does the same thing in the cloud and commits the new files, so you
  don't need a computer for it.
- Laughs, whispers and screams are Kokoro's weak spot. Options for later: Chatterbox (copies the Lewis voice with
  more emotion), Dia, or real recordings.

## Milestones

1. **First playable (this version):** ground floor, the Hunter, the Host's voice from upstairs, hiding, searching,
   the front door key, escape or get caught.
2. **Upstairs and the Host in person:** a second floor and stairs, the Host walking around with her own footsteps,
   and the two of them coordinating.
3. **Days:** getting caught costs a day instead of ending the game. Five days to escape.
4. **More ways out and more items:** the car in the garage, the gate code, the cellar tunnel. Throwable items
   to make noise somewhere else. Traps.
5. **Your friend's story:** all the tapes, and an ending where you find out what happened.
6. **Grounds outside:** gravel paths, the garden, the shed, rain.
