import os
from graphics.svg_builder import SvgDocument, save_and_rasterize

RESOURCE_PATHS = {
    "coal_body": "M12,15 L25,8 L38,14 L40,28 L32,39 L15,40 L8,29 Z",
    "coal_facet": "M12,15 L25,8 L29,21 L18,26 Z",
    "garbage_body": "M13,15 L35,15 L32,40 L16,40 Z",
    "bolt": "M28,6 L14,26 L23,26 L19,42 L34,21 L25,21 Z",
    "house_roof": "M24,6 L6,22 L11,22 L11,41 L37,41 L37,22 L42,22 Z",
}


def make_nine_patch_svg(width, height, fill, border, radius, border_width, highlight=None):
    doc = SvgDocument(width, height)
    doc.add_linear_gradient("panel_grad", [("0%", fill, 1.0), ("100%", "#11161f", 1.0)])
    inset = border_width / 2.0
    doc.rect(
        inset,
        inset,
        width - border_width,
        height - border_width,
        rx=radius,
        ry=radius,
        fill="url(#panel_grad)" if fill != "none" else "none",
        stroke=border,
        stroke_width=border_width,
    )
    if highlight and fill != "none":
        doc.rect(
            inset + border_width,
            inset + border_width,
            width - border_width * 2 - 2,
            max(4, height * 0.25),
            rx=max(2, radius - 2),
            ry=max(2, radius - 2),
            fill=highlight,
            fill_opacity="0.08",
        )
    return doc


def make_house_svg(fill, highlight, outline):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("house_shadow", dx=0, dy=2, std_dev=1.6, opacity=0.45)
    doc.add_linear_gradient("house_grad", [("0%", highlight, 1.0), ("100%", fill, 1.0)])
    doc.add_raw('<g filter="url(#house_shadow)">')
    doc.polygon(
        [(24, 6), (6, 22), (11, 22), (11, 41), (37, 41), (37, 22), (42, 22)],
        fill="url(#house_grad)",
        stroke=outline,
        stroke_width=2.4,
        stroke_linejoin="round",
    )
    doc.polygon([(24, 8), (9, 21), (24, 21)], fill="#ffffff", fill_opacity="0.16")
    doc.rect(19, 29, 10, 12, rx=1.5, ry=1.5, fill=outline, fill_opacity="0.35")
    doc.add_raw("</g>")
    return doc


def make_coal_svg(res_info):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("res_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_linear_gradient("coal_grad", [("0%", res_info["highlight"], 1.0), ("100%", res_info["fill"], 1.0)])
    doc.add_raw('<g filter="url(#res_shadow)">')
    doc.path(
        RESOURCE_PATHS["coal_body"],
        fill="url(#coal_grad)",
        stroke=res_info["outline"],
        stroke_width=2.2,
        stroke_linejoin="round",
    )
    doc.path(RESOURCE_PATHS["coal_facet"], fill="#ffffff", fill_opacity="0.18")
    doc.line(25, 8, 29, 21, stroke=res_info["outline"], stroke_width=1.4, stroke_opacity="0.7")
    doc.line(29, 21, 32, 39, stroke=res_info["outline"], stroke_width=1.4, stroke_opacity="0.5")
    doc.add_raw("</g>")
    return doc


def make_oil_svg(res_info):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("res_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_linear_gradient("oil_grad", [("0%", res_info["highlight"], 1.0), ("55%", res_info["fill"], 1.0), ("100%", "#12151c", 1.0)], x1="0%", y1="0%", x2="100%", y2="0%")
    doc.add_raw('<g filter="url(#res_shadow)">')
    doc.rect(12, 8, 24, 32, rx=4, ry=4, fill="url(#oil_grad)", stroke=res_info["outline"], stroke_width=2.2)
    doc.rect(13, 19, 22, 10, fill="#d8ad40", fill_opacity="0.85")
    doc.line(11, 16, 37, 16, stroke=res_info["outline"], stroke_width=2.2, stroke_linecap="round")
    doc.line(11, 32, 37, 32, stroke=res_info["outline"], stroke_width=2.2, stroke_linecap="round")
    doc.rect(15, 10, 4, 28, rx=2, ry=2, fill="#ffffff", fill_opacity="0.14")
    doc.add_raw("</g>")
    return doc


def make_garbage_svg(res_info):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("res_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_linear_gradient("garb_grad", [("0%", res_info["highlight"], 1.0), ("100%", res_info["fill"], 1.0)])
    doc.add_raw('<g filter="url(#res_shadow)">')
    doc.path(
        RESOURCE_PATHS["garbage_body"],
        fill="url(#garb_grad)",
        stroke=res_info["outline"],
        stroke_width=2.2,
        stroke_linejoin="round",
    )
    doc.rect(10, 10, 28, 5, rx=2, ry=2, fill=res_info["highlight"], stroke=res_info["outline"], stroke_width=1.8)
    doc.rect(19, 6, 10, 4, rx=1.5, ry=1.5, fill="none", stroke=res_info["outline"], stroke_width=2.0)
    doc.line(19, 19, 20, 36, stroke=res_info["outline"], stroke_width=1.6, stroke_linecap="round", stroke_opacity="0.75")
    doc.line(24, 19, 24, 36, stroke=res_info["outline"], stroke_width=1.6, stroke_linecap="round", stroke_opacity="0.75")
    doc.line(29, 19, 28, 36, stroke=res_info["outline"], stroke_width=1.6, stroke_linecap="round", stroke_opacity="0.75")
    doc.add_raw("</g>")
    return doc


def make_uranium_svg(res_info):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("res_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_radial_gradient("ura_grad", [("0%", res_info["highlight"], 1.0), ("70%", res_info["fill"], 1.0), ("100%", "#7a161d", 1.0)])
    doc.add_raw('<g filter="url(#res_shadow)">')
    doc.circle(24, 24, 17, fill="url(#ura_grad)", stroke=res_info["outline"], stroke_width=2.2)
    doc.circle(24, 24, 5, fill="#ffeb78", stroke="#7a161d", stroke_width=1.2)
    for angle_deg in [0, 120, 240]:
        doc.add_raw(
            f'<path d="M24,24 L18,12 A13,13 0 0,1 30,12 Z" fill="#ffeb78" fill-opacity="0.88" '
            f'transform="rotate({angle_deg} 24 24)" />'
        )
    doc.circle(24, 24, 4.5, fill="#ffeb78", stroke="#9e2028", stroke_width=1.5)
    doc.add_raw("</g>")
    return doc


def make_ecological_svg(res_info):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("res_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_radial_gradient("eco_grad", [("0%", res_info["highlight"], 1.0), ("100%", res_info["fill"], 1.0)])
    doc.add_raw('<g filter="url(#res_shadow)">')
    doc.circle(24, 24, 17, fill="url(#eco_grad)", stroke=res_info["outline"], stroke_width=2.2)
    doc.line(24, 20, 24, 37, stroke="#ffffff", stroke_width=2.6, stroke_linecap="round")
    for angle_deg in [0, 120, 240]:
        doc.add_raw(
            f'<path d="M24,20 C22,13 24,9 26,10 C28,12 26,17 24,20 Z" fill="#ffffff" '
            f'transform="rotate({angle_deg} 24 20)" />'
        )
    doc.circle(24, 20, 2.5, fill="#ffffff")
    doc.add_raw("</g>")
    return doc


def make_hybrid_badge_svg(tokens_data):
    doc = SvgDocument(48, 48)
    oil_fill = tokens_data["resource_types"]["oil"]["fill"]
    coal_fill = tokens_data["resource_types"]["coal"]["fill"]
    doc.add_drop_shadow("hyb_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_raw('<g filter="url(#hyb_shadow)">')
    doc.path("M24,7 A17,17 0 0,0 24,41 Z", fill=oil_fill, stroke="#dce3ee", stroke_width=2.0)
    doc.path("M24,7 A17,17 0 0,1 24,41 Z", fill=coal_fill, stroke="#dce3ee", stroke_width=2.0)
    doc.line(24, 7, 24, 41, stroke="#dce3ee", stroke_width=2.0)
    doc.add_raw("</g>")
    return doc


def make_power_bolt_svg(theme):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("bolt_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_linear_gradient("bolt_grad", [("0%", "#ffe57f", 1.0), ("100%", theme["palette"]["text_accent"], 1.0)])
    doc.add_raw('<g filter="url(#bolt_shadow)">')
    doc.path(
        RESOURCE_PATHS["bolt"],
        fill="url(#bolt_grad)",
        stroke=theme["palette"]["border_brass_dark"],
        stroke_width=2.2,
        stroke_linejoin="round",
    )
    doc.add_raw("</g>")
    return doc


def make_elektro_badge_svg(theme):
    doc = SvgDocument(48, 48)
    doc.add_drop_shadow("coin_shadow", dx=0, dy=2, std_dev=1.5, opacity=0.45)
    doc.add_radial_gradient("coin_grad", [("0%", "#ffe57f", 1.0), ("70%", "#ebbc30", 1.0), ("100%", "#9e7316", 1.0)])
    doc.add_raw('<g filter="url(#coin_shadow)">')
    doc.circle(24, 24, 18, fill="url(#coin_grad)", stroke="#785810", stroke_width=2.5)
    doc.circle(24, 24, 14, fill="none", stroke="#fff2b2", stroke_width=1.2, stroke_opacity="0.65")
    doc.polygon([(27, 11), (17, 25), (24, 25), (20, 37), (31, 22), (24, 22)], fill=theme["palette"]["text_dark"])
    doc.add_raw("</g>")
    return doc


def make_city_node_svg(theme):
    doc = SvgDocument(96, 64)
    doc.add_linear_gradient("city_grad", [("0%", "#2a3344", 1.0), ("100%", "#1b212d", 1.0)])
    doc.rect(2, 2, 92, 60, rx=12, ry=12, fill="url(#city_grad)", stroke=theme["palette"]["border_steel"], stroke_width=2.4)
    for center_x in [22, 48, 74]:
        doc.circle(center_x, 32, 10, fill="#141822", stroke=theme["palette"]["border_brass"], stroke_width=2.0)
    return doc


def make_connection_badge_svg(theme):
    doc = SvgDocument(40, 40)
    doc.circle(20, 20, 16, fill=theme["palette"]["bg_panel"], stroke=theme["palette"]["border_brass"], stroke_width=2.4)
    return doc


def make_turn_order_marker_svg(theme):
    doc = SvgDocument(48, 48)
    doc.add_linear_gradient("turn_grad", [("0%", "#ffffff", 1.0), ("100%", "#d8e0ec", 1.0)])
    doc.rect(4, 4, 40, 40, rx=10, ry=10, fill="url(#turn_grad)", stroke=theme["palette"]["bg_panel"], stroke_width=3.0)
    return doc


def make_dpad_svg(direction, theme):
    doc = SvgDocument(48, 48)
    doc.rect(2, 2, 44, 44, rx=8, ry=8, fill=theme["palette"]["bg_button_normal"], stroke=theme["palette"]["border_brass"], stroke_width=2.2)
    points_map = {
        "up": [(24, 11), (11, 33), (37, 33)],
        "down": [(24, 37), (11, 15), (37, 15)],
        "left": [(11, 24), (33, 11), (33, 37)],
        "right": [(37, 24), (15, 11), (15, 37)],
    }
    doc.polygon(points_map[direction], fill=theme["palette"]["text_primary"])
    return doc


def make_action_badge_svg(fill, symbol, theme):
    doc = SvgDocument(64, 48)
    doc.rect(2, 2, 60, 44, rx=10, ry=10, fill=fill, stroke=theme["palette"]["text_primary"], stroke_width=2.2, stroke_opacity="0.9")
    if symbol == "check":
        doc.polyline([(18, 24), (27, 34), (46, 15)], fill="none", stroke="#ffffff", stroke_width=4.2, stroke_linecap="round", stroke_linejoin="round")
    elif symbol == "cross":
        doc.line(20, 14, 44, 34, stroke="#ffffff", stroke_width=4.2, stroke_linecap="round")
        doc.line(44, 14, 20, 34, stroke="#ffffff", stroke_width=4.2, stroke_linecap="round")
    elif symbol == "plus1":
        doc.text(32, 31, "+1", fill="#ffffff", font_family=theme["typography"]["font_family"], font_size="22", font_weight="bold", text_anchor="middle")
    elif symbol == "plus5":
        doc.text(32, 31, "+5", fill="#ffffff", font_family=theme["typography"]["font_family"], font_size="22", font_weight="bold", text_anchor="middle")
    return doc


def generate_all_tokens(theme, tokens_data, svg_dir, png_dirs):
    scales = theme["scales"]
    palette = theme["palette"]
    radii = theme["radii"]
    tasks = [
        ("ui/panel_frame", "ui", lambda: make_nine_patch_svg(96, 96, palette["bg_panel"], palette["border_brass"], radii["medium"], 3.0, "#ffffff")),
        ("ui/button_normal", "ui", lambda: make_nine_patch_svg(64, 48, palette["bg_button_normal"], palette["border_brass"], radii["small"] + 2, 2.2, "#ffffff")),
        ("ui/button_hover", "ui", lambda: make_nine_patch_svg(64, 48, palette["bg_button_hover"], palette["border_brass_bright"], radii["small"] + 2, 2.2, "#ffffff")),
        ("ui/button_pressed", "ui", lambda: make_nine_patch_svg(64, 48, palette["bg_button_pressed"], palette["border_brass_dark"], radii["small"] + 2, 2.2)),
        ("ui/button_disabled", "ui", lambda: make_nine_patch_svg(64, 48, palette["bg_button_disabled"], palette["border_muted"], radii["small"] + 2, 2.2)),
        ("ui/focus_ring", "ui", lambda: make_nine_patch_svg(64, 64, "none", palette["border_brass_bright"], radii["medium"], 4.0)),
        ("ui/elektro_badge", "ui", lambda: make_elektro_badge_svg(theme)),
        ("token/house_token", "token", lambda: make_house_svg("#f2f4f8", "#ffffff", "#3c424e")),
        ("token/city_node", "token", lambda: make_city_node_svg(theme)),
        ("token/connection_badge", "token", lambda: make_connection_badge_svg(theme)),
        ("token/turn_order_marker", "token", lambda: make_turn_order_marker_svg(theme)),
        ("icon/resource_coal", "icon", lambda: make_coal_svg(tokens_data["resource_types"]["coal"])),
        ("icon/resource_oil", "icon", lambda: make_oil_svg(tokens_data["resource_types"]["oil"])),
        ("icon/resource_garbage", "icon", lambda: make_garbage_svg(tokens_data["resource_types"]["garbage"])),
        ("icon/resource_uranium", "icon", lambda: make_uranium_svg(tokens_data["resource_types"]["uranium"])),
        ("icon/plant_ecological", "icon", lambda: make_ecological_svg(tokens_data["resource_types"]["ecological"])),
        ("icon/plant_hybrid_badge", "icon", lambda: make_hybrid_badge_svg(tokens_data)),
        ("icon/power_bolt", "icon", lambda: make_power_bolt_svg(theme)),
        ("icon/action_confirm", "icon", lambda: make_action_badge_svg("#2c8c4a", "check", theme)),
        ("icon/action_pass", "icon", lambda: make_action_badge_svg("#a83434", "cross", theme)),
        ("icon/action_bid_plus1", "icon", lambda: make_action_badge_svg("#3468b2", "plus1", theme)),
        ("icon/action_bid_plus5", "icon", lambda: make_action_badge_svg("#8c52b4", "plus5", theme)),
    ]

    for color_key, color_info in tokens_data["player_colors"].items():
        tasks.append((
            os.path.join("token", f"house_{color_key}"),
            "token",
            lambda ci=color_info: make_house_svg(ci["fill"], ci["highlight"], ci["outline"]),
        ))

    for direction in ["up", "down", "left", "right"]:
        tasks.append((
            os.path.join("icon", f"dpad_{direction}"),
            "icon",
            lambda dr=direction: make_dpad_svg(dr, theme),
        ))

    results = {}
    total = len(tasks)
    for idx, (rel_name, category, builder_fn) in enumerate(tasks, start=1):
        norm_name = rel_name.replace("\\", "/")
        print(f"Building token {idx}/{total}: {norm_name}")
        doc = builder_fn()
        meta = save_and_rasterize(doc, svg_dir, png_dirs, norm_name, scales)
        meta["category"] = category
        results[norm_name] = meta
    return results
