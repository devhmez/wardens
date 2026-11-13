# Synthesises every sound effect and the music loop for WARDENS (no samples used).
# Run with Blender's bundled Python (it ships numpy):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python blender/make_sfx.py
import numpy as np, wave, os, math

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(d):
    return np.arange(int(SR * d)) / SR

def noise(d):
    return rng.uniform(-1, 1, int(SR * d))

def bp(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    f = np.maximum(f, 1e-6)
    mask = 1 / (1 + (lo / f) ** 6) / (1 + (f / hi) ** 6)
    return np.fft.irfft(X * mask, len(x))

def env(d, a=0.01, decay=6.0):
    t = t_(d)
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t * decay)

def hann(d):
    n = int(SR * d)
    return np.hanning(n)

def sweep(d, f0, f1, shape="sin"):
    t = t_(d)
    f = f0 * (f1 / f0) ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    return np.sin(ph)

def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x

def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out

def loopify(x, xf=0.25):
    n = int(SR * xf)
    head, tail = x[:n], x[-n:]
    k = np.linspace(0, 1, n)
    body = x[n:-n]
    return np.concatenate([tail * (1 - k) + head * k, body])

def save(name, x, peak=0.9):
    x = norm(x, peak)
    f = min(int(SR * 0.004), len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())

def save_loop(name, x, peak=0.9):
    x = norm(x, peak)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())

def bell(freq, d, partials=(1, 2.0, 2.76, 3.9, 5.4), decay=3.0):
    t = t_(d)
    out = np.zeros(len(t))
    for i, p in enumerate(partials):
        out += np.sin(2 * np.pi * freq * p * t) * np.exp(-t * decay * (1 + i * 0.7)) / (i + 1)
    return out

def pluck(freq, d=1.6):
    t = t_(d)
    out = np.zeros(len(t))
    for k in range(1, 9):
        out += np.sin(2 * np.pi * freq * k * t + k * 0.3) * np.exp(-t * (1.8 + k * 1.6)) / k
    return out * np.minimum(t / 0.004, 1.0)


# ---------------------------------------------------------------- effects
save("rumble", mix(bp(noise(0.7), 30, 160) * env(0.7, 0.06, 5), 0.6 * np.sin(2 * np.pi * 52 * t_(0.7)) * env(0.7, 0.05, 6)))
save("boom", mix(sweep(1.0, 95, 32) * env(1.0, 0.005, 4.5), 0.7 * bp(noise(1.0), 40, 500) * env(1.0, 0.005, 7)))
save("rock_hit", mix(bp(noise(0.5), 180, 3200) * env(0.5, 0.002, 14), 0.9 * sweep(0.5, 130, 50) * env(0.5, 0.002, 10),
                     0.3 * bp(noise(0.5), 2000, 7000) * env(0.5, 0.001, 30)))
save("whoosh", mix(bp(noise(0.4), 300, 1200) * hann(0.4), pad_to(np.concatenate([np.zeros(int(SR * 0.08)), bp(noise(0.3), 900, 3000) * hann(0.3)]), int(SR * 0.4)) * 0.7))
cr = noise(0.35) * (rng.uniform(0, 1, int(SR * 0.35)) > 0.985)
save("fire_shot", mix(bp(noise(0.35), 250, 2400) * env(0.35, 0.01, 9), 0.5 * bp(cr, 1500, 8000) * 6, 0.4 * sweep(0.35, 220, 90) * env(0.35, 0.005, 10)))
save("fire_hit", mix(bp(noise(0.5), 70, 900) * env(0.5, 0.003, 9), 0.6 * sweep(0.5, 110, 45) * env(0.5, 0.003, 9)))
fl = bp(noise(2.2), 120, 1700)
am = bp(noise(2.2), 0.5, 9)
fl = fl * (0.6 + 0.4 * am / np.max(np.abs(am)))
save_loop("fire_loop", loopify(fl))
save("explode", mix(sweep(1.2, 110, 28) * env(1.2, 0.003, 4), bp(noise(1.2), 50, 2500) * env(1.2, 0.003, 5), 0.3 * bp(noise(1.2), 2000, 8000) * env(1.2, 0.001, 14)))
save("whip", mix(bp(noise(0.32), 700, 5200) * hann(0.32) ** 2, 0.4 * sweep(0.32, 500, 1400) * hann(0.32) * 0.3))
bub = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_(0.7) + 3 * np.sin(2 * np.pi * 5 * t_(0.7)))
save("splash", mix(bp(noise(0.7), 450, 6500) * env(0.7, 0.01, 6) * bub, 0.4 * bp(noise(0.7), 100, 500) * env(0.7, 0.005, 9)))
ice = np.zeros(int(SR * 0.6))
for i in range(9):
    b = bell(1800 + i * 420 + rng.uniform(-80, 80), 0.3, decay=14)
    st = int(SR * i * 0.03)
    ice[st:st + len(b)] += b[:len(ice) - st] * 0.5
save("ice", mix(ice, 0.25 * bp(noise(0.6), 4000, 12000) * env(0.6, 0.02, 8)))
save("ice_shot", mix(bp(noise(0.22), 1500, 8000) * hann(0.22) ** 2, 0.5 * bell(3100, 0.22, decay=18)))
sh = np.zeros(int(SR * 0.35))
for i in range(7):
    b = bell(rng.uniform(2500, 7000), 0.2, decay=22)
    st = int(SR * rng.uniform(0, 0.06))
    sh[st:st + len(b)] += b[:len(sh) - st] * 0.4
save("ice_hit", mix(sh, bp(noise(0.35), 3000, 11000) * env(0.35, 0.001, 18)))
big = np.zeros(int(SR * 1.0))
for i in range(22):
    b = bell(rng.uniform(1200, 7500), 0.5, decay=9)
    st = int(SR * rng.uniform(0, 0.25))
    big[st:st + len(b)] += b[:len(big) - st] * 0.35
save("shatter", mix(big, bp(noise(1.0), 1500, 11000) * env(1.0, 0.001, 7), 0.8 * sweep(1.0, 140, 40) * env(1.0, 0.003, 6)))
sw = np.sin(np.pi * t_(1.5) / 1.5) ** 1.5
save("wave", mix(bp(noise(1.5), 90, 2800) * sw, 0.5 * bp(noise(1.5), 2500, 8000) * sw ** 3))
save("air_shot", mix(bp(noise(0.34), 500, 4200) * hann(0.34) ** 1.5, 0.15 * sweep(0.34, 300, 900) * hann(0.34)))
save("air_burst", mix(bp(noise(0.9), 180, 2600) * env(0.9, 0.03, 4.5), 0.4 * bp(noise(0.9), 2000, 7000) * env(0.9, 0.02, 7), 0.5 * sweep(0.9, 80, 40) * env(0.9, 0.01, 6)))
tl = bp(noise(2.6), 180, 1500) * (0.65 + 0.35 * np.sin(2 * np.pi * 5.0 * t_(2.6)))
save_loop("tornado_loop", loopify(tl))
save("hit", mix(sweep(0.14, 170, 70) * env(0.14, 0.001, 22), 0.6 * bp(noise(0.14), 800, 5000) * env(0.14, 0.001, 45)))
save("hurt", mix(sweep(0.3, 300, 120, "saw") * env(0.3, 0.003, 9) * 0.5, bp(noise(0.3), 300, 2500) * env(0.3, 0.002, 14), sweep(0.3, 150, 60) * env(0.3, 0.002, 10)))
save("die", mix(sweep(1.2, 330, 70) * env(1.2, 0.01, 2.5), 0.5 * sweep(1.2, 220, 46) * env(1.2, 0.01, 2.5), 0.3 * bp(noise(1.2), 100, 800) * env(1.2, 0.01, 3)))
save("enemy_die", mix(sweep(0.7, 520, 110) * env(0.7, 0.01, 5) * 0.6, bp(noise(0.7), 300, 3000) * env(0.7, 0.02, 6), 0.3 * sweep(0.7, 780, 160) * env(0.7, 0.01, 6)))
save("jump", bp(noise(0.14), 400, 2500) * hann(0.14))
save("land", mix(sweep(0.16, 120, 55) * env(0.16, 0.001, 20), 0.5 * bp(noise(0.16), 200, 1500) * env(0.16, 0.001, 30)))
save("dash", mix(bp(noise(0.28), 350, 3000) * hann(0.28) ** 1.3, 0.2 * sweep(0.28, 200, 600) * hann(0.28)))
save("switch", mix(bell(660, 0.5, partials=(1, 2, 3), decay=7), 0.7 * np.concatenate([np.zeros(int(SR * 0.05)), bell(990, 0.45, partials=(1, 2, 3), decay=7)])))
save("deny", sweep(0.16, 140, 110, "saw") * env(0.16, 0.002, 10) * 0.6)
save("gong", mix(bell(98, 3.0, decay=0.9), 0.5 * bell(147, 3.0, decay=1.1), 0.25 * bp(noise(3.0), 200, 3000) * env(3.0, 0.002, 6)))
ch = np.zeros(int(SR * 1.3))
for i, f in enumerate((587.33, 880.0, 1174.66, 1760.0)):
    b = bell(f, 0.9, partials=(1, 2.0, 3.0), decay=4)
    st = int(SR * i * 0.11)
    ch[st:st + len(b)] += b[:len(ch) - st]
save("chime", ch)
save("tick", bell(1400, 0.07, partials=(1, 2), decay=40), 0.5)
save("spawn", mix(sweep(0.6, 90, 420) * hann(0.6) * 0.6, bp(noise(0.6), 200, 2500) * hann(0.6) ** 2, 0.3 * sweep(0.6, 133, 640) * hann(0.6)))
save("dark_shot", mix(sweep(0.32, 240, 80, "saw") * env(0.32, 0.004, 8) * 0.5, bp(noise(0.32), 300, 2200) * env(0.32, 0.01, 10)))

# ---------------------------------------------------------------- ambience loop
amb_d = 12.0
wind = bp(noise(amb_d), 60, 700)
slow = bp(noise(amb_d), 0.05, 0.5)
wind = wind * (0.55 + 0.45 * slow / np.max(np.abs(slow)))
amb = wind * 0.8
for i in range(9):
    st = rng.uniform(0.3, amb_d - 1.0)
    f0 = rng.uniform(2600, 4200)
    for j in range(rng.integers(2, 5)):
        c = sweep(0.07, f0, f0 * rng.uniform(1.1, 1.5)) * hann(0.07) * 0.1
        s0 = int(SR * (st + j * 0.11))
        amb[s0:s0 + len(c)] += c[:len(amb) - s0]
save_loop("ambience", loopify(amb, 0.8), 0.7)

# ---------------------------------------------------------------- music loop
BEAT = 0.8
BARS = 20
N = int(SR * BEAT * 4 * BARS)
mus = np.zeros(N)

def add(buf, x, at, gain=1.0):
    i0 = int(SR * at) % len(buf)
    n = len(x)
    if i0 + n <= len(buf):
        buf[i0:i0 + n] += x * gain
    else:
        k = len(buf) - i0
        buf[i0:] += x[:k] * gain
        buf[:n - k] += x[k:] * gain

NOTE = {"C2": 65.41, "D2": 73.42, "F2": 87.31, "G2": 98.0, "A2": 110.0, "Bb2": 116.54,
        "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "A3": 220.0, "Bb3": 233.08,
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0, "A4": 440.0, "C5": 523.25, "D5": 587.33,
        "F5": 698.46, "G5": 783.99, "A5": 880.0}
CHORDS = [("D2", "A2", "D3", "F3", "A3"), ("Bb2", "F3", "Bb3", "D4"), ("F2", "C3", "F3", "A3", "C4"), ("C2", "G2", "C3", "E3", "G3"),
          ("D2", "A2", "D3", "F3", "A3"), ("Bb2", "F3", "Bb3", "D4"), ("F2", "C3", "F3", "A3", "C4"), ("C2", "G2", "C3", "E3", "G3"),
          ("Bb2", "F3", "Bb3", "D4"), ("C2", "G2", "C3", "E3", "G3")]
PENT = ["D4", "F4", "G4", "A4", "C5", "D5", "F5", "G5", "A5"]

def padnote(freq, d):
    t = t_(d)
    e = np.minimum(t / 1.8, 1.0) * np.minimum((d - t) / 2.2, 1.0)
    x = np.zeros(len(t))
    for det in (-0.35, 0.0, 0.4):
        x += np.sin(2 * np.pi * (freq + det) * t + rng.uniform(0, 6))
        x += 0.25 * np.sin(2 * np.pi * (freq + det) * 2 * t + rng.uniform(0, 6))
    return x * e

def taiko(low=True):
    d = 0.7
    return mix(sweep(d, 105 if low else 150, 48 if low else 80) * env(d, 0.002, 7), 0.25 * bp(noise(d), 200, 1800) * env(d, 0.001, 30))

chord_len = BEAT * 8
mel_rng = np.random.default_rng(21)
idx = 4
for ci, ch_ in enumerate(CHORDS):
    at = ci * chord_len
    for n_ in ch_:
        add(mus, padnote(NOTE[n_], chord_len + 2.6), at - 0.6, 0.05 if n_.endswith("2") else 0.035)
    for bar in range(2):
        bt = at + bar * BEAT * 4
        add(mus, taiko(True), bt, 0.42)
        add(mus, taiko(False), bt + BEAT * 2.5, 0.2)
        if ci >= 4:
            add(mus, taiko(True), bt + BEAT * 3.5, 0.25)
        for e8 in range(8):
            if mel_rng.random() < (0.38 if ci < 4 else 0.55):
                idx = int(np.clip(idx + mel_rng.integers(-2, 3), 0, len(PENT) - 1))
                add(mus, pluck(NOTE[PENT[idx]]), bt + e8 * BEAT * 0.5, 0.16)
                if mel_rng.random() < 0.3:
                    add(mus, pluck(NOTE[PENT[idx]] * 0.5), bt + e8 * BEAT * 0.5, 0.1)
# gentle echo for space
echo = np.roll(mus, int(SR * BEAT * 0.75)) * 0.28 + np.roll(mus, int(SR * BEAT * 1.5)) * 0.14
mus = bp(mus + echo, 30, 9000)
save_loop("music", mus, 0.8)
print("SFX DONE", len(os.listdir(OUT)))
