"""Downloads real recorded sounds and music (all CC0, public domain) and turns them into the game's files.

Sound effects go to App/Sounds/*.wav (mono for things placed in 3D), music to App/Music/*.m4a.
The names match what the game plays, so any file here replaces the synthesized placeholder of the same name
(made by make_sounds.py). Every source and its author is listed in CREDITS.md.

Usage: python3 tools/sfx/import_real_sounds.py   (needs ffmpeg)
"""
import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "tools/sfx/.cache"
SOUNDS = ROOT / "App/Sounds"
MUSIC = ROOT / "App/Music"
OGA = "https://opengameart.org/sites/default/files/"

# name in the cache: (download URL, zip or not)
DOWNLOADS = {
    "steps_kdd": OGA + "%5Bkdd%5DDifferentSteps_0.zip",
    "sfx100": OGA + "100-CC0-SFX_0.zip",
    "woodmetal": OGA + "100-CC0-wood-metal-SFX.zip",
    "sfx100v2": OGA + "sfx_100_v2.zip",
    "doorlock": OGA + "DoorLockSounds.zip",
    "haeldb": OGA + "footsteps.zip",
    "laleksic": OGA + "sounds_8.zip",
    "fozzy_01.ogg": OGA + "01-footstep_0.ogg",
    "fozzy_02.ogg": OGA + "02-footstep.ogg",
    "fozzy_03.ogg": OGA + "03-footstep.ogg",
    "fozzy_04.ogg": OGA + "04-footstep.ogg",
    "fozzy_05.ogg": OGA + "05-footstep.ogg",
    "fozzy_06.ogg": OGA + "06-footstep.ogg",
    "heartbeat.wav": OGA + "heartbeat_slow_0.wav",
    "rain_window.wav": OGA + "rain_on_window_loop.wav",
    "music_menu.ogg": OGA + "musicbox1_spooky_waltz.ogg",
    "music_sad.ogg": OGA + "musicbox3_sad_tune.ogg",
    "music_explore.ogg": OGA + "Dark%20Rooms%20and%20Scary%20Things%20-%20isaiah658_1.ogg",
    "music_chase.ogg": OGA + "chase_in_the_night_0.ogg",
    "music_escaped.mp3": OGA + "haunting%20piano.mp3",
}


def fetch():
    CACHE.mkdir(parents=True, exist_ok=True)
    for name, url in DOWNLOADS.items():
        target = CACHE / name
        if target.exists():
            continue
        print("Downloading", name)
        if name.endswith((".ogg", ".wav", ".mp3")):
            urllib.request.urlretrieve(url, target)
        else:
            archive = CACHE / f"{name}.zip"
            urllib.request.urlretrieve(url, archive)
            with zipfile.ZipFile(archive) as z:
                z.extractall(target)
            archive.unlink()


def src(path):
    """A file inside the cache, found by its name anywhere under a pack folder."""
    pack, _, file = path.partition("/")
    if not file:
        return CACHE / pack
    matches = list((CACHE / pack).rglob(file))
    if not matches:
        raise FileNotFoundError(path)
    return matches[0]


def ffmpeg(inputs, out, filter_complex=None, af=None, mono=True, extra=()):
    cmd = ["ffmpeg", "-loglevel", "error", "-y"]
    for i in inputs:
        cmd += ["-i", str(i)]
    if filter_complex:
        cmd += ["-filter_complex", filter_complex]
    if af:
        cmd += ["-af", af]
    if mono:
        cmd += ["-ac", "1"]
    cmd += ["-ar", "44100", *extra, str(out)]
    subprocess.run(cmd, check=True)


# Loudness: everything is brought to a similar level, then the game sets volumes.
NORM = "loudnorm=I=-18:TP=-2:LRA=11"


def level(path, peak_db):
    """Scales a file so its loudest moment is peak_db (short sounds are levelled by peak, not loudness)."""
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    current = float(out.split("max_volume:")[1].split("dB")[0])
    tmp = path.with_suffix(".tmp.wav")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(path), "-af", f"volume={peak_db - current}dB",
                    str(tmp)], check=True)
    tmp.replace(path)


# How loud each kind of sound peaks before the game sets its volume. Your own steps are quieter than his boots.
PEAKS = {"step": -6, "boot": -2, "creak": -6, "heartbeat": -3, "unhide": -6}


def sfx(name, source, af=""):
    chain = ",".join(x for x in [af, "apad=pad_dur=0.05"] if x)
    out = SOUNDS / f"{name}.wav"
    ffmpeg([src(source)], out, af=chain)
    level(out, PEAKS.get(name.split("_")[0], -2))


def layered(name, sources, filters, mix_weights):
    """Several sources, each with its own filter (including delays), mixed into one."""
    parts = [f"[{i}:a]{f}[a{i}]" for i, f in enumerate(filters)]
    ins = "".join(f"[a{i}]" for i in range(len(sources)))
    graph = ";".join(parts) + f";{ins}amix=inputs={len(sources)}:normalize=0:weights={' '.join(map(str, mix_weights))}"
    out = SOUNDS / f"{name}.wav"
    ffmpeg([src(s) for s in sources], out, filter_complex=graph)
    level(out, PEAKS.get(name.split("_")[0], -2))


def main():
    fetch()
    SOUNDS.mkdir(parents=True, exist_ok=True)
    MUSIC.mkdir(parents=True, exist_ok=True)

    # --- Your footsteps, one set per floor ---
    for i, f in enumerate(["wood01.ogg", "wood02.ogg", "wood03.ogg"], 1):
        sfx(f"step_wood_{i}", f"steps_kdd/{f}")
    for i, f in enumerate(["sfx100v2_footstep_wood_01.ogg", "sfx100v2_footstep_wood_02.ogg",
                           "sfx100v2_footstep_wood_04.ogg"], 1):
        sfx(f"step_creakyWood_{i}", f"sfx100v2/{f}", "lowpass=f=5000")
    for i, f in enumerate(["step_cloth1.ogg", "step_cloth2.ogg", "step_cloth3.ogg"], 1):
        sfx(f"step_carpet_{i}", f"haeldb/{f}", "lowpass=f=1800,volume=0.6")
    for i, f in enumerate(["fozzy_01.ogg", "fozzy_02.ogg", "fozzy_06.ogg"], 1):
        sfx(f"step_tile_{i}", f, "highpass=f=150")
    for i, f in enumerate(["stone01.ogg"], 1):
        sfx(f"step_stone_{i}", f"steps_kdd/{f}")
    sfx("step_stone_2", "sfx100v2/sfx100v2_footstep_01.ogg", "lowpass=f=4000")
    sfx("step_stone_3", "sfx100v2/sfx100v2_footstep_02.ogg", "lowpass=f=4000")
    for i, f in enumerate(["fozzy_03.ogg", "fozzy_04.ogg", "fozzy_05.ogg"], 1):
        # Marble: hard and a little echoey.
        sfx(f"step_marble_{i}", f, "aecho=0.8:0.5:70|150:0.25|0.12")

    # --- The Hunter's boots: leather boot steps under a heavier, deeper version of the floor ---
    boots = ["step_lth1.ogg", "step_lth2.ogg", "step_lth4.ogg"]
    for surface in ["wood", "creakyWood", "carpet", "tile", "stone", "marble"]:
        for i in range(1, 4):
            floor = SOUNDS / f"step_{surface}_{i}.wav"
            shutil.copy(floor, CACHE / "floor_tmp.wav")
            layered(
                f"boot_{surface}_{i}",
                ["floor_tmp.wav", f"haeldb/{boots[i - 1]}"],
                ["asetrate=44100*0.78,aresample=44100,bass=g=6:f=100",
                 "asetrate=44100*0.85,aresample=44100" + (",lowpass=f=1500" if surface == "carpet" else "")],
                [1.0, 0.8],
            )

    # --- Creaks, the heartbeat and the house ---
    for i in range(1, 4):
        sfx(f"creak_{i}", f"laleksic/floor_creak{i}.wav", "atrim=0:1.3,afade=t=out:st=1.0:d=0.3")
    sfx("heartbeat", "heartbeat.wav", "atrim=0:0.75,afade=t=out:st=0.6:d=0.15,lowpass=f=400,bass=g=4")
    ffmpeg([src("rain_window.wav")], SOUNDS / "amb_rain.wav", mono=False)
    level(SOUNDS / "amb_rain.wav", -3)
    sfx("thunder_1", "sfx100v2/sfx100v2_thunder_01.ogg")
    sfx("thunder_2", "sfx100v2/sfx100v2_thunder_01.ogg", "asetrate=48000*0.8,aresample=44100,lowpass=f=2500")

    # --- Things you do ---
    layered("search",
            ["laleksic/drawer_open.wav", "sfx100/paper_02.ogg", "laleksic/drawer_close.wav"],
            ["anull", "adelay=500:all=1,volume=0.6", "adelay=1000:all=1"],
            [1.0, 0.6, 1.0])
    layered("key_found", ["laleksic/pickup_keys.wav", "woodmetal/keys_02.ogg"],
            ["anull", "adelay=150:all=1"], [1.0, 0.8])
    sfx("door_locked", "doorlock/LockedDoorHandleJiggle.wav")
    layered("unlock", ["laleksic/lock_pick.wav", "doorlock/UnlockDoor.wav"],
            ["anull", "adelay=1900:all=1"], [0.8, 1.0])
    layered("door_open", ["doorlock/DoorOpen.wav", "laleksic/door_creak_open.wav"],
            ["anull", "adelay=300:all=1"], [1.0, 1.0])
    sfx("gate_slam", "woodmetal/metal_slam_01.ogg",
        "asetrate=48000*0.7,aresample=44100,aecho=0.8:0.6:200|450:0.4|0.25")
    layered("hide", ["laleksic/door_creak_open.wav", "haeldb/step_cloth2.ogg", "sfx100/door_close_01.ogg"],
            ["atrim=0:0.7,afade=t=out:st=0.5:d=0.2", "adelay=400:all=1", "adelay=700:all=1,volume=0.5"],
            [0.7, 0.6, 0.5])
    sfx("unhide", "laleksic/door_creak_close.wav", "atrim=0:1.0,afade=t=out:st=0.8:d=0.2,volume=0.7")
    sfx("bump", "woodmetal/wood_hit_01.ogg", "lowpass=f=2500")
    sfx("tape_click", "laleksic/switch_on.wav")

    # --- Music (stereo AAC) ---
    for name, file in [("menu", "music_menu.ogg"), ("explore", "music_explore.ogg"), ("chase", "music_chase.ogg"),
                       ("caught", "music_sad.ogg"), ("escaped", "music_escaped.mp3")]:
        ffmpeg([src(file)], MUSIC / f"{name}.m4a", af=NORM, mono=False, extra=["-c:a", "aac", "-b:a", "96k"])
    print("Real sounds written to", SOUNDS, "and music to", MUSIC)


if __name__ == "__main__":
    main()
