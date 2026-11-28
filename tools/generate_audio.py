import math
import os
import subprocess
import sys
import wave
import numpy as np
from scipy import signal

SAMPLE_RATE = 44100


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
    return path


def time_axis(duration):
    count = max(1, int(round(duration * SAMPLE_RATE)))
    return np.arange(count, dtype=np.float64) / SAMPLE_RATE


def soft_saturate(samples, drive=1.05):
    return np.tanh(samples * drive) / math.tanh(drive)


def butter_lowpass(samples, cutoff_hz, order=2):
    nyquist = SAMPLE_RATE * 0.5
    norm_cutoff = min(0.98, max(0.001, cutoff_hz / nyquist))
    sos = signal.butter(order, norm_cutoff, btype="low", output="sos")
    return signal.sosfilt(sos, samples)


def butter_bandpass(samples, low_hz, high_hz, order=2):
    nyquist = SAMPLE_RATE * 0.5
    low_norm = min(0.95, max(0.001, low_hz / nyquist))
    high_norm = min(0.98, max(low_norm + 0.01, high_hz / nyquist))
    sos = signal.butter(order, [low_norm, high_norm], btype="band", output="sos")
    return signal.sosfilt(sos, samples)


def apply_edge_fades(samples, fade_in_sec=0.008, fade_out_sec=0.03):
    out = samples.copy()
    fade_in_count = min(len(out), int(fade_in_sec * SAMPLE_RATE))
    fade_out_count = min(len(out), int(fade_out_sec * SAMPLE_RATE))
    if fade_in_count > 0:
        out[:fade_in_count] *= np.linspace(0.0, 1.0, fade_in_count)
    if fade_out_count > 0:
        out[-fade_out_count:] *= np.linspace(1.0, 0.0, fade_out_count)
    return out


def add_room_tail(samples, mix=0.18):
    taps = [
        (0.018, 0.44),
        (0.034, 0.30),
        (0.055, 0.20),
        (0.082, 0.12),
    ]
    wet = np.zeros_like(samples)
    for delay_sec, gain in taps:
        offset = int(delay_sec * SAMPLE_RATE)
        if offset < len(samples):
            wet[offset:] += samples[:-offset] * gain
    wet = butter_lowpass(wet, 1900.0, order=2)
    return samples * (1.0 - mix * 0.3) + wet * mix


def warm_rhodes_tone(freq, duration, mod_index=0.35, decay=5.2, warmth=0.18, attack_sec=0.010):
    tt = time_axis(duration)
    attack = np.minimum(1.0, tt / max(0.002, attack_sec))
    mod_env = np.exp(-tt * (decay * 2.2))
    carrier_env = np.exp(-tt * decay) * attack
    modulator = np.sin(2.0 * np.pi * (freq * 2.0) * tt) * mod_index * mod_env
    fundamental = np.sin(2.0 * np.pi * freq * tt + modulator)
    harmonic_two = np.sin(2.0 * np.pi * (freq * 2.0) * tt) * warmth * np.exp(-tt * (decay * 1.8))
    return butter_lowpass((fundamental + harmonic_two) * carrier_env, 2600.0, order=2)


def soft_tactile_thump(duration=0.055, center_hz=1100.0, thump_start_hz=145.0, thump_end_hz=55.0, seed=42):
    rng = np.random.default_rng(seed)
    tt = time_axis(duration)
    noise = rng.standard_normal(len(tt))
    filtered_noise = butter_bandpass(noise, max(200.0, center_hz * 0.5), min(3200.0, center_hz * 1.4), order=2)
    noise_env = np.exp(-tt * 75.0) * np.minimum(1.0, tt / 0.004)
    freq_curve = thump_end_hz + (thump_start_hz - thump_end_hz) * np.exp(-tt * 85.0)
    phase = 2.0 * np.pi * np.cumsum(freq_curve) / SAMPLE_RATE
    thump = np.sin(phase) * np.exp(-tt * 55.0) * np.minimum(1.0, tt / 0.004)
    return filtered_noise * noise_env * 0.28 + thump * 0.72


def place_event(buffer, event_samples, start_sec, gain=1.0):
    start_idx = int(round(start_sec * SAMPLE_RATE))
    if start_idx >= len(buffer):
        return
    end_idx = min(len(buffer), start_idx + len(event_samples))
    count = end_idx - start_idx
    if count > 0:
        buffer[start_idx:end_idx] += event_samples[:count] * gain


def normalize_to_db(samples, target_db):
    peak = np.max(np.abs(samples))
    if peak < 1e-9:
        return samples
    target_amp = 10.0 ** (target_db / 20.0)
    return samples * (target_amp / peak)


def write_wav_mono(path, samples):
    clipped = np.clip(samples, -0.99, 0.99)
    pcm = (clipped * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def write_ogg_stereo(ogg_path, left_samples, right_samples):
    wav_path = ogg_path + ".tmp.wav"
    stereo = np.column_stack((np.clip(left_samples, -0.99, 0.99), np.clip(right_samples, -0.99, 0.99)))
    pcm = (stereo * 32767.0).astype(np.int16)
    with wave.open(wav_path, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", ogg_path],
        check=True,
    )
    os.remove(wav_path)


def synth_ui_hover():
    buf = np.zeros(int(0.055 * SAMPLE_RATE), dtype=np.float64)
    pip = warm_rhodes_tone(739.99, 0.045, mod_index=0.15, decay=55.0, warmth=0.05, attack_sec=0.005)
    place_event(buf, pip, 0.0, 0.5)
    return normalize_to_db(apply_edge_fades(buf, 0.005, 0.015), -24.0)


def synth_ui_click():
    buf = np.zeros(int(0.095 * SAMPLE_RATE), dtype=np.float64)
    click = soft_tactile_thump(duration=0.042, center_hz=1150.0, thump_start_hz=175.0, thump_end_hz=72.0, seed=12)
    pip = warm_rhodes_tone(440.00, 0.075, mod_index=0.25, decay=28.0, warmth=0.12, attack_sec=0.004)
    place_event(buf, click, 0.0, 0.75)
    place_event(buf, pip, 0.003, 0.45)
    out = add_room_tail(buf, mix=0.10)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.003, 0.020), -18.0)


def synth_action_invalid():
    buf = np.zeros(int(0.36 * SAMPLE_RATE), dtype=np.float64)
    for idx, (freq_a, freq_b, start_sec) in enumerate([(164.81, 123.47, 0.0), (146.83, 110.00, 0.13)]):
        tt = time_axis(0.18)
        env = np.minimum(1.0, tt / 0.012) * np.exp(-tt * 11.5)
        tone = np.sin(2.0 * np.pi * freq_a * tt) * 0.55 + np.sin(2.0 * np.pi * freq_b * tt) * 0.45
        tone += np.sin(2.0 * np.pi * (freq_a * 2.0) * tt) * 0.15
        warm = butter_lowpass(tone * env, 520.0, order=2)
        thud = soft_tactile_thump(duration=0.045, center_hz=700.0, thump_start_hz=120.0, thump_end_hz=48.0, seed=20 + idx)
        place_event(buf, warm, start_sec, 0.85)
        place_event(buf, thud, start_sec, 0.35)
    out = add_room_tail(buf, mix=0.12)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.06), 0.008, 0.035), -16.0)


def synth_bid_placed():
    buf = np.zeros(int(0.28 * SAMPLE_RATE), dtype=np.float64)
    chip = soft_tactile_thump(duration=0.042, center_hz=1350.0, thump_start_hz=170.0, thump_end_hz=78.0, seed=31)
    note_a = warm_rhodes_tone(369.99, 0.15, mod_index=0.30, decay=13.0, warmth=0.14, attack_sec=0.006)
    note_b = warm_rhodes_tone(493.88, 0.20, mod_index=0.35, decay=10.0, warmth=0.16, attack_sec=0.006)
    place_event(buf, chip, 0.0, 0.60)
    place_event(buf, note_a, 0.006, 0.65)
    place_event(buf, note_b, 0.080, 0.80)
    out = add_room_tail(buf, mix=0.16)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.005, 0.035), -16.0)


def synth_auction_won():
    buf = np.zeros(int(0.85 * SAMPLE_RATE), dtype=np.float64)
    gavel = soft_tactile_thump(duration=0.065, center_hz=950.0, thump_start_hz=145.0, thump_end_hz=48.0, seed=41)
    place_event(buf, gavel, 0.0, 0.70)
    arp_notes = [(369.99, 0.02), (440.00, 0.13), (587.33, 0.24), (739.99, 0.35)]
    for freq, start_sec in arp_notes:
        tone = warm_rhodes_tone(freq, 0.45, mod_index=0.38, decay=5.5, warmth=0.18, attack_sec=0.008)
        place_event(buf, tone, start_sec, 0.65)
    out = add_room_tail(buf, mix=0.22)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.006, 0.060), -14.0)


def synth_resource_bought():
    buf = np.zeros(int(0.42 * SAMPLE_RATE), dtype=np.float64)
    clack_one = soft_tactile_thump(duration=0.045, center_hz=1100.0, thump_start_hz=150.0, thump_end_hz=64.0, seed=51)
    clack_two = soft_tactile_thump(duration=0.042, center_hz=1400.0, thump_start_hz=175.0, thump_end_hz=76.0, seed=52)
    place_event(buf, clack_one, 0.0, 0.65)
    place_event(buf, clack_two, 0.085, 0.55)
    for freq, start_sec in [(329.63, 0.02), (392.00, 0.105), (493.88, 0.19)]:
        tone = warm_rhodes_tone(freq, 0.20, mod_index=0.30, decay=10.5, warmth=0.15, attack_sec=0.006)
        place_event(buf, tone, start_sec, 0.62)
    out = add_room_tail(buf, mix=0.16)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.005, 0.040), -15.5)


def synth_city_built():
    buf = np.zeros(int(0.72 * SAMPLE_RATE), dtype=np.float64)
    impact = soft_tactile_thump(duration=0.085, center_hz=850.0, thump_start_hz=135.0, thump_end_hz=42.0, seed=61)
    place_event(buf, impact, 0.0, 0.80)
    chord_freqs = [(220.00, 0.02), (293.66, 0.07), (369.99, 0.12), (440.00, 0.17)]
    for freq, start_sec in chord_freqs:
        tone = warm_rhodes_tone(freq, 0.52, mod_index=0.35, decay=5.0, warmth=0.20, attack_sec=0.010)
        place_event(buf, tone, start_sec, 0.58)
    out = add_room_tail(buf, mix=0.22)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.006, 0.060), -14.0)


def synth_phase_change():
    buf = np.zeros(int(0.70 * SAMPLE_RATE), dtype=np.float64)
    tone_one = warm_rhodes_tone(329.63, 0.34, mod_index=0.28, decay=6.5, warmth=0.18, attack_sec=0.014)
    tone_two = warm_rhodes_tone(440.00, 0.48, mod_index=0.32, decay=4.8, warmth=0.20, attack_sec=0.014)
    place_event(buf, tone_one, 0.01, 0.65)
    place_event(buf, tone_two, 0.18, 0.80)
    out = add_room_tail(buf, mix=0.22)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.010, 0.060), -15.5)


def synth_turn_alert():
    buf = np.zeros(int(0.58 * SAMPLE_RATE), dtype=np.float64)
    for freq, start_sec, gain in [(493.88, 0.01, 0.68), (587.33, 0.14, 0.80)]:
        tone = warm_rhodes_tone(freq, 0.36, mod_index=0.30, decay=7.0, warmth=0.14, attack_sec=0.010)
        place_event(buf, tone, start_sec, gain)
    out = add_room_tail(buf, mix=0.20)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.008, 0.050), -15.5)


def synth_step_transition():
    buf = np.zeros(int(1.15 * SAMPLE_RATE), dtype=np.float64)
    notes = [(220.00, 0.02), (293.66, 0.16), (369.99, 0.30), (440.00, 0.44), (587.33, 0.58)]
    for idx, (freq, start_sec) in enumerate(notes):
        dur = 0.55 if idx == len(notes) - 1 else 0.34
        decay = 4.2 if idx == len(notes) - 1 else 6.8
        tone = warm_rhodes_tone(freq, dur, mod_index=0.34, decay=decay, warmth=0.18, attack_sec=0.014)
        place_event(buf, tone, start_sec, 0.62)
    out = add_room_tail(buf, mix=0.24)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.010, 0.075), -14.0)


def synth_power_up():
    buf = np.zeros(int(1.05 * SAMPLE_RATE), dtype=np.float64)
    charge_dur = 0.46
    tt = time_axis(charge_dur)
    charge_freq = 98.0 * (2.5 ** (tt / charge_dur))
    charge_phase = 2.0 * np.pi * np.cumsum(charge_freq) / SAMPLE_RATE
    hum = np.sin(charge_phase) * 0.7 + np.sin(2.0 * charge_phase) * 0.2
    hum_env = np.minimum(1.0, tt / 0.06) * (tt / charge_dur) * np.minimum(1.0, (charge_dur - tt) / 0.05)
    place_event(buf, butter_lowpass(hum * hum_env, 900.0, order=2), 0.0, 0.55)
    snap = soft_tactile_thump(duration=0.065, center_hz=1100.0, thump_start_hz=150.0, thump_end_hz=52.0, seed=91)
    place_event(buf, snap, 0.42, 0.65)
    chord = [(220.00, 0.52), (293.66, 0.56), (440.00, 0.60), (587.33, 0.52), (739.99, 0.38)]
    for freq, gain in chord:
        tone = warm_rhodes_tone(freq, 0.62, mod_index=0.35, decay=4.2, warmth=0.22, attack_sec=0.016)
        place_event(buf, tone, 0.43, gain)
    out = add_room_tail(buf, mix=0.24)
    return normalize_to_db(apply_edge_fades(soft_saturate(out, 1.05), 0.010, 0.075), -14.0)


def wrap_add(left, right, event_l, event_r, start_sec):
    total_len = len(left)
    start_idx = int(round(start_sec * SAMPLE_RATE)) % total_len
    event_len = len(event_l)
    indices = (start_idx + np.arange(event_len)) % total_len
    np.add.at(left, indices, event_l)
    np.add.at(right, indices, event_r)


def circular_stereo_reverb(left, right, mix=0.28):
    taps_l = [(0.041, 0.42), (0.089, 0.28), (0.149, 0.16), (0.223, 0.09)]
    taps_r = [(0.053, 0.42), (0.107, 0.28), (0.173, 0.16), (0.251, 0.09)]
    wet_l = np.zeros_like(left)
    wet_r = np.zeros_like(right)
    for delay_sec, gain in taps_l:
        wet_l += np.roll(right, int(delay_sec * SAMPLE_RATE)) * gain
    for delay_sec, gain in taps_r:
        wet_r += np.roll(left, int(delay_sec * SAMPLE_RATE)) * gain
    wet_l = butter_lowpass(wet_l, 1600.0, order=2)
    wet_r = butter_lowpass(wet_r, 1600.0, order=2)
    return left * (1.0 - mix * 0.25) + wet_l * mix, right * (1.0 - mix * 0.25) + wet_r * mix


def synth_menu_theme():
    loop_sec = 32.0
    total_samples = int(loop_sec * SAMPLE_RATE)
    left = np.zeros(total_samples, dtype=np.float64)
    right = np.zeros(total_samples, dtype=np.float64)
    beat_sec = 1.0

    chords = [
        (0.0, [146.83, 220.00, 277.18, 329.63, 369.99], 73.42),
        (8.0, [123.47, 220.00, 293.66, 369.99, 440.00], 61.74),
        (16.0, [196.00, 246.94, 293.66, 369.99, 440.00], 98.00),
        (24.0, [220.00, 293.66, 329.63, 392.00, 493.88], 110.00),
    ]

    for start_sec, notes, bass_freq in chords:
        pad_dur = 8.8
        tt = time_axis(pad_dur)
        pad_env = np.minimum(1.0, tt / 1.1) * np.minimum(1.0, (pad_dur - tt) / 1.1)
        pad_l = np.zeros_like(tt)
        pad_r = np.zeros_like(tt)
        for idx, freq in enumerate(notes):
            detune = 1.0015 if idx % 2 == 0 else 0.9985
            voice_l = np.sin(2.0 * np.pi * freq * tt) + 0.12 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
            voice_r = np.sin(2.0 * np.pi * (freq * detune) * tt) + 0.12 * np.sin(2.0 * np.pi * (freq * detune) * 2.0 * tt)
            pan = 0.35 + 0.30 * (idx / max(1, len(notes) - 1))
            pad_l += voice_l * (1.0 - pan) * 0.15
            pad_r += voice_r * pan * 0.15
        pad_l = butter_lowpass(pad_l * pad_env, 1050.0, order=2)
        pad_r = butter_lowpass(pad_r * pad_env, 1050.0, order=2)
        wrap_add(left, right, pad_l, pad_r, start_sec)

        for beat_idx in range(8):
            note_time = start_sec + beat_idx * beat_sec
            if beat_idx % 2 == 0:
                b_freq = bass_freq if beat_idx % 4 == 0 else bass_freq * 1.5
                b_tone = warm_rhodes_tone(b_freq, 1.4, mod_index=0.20, decay=2.4, warmth=0.20, attack_sec=0.03)
                b_tone = butter_lowpass(b_tone, 360.0, order=2) * 0.25
                wrap_add(left, right, b_tone, b_tone, note_time)

            arp_freq = notes[(beat_idx * 2) % len(notes)]
            arp_tone = warm_rhodes_tone(arp_freq, 1.1, mod_index=0.28, decay=3.6, warmth=0.10, attack_sec=0.018) * 0.14
            pan = 0.32 + 0.36 * ((beat_idx % 4) / 3.0)
            wrap_add(left, right, arp_tone * (1.0 - pan), arp_tone * pan, note_time + 0.5)

    left, right = circular_stereo_reverb(left, right, mix=0.30)
    left = soft_saturate(left, 1.04)
    right = soft_saturate(right, 1.04)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)), 1e-9)
    scale = (10.0 ** (-22.0 / 20.0)) / peak
    return left * scale, right * scale


def synth_board_ambient():
    loop_sec = 32.0
    total_samples = int(loop_sec * SAMPLE_RATE)
    left = np.zeros(total_samples, dtype=np.float64)
    right = np.zeros(total_samples, dtype=np.float64)

    tt_full = time_axis(loop_sec)
    lfo = 0.5 + 0.5 * np.sin(2.0 * np.pi * (1.0 / 16.0) * tt_full)

    sections = [
        (0.0, [146.83, 220.00, 293.66, 369.99]),
        (16.0, [196.00, 246.94, 293.66, 369.99]),
    ]
    for start_sec, notes in sections:
        dur = 17.6
        tt = time_axis(dur)
        env = np.minimum(1.0, tt / 2.2) * np.minimum(1.0, (dur - tt) / 2.2)
        pad_l = np.zeros_like(tt)
        pad_r = np.zeros_like(tt)
        for idx, freq in enumerate(notes):
            detune = 1.0012 if idx % 2 == 0 else 0.9988
            pad_l += np.sin(2.0 * np.pi * freq * tt) * 0.16
            pad_r += np.sin(2.0 * np.pi * (freq * detune) * tt) * 0.16
        pad_l = butter_lowpass(pad_l * env, 720.0, order=2)
        pad_r = butter_lowpass(pad_r * env, 720.0, order=2)
        wrap_add(left, right, pad_l, pad_r, start_sec)

    warm_bass = (np.sin(2.0 * np.pi * 73.42 * tt_full) * 0.06 + np.sin(2.0 * np.pi * 146.83 * tt_full) * 0.03) * (0.6 + 0.4 * lfo)
    left += warm_bass
    right += warm_bass

    droplets = [
        (2.0, 440.00, 0.35),
        (7.5, 587.33, 0.65),
        (13.0, 493.88, 0.42),
        (18.5, 440.00, 0.60),
        (24.0, 587.33, 0.38),
        (29.0, 369.99, 0.55),
    ]
    for start_sec, freq, pan in droplets:
        bell = warm_rhodes_tone(freq, 2.0, mod_index=0.22, decay=2.2, warmth=0.08, attack_sec=0.025) * 0.13
        wrap_add(left, right, bell * (1.0 - pan), bell * pan, start_sec)

    left, right = circular_stereo_reverb(left, right, mix=0.34)
    left = soft_saturate(left, 1.03)
    right = soft_saturate(right, 1.03)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)), 1e-9)
    scale = (10.0 ** (-22.5 / 20.0)) / peak
    return left * scale, right * scale


def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    audio_dir = ensure_dir(os.path.join(root_dir, "asset", "audio"))

    sfx_generators = [
        ("ui_hover.wav", synth_ui_hover),
        ("ui_click.wav", synth_ui_click),
        ("action_invalid.wav", synth_action_invalid),
        ("bid_placed.wav", synth_bid_placed),
        ("auction_won.wav", synth_auction_won),
        ("resource_bought.wav", synth_resource_bought),
        ("city_built.wav", synth_city_built),
        ("phase_change.wav", synth_phase_change),
        ("turn_alert.wav", synth_turn_alert),
        ("step_transition.wav", synth_step_transition),
        ("power_up.wav", synth_power_up),
    ]
    music_generators = [
        ("menu_theme.ogg", synth_menu_theme),
        ("board_ambient.ogg", synth_board_ambient),
    ]

    total = len(sfx_generators) + len(music_generators)
    step = 0

    for file_name, generator_fn in sfx_generators:
        step += 1
        print(f"Generating audio {step}/{total}: {file_name}")
        samples = generator_fn()
        write_wav_mono(os.path.join(audio_dir, file_name), samples)

    for file_name, generator_fn in music_generators:
        step += 1
        print(f"Generating audio {step}/{total}: {file_name}")
        left, right = generator_fn()
        write_ogg_stereo(os.path.join(audio_dir, file_name), left, right)

    return 0


if __name__ == "__main__":
    sys.exit(main())
