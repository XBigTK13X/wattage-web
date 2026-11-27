import argparse
import html
import json
import os
import shutil
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from graphics.cards import generate_all_cards
from graphics.svg_builder import load_json
from graphics.tokens import generate_all_tokens
from pack_atlas import pack_atlas
from render_map import render_maps
from sync_godot_data import sync_all


def sync_pngs_to_godot_assets(root_dir, png_1x_dir, entries):
    asset_root = os.path.join(root_dir, "asset")
    total = len(entries)
    for idx, (rel_name, _meta) in enumerate(sorted(entries.items()), start=1):
        src_path = os.path.join(png_1x_dir, rel_name + ".png")
        dst_path = os.path.join(asset_root, rel_name + ".png")
        if not os.path.isfile(src_path):
            continue
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.copy2(src_path, dst_path)
        if idx % 25 == 0 or idx == total:
            print(f"Synced Godot asset {idx}/{total}: asset/{rel_name}.png")


def build_preview_html(dist_dir, manifest):
    sections = {}
    for asset_key, asset_info in sorted(manifest["assets"].items()):
        category = asset_info.get("category", "other")
        sections.setdefault(category, []).append((asset_key, asset_info))

    section_order = ["ui", "token", "icon", "card", "map", "other"]
    html_sections = []
    for category in section_order:
        items = sections.get(category, [])
        if not items:
            continue
        cards_html = []
        for asset_key, asset_info in items:
            rel_png = f"png/1x/{asset_key}.png"
            dims = f"{asset_info['width']}x{asset_info['height']}"
            escaped_key = html.escape(asset_key)
            cards_html.append(
                f'<div class="item">'
                f'<div class="thumb"><img src="{html.escape(rel_png)}" alt="{escaped_key}" loading="lazy" /></div>'
                f'<div class="label">{escaped_key}</div>'
                f'<div class="meta">{dims}</div>'
                f'</div>'
            )
        html_sections.append(
            f'<section><h2>{html.escape(category.upper())} ({len(items)})</h2>'
            f'<div class="grid">{"".join(cards_html)}</div></section>'
        )

    atlas_block = ""
    if manifest.get("atlas"):
        atlas_size = manifest["atlas"]["size"]
        atlas_block = (
            f'<section><h2>SPRITE ATLAS ({atlas_size["w"]}x{atlas_size["h"]})</h2>'
            f'<div class="atlas-wrap"><img src="atlas.png" alt="Sprite Atlas" /></div></section>'
        )

    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Wattage Web Asset Preview</title>
<style>
  body {{ background: #0f141c; color: #f0f4fa; font-family: system-ui, sans-serif; margin: 0; padding: 24px; }}
  h1 {{ color: #f5c542; margin: 0 0 8px 0; }}
  .summary {{ color: #b8c4d8; margin-bottom: 24px; }}
  h2 {{ color: #d8ad40; border-bottom: 1px solid #2e384c; padding-bottom: 6px; margin-top: 32px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 14px; }}
  .item {{ background: #1a202c; border: 1px solid #2e384c; border-radius: 8px; padding: 10px; text-align: center; }}
  .thumb {{ height: 120px; display: flex; align-items: center; justify-content: center; background: #121722; border-radius: 6px; overflow: hidden; }}
  .thumb img {{ max-width: 100%; max-height: 100%; object-fit: contain; }}
  .label {{ margin-top: 8px; font-size: 12px; font-weight: 600; word-break: break-word; }}
  .meta {{ font-size: 11px; color: #8ca0be; margin-top: 2px; }}
  .atlas-wrap {{ background: #121722; border: 1px solid #2e384c; border-radius: 8px; padding: 12px; overflow: auto; }}
  .atlas-wrap img {{ max-width: 100%; height: auto; }}
</style>
</head>
<body>
  <h1>Wattage Web Generated Assets</h1>
  <div class="summary">Total assets: {len(manifest["assets"])}</div>
  {"".join(html_sections)}
  {atlas_block}
</body>
</html>
"""
    preview_path = os.path.join(dist_dir, "preview.html")
    with open(preview_path, "w", encoding="utf-8") as handle:
        handle.write(page)
    print(f"Wrote visual preview: {preview_path}")


def main():
    parser = argparse.ArgumentParser(description="Build SVG/PNG assets and sync Godot game data.")
    parser.add_argument("--skip-cards", action="store_true", help="Skip generating individual plant cards")
    parser.add_argument("--skip-sync", action="store_true", help="Skip syncing Godot data and asset/ PNGs")
    parser.add_argument("--maps", nargs="+", default=["united_states", "germany"], help="Map IDs to render")
    args = parser.parse_args()

    root_dir = os.path.abspath(os.path.join(TOOLS_DIR, ".."))
    theme = load_json(os.path.join(TOOLS_DIR, "graphics", "theme.json"))
    tokens_data = load_json(os.path.join(TOOLS_DIR, "game_data", "tokens.json"))
    plants_data = load_json(os.path.join(TOOLS_DIR, "game_data", "plants.json"))

    dist_dir = os.path.join(TOOLS_DIR, "dist")
    svg_dir = os.path.join(dist_dir, "svg")
    png_dirs = {
        scale_key: os.path.join(dist_dir, "png", scale_key)
        for scale_key in theme["scales"].keys()
    }

    if not args.skip_sync:
        sync_all(root_dir)

    all_assets = {}
    all_assets.update(generate_all_tokens(theme, tokens_data, svg_dir, png_dirs))
    all_assets.update(generate_all_cards(theme, tokens_data, plants_data, svg_dir, png_dirs, include_decks=not args.skip_cards))
    all_assets.update(render_maps(root_dir, args.maps, theme, svg_dir, png_dirs))

    atlas_meta = pack_atlas(
        png_dirs["1x"],
        os.path.join(dist_dir, "atlas.png"),
        os.path.join(dist_dir, "atlas.json"),
    )

    if not args.skip_sync:
        sync_pngs_to_godot_assets(root_dir, png_dirs["1x"], all_assets)

    manifest_assets = {}
    for asset_key, asset_info in sorted(all_assets.items()):
        manifest_assets[asset_key] = {
            "category": asset_info["category"],
            "width": asset_info["width"],
            "height": asset_info["height"],
            "svg": os.path.relpath(asset_info["svg"], dist_dir).replace("\\", "/"),
            "pngs": {
                scale_key: os.path.relpath(path_val, dist_dir).replace("\\", "/")
                for scale_key, path_val in asset_info["pngs"].items()
            },
        }

    manifest = {
        "assets": manifest_assets,
        "atlas": atlas_meta,
    }
    manifest_path = os.path.join(dist_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    print(f"Wrote manifest: {manifest_path}")

    build_preview_html(dist_dir, manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
