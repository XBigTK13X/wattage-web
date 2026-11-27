import argparse
import json
import os
import sys
from PIL import Image


def collect_sprite_files(input_dir, include_categories=("ui", "token", "icon")):
    sprites = []
    for category in include_categories:
        cat_dir = os.path.join(input_dir, category)
        if not os.path.isdir(cat_dir):
            continue
        for file_name in sorted(os.listdir(cat_dir)):
            if file_name.endswith(".png"):
                full_path = os.path.join(cat_dir, file_name)
                rel_key = f"{category}/{file_name[:-4]}"
                sprites.append((rel_key, full_path))
    return sprites


def pack_atlas(input_dir, output_png, output_json, padding=4, max_width=1024):
    sprites = collect_sprite_files(input_dir)
    if not sprites:
        print("No sprites found to pack.")
        return {}

    loaded = []
    total = len(sprites)
    for idx, (rel_key, full_path) in enumerate(sprites, start=1):
        print(f"Loading sprite {idx}/{total}: {rel_key}")
        img = Image.open(full_path).convert("RGBA")
        loaded.append((rel_key, img))

    loaded.sort(key=lambda item: item[1].height, reverse=True)

    cursor_x = padding
    cursor_y = padding
    row_height = 0
    placements = []
    sheet_width = max_width

    for rel_key, img in loaded:
        w_px, h_px = img.size
        if cursor_x + w_px + padding > sheet_width:
            cursor_x = padding
            cursor_y += row_height + padding
            row_height = 0
        placements.append((rel_key, img, cursor_x, cursor_y, w_px, h_px))
        cursor_x += w_px + padding
        row_height = max(row_height, h_px)

    sheet_height = max(64, cursor_y + row_height + padding)
    atlas_img = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))
    frames = {}

    for rel_key, img, pos_x, pos_y, w_px, h_px in placements:
        atlas_img.paste(img, (pos_x, pos_y))
        frames[rel_key] = {"x": pos_x, "y": pos_y, "w": w_px, "h": h_px}

    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    atlas_img.save(output_png)

    atlas_meta = {
        "image": os.path.basename(output_png),
        "size": {"w": sheet_width, "h": sheet_height},
        "frames": frames,
    }
    with open(output_json, "w", encoding="utf-8") as handle:
        json.dump(atlas_meta, handle, indent=2)

    print(f"Packed {len(frames)} sprites into {output_png} ({sheet_width}x{sheet_height})")
    return atlas_meta


def main():
    parser = argparse.ArgumentParser(description="Pack 1x sprites into a texture atlas.")
    parser.add_argument("--input-dir", default=None)
    parser.add_argument("--output-png", default=None)
    parser.add_argument("--output-json", default=None)
    args = parser.parse_args()

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    input_dir = args.input_dir or os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist", "png", "1x")
    output_png = args.output_png or os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist", "atlas.png")
    output_json = args.output_json or os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist", "atlas.json")
    pack_atlas(input_dir, output_png, output_json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
