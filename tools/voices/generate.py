"""Makes Hollow Manor's voice lines with Kokoro (free, runs offline, Apache 2.0).

Reads tools/voices/lines.json and writes one mono .m4a per line into App/Voices/.
Only lines whose text, voice, speed or effect changed are made again (App/Voices/manifest.json remembers).

Usage: tools/voices/generate.sh            (makes what changed)
       tools/voices/generate.sh --all      (makes everything again)
       tools/voices/generate.sh hunter_heard_1 host_welcome   (just these)
"""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LINES = ROOT / "tools/voices/lines.json"
OUT = ROOT / "App/Voices"
MODELS = ROOT / "tools/voices/models"
MANIFEST = OUT / "manifest.json"
EFFECT_VERSION = 2  # bump when an effect below changes, to remake those lines

# ffmpeg filters applied after Kokoro. Kokoro speaks at 24 kHz.
EFFECTS = {
    # Slightly deeper and heavier. The game adds room echo and 3D position live, so none is baked in.
    "hunter": "asetrate=24000*0.9,aresample=24000,atempo=1.04,bass=g=4:f=120,volume=1.2",
    # Soft and close.
    "host": "highpass=f=90,treble=g=2,volume=1.1",
    # An old cassette: narrow and a little hissy.
    "tape": "highpass=f=250,lowpass=f=3800,acompressor=threshold=0.1:ratio=3,volume=1.3",
    "none": "anull",
}


def line_hash(line, speaker):
    key = json.dumps([line["text"], speaker, line.get("speed"), line.get("effect"), EFFECT_VERSION], sort_keys=True)
    return hashlib.sha256(key.encode()).hexdigest()[:16]


def main(args):
    data = json.loads(LINES.read_text())
    speakers = data["speakers"]
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)

    wanted = [a for a in args if not a.startswith("--")]
    todo = []
    for line in data["lines"]:
        speaker = speakers[line["speaker"]]
        h = line_hash(line, speaker)
        out = OUT / f"{line['id']}.m4a"
        if wanted and line["id"] not in wanted:
            continue
        if "--all" in args or wanted or manifest.get(line["id"]) != h or not out.exists():
            todo.append((line, speaker, h, out))

    ids = {l["id"] for l in data["lines"]}
    for stale in OUT.glob("*.m4a"):
        if stale.stem not in ids:
            print(f"Removing {stale.name} (no longer in lines.json)")
            stale.unlink()
            manifest.pop(stale.stem, None)

    if not todo:
        print("All voice lines are up to date.")
        MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        return

    import soundfile as sf
    from kokoro_onnx import Kokoro

    kokoro = Kokoro(str(MODELS / "kokoro-v1.0.onnx"), str(MODELS / "voices-v1.0.bin"))
    with tempfile.TemporaryDirectory() as tmp:
        for line, speaker, h, out in todo:
            speed = line.get("speed", speaker.get("speed", 1.0))
            audio, rate = kokoro.create(line["text"], voice=speaker["voice"], speed=speed, lang=speaker["lang"])
            wav = Path(tmp) / f"{line['id']}.wav"
            sf.write(wav, audio, rate)
            effect = EFFECTS[line.get("effect", speaker.get("effect", "none"))]
            # Mono, so the game can place it in 3D. A short silence at the end keeps AAC from clipping the tail.
            subprocess.run(
                ["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-af", f"{effect},apad=pad_dur=0.15",
                 "-ac", "1", "-ar", "44100", "-c:a", "aac", "-b:a", "64k", str(out)],
                check=True,
            )
            manifest[line["id"]] = h
            print(f"Made {out.name}: {line['text'][:60]}")
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
