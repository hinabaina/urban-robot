"""Звуки вступительного ролика DALA WORKS (владелец A): ветер, низкий гул и гром.
Всё синтезируется кодом, чужих записей нет. Запуск: python3 tools/audio/gen_intro_audio.py
(нужны numpy и ffmpeg). Голос рассказчика сгенерирован отдельно (ElevenLabs), см. third_party.md."""
import os
import subprocess
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(11)


def onepole(x, k):
    """Фильтр низких частот: k в (0, 1], меньше — глуше."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc)
        y[i] = acc
    return y


def loop_crossfade(x, fade_sec=1.0):
    """Склеить конец с началом, чтобы петля звучала без щелчка."""
    n = int(SR * fade_sec)
    ramp = np.linspace(0, 1, n)
    head = x[:n] * ramp + x[-n:] * (1 - ramp)
    return np.concatenate([head, x[n:-n]])


def normalize(x, peak=0.8):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save_wav(name, x):
    path = os.path.join(OUT, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    return path


def save_ogg(name, x):
    tmp = save_wav(name + "_tmp", x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def wind(sec=12.0):
    """Степной ветер: шум, у которого медленно плавают громкость и «яркость»."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.13 * t) * np.sin(2 * np.pi * 0.07 * t + 1.0)
    low = onepole(rng.uniform(-1, 1, n), 0.02)
    whistle = onepole(rng.uniform(-1, 1, n), 0.12) - onepole(rng.uniform(-1, 1, n), 0.05)
    return normalize(loop_crossfade((low * 1.2 + whistle * 0.35 * gust) * gust), 0.7)


def drone(sec=12.0):
    """Тревожный низкий гул: два близких баса биением и тихая квинта."""
    t = np.arange(int(SR * sec)) / SR
    x = np.sin(2 * np.pi * 55.0 * t) + np.sin(2 * np.pi * 55.6 * t) + 0.35 * np.sin(2 * np.pi * 82.4 * t)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.25 * t)
    x += 0.15 * onepole(rng.uniform(-1, 1, len(t)), 0.01)
    return normalize(loop_crossfade(x), 0.6)


def thunder(sec=3.0):
    """Гром: резкий треск и долгий рокот с затуханием."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    crack = rng.uniform(-1, 1, n) * np.exp(-t * 18.0)
    rumble = onepole(rng.uniform(-1, 1, n), 0.015) * 6.0
    rumble *= np.minimum(1.0, t / 0.08) * np.exp(-t * 1.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.0 * t))
    return normalize(crack * 0.5 + rumble, 0.9)


if __name__ == "__main__":
    save_ogg("intro_wind", wind())
    save_ogg("intro_drone", drone())
    save_wav("intro_thunder", thunder())
    print("intro audio: ok")
