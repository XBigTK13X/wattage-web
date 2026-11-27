import os
from graphics.svg_builder import SvgDocument, save_and_rasterize
from graphics.tokens import make_nine_patch_svg


def make_card_frame_svg(width, height, bg_color, border_color, radius, border_width):
    return make_nine_patch_svg(width, height, bg_color, border_color, radius, border_width, "#ffffff")


def draw_fuel_glyph(doc, fuel_type, center_x, center_y, tokens_data):
    res_info = tokens_data["resource_types"].get(fuel_type, {"fill": "#888888", "outline": "#ffffff"})
    fill = res_info["fill"]
    outline = res_info["outline"]
    if fuel_type == "coal":
        doc.polygon(
            [
                (center_x - 10, center_y - 6),
                (center_x, center_y - 11),
                (center_x + 10, center_y - 6),
                (center_x + 11, center_y + 4),
                (center_x + 4, center_y + 11),
                (center_x - 8, center_y + 10),
            ],
            fill=fill,
            stroke=outline,
            stroke_width=1.6,
        )
    elif fuel_type == "oil":
        doc.rect(center_x - 8, center_y - 11, 16, 22, rx=2.5, ry=2.5, fill=fill, stroke=outline, stroke_width=1.6)
        doc.rect(center_x - 7, center_y - 3, 14, 6, fill="#d8ad40", fill_opacity="0.85")
    elif fuel_type == "garbage":
        doc.polygon(
            [
                (center_x - 8, center_y - 7),
                (center_x + 8, center_y - 7),
                (center_x + 6, center_y + 11),
                (center_x - 6, center_y + 11),
            ],
            fill=fill,
            stroke=outline,
            stroke_width=1.6,
        )
        doc.rect(center_x - 10, center_y - 11, 20, 4, rx=1.5, ry=1.5, fill=outline)
    elif fuel_type == "uranium":
        doc.circle(center_x, center_y, 11, fill=fill, stroke=outline, stroke_width=1.6)
        doc.circle(center_x, center_y, 4, fill="#ffeb78")
    elif fuel_type == "ecological":
        doc.circle(center_x, center_y, 11, fill=fill, stroke=outline, stroke_width=1.6)
        doc.line(center_x, center_y - 7, center_x, center_y + 8, stroke="#ffffff", stroke_width=2.0)
        doc.polygon([(center_x, center_y - 7), (center_x + 7, center_y - 1), (center_x, center_y + 1)], fill="#ffffff")


def make_plant_card_svg(card_data, theme, tokens_data):
    dims = tokens_data["card_dimensions"]
    width = int(dims["width"])
    height = int(dims["height"])
    palette = theme["palette"]
    font_family = theme["typography"]["font_family"]

    is_step3 = bool(card_data.get("is_step_three", False))
    fuel_type = card_data.get("fuel_type", "coal")
    res_info = tokens_data["resource_types"].get(fuel_type, {"fill": "#8ca0be", "outline": "#dce3ee"})
    border_color = palette["border_brass_bright"] if is_step3 else res_info["outline"]
    bg_color = palette["card_step3_bg"] if is_step3 else palette["card_bg"]

    doc = SvgDocument(width, height)
    doc.add_linear_gradient("card_bg_grad", [("0%", bg_color, 1.0), ("100%", "#11161f", 1.0)])
    doc.rect(2, 2, width - 4, height - 4, rx=12, ry=12, fill="url(#card_bg_grad)", stroke=border_color, stroke_width=3.2)

    if is_step3:
        doc.rect(14, 16, width - 28, 42, rx=8, ry=8, fill=palette["border_brass"], fill_opacity="0.22", stroke=palette["border_brass"], stroke_width=1.8)
        doc.text(width / 2, 44, "STEP 3", fill=palette["text_accent"], font_family=font_family, font_size="22", font_weight="bold", text_anchor="middle")
        doc.circle(width / 2, 116, 32, fill="#221b10", stroke=palette["border_brass_bright"], stroke_width=2.4)
        doc.text(width / 2, 126, "III", fill=palette["text_accent"], font_family=font_family, font_size="28", font_weight="bold", text_anchor="middle")
        doc.text(width / 2, 180, "MARKET RESET", fill=palette["text_secondary"], font_family=font_family, font_size="12", font_weight="bold", text_anchor="middle")
        return doc

    number = int(card_data.get("number", 0))
    fuel_cost = int(card_data.get("fuel_cost", 0))
    cities_powered = int(card_data.get("cities_powered", 0))
    accepted_fuels = card_data.get("accepted_fuels", [])

    doc.rect(12, 12, 54, 40, rx=8, ry=8, fill=res_info["fill"], stroke=border_color, stroke_width=2.0)
    doc.text(39, 40, str(number), fill="#ffffff", font_family=font_family, font_size="24", font_weight="bold", text_anchor="middle")

    doc.rect(12, 62, width - 24, 78, rx=8, ry=8, fill="#121722", stroke="#2e384c", stroke_width=1.5)
    if bool(card_data.get("is_ecological", False)):
        draw_fuel_glyph(doc, "ecological", width / 2, 95, tokens_data)
        doc.text(width / 2, 128, "CLEAN ENERGY", fill="#aaf5c8", font_family=font_family, font_size="11", font_weight="bold", text_anchor="middle")
    else:
        count = max(1, len(accepted_fuels))
        spacing = 30
        start_x = (width / 2) - ((count - 1) * spacing) / 2.0
        for idx, sub_fuel in enumerate(accepted_fuels):
            draw_fuel_glyph(doc, sub_fuel, start_x + idx * spacing, 92, tokens_data)
        fuel_label = f"{fuel_cost}x " + "/".join(accepted_fuels).upper()
        doc.text(width / 2, 128, fuel_label, fill=palette["text_secondary"], font_family=font_family, font_size="11", font_weight="bold", text_anchor="middle")

    doc.rect(12, height - 56, width - 24, 42, rx=8, ry=8, fill="#1b2333", stroke=palette["border_brass"], stroke_width=1.8)
    doc.polygon([(36, height - 46), (26, height - 34), (33, height - 34), (30, height - 22), (42, height - 37), (35, height - 37)], fill=palette["text_accent"])
    doc.text(width / 2 + 12, height - 27, f"{cities_powered} CITIES" if cities_powered != 1 else "1 CITY", fill=palette["text_primary"], font_family=font_family, font_size="16", font_weight="bold", text_anchor="middle")
    return doc


def generate_all_cards(theme, tokens_data, plants_data, svg_dir, png_dirs, include_decks=True):
    scales = theme["scales"]
    palette = theme["palette"]
    dims = tokens_data["card_dimensions"]
    width = int(dims["width"])
    height = int(dims["height"])

    tasks = [
        ("ui/card_frame_standard", "ui", lambda: make_card_frame_svg(width, height, palette["card_bg"], palette["border_steel"], 12, 3.0)),
        ("ui/card_frame_step3", "ui", lambda: make_card_frame_svg(width, height, palette["card_step3_bg"], palette["border_brass_bright"], 12, 4.0)),
        ("ui/card_frame_ecological", "ui", lambda: make_card_frame_svg(width, height, "#142922", tokens_data["resource_types"]["ecological"]["outline"], 12, 3.0)),
        ("ui/card_frame_hybrid", "ui", lambda: make_card_frame_svg(width, height, "#26232b", "#dcdce8", 12, 3.0)),
    ]

    if include_decks:
        for deck_id, cards in plants_data.get("decks", {}).items():
            for card in cards:
                is_step3 = bool(card.get("is_step_three", False))
                card_name = "step3" if is_step3 else f"plant_{int(card['number']):02d}"
                rel_name = os.path.join("card", deck_id, card_name)
                tasks.append((
                    rel_name,
                    "card",
                    lambda cd=card: make_plant_card_svg(cd, theme, tokens_data),
                ))

    results = {}
    total = len(tasks)
    for idx, (rel_name, category, builder_fn) in enumerate(tasks, start=1):
        norm_name = rel_name.replace("\\", "/")
        print(f"Building card {idx}/{total}: {norm_name}")
        doc = builder_fn()
        meta = save_and_rasterize(doc, svg_dir, png_dirs, norm_name, scales)
        meta["category"] = category
        results[norm_name] = meta
    return results
