import os
import subprocess
import sys
import wave
import fluidsynth
import numpy as np
from scipy import signal

SAMPLE_RATE = 44100
SOUNDFONT_PATH = "/usr/share/soundfonts/FluidR3_GM.sf2"


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
    return path


def butter_lowpass(samples, cutoff_hz, order=2):
    nyquist = SAMPLE_RATE * 0.5
    norm_cutoff = min(0.98, max(0.001, cutoff_hz / nyquist))
    sos = signal.butter(order, norm_cutoff, btype="low", output="sos")
    return signal.sosfilt(sos, samples)


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


def render_midi_loop(channels, events, loop_sec, tail_sec=4.0, target_db=-22.0, lowpass_hz=3200.0):
    synth = fluidsynth.Synth(gain=0.45, samplerate=float(SAMPLE_RATE))
    synth.setting("synth.reverb.active", 1)
    synth.setting("synth.reverb.room-size", 0.65)
    synth.setting("synth.reverb.damp", 0.6)
    synth.setting("synth.reverb.level", 0.45)
    synth.setting("synth.chorus.active", 1)
    synth.setting("synth.chorus.level", 0.25)
    sfid = synth.sfload(SOUNDFONT_PATH)

    for channel_idx, program_num, pan_val, volume_val in channels:
        synth.program_select(channel_idx, sfid, 0, program_num)
        synth.cc(channel_idx, 10, pan_val)
        synth.cc(channel_idx, 7, volume_val)

    timeline = []
    for start_sec, duration_sec, channel_idx, note_num, velocity in events:
        timeline.append((start_sec, 1, channel_idx, note_num, velocity))
        timeline.append((start_sec + duration_sec, 0, channel_idx, note_num, 0))
    timeline.sort(key=lambda item: (item[0], item[1]))

    total_render_sec = loop_sec + tail_sec
    total_render_samples = int(round(total_render_sec * SAMPLE_RATE))
    loop_samples = int(round(loop_sec * SAMPLE_RATE))

    raw = np.zeros((total_render_samples, 2), dtype=np.float64)
    cursor_sample = 0

    for event_sec, is_on, channel_idx, note_num, velocity in timeline:
        target_sample = min(total_render_samples, int(round(event_sec * SAMPLE_RATE)))
        if target_sample > cursor_sample:
            chunk_count = target_sample - cursor_sample
            interleaved = synth.get_samples(chunk_count).astype(np.float64) / 32768.0
            raw[cursor_sample:target_sample, 0] = interleaved[0::2]
            raw[cursor_sample:target_sample, 1] = interleaved[1::2]
            cursor_sample = target_sample
        if is_on:
            synth.noteon(channel_idx, note_num, velocity)
        else:
            synth.noteoff(channel_idx, note_num)

    if cursor_sample < total_render_samples:
        chunk_count = total_render_samples - cursor_sample
        interleaved = synth.get_samples(chunk_count).astype(np.float64) / 32768.0
        raw[cursor_sample:total_render_samples, 0] = interleaved[0::2]
        raw[cursor_sample:total_render_samples, 1] = interleaved[1::2]

    synth.delete()

    left = raw[:loop_samples, 0].copy()
    right = raw[:loop_samples, 1].copy()
    tail_len = min(loop_samples, total_render_samples - loop_samples)
    if tail_len > 0:
        left[:tail_len] += raw[loop_samples:loop_samples + tail_len, 0]
        right[:tail_len] += raw[loop_samples:loop_samples + tail_len, 1]

    left = butter_lowpass(left, lowpass_hz, order=2)
    right = butter_lowpass(right, lowpass_hz, order=2)

    peak = max(np.max(np.abs(left)), np.max(np.abs(right)), 1e-9)
    scale = (10.0 ** (target_db / 20.0)) / peak
    return left * scale, right * scale


def build_menu_theme():
    beat = 60.0 / 64.0
    loop_sec = 32.0 * beat
    channels = [
        (0, 4, 56, 95),
        (1, 89, 64, 62),
        (2, 32, 64, 88),
        (3, 11, 78, 72),
    ]
    progression = [
        ([62, 66, 69, 73], 38, [74, 73, 69, 66]),
        ([59, 62, 66, 69], 35, [71, 69, 66, 62]),
        ([55, 59, 62, 66], 43, [67, 71, 74, 69]),
        ([57, 61, 64, 67], 45, [69, 67, 64, 61]),
    ]
    events = []
    for bar_idx, (chord, bass, melody) in enumerate(progression):
        bar_start = bar_idx * 8.0 * beat
        for note in chord:
            events.append((bar_start, 7.6 * beat, 1, note, 46))
            events.append((bar_start, 3.5 * beat, 0, note + 12, 54))
            events.append((bar_start + 4.0 * beat, 3.5 * beat, 0, note + 12, 48))
        events.append((bar_start, 3.8 * beat, 2, bass, 64))
        events.append((bar_start + 4.0 * beat, 3.8 * beat, 2, bass + 7, 58))
        for step_idx, mel_note in enumerate(melody):
            events.append((bar_start + (step_idx * 2.0 + 1.0) * beat, 1.6 * beat, 3, mel_note + 12, 52))
    return render_midi_loop(channels, events, loop_sec, target_db=-22.0, lowpass_hz=3000.0)


def build_board_ambient():
    beat = 60.0 / 56.0
    loop_sec = 32.0 * beat
    channels = [
        (0, 12, 48, 86),
        (1, 49, 64, 58),
        (2, 35, 64, 82),
        (3, 24, 82, 74),
    ]
    progression = [
        ([57, 60, 64, 67, 71], 45, [64, 67, 71, 69]),
        ([53, 57, 60, 64, 69], 41, [60, 64, 69, 67]),
        ([50, 53, 57, 60, 64], 38, [57, 60, 64, 62]),
        ([52, 55, 59, 62, 67], 40, [59, 62, 64, 59]),
    ]
    events = []
    for bar_idx, (chord, bass, guitar_notes) in enumerate(progression):
        bar_start = bar_idx * 8.0 * beat
        for note in chord[:4]:
            events.append((bar_start, 7.8 * beat, 1, note, 42))
        events.append((bar_start, 7.2 * beat, 2, bass, 58))
        for pulse_idx in range(4):
            m_note = chord[pulse_idx % len(chord)]
            events.append((bar_start + pulse_idx * 2.0 * beat, 1.5 * beat, 0, m_note, 48))
        for g_idx, g_note in enumerate(guitar_notes):
            events.append((bar_start + (g_idx * 2.0 + 1.0) * beat, 1.8 * beat, 3, g_note + 12, 46))
    return render_midi_loop(channels, events, loop_sec, target_db=-22.5, lowpass_hz=2400.0)


def build_map_united_states():
    beat = 60.0 / 60.0
    loop_sec = 32.0 * beat
    channels = [
        (0, 5, 52, 84),
        (1, 89, 64, 56),
        (2, 42, 74, 70),
        (3, 24, 42, 78),
    ]
    progression = [
        ([55, 59, 62, 66], 43, [67, 71, 74, 71]),
        ([52, 55, 59, 62], 40, [64, 67, 71, 67]),
        ([48, 52, 55, 62], 36, [60, 64, 67, 62]),
        ([50, 54, 57, 62], 38, [62, 66, 69, 66]),
    ]
    events = []
    for bar_idx, (chord, cello, guitar) in enumerate(progression):
        bar_start = bar_idx * 8.0 * beat
        for note in chord:
            events.append((bar_start, 7.6 * beat, 1, note, 44))
            events.append((bar_start + 0.5 * beat, 3.2 * beat, 0, note + 12, 46))
        events.append((bar_start, 7.4 * beat, 2, cello, 54))
        for g_idx, g_note in enumerate(guitar):
            events.append((bar_start + g_idx * 2.0 * beat, 1.8 * beat, 3, g_note, 50))
    return render_midi_loop(channels, events, loop_sec, target_db=-22.5, lowpass_hz=2600.0)


def build_map_germany():
    beat = 60.0 / 58.0
    loop_sec = 32.0 * beat
    channels = [
        (0, 4, 58, 86),
        (1, 42, 46, 74),
        (2, 60, 78, 56),
        (3, 32, 64, 80),
    ]
    progression = [
        ([60, 63, 67, 74], 36, 67),
        ([56, 60, 63, 67], 44, 63),
        ([53, 56, 60, 63], 41, 65),
        ([55, 60, 62, 67], 43, 62),
    ]
    events = []
    for bar_idx, (chord, bass, horn_note) in enumerate(progression):
        bar_start = bar_idx * 8.0 * beat
        for note in chord:
            events.append((bar_start, 3.6 * beat, 0, note, 48))
            events.append((bar_start + 4.0 * beat, 3.6 * beat, 0, note, 44))
        events.append((bar_start, 7.5 * beat, 1, bass + 12, 56))
        events.append((bar_start, 7.5 * beat, 3, bass, 58))
        events.append((bar_start + 2.0 * beat, 5.0 * beat, 2, horn_note, 42))
    return render_midi_loop(channels, events, loop_sec, target_db=-22.5, lowpass_hz=2400.0)


def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    audio_dir = ensure_dir(os.path.join(root_dir, "asset", "audio"))
    tracks = [
        ("menu_theme.ogg", build_menu_theme),
        ("board_ambient.ogg", build_board_ambient),
        ("map_united_states.ogg", build_map_united_states),
        ("map_germany.ogg", build_map_germany),
    ]
    total = len(tracks)
    for idx, (file_name, builder_fn) in enumerate(tracks, start=1):
        print(f"Rendering music {idx}/{total}: {file_name}")
        left, right = builder_fn()
        write_ogg_stereo(os.path.join(audio_dir, file_name), left, right)
    return 0


if __name__ == "__main__":
    sys.exit(main())
