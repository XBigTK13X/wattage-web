import json
import os
import sys


def hex_to_godot_color(hex_str, alpha=1.0):
    cleaned = hex_str.lstrip("#")
    red = int(cleaned[0:2], 16) / 255.0
    green = int(cleaned[2:4], 16) / 255.0
    blue = int(cleaned[4:6], 16) / 255.0
    return f"Color({red:.4f}, {green:.4f}, {blue:.4f}, {alpha:.4f})"


def sync_decks(root_dir):
    plants_path = os.path.join(root_dir, "tools", "game_data", "plants.json")
    with open(plants_path, "r", encoding="utf-8") as handle:
        plants_data = json.load(handle)

    decks = plants_data.get("decks", {})
    decks_out_dir = os.path.join(root_dir, "data", "decks")
    os.makedirs(decks_out_dir, exist_ok=True)

    deck_ids = sorted(decks.keys())
    for idx, deck_id in enumerate(deck_ids, start=1):
        out_path = os.path.join(decks_out_dir, deck_id + ".json")
        payload = {"id": deck_id, "cards": decks[deck_id]}
        with open(out_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
        print(f"Synced deck {idx}/{len(deck_ids)}: {deck_id} ({len(decks[deck_id])} cards)")
    return deck_ids


def sync_maps(root_dir):
    maps_src_dir = os.path.join(root_dir, "tools", "game_data", "maps")
    maps_out_dir = os.path.join(root_dir, "data", "maps")
    os.makedirs(maps_out_dir, exist_ok=True)

    map_files = sorted(name for name in os.listdir(maps_src_dir) if name.endswith(".json"))
    render_sizes = {}
    for idx, file_name in enumerate(map_files, start=1):
        src_path = os.path.join(maps_src_dir, file_name)
        with open(src_path, "r", encoding="utf-8") as handle:
            map_data = json.load(handle)

        render_size = map_data.get("render_size", [1200, 820])
        width = float(render_size[0])
        height = float(render_size[1])
        map_id = map_data.get("id", file_name[:-5])
        render_sizes[map_id] = [int(width), int(height)]

        out_data = dict(map_data)
        out_cities = []
        for city in map_data.get("cities", []):
            city_copy = dict(city)
            norm_pos = city.get("position", [0.0, 0.0])
            city_copy["position"] = [
                round(float(norm_pos[0]) * width, 1),
                round(float(norm_pos[1]) * height, 1),
            ]
            out_cities.append(city_copy)
        out_data["cities"] = out_cities

        out_path = os.path.join(maps_out_dir, file_name)
        with open(out_path, "w", encoding="utf-8") as handle:
            json.dump(out_data, handle, indent=2)
        print(f"Synced map {idx}/{len(map_files)}: {map_id}")
    return render_sizes


def sync_gdscript_constants(root_dir, deck_ids, render_sizes):
    tokens_path = os.path.join(root_dir, "tools", "game_data", "tokens.json")
    theme_path = os.path.join(root_dir, "tools", "graphics", "theme.json")
    with open(tokens_path, "r", encoding="utf-8") as handle:
        tokens_data = json.load(handle)
    with open(theme_path, "r", encoding="utf-8") as handle:
        theme_data = json.load(handle)

    player_lines = []
    for color_key, color_info in tokens_data.get("player_colors", {}).items():
        player_lines.append(f'\t"{color_key}": {hex_to_godot_color(color_info["fill"])}')

    resource_lines = []
    for res_key, res_info in tokens_data.get("resource_types", {}).items():
        resource_lines.append(f'\t"{res_key}": {hex_to_godot_color(res_info["fill"])}')

    palette = theme_data.get("palette", {})
    ui_lines = []
    for pal_key, pal_hex in palette.items():
        ui_lines.append(f'\t"{pal_key}": {hex_to_godot_color(pal_hex)}')

    map_size_lines = []
    for map_id in sorted(render_sizes.keys()):
        dims = render_sizes[map_id]
        map_size_lines.append(f'\t"{map_id}": Vector2i({dims[0]}, {dims[1]})')

    deck_entries = ", ".join(f'"{deck_id}"' for deck_id in deck_ids)
    token_counts = tokens_data.get("token_counts", {})
    card_dims = tokens_data.get("card_dimensions", {"width": 160, "height": 210})

    gd_lines = [
        "extends RefCounted",
        "",
        "const PLAYER_COLORS = {",
        ",\n".join(player_lines),
        "}",
        "",
        "const RESOURCE_COLORS = {",
        ",\n".join(resource_lines),
        "}",
        "",
        "const UI_COLORS = {",
        ",\n".join(ui_lines),
        "}",
        "",
        "const MAP_RENDER_SIZES = {",
        ",\n".join(map_size_lines),
        "}",
        "",
        f"const DECK_IDS = [{deck_entries}]",
        f'const HOUSES_PER_PLAYER = {int(token_counts.get("houses_per_player", 22))}',
        f'const STARTING_ELEKTRO = {int(token_counts.get("starting_elektro", 50))}',
        f'const CARD_DIMENSIONS = Vector2i({int(card_dims["width"])}, {int(card_dims["height"])})',
        "",
    ]

    out_dir = os.path.join(root_dir, "script", "generated")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "game_constants.gd")
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(gd_lines))
    print(f"Generated GDScript constants: {os.path.relpath(out_path, root_dir)}")


def sync_all(root_dir):
    deck_ids = sync_decks(root_dir)
    render_sizes = sync_maps(root_dir)
    sync_gdscript_constants(root_dir, deck_ids, render_sizes)


def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    sync_all(root_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
