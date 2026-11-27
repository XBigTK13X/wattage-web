import argparse
import math
import os
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from graphics.svg_builder import SvgDocument, load_json, save_and_rasterize


def cross_product(origin, point_a, point_b):
    return (point_a[0] - origin[0]) * (point_b[1] - origin[1]) - (point_a[1] - origin[1]) * (point_b[0] - origin[0])


def convex_hull(points):
    unique = sorted(set((round(pt[0], 2), round(pt[1], 2)) for pt in points))
    if len(unique) <= 2:
        return unique
    lower = []
    for pt in unique:
        while len(lower) >= 2 and cross_product(lower[-2], lower[-1], pt) <= 0:
            lower.pop()
        lower.append(pt)
    upper = []
    for pt in reversed(unique):
        while len(upper) >= 2 and cross_product(upper[-2], upper[-1], pt) <= 0:
            upper.pop()
        upper.append(pt)
    return lower[:-1] + upper[:-1]


def expand_polygon(points, padding):
    if not points:
        return []
    cx = sum(pt[0] for pt in points) / len(points)
    cy = sum(pt[1] for pt in points) / len(points)
    if len(points) == 1:
        px, py = points[0]
        return [
            (round(px + padding * math.cos(2 * math.pi * idx / 8), 1), round(py + padding * math.sin(2 * math.pi * idx / 8), 1))
            for idx in range(8)
        ]
    expanded = []
    for px, py in points:
        dx = px - cx
        dy = py - cy
        dist = math.hypot(dx, dy)
        if dist < 1e-3:
            expanded.append((round(px, 1), round(py, 1)))
        else:
            scale = (dist + padding) / dist
            expanded.append((round(cx + dx * scale, 1), round(cy + dy * scale, 1)))
    return expanded


def render_map_base_svg(map_data, theme):
    render_size = map_data.get("render_size", [1200, 820])
    width = int(render_size[0])
    height = int(render_size[1])
    palette = theme["palette"]
    font_family = theme["typography"]["font_family"]

    doc = SvgDocument(width, height)
    doc.add_linear_gradient("ocean_grad", [("0%", palette["map_ocean"], 1.0), ("100%", "#090d14", 1.0)])
    doc.rect(0, 0, width, height, fill="url(#ocean_grad)")

    grid_step = 80
    for gx in range(grid_step, width, grid_step):
        doc.line(gx, 0, gx, height, stroke=palette["map_grid"], stroke_width=1.0, stroke_opacity="0.65")
    for gy in range(grid_step, height, grid_step):
        doc.line(0, gy, width, gy, stroke=palette["map_grid"], stroke_width=1.0, stroke_opacity="0.65")

    cities_by_region = {}
    for city in map_data.get("cities", []):
        region_id = city.get("region_id", "")
        norm_pos = city.get("position", [0.0, 0.0])
        px = float(norm_pos[0]) * width
        py = float(norm_pos[1]) * height
        cities_by_region.setdefault(region_id, []).append((px, py))

    regions = map_data.get("regions", {})
    for region_id in sorted(regions.keys()):
        region_info = regions[region_id]
        region_color = region_info.get("color", "#4a6fa5")
        pts = cities_by_region.get(region_id, [])
        if not pts:
            continue
        hull = expand_polygon(convex_hull(pts), 52.0)
        if len(hull) >= 3:
            doc.polygon(
                hull,
                fill=region_color,
                fill_opacity="0.18",
                stroke=region_color,
                stroke_width=2.6,
                stroke_opacity="0.72",
                stroke_linejoin="round",
            )
        cx = sum(pt[0] for pt in pts) / len(pts)
        cy = sum(pt[1] for pt in pts) / len(pts)
        doc.text(
            round(cx, 1),
            round(cy, 1),
            region_info.get("name", region_id).upper(),
            fill=region_color,
            fill_opacity="0.45",
            font_family=font_family,
            font_size="22",
            font_weight="bold",
            text_anchor="middle",
        )

    doc.rect(6, 6, width - 12, height - 12, rx=10, ry=10, fill="none", stroke=palette["border_brass"], stroke_width=2.0, stroke_opacity="0.45")
    return doc


def render_map_overlay_svg(map_data, theme):
    render_size = map_data.get("render_size", [1200, 820])
    width = int(render_size[0])
    height = int(render_size[1])
    palette = theme["palette"]
    font_family = theme["typography"]["font_family"]

    doc = SvgDocument(width, height)
    city_lookup = {}
    for city in map_data.get("cities", []):
        norm_pos = city.get("position", [0.0, 0.0])
        city_lookup[city["id"]] = {
            "x": float(norm_pos[0]) * width,
            "y": float(norm_pos[1]) * height,
            "name": city.get("name", city["id"]),
            "region_id": city.get("region_id", ""),
        }

    for edge in map_data.get("connections", []):
        src = city_lookup.get(edge.get("from", ""))
        dst = city_lookup.get(edge.get("to", ""))
        if src is None or dst is None:
            continue
        doc.line(round(src["x"], 1), round(src["y"], 1), round(dst["x"], 1), round(dst["y"], 1), stroke=palette["map_edge_casing"], stroke_width=6.0, stroke_linecap="round")
        doc.line(round(src["x"], 1), round(src["y"], 1), round(dst["x"], 1), round(dst["y"], 1), stroke=palette["map_edge_line"], stroke_width=2.6, stroke_linecap="round")
        mid_x = round((src["x"] + dst["x"]) * 0.5, 1)
        mid_y = round((src["y"] + dst["y"]) * 0.5, 1)
        doc.circle(mid_x, mid_y, 13, fill=palette["bg_panel"], stroke=palette["border_brass"], stroke_width=1.8)
        doc.text(mid_x, mid_y + 4, str(edge.get("cost", 0)), fill=palette["text_accent"], font_family=font_family, font_size="12", font_weight="bold", text_anchor="middle")

    regions = map_data.get("regions", {})
    for city_id, city_info in city_lookup.items():
        region_color = regions.get(city_info["region_id"], {}).get("color", palette["border_steel"])
        cx = round(city_info["x"], 1)
        cy = round(city_info["y"], 1)
        doc.rect(cx - 48, cy - 16, 96, 32, rx=8, ry=8, fill=palette["bg_panel"], stroke=region_color, stroke_width=2.2)
        doc.text(cx, cy + 4, city_info["name"], fill=palette["text_primary"], font_family=font_family, font_size="11", font_weight="bold", text_anchor="middle")
    return doc


def render_maps(root_dir, map_ids, theme, svg_dir, png_dirs):
    scales = {"1x": theme["scales"]["1x"]}
    results = {}
    total = len(map_ids) * 2
    step = 0
    for map_id in map_ids:
        map_path = os.path.join(root_dir, "tools", "game_data", "maps", map_id + ".json")
        if not os.path.isfile(map_path):
            print(f"Skipping missing map: {map_id}")
            continue
        map_data = load_json(map_path)

        step += 1
        base_name = f"map/map_{map_id}_base"
        print(f"Rendering map {step}/{total}: {base_name}")
        base_doc = render_map_base_svg(map_data, theme)
        base_meta = save_and_rasterize(base_doc, svg_dir, png_dirs, base_name, scales)
        base_meta["category"] = "map"
        results[base_name] = base_meta

        step += 1
        overlay_name = f"map/map_{map_id}_overlay"
        print(f"Rendering map {step}/{total}: {overlay_name}")
        overlay_doc = render_map_overlay_svg(map_data, theme)
        overlay_meta = save_and_rasterize(overlay_doc, svg_dir, png_dirs, overlay_name, scales)
        overlay_meta["category"] = "map"
        results[overlay_name] = overlay_meta

    return results


def main():
    parser = argparse.ArgumentParser(description="Render base and overlay map graphics.")
    parser.add_argument("--maps", nargs="+", default=["united_states", "germany"])
    args = parser.parse_args()

    root_dir = os.path.abspath(os.path.join(TOOLS_DIR, ".."))
    theme = load_json(os.path.join(TOOLS_DIR, "graphics", "theme.json"))
    svg_dir = os.path.join(TOOLS_DIR, "dist", "svg")
    png_dirs = {"1x": os.path.join(TOOLS_DIR, "dist", "png", "1x")}
    render_maps(root_dir, args.maps, theme, svg_dir, png_dirs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
