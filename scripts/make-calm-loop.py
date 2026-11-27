"""
generates static/audio/music/calm-loop.mp3, the home page's background music (#175)

the track is synthesized from scratch here, so Distill owns it and no license applies beyond the
repo's own. run from the repo root (needs numpy, scipy and ffmpeg):

    python3 scripts/make-calm-loop.py

the output is deterministic, so running it again gives the same file
"""
import subprocess
import numpy as np, scipy.signal as sg, scipy.io.wavfile as wf
SR = 32000
BPM = 72
beat = 60 / BPM
bar = 4 * beat
BARS = 8
L = int(round(BARS * bar * SR))
rng = np.random.default_rng(7)

def midi(n): return 440 * 2 ** ((n - 69) / 12)

def env(n, a, r, sustain=1.0):
    t = np.arange(n) / SR
    e = np.minimum(1, t / a) if a > 0 else np.ones(n)
    rel = np.clip((n / SR - t) / r, 0, 1)
    return e * rel * sustain

def tri(f, n):
    t = np.arange(n) / SR
    return 2 * np.abs(2 * ((t * f) % 1) - 1) - 1

def pulse(f, n, duty=0.25):
    t = np.arange(n) / SR
    return np.where((t * f) % 1 < duty, 1.0, -1.0)

buf = np.zeros((L + SR * 4, 2))
def add(sig, start_s, pan=0.0, gain=1.0):
    i = int(round(start_s * SR)) 
    n = len(sig)
    l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
    buf[i:i + n, 0] += sig * gain * l
    buf[i:i + n, 1] += sig * gain * r

# fmaj7 - em7 - Dm7 - Cmaj7, two bars each: a slow, settled descent
chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
for ci, ch in enumerate(chords):
    t0 = ci * 2 * bar
    # pad: soft triangle chord, slow swell
    n = int(2 * bar * SR)
    pad = sum(tri(midi(x + 12), n) for x in ch) / len(ch)
    add(pad * env(n, 1.2, 1.4), t0, 0.0, 0.10)
    # bass: triangle roots on beats 1 and 3
    for b in range(4):
        n = int(1.8 * beat * SR)
        add(tri(midi(ch[0] - 12), n) * env(n, 0.01, 1.2), t0 + b * 2 * beat, 0.0, 0.22)
    # arpeggio: quiet 25% pulse in eighths, up and back down the chord
    pattern = [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 3, 2, 1]
    for k in range(16):
        n = int(0.9 * beat * SR)
        note = ch[pattern[k]] + 24
        s = pulse(midi(note), n) * env(n, 0.005, 0.85 * beat * 1.0) * np.exp(-np.arange(n) / SR * 3.0)
        add(s, t0 + k * beat / 2, -0.35 if k % 2 else 0.35, 0.045 + 0.01 * rng.random())

# a sparse, high melody answering every other bar
melody = [(0, 72, 2), (2, 71, 1), (3, 69, 1), (8, 71, 2), (10, 69, 1), (11, 67, 1),
          (16, 69, 2), (18, 67, 1), (19, 65, 1), (24, 67, 3), (27, 64, 1)]
for beat_i, note, dur in melody:
    n = int(dur * beat * SR)
    s = tri(midi(note + 12), n) * env(n, 0.03, dur * beat * 0.9) * np.exp(-np.arange(n) / SR * 1.2)
    add(s, beat_i * beat, 0.1, 0.09)

# soften the chip edges, add a gentle echo, then wrap the tail onto the start so it loops cleanly
b, a = sg.butter(2, 3200 / (SR / 2))
buf = sg.lfilter(b, a, buf, axis=0)
d = int(beat * 0.75 * SR)
echo = np.zeros_like(buf)
for k, g in enumerate([0.32, 0.16, 0.08], 1):
    echo[k * d:] += buf[:-k * d] * g
buf = buf + echo
loop = buf[:L].copy()
loop[:len(buf) - L] += buf[L:]
# match the concentration loop's loudness roughly
loop = loop / np.sqrt(np.mean(loop ** 2)) * 0.11
peak = np.max(np.abs(loop))
if peak > 0.95: loop *= 0.95 / peak
wav = 'static/audio/music/calm-loop.wav'
wf.write(wav, SR, (loop * 32767).astype(np.int16))
# same format as the other music: 32 kHz stereo, 96 kbps mp3
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k',
                '-ar', '32000', 'static/audio/music/calm-loop.mp3'], check=True)
subprocess.run(['rm', wav], check=True)
