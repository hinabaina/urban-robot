"""Генератор звуков и музыки DALA WORKS (владелец B). Всё синтезируется кодом — чужих записей нет.
Запуск: python3 tools/audio/gen_audio.py (нужны numpy и ffmpeg для музыки в OGG)."""
import os
import subprocess
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(sec, attack=0.005, decay=6.0):
    """Огибающая: быстрая атака и экспоненциальное затухание."""
    x = t(sec)
    return np.minimum(1.0, x / attack) * np.exp(-decay * x)


def sine(freq, sec, **kw):
    return np.sin(2 * np.pi * freq * t(sec)) * env(sec, **kw)


def square(freq, sec, **kw):
    return np.sign(np.sin(2 * np.pi * freq * t(sec))) * env(sec, **kw)


def noise(sec, **kw):
    return rng.uniform(-1, 1, int(SR * sec)) * env(sec, **kw)


def lowpass(x, k):
    """Простой однополюсный фильтр низких частот; k в (0, 1], меньше — глуше."""
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts):
    return np.concatenate(parts)


def pad(x, sec):
    return np.concatenate([np.zeros(int(SR * sec)), x])


def sweep(f0, f1, sec, **kw):
    x = t(sec)
    phase = 2 * np.pi * (f0 * x + (f1 - f0) * x * x / (2 * sec))
    return np.sin(phase) * env(sec, **kw)


def save(name, x, gain=0.8):
    os.makedirs(OUT, exist_ok=True)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def pluck(freq, sec, damp=0.996):
    """Щипок струны (алгоритм Карплуса — Стронга): звучит как домбра."""
    n = int(SR / freq)
    buf = rng.uniform(-1, 1, n)
    out = np.zeros(int(SR * sec))
    for i in range(len(out)):
        out[i] = buf[i % n]
        buf[i % n] = damp * 0.5 * (buf[i % n] + buf[(i + 1) % n])
    return out


def effects():
    save("dig", mix(lowpass(noise(0.09, decay=40), 0.25), sine(95, 0.09, decay=35)), 0.7)
    save("ore", mix(sine(1320, 0.25, decay=14), pad(sine(1980, 0.25, decay=16), 0.05) * 0.7), 0.55)
    save("place", mix(square(180, 0.05, decay=60) * 0.6, lowpass(noise(0.04, decay=70), 0.5), pad(sine(520, 0.06, decay=40), 0.03)), 0.6)
    save("error", lowpass(square(110, 0.16, decay=9), 0.35), 0.5)
    save("select", sine(880, 0.04, decay=60), 0.35)
    save("interact", mix(sine(440, 0.07, decay=30), pad(sine(660, 0.08, decay=30), 0.04)), 0.45)
    save("ingot", mix(sine(1047, 0.5, decay=7), sine(2094, 0.5, decay=10) * 0.4, sine(1568, 0.5, decay=8) * 0.5), 0.5)
    save("deliver", mix(sine(1568, 0.3, decay=12), sine(3136, 0.3, decay=16) * 0.3), 0.3)
    save("quota_ok", seq(*[mix(square(f, 0.13, decay=7) * 0.35, sine(f, 0.13, decay=7)) for f in (523, 659, 784)],
                         mix(square(1047, 0.45, decay=5) * 0.35, sine(1047, 0.45, decay=5))), 0.55)
    save("quota_fail", mix(sine(110, 0.6, decay=5), lowpass(noise(0.3, decay=12), 0.1), sweep(220, 80, 0.5, decay=5) * 0.6), 0.7)
    save("water", lowpass(noise(0.35, attack=0.05, decay=8), 0.3) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t(0.35))), 0.4)
    save("harvest", mix(noise(0.12, decay=25) * 0.5, pad(sine(990, 0.1, decay=25), 0.05)), 0.4)
    save("plant", mix(lowpass(noise(0.08, decay=40), 0.3), sine(330, 0.08, decay=30)), 0.4)
    save("demolish", mix(lowpass(noise(0.2, decay=14), 0.4), sweep(300, 90, 0.2, decay=12)), 0.55)
    save("hint", mix(sine(784, 0.12, decay=18), pad(sine(1175, 0.2, decay=12), 0.09)), 0.4)
    save("blocked", square(392, 0.12, decay=14), 0.18)
    drone_len = 2.4
    hum = np.sin(2 * np.pi * 140 * t(drone_len) + 3 * np.sin(2 * np.pi * 31 * t(drone_len)))
    shape = np.sin(np.pi * t(drone_len) / drone_len) ** 0.6
    save("drone", mix(hum * shape * 0.6, lowpass(rng.uniform(-1, 1, int(SR * drone_len)), 0.15) * shape), 0.5)
    launch = 6.0
    rise = (t(launch) / launch) ** 1.5
    rumble = lowpass(rng.uniform(-1, 1, int(SR * launch)), 0.06) * rise
    save("rocket", mix(rumble * 1.4, sweep(40, 160, launch, decay=0.0) * rise * 0.5), 0.9)


# Ля-минорная пентатоника: спокойная степная мелодия на «домбре» с басом.
NOTE = {"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "G3": 196.0, "A3": 220.0, "C4": 261.63,
        "D4": 293.66, "E4": 329.63, "G4": 392.0, "A4": 440.0, "C5": 523.25, "D5": 587.33, "E5": 659.25}
MELODY = ("A3 . E4 . D4 C4 A3 . | G3 . C4 . D4 . E4 . | A4 . G4 E4 D4 . C4 . | D4 E4 D4 C4 A3 . . . | "
          "C4 . E4 . G4 . A4 . | G4 E4 D4 . E4 . C4 . | A3 C4 D4 E4 D4 C4 A3 G3 | A3 . . . E3 . A3 .")
BASS = "A2 A2 | C3 C3 | A2 A2 | D3 E3 | C3 C3 | E3 C3 | A2 D3 | A2 A2"


def music(bpm=96):
    step = 60.0 / bpm / 2            # восьмая нота
    notes = [n for n in MELODY.replace("|", " ").split()]
    total = len(notes) * step
    track = np.zeros(int(SR * (total + 2.0)))
    for i, n in enumerate(notes):
        if n == ".":
            continue
        s = pluck(NOTE[n], 1.6) * 0.8
        a = int(i * step * SR)
        track[a: a + len(s)] += s
    bass = BASS.replace("|", " ").split()
    for i, n in enumerate(bass):
        s = pluck(NOTE[n], 2.2, damp=0.998) * 0.6
        a = int(i * step * 4 * SR)
        track[a: a + len(s)] += s
    loop = track[: int(SR * total)].copy()
    tail = track[int(SR * total):]
    loop[: len(tail)] += tail        # хвост последних нот заворачиваем в начало: петля без щелчка
    save("music_steppe", lowpass(loop, 0.55), 0.6)
    wav = os.path.join(OUT, "music_steppe.wav")
    ogg = os.path.join(OUT, "music_steppe.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)


if __name__ == "__main__":
    effects()
    music()
    print("ok: assets/audio")
