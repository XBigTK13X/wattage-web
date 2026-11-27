import math
import os
import struct
import subprocess
import sys
import wave
from PIL import Image, ImageDraw

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def ensure_dir(relative_dir):
    full_path = os.path.join(ROOT_DIR, relative_dir)
    os.makedirs(full_path, exist_ok=True)
    return full_path


def make_nine_patch(path, size, fill, border, radius=10, border_width=3):
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1],
        radius=radius,
        fill=fill,
        outline=border,
        width=border_width,
    )
    image.save(path)


def make_house(path, fill, outline):
    image = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    roof = [(24, 6), (6, 22), (42, 22)]
    draw.polygon(roof, fill=fill, outline=outline)
    draw.rectangle([11, 22, 37, 42], fill=fill, outline=outline, width=2)
    draw.polygon(roof, fill=fill)
    draw.line(roof + [roof[0]], fill=outline, width=2)
    image.save(path)


def make_arrow(path, direction):
    image = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle([2, 2, 45, 45], radius=8, fill=(40, 48, 64, 240), outline=(216, 173, 64, 255), width=2)
    if direction == "up":
        pts = [(24, 10), (10, 34), (38, 34)]
    elif direction == "down":
        pts = [(24, 38), (10, 14), (38, 14)]
    elif direction == "left":
        pts = [(10, 24), (34, 10), (34, 38)]
    else:
        pts = [(38, 24), (14, 10), (14, 38)]
    draw.polygon(pts, fill=(240, 244, 250, 255))
    image.save(path)


def make_action_badge(path, fill, symbol):
    image = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle([2, 2, 61, 45], radius=10, fill=fill, outline=(235, 240, 248, 230), width=2)
    if symbol == "check":
        draw.line([(18, 24), (28, 34), (46, 14)], fill=(255, 255, 255, 255), width=4)
    elif symbol == "cross":
        draw.line([(20, 14), (44, 34)], fill=(255, 255, 255, 255), width=4)
        draw.line([(44, 14), (20, 34)], fill=(255, 255, 255, 255), width=4)
    elif symbol == "plus1":
        draw.line([(18, 24), (30, 24)], fill=(255, 255, 255, 255), width=3)
        draw.line([(24, 18), (24, 30)], fill=(255, 255, 255, 255), width=3)
        draw.line([(40, 14), (40, 34)], fill=(255, 255, 255, 255), width=4)
    elif symbol == "plus5":
        draw.line([(16, 24), (28, 24)], fill=(255, 255, 255, 255), width=3)
        draw.line([(22, 18), (22, 30)], fill=(255, 255, 255, 255), width=3)
        draw.line([(34, 14), (46, 14)], fill=(255, 255, 255, 255), width=3)
        draw.line([(34, 14), (34, 24)], fill=(255, 255, 255, 255), width=3)
        draw.line([(34, 24), (46, 24)], fill=(255, 255, 255, 255), width=3)
        draw.line([(46, 24), (46, 34)], fill=(255, 255, 255, 255), width=3)
        draw.line([(34, 34), (46, 34)], fill=(255, 255, 255, 255), width=3)
    image.save(path)


def generate_graphics():
    ui_dir = ensure_dir(os.path.join("asset", "ui"))
    token_dir = ensure_dir(os.path.join("asset", "token"))
    icon_dir = ensure_dir(os.path.join("asset", "icon"))

    tasks = []

    tasks.append(("panel_frame.png", lambda: make_nine_patch(os.path.join(ui_dir, "panel_frame.png"), (96, 96), (26, 32, 44, 242), (216, 173, 64, 245), radius=10, border_width=3)))
    tasks.append(("button_normal.png", lambda: make_nine_patch(os.path.join(ui_dir, "button_normal.png"), (64, 48), (46, 56, 76, 255), (216, 173, 64, 230), radius=8, border_width=2)))
    tasks.append(("button_hover.png", lambda: make_nine_patch(os.path.join(ui_dir, "button_hover.png"), (64, 48), (62, 74, 99, 255), (245, 206, 92, 255), radius=8, border_width=2)))
    tasks.append(("button_pressed.png", lambda: make_nine_patch(os.path.join(ui_dir, "button_pressed.png"), (64, 48), (33, 41, 56, 255), (180, 142, 48, 255), radius=8, border_width=2)))
    tasks.append(("button_disabled.png", lambda: make_nine_patch(os.path.join(ui_dir, "button_disabled.png"), (64, 48), (34, 38, 46, 200), (96, 102, 114, 180), radius=8, border_width=2)))
    tasks.append(("focus_ring.png", lambda: make_nine_patch(os.path.join(ui_dir, "focus_ring.png"), (64, 64), (0, 0, 0, 0), (255, 217, 76, 255), radius=10, border_width=4)))
    tasks.append(("card_frame_standard.png", lambda: make_nine_patch(os.path.join(ui_dir, "card_frame_standard.png"), (160, 210), (32, 39, 54, 250), (140, 160, 190, 255), radius=12, border_width=3)))
    tasks.append(("card_frame_step3.png", lambda: make_nine_patch(os.path.join(ui_dir, "card_frame_step3.png"), (160, 210), (54, 42, 24, 250), (245, 197, 66, 255), radius=12, border_width=4)))

    def make_elektro():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.ellipse([4, 4, 43, 43], fill=(235, 188, 48, 255), outline=(120, 88, 16, 255), width=3)
        drw.polygon([(27, 10), (16, 25), (24, 25), (20, 38), (32, 22), (24, 22)], fill=(28, 32, 42, 255))
        img.save(os.path.join(ui_dir, "elektro_badge.png"))

    tasks.append(("elektro_badge.png", make_elektro))

    tasks.append(("house_token.png", lambda: make_house(os.path.join(token_dir, "house_token.png"), (245, 245, 245, 255), (60, 60, 60, 255))))
    player_colors = {
        "red": ((214, 56, 51, 255), (105, 24, 22, 255)),
        "blue": ((51, 122, 219, 255), (24, 58, 112, 255)),
        "green": ((56, 173, 87, 255), (24, 86, 40, 255)),
        "yellow": ((235, 194, 46, 255), (120, 96, 18, 255)),
        "purple": ((158, 82, 199, 255), (78, 36, 102, 255)),
        "black": ((42, 46, 54, 255), (16, 18, 22, 255)),
    }
    for color_key, (fill, outline) in player_colors.items():
        tasks.append((f"house_{color_key}.png", lambda ck=color_key, fl=fill, ol=outline: make_house(os.path.join(token_dir, f"house_{ck}.png"), fl, ol)))

    def make_city_node():
        img = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.rounded_rectangle([2, 2, 93, 61], radius=12, fill=(38, 45, 60, 245), outline=(170, 185, 210, 255), width=2)
        for center_x in [22, 48, 74]:
            drw.ellipse([center_x - 10, 22, center_x + 10, 42], fill=(24, 28, 38, 255), outline=(216, 173, 64, 220), width=2)
        img.save(os.path.join(token_dir, "city_node.png"))

    def make_connection_badge():
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.ellipse([3, 3, 36, 36], fill=(28, 34, 46, 245), outline=(216, 173, 64, 255), width=2)
        img.save(os.path.join(token_dir, "connection_badge.png"))

    def make_turn_marker():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.rounded_rectangle([4, 4, 43, 43], radius=10, fill=(245, 245, 245, 255), outline=(40, 46, 58, 255), width=3)
        img.save(os.path.join(token_dir, "turn_order_marker.png"))

    tasks.append(("city_node.png", make_city_node))
    tasks.append(("connection_badge.png", make_connection_badge))
    tasks.append(("turn_order_marker.png", make_turn_marker))

    def make_resource_coal():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.polygon([(12, 14), (28, 8), (40, 18), (36, 38), (14, 40), (8, 26)], fill=(112, 70, 44, 255), outline=(210, 160, 120, 255))
        img.save(os.path.join(icon_dir, "resource_coal.png"))

    def make_resource_oil():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.rounded_rectangle([12, 8, 36, 40], radius=4, fill=(32, 36, 46, 255), outline=(140, 160, 190, 255), width=2)
        drw.line([(12, 18), (36, 18)], fill=(140, 160, 190, 255), width=2)
        drw.line([(12, 30), (36, 30)], fill=(140, 160, 190, 255), width=2)
        img.save(os.path.join(icon_dir, "resource_oil.png"))

    def make_resource_garbage():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.polygon([(12, 14), (36, 14), (32, 40), (16, 40)], fill=(194, 173, 51, 255), outline=(245, 228, 120, 255))
        drw.rectangle([10, 10, 38, 14], fill=(220, 200, 80, 255))
        img.save(os.path.join(icon_dir, "resource_garbage.png"))

    def make_resource_uranium():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.ellipse([6, 6, 41, 41], fill=(214, 51, 61, 255), outline=(255, 165, 170, 255), width=2)
        drw.ellipse([19, 19, 28, 28], fill=(255, 235, 120, 255))
        img.save(os.path.join(icon_dir, "resource_uranium.png"))

    def make_ecological():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.ellipse([6, 6, 41, 41], fill=(54, 175, 108, 255), outline=(170, 245, 200, 255), width=2)
        drw.line([(24, 12), (24, 36)], fill=(255, 255, 255, 255), width=3)
        drw.polygon([(24, 12), (35, 22), (24, 24)], fill=(255, 255, 255, 255))
        img.save(os.path.join(icon_dir, "plant_ecological.png"))

    def make_hybrid_badge():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.pieslice([6, 6, 41, 41], 90, 270, fill=(32, 36, 46, 255), outline=(220, 225, 235, 255), width=2)
        drw.pieslice([6, 6, 41, 41], 270, 90, fill=(112, 70, 44, 255), outline=(220, 225, 235, 255), width=2)
        img.save(os.path.join(icon_dir, "plant_hybrid_badge.png"))

    def make_power_bolt():
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        drw = ImageDraw.Draw(img)
        drw.polygon([(28, 4), (12, 26), (22, 26), (18, 44), (36, 20), (26, 20)], fill=(245, 197, 66, 255), outline=(140, 100, 16, 255))
        img.save(os.path.join(icon_dir, "power_bolt.png"))

    tasks.extend([
        ("resource_coal.png", make_resource_coal),
        ("resource_oil.png", make_resource_oil),
        ("resource_garbage.png", make_resource_garbage),
        ("resource_uranium.png", make_resource_uranium),
        ("plant_ecological.png", make_ecological),
        ("plant_hybrid_badge.png", make_hybrid_badge),
        ("power_bolt.png", make_power_bolt),
    ])

    for direction in ["up", "down", "left", "right"]:
        tasks.append((f"dpad_{direction}.png", lambda dr=direction: make_arrow(os.path.join(icon_dir, f"dpad_{dr}.png"), dr)))

    tasks.append(("action_confirm.png", lambda: make_action_badge(os.path.join(icon_dir, "action_confirm.png"), (44, 140, 74, 255), "check")))
    tasks.append(("action_pass.png", lambda: make_action_badge(os.path.join(icon_dir, "action_pass.png"), (168, 52, 52, 255), "cross")))
    tasks.append(("action_bid_plus1.png", lambda: make_action_badge(os.path.join(icon_dir, "action_bid_plus1.png"), (52, 104, 178, 255), "plus1")))
    tasks.append(("action_bid_plus5.png", lambda: make_action_badge(os.path.join(icon_dir, "action_bid_plus5.png"), (140, 82, 180, 255), "plus5")))

    total = len(tasks)
    for index, (label, fn) in enumerate(tasks, start=1):
        print(f"Generating graphic {index}/{total}: {label}")
        fn()


def write_wav(path, notes, duration=0.14, volume=0.35):
    sample_rate = 22050
    frames = []
    for freq in notes:
        count = int(sample_rate * duration)
        for sample_index in range(count):
            tt = sample_index / sample_rate
            env = min(1.0, sample_index / 180.0) * max(0.0, 1.0 - (sample_index / count))
            val = math.sin(2.0 * math.pi * freq * tt) * env * volume
            frames.append(struct.pack("<h", int(val * 32767)))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(b"".join(frames))


def write_loop_ogg(ogg_path, chord_freqs, duration=4.0, volume=0.15):
    wav_path = ogg_path + ".tmp.wav"
    sample_rate = 22050
    total_samples = int(sample_rate * duration)
    frames = []
    for sample_index in range(total_samples):
        tt = sample_index / sample_rate
        val = 0.0
        for freq in chord_freqs:
            val += math.sin(2.0 * math.pi * freq * tt) / len(chord_freqs)
        fade = 1.0
        if sample_index < 800:
            fade = sample_index / 800.0
        elif sample_index > total_samples - 800:
            fade = (total_samples - sample_index) / 800.0
        frames.append(struct.pack("<h", int(val * fade * volume * 32767)))
    with wave.open(wav_path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(b"".join(frames))
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", ogg_path],
        check=True,
    )
    os.remove(wav_path)


def generate_audio():
    audio_dir = ensure_dir(os.path.join("asset", "audio"))
    sfx_cues = {
        "bid_placed.wav": ([523.25], 0.10),
        "auction_won.wav": ([523.25, 659.25, 783.99], 0.12),
        "resource_bought.wav": ([392.00, 493.88], 0.10),
        "city_built.wav": ([329.63, 440.00, 659.25], 0.12),
        "phase_change.wav": ([440.00, 554.37], 0.15),
        "turn_alert.wav": ([659.25, 880.00], 0.14),
        "step_transition.wav": ([392.00, 523.25, 659.25, 783.99], 0.14),
        "power_up.wav": ([261.63, 329.63, 392.00, 523.25], 0.12),
        "action_invalid.wav": ([185.00, 146.83], 0.12),
        "ui_click.wav": ([740.00], 0.05),
        "ui_hover.wav": ([587.33], 0.04),
    }
    music_tracks = {
        "menu_theme.ogg": [220.00, 277.18, 329.63],
        "board_ambient.ogg": [196.00, 246.94, 293.66],
    }
    total = len(sfx_cues) + len(music_tracks)
    step = 0
    for file_name, (freqs, dur) in sfx_cues.items():
        step += 1
        print(f"Generating audio {step}/{total}: {file_name}")
        write_wav(os.path.join(audio_dir, file_name), freqs, dur)
    for file_name, chord in music_tracks.items():
        step += 1
        print(f"Generating audio {step}/{total}: {file_name}")
        write_loop_ogg(os.path.join(audio_dir, file_name), chord)


def main():
    generate_graphics()
    generate_audio()
    return 0


if __name__ == "__main__":
    sys.exit(main())
