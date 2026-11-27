import json
import os
import xml.sax.saxutils as saxutils
import resvg_py


def load_json(file_path):
    with open(file_path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def escape_attr(value):
    return saxutils.quoteattr(str(value))


def escape_text(value):
    return saxutils.escape(str(value))


def format_attrs(attrs):
    parts = []
    for key, val in attrs.items():
        if val is None:
            continue
        attr_name = key.replace("_", "-")
        parts.append(f"{attr_name}={escape_attr(val)}")
    return " ".join(parts)


class SvgDocument:
    def __init__(self, width, height, view_box=None):
        self.width = width
        self.height = height
        self.view_box = view_box or f"0 0 {width} {height}"
        self.defs = []
        self.elements = []

    def add_def(self, raw_xml):
        self.defs.append(raw_xml)

    def add_drop_shadow(self, filter_id="drop_shadow", dx=0, dy=2, std_dev=2.2, color="#000000", opacity=0.45):
        xml = (
            f'<filter id={escape_attr(filter_id)} x="-20%" y="-20%" width="140%" height="140%">'
            f'<feDropShadow dx="{dx}" dy="{dy}" stdDeviation="{std_dev}" '
            f'flood-color={escape_attr(color)} flood-opacity="{opacity}" />'
            f"</filter>"
        )
        self.defs.append(xml)

    def add_linear_gradient(self, grad_id, stops, x1="0%", y1="0%", x2="0%", y2="100%"):
        stop_xml = []
        for offset, color, opacity in stops:
            stop_xml.append(
                f'<stop offset={escape_attr(offset)} stop-color={escape_attr(color)} stop-opacity="{opacity}" />'
            )
        xml = (
            f'<linearGradient id={escape_attr(grad_id)} x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
            f'{"".join(stop_xml)}</linearGradient>'
        )
        self.defs.append(xml)

    def add_radial_gradient(self, grad_id, stops, cx="50%", cy="40%", radius="60%"):
        stop_xml = []
        for offset, color, opacity in stops:
            stop_xml.append(
                f'<stop offset={escape_attr(offset)} stop-color={escape_attr(color)} stop-opacity="{opacity}" />'
            )
        xml = (
            f'<radialGradient id={escape_attr(grad_id)} cx="{cx}" cy="{cy}" r="{radius}">'
            f'{"".join(stop_xml)}</radialGradient>'
        )
        self.defs.append(xml)

    def add_raw(self, raw_xml):
        self.elements.append(raw_xml)

    def rect(self, pos_x, pos_y, width, height, **attrs):
        base = {"x": pos_x, "y": pos_y, "width": width, "height": height}
        base.update(attrs)
        self.elements.append(f"<rect {format_attrs(base)} />")

    def circle(self, cx, cy, radius, **attrs):
        base = {"cx": cx, "cy": cy, "r": radius}
        base.update(attrs)
        self.elements.append(f"<circle {format_attrs(base)} />")

    def ellipse(self, cx, cy, rx, ry, **attrs):
        base = {"cx": cx, "cy": cy, "rx": rx, "ry": ry}
        base.update(attrs)
        self.elements.append(f"<ellipse {format_attrs(base)} />")

    def line(self, x1, y1, x2, y2, **attrs):
        base = {"x1": x1, "y1": y1, "x2": x2, "y2": y2}
        base.update(attrs)
        self.elements.append(f"<line {format_attrs(base)} />")

    def polygon(self, points, **attrs):
        point_str = " ".join(f"{pt[0]},{pt[1]}" for pt in points)
        base = {"points": point_str}
        base.update(attrs)
        self.elements.append(f"<polygon {format_attrs(base)} />")

    def polyline(self, points, **attrs):
        point_str = " ".join(f"{pt[0]},{pt[1]}" for pt in points)
        base = {"points": point_str}
        base.update(attrs)
        self.elements.append(f"<polyline {format_attrs(base)} />")

    def path(self, d_str, **attrs):
        base = {"d": d_str}
        base.update(attrs)
        self.elements.append(f"<path {format_attrs(base)} />")

    def text(self, pos_x, pos_y, content, **attrs):
        attr_str = format_attrs({"x": pos_x, "y": pos_y, **attrs})
        self.elements.append(f"<text {attr_str}>{escape_text(content)}</text>")

    def to_svg(self):
        defs_block = f"<defs>{''.join(self.defs)}</defs>" if self.defs else ""
        body = "".join(self.elements)
        return (
            f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{self.width}" height="{self.height}" viewBox="{self.view_box}">\n'
            f"{defs_block}\n{body}\n</svg>\n"
        )


def save_and_rasterize(svg_doc, svg_dir, png_dirs, relative_name, scales):
    svg_string = svg_doc.to_svg()
    svg_path = os.path.join(svg_dir, relative_name + ".svg")
    os.makedirs(os.path.dirname(svg_path), exist_ok=True)
    with open(svg_path, "w", encoding="utf-8") as handle:
        handle.write(svg_string)

    outputs = {}
    for scale_label, scale_factor in scales.items():
        png_bytes = resvg_py.svg_to_bytes(svg_string=svg_string, zoom=float(scale_factor))
        png_path = os.path.join(png_dirs[scale_label], relative_name + ".png")
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        with open(png_path, "wb") as handle:
            handle.write(png_bytes)
        outputs[scale_label] = png_path

    return {
        "svg": svg_path,
        "pngs": outputs,
        "width": int(svg_doc.width),
        "height": int(svg_doc.height),
    }
