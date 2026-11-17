"""Synthesizes Hollow Manor's sound effects into App/Sounds/*.wav.

Synthesized sounds made from noise and tones. Most were replaced by real recordings (import_real_sounds.py);
the clock, the doorway draft, the caught sting and the escape chime are still made here.
Existing files are left alone, so real recordings are never overwritten. Pass --force to remake everything.

Usage: python3 tools/sfx/make_sounds.py [--force]   (needs numpy)
"""
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "App/Sounds"
SR = 44100
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * SR))


def env(n, attack, decay, sustain=0.0, hold=0.0):
    """Attack then exponential decay (times in seconds)."""
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = np.where(x < attack + hold, 1.0, np.exp(-(x - attack - hold) / max(decay, 1e-4)))
    return a * (sustain + (1 - sustain) * d)


def biquad(x, kind, freq, q=0.707, gain_db=0.0):
    w0 = 2 * np.pi * freq / SR
    alpha = np.sin(w0) / (2 * q)
    cos = np.cos(w0)
    if kind == "low":
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2]
        a = [1 + alpha, -2 * cos, 1 - alpha]
    elif kind == "high":
        b = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
        a = [1 + alpha, -2 * cos, 1 - alpha]
    else:  # band
        b = [alpha, 0, -alpha]
        a = [1 + alpha, -2 * cos, 1 - alpha]
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b[0] * xi + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def tone(freq, seconds, phase_noise=0.0):
    f = freq * (1 + phase_noise * rng.standard_normal(int(seconds * SR)).cumsum() / SR)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def pad(x, before=0.0, after=0.05):
    return np.concatenate([np.zeros(int(before * SR)), x, np.zeros(int(after * SR))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, seconds, total):
    out = np.zeros(int(total * SR))
    s = int(seconds * SR)
    end = min(len(out), s + len(x))
    out[s:end] += x[: end - s]
    return out


def save(name, x, peak=0.8, stereo=None):
    if (OUT / f"{name}.wav").exists() and "--force" not in sys.argv:
        return
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    channels = 1
    if stereo is not None:
        r = np.asarray(stereo, dtype=float) / m * peak
        x = np.stack([x, r[: len(x)]], axis=1).reshape(-1)
        channels = 2
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


# --- Footsteps -------------------------------------------------------------------------------------------------

def thump(freq, length, weight):
    n = int(length * SR)
    body = tone(freq, length) * env(n, 0.002, length / 5)
    return body * weight


SURFACE_SEED = {"wood": 1, "creakyWood": 2, "carpet": 3, "tile": 4, "stone": 5, "marble": 6}


def step(surface, heavy=False, variant=0):
    """One footstep. Heavy is the Hunter's boots."""
    rngv = np.random.default_rng(100 + variant * 7 + (50 if heavy else 0) + SURFACE_SEED[surface])
    jitter = 1 + rngv.uniform(-0.08, 0.08)
    weight = 1.6 if heavy else 1.0
    low = (55 if heavy else 80) * jitter
    n = noise(0.25)
    if surface == "carpet":
        x = mix(biquad(n, "low", 500 * jitter) * env(len(n), 0.01, 0.05) * 0.8, thump(low, 0.18, 0.5 * weight))
    elif surface == "tile":
        click = biquad(n, "high", 2500 * jitter) * env(len(n), 0.001, 0.012) * 0.9
        x = mix(click, biquad(n, "band", 1200 * jitter, 2) * env(len(n), 0.001, 0.03) * 0.6, thump(low * 1.5, 0.12, 0.6 * weight))
    elif surface == "marble":
        click = biquad(n, "high", 3000 * jitter) * env(len(n), 0.001, 0.01)
        ring = biquad(noise(0.6), "band", 1800 * jitter, 6) * env(int(0.6 * SR), 0.001, 0.12) * 0.5
        x = mix(click, ring, thump(low * 1.3, 0.15, 0.6 * weight))
    elif surface == "stone":
        grit = biquad(n, "band", 900 * jitter, 1) * env(len(n), 0.002, 0.03)
        x = mix(grit, thump(low * 1.2, 0.14, 0.7 * weight))
    else:  # wood and creakyWood
        knock = biquad(n, "band", 350 * jitter, 1.5) * env(len(n), 0.002, 0.04)
        x = mix(knock * 1.2, thump(low, 0.2, 0.9 * weight))
    if heavy:
        # Boot heel then sole.
        x = mix(x, at(x * 0.6, 0.05, len(x) / SR + 0.05))
    return pad(x, after=0.08)


def creak(variant):
    """A floorboard creak: a scraping, bending tone."""
    rngv = np.random.default_rng(300 + variant)
    length = rngv.uniform(0.35, 0.6)
    tt = t(length)
    base = rngv.uniform(140, 220)
    f = base * (1 + 0.35 * np.sin(np.pi * tt / length) + 0.04 * rngv.standard_normal(len(tt)).cumsum() / 50)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    grain = (rngv.uniform(0, 1, len(tt)) < 0.04) * rngv.uniform(0.3, 1, len(tt))
    x = biquad(saw * (0.4 + grain), "band", base * 3, 1.2)
    return pad(x * env(len(tt), 0.05, length / 2, sustain=0.3, hold=length / 3))


# --- Everything else -------------------------------------------------------------------------------------------

def heartbeat():
    lub = thump(48, 0.16, 1.0) + biquad(noise(0.16), "low", 120) * env(int(0.16 * SR), 0.003, 0.03) * 0.5
    dub = thump(42, 0.14, 0.7)
    return pad(mix(lub, at(dub, 0.26, 0.5)), after=0.0)


def clock():
    """Tick, then tock half a second later: a seamless 1-second loop."""
    def tick(freq):
        n = noise(0.05)
        return biquad(n, "band", freq, 8) * env(len(n), 0.0005, 0.006) + tone(freq / 2, 0.05) * env(len(n), 0.0005, 0.01) * 0.3
    return mix(at(tick(3200), 0.0, 1.0), at(tick(2600), 0.5, 1.0))


def rain(seconds=12.0):
    """Rain on the windows and a low wind, stereo, loops."""
    left = biquad(noise(seconds), "low", 2500) * 0.25 + biquad(noise(seconds), "band", 5000, 0.5) * 0.08
    right = biquad(noise(seconds), "low", 2500) * 0.25 + biquad(noise(seconds), "band", 5000, 0.5) * 0.08
    for ch in (left, right):
        drops = np.flatnonzero(rng.uniform(0, 1, len(ch)) < 0.0009)
        for d in drops:
            k = biquad(noise(0.02), "band", rng.uniform(1500, 4000), 4) * env(int(0.02 * SR), 0.0005, 0.004)
            end = min(len(ch), d + len(k))
            ch[d:end] += k[: end - d] * rng.uniform(0.1, 0.4)
    wind_env = 0.5 + 0.5 * np.sin(2 * np.pi * t(seconds) / seconds * 2)
    wind = biquad(noise(seconds), "band", 300, 3) * wind_env * 0.5
    left += wind
    right += np.roll(wind, SR // 3)
    fade = int(0.5 * SR)  # crossfade the ends so the loop has no click
    for ch in (left, right):
        ch[:fade] = ch[:fade] * np.linspace(0, 1, fade) + ch[-fade:] * np.linspace(1, 0, fade)
    return left[:-fade], right[:-fade]


def rummage():
    total = 1.2
    out = np.zeros(int(total * SR))
    for i in range(9):
        s = rng.uniform(0, total - 0.15)
        n = noise(0.12)
        k = biquad(n, "band", rng.uniform(600, 3000), 1.5) * env(len(n), 0.003, 0.03) * rng.uniform(0.3, 1)
        out += at(k, s, total)
    slide = biquad(noise(0.3), "band", 800, 2) * env(int(0.3 * SR), 0.05, 0.1, sustain=0.4, hold=0.15)
    return mix(slide, out)


def keys():
    total = 0.8
    out = np.zeros(int(total * SR))
    for i in range(7):
        f = rng.uniform(3000, 6500)
        n = int(0.25 * SR)
        k = tone(f, 0.25) * env(n, 0.0005, 0.04) + tone(f * 1.47, 0.25) * env(n, 0.0005, 0.03) * 0.5
        out += at(k, rng.uniform(0, 0.5), total)
    return out


def rattle():
    total = 0.7
    out = np.zeros(int(total * SR))
    for i in range(5):
        k = biquad(noise(0.08), "band", 700, 3) * env(int(0.08 * SR), 0.001, 0.02) + thump(90, 0.08, 0.5)
        out += at(k, i * 0.12, total)
    return out


def unlock():
    total = 2.5
    out = np.zeros(int(total * SR))
    for s in (0.2, 0.9, 1.4, 1.9, 2.25):
        k = biquad(noise(0.05), "band", 2500, 5) * env(int(0.05 * SR), 0.0005, 0.008)
        out += at(k + tone(1200, 0.05) * env(int(0.05 * SR), 0.0005, 0.01) * 0.4, s, total)
    scrape = biquad(noise(total), "band", 1500, 3) * 0.08
    return out + scrape * env(len(scrape), 0.2, 2, sustain=0.5)


def door_open():
    c = creak(42)
    big = biquad(np.repeat(c, 2)[: int(1.6 * SR)], "low", 1500)
    whoosh = biquad(noise(1.6), "low", 400) * env(int(1.6 * SR), 0.4, 0.6)
    return mix(big, whoosh * 0.6, at(thump(60, 0.4, 1.2), 1.3, 1.8))


def gate_slam():
    hit = thump(45, 1.0, 1.0) + biquad(noise(1.0), "band", 400, 1) * env(int(SR), 0.002, 0.25)
    ring = sum(tone(f, 2.0) * env(int(2 * SR), 0.002, 0.7) for f in (210, 333, 517, 790)) * 0.15
    return mix(hit, ring)


def caught_sting():
    n = int(2.0 * SR)
    cluster = sum(tone(f, 2.0, 0.3) for f in (55, 58.3, 82.4, 87.3, 116.5)) * env(n, 0.005, 0.9)
    scream = biquad(noise(2.0), "band", 2200, 2) * env(n, 0.01, 0.4) * 0.6
    return mix(cluster * 0.4, scream, thump(40, 0.6, 1.0))


def win_chime():
    n = int(2.5 * SR)
    notes = [(523.25, 0), (659.25, 0.18), (783.99, 0.36), (1046.5, 0.54)]
    return sum(at(tone(f, 2.0) * env(int(2 * SR), 0.005, 0.6) * 0.3, s, 2.5) for f, s in notes)


def rustle(length=0.6):
    n = noise(length)
    return biquad(n, "band", 2500, 0.8) * env(len(n), 0.08, length / 3, sustain=0.2, hold=length / 4) * 0.7


def hide():
    return mix(rustle(0.6), at(thump(110, 0.15, 0.6) + biquad(noise(0.15), "band", 600, 2) * env(int(0.15 * SR), 0.001, 0.02), 0.55, 0.9))


def unhide():
    return mix(at(biquad(noise(0.3), "band", 900, 2) * env(int(0.3 * SR), 0.05, 0.1), 0, 0.8), at(rustle(0.5), 0.2, 0.8))


def bump():
    return thump(70, 0.2, 1.0) + biquad(noise(0.2), "low", 300) * env(int(0.2 * SR), 0.001, 0.02)


def door_cue():
    """A faint draft: tells you a doorway is right ahead."""
    n = noise(0.7)
    return biquad(n, "band", 700, 1.5) * env(len(n), 0.2, 0.2, sustain=0.0, hold=0.15) * 0.6


def tape_click():
    k = biquad(noise(0.04), "high", 2000) * env(int(0.04 * SR), 0.0005, 0.005)
    hum = tone(60, 0.5) * 0.05 + biquad(noise(0.5), "high", 4000) * 0.04
    return mix(k, at(hum * env(int(0.5 * SR), 0.05, 0.2), 0.03, 0.6))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for surface in ["wood", "creakyWood", "carpet", "tile", "stone", "marble"]:
        for v in range(3):
            save(f"step_{surface}_{v + 1}", step(surface, variant=v), peak=0.7)
            save(f"boot_{surface}_{v + 1}", step(surface, heavy=True, variant=v), peak=0.9)
    for v in range(3):
        save(f"creak_{v + 1}", creak(v), peak=0.7)
    save("heartbeat", heartbeat(), peak=0.9)
    save("clock", clock(), peak=0.6)
    left, right = rain()
    save("amb_rain", left, peak=0.5, stereo=right)
    save("search", rummage(), peak=0.7)
    save("key_found", keys(), peak=0.6)
    save("door_locked", rattle(), peak=0.8)
    save("unlock", unlock(), peak=0.7)
    save("door_open", door_open(), peak=0.8)
    save("gate_slam", gate_slam(), peak=0.9)
    save("caught", caught_sting(), peak=0.95)
    save("escaped", win_chime(), peak=0.7)
    save("hide", hide(), peak=0.6)
    save("unhide", unhide(), peak=0.6)
    save("bump", bump(), peak=0.7)
    save("door_cue", door_cue(), peak=0.5)
    save("tape_click", tape_click(), peak=0.6)
    print("Sounds written to", OUT)


if __name__ == "__main__":
    main()
