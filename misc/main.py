#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
from pathlib import Path


# Margin controls. These can also be overridden from the command line.
QST_MARGIN_TOP = 32
QST_MARGIN_RIGHT = 32
QST_MARGIN_BOTTOM = 28
QST_MARGIN_LEFT = 32
TITLE_GAP = 20
TEXT_GAP = 24

TITLE_FONT_SIZE = 18  
QST_FONT_SIZE = 18
TEXT_FONT_SIZE = 18

TITLE_LINE_HEIGHT = 21
QST_LINE_HEIGHT = 21
TEXT_LINE_HEIGHT = 22

TITLE_COLOR = "#A0A0A0"
QST_COLOR_TOP = "#6464ff"
QST_COLOR_BOTTOM = "#c864ff"
TEXT_COLOR = "#A0A0A0"
BACKGROUND_COLOR = "#000000"

FONT_FAMILY = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace"


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def estimate_text_width(lines: list[str], font_size: int) -> float:
    if not lines:
        return 0
    widest = max(len(line) for line in lines)
    return widest * font_size * 0.62


def render_text_block(
    lines: list[str],
    x: float,
    y: float,
    font_size: int,
    line_height: int,
    fill: str,
    gradient_id: str | None = None,
) -> str:
    attrs = [
        f'x="{x}"',
        f'y="{y}"',
        f'font-family="{FONT_FAMILY}"',
        f'font-size="{font_size}"',
        f'line-height="{line_height}"',
        'xml:space="preserve"',
    ]
    if gradient_id:
        attrs.append(f'fill="url(#{gradient_id})"')
    else:
        attrs.append(f'fill="{fill}"')

    tspans = []
    for index, line in enumerate(lines):
        dy = 0 if index == 0 else line_height
        tspans.append(
            f'<tspan x="{x}" dy="{dy}">{html.escape(line)}</tspan>'
        )

    return f'<text {" ".join(attrs)}>{"".join(tspans)}</text>'


def build_svg(
    title_lines: list[str],
    qst_lines: list[str],
    caption_lines: list[str],
    margin_top: int,
    margin_right: int,
    margin_bottom: int,
    margin_left: int,
    title_gap: int,
    text_gap: int,
    background_color: str | None,
    title_gradient_top: str,
    title_gradient_bottom: str,
    use_title_gradient: bool,
    show_title: bool,
) -> str:
    if not show_title:
        title_lines = []

    title_width = estimate_text_width(title_lines, TITLE_FONT_SIZE)
    qst_width = estimate_text_width(qst_lines, QST_FONT_SIZE)
    caption_width = estimate_text_width(caption_lines, TEXT_FONT_SIZE)
    content_width = max(title_width, qst_width, caption_width)

    title_height = max(len(title_lines), 1) * TITLE_LINE_HEIGHT if title_lines else 0
    qst_height = max(len(qst_lines), 1) * QST_LINE_HEIGHT
    caption_height = max(len(caption_lines), 1) * TEXT_LINE_HEIGHT

    title_block = title_height + (title_gap if title_lines else 0)
    width = int(margin_left + content_width + margin_right)
    height = int(margin_top + title_block + qst_height + text_gap + caption_height + margin_bottom)

    title_y = margin_top + TITLE_FONT_SIZE if title_lines else 0
    qst_y = margin_top + title_block + QST_FONT_SIZE
    caption_y = margin_top + title_block + qst_height + text_gap + TEXT_FONT_SIZE

    gradient_parts = [
        "<defs>",
        f'  <linearGradient id="qstGradient" x1="0%" y1="0%" x2="0%" y2="100%">',
        f'    <stop offset="0%" stop-color="{QST_COLOR_TOP}" />',
        f'    <stop offset="100%" stop-color="{QST_COLOR_BOTTOM}" />',
        "  </linearGradient>",
    ]

    if use_title_gradient:
        gradient_parts.extend(
            [
                f'  <linearGradient id="titleGradient" x1="0%" y1="0%" x2="0%" y2="100%">',
                f'    <stop offset="0%" stop-color="{title_gradient_top}" />',
                f'    <stop offset="100%" stop-color="{title_gradient_bottom}" />',
                "  </linearGradient>",
            ]
        )

    gradient_parts.append("</defs>")
    gradient = "\n  ".join(gradient_parts)

    title_block_svg = ""
    if title_lines:
        title_block_svg = render_text_block(
            title_lines,
            margin_left,
            title_y,
            TITLE_FONT_SIZE,
            TITLE_LINE_HEIGHT,
            TITLE_COLOR,
            gradient_id="titleGradient" if use_title_gradient else None,
        )

    qst_block = render_text_block(
        qst_lines or [""],
        margin_left,
        qst_y,
        QST_FONT_SIZE,
        QST_LINE_HEIGHT,
        "#000000",
        gradient_id="qstGradient",
    )
    caption_block = render_text_block(
        caption_lines or [""],
        margin_left,
        caption_y,
        TEXT_FONT_SIZE,
        TEXT_LINE_HEIGHT,
        TEXT_COLOR,
    )

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  {gradient}
  <rect width="100%" height="100%" fill="{background_color or 'none'}" />
  {title_block_svg}
  {qst_block}
  {caption_block}
</svg>
'''


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render title.txt, qst.txt, and text.txt as an SVG.")
    parser.add_argument("--title", type=Path, default=Path("title.txt"), help="Path to the optional title ASCII art input")
    parser.add_argument("--qst", type=Path, default=Path("qst.txt"), help="Path to the ASCII art input")
    parser.add_argument("--text", type=Path, default=Path("text.txt"), help="Path to the caption text input")
    parser.add_argument("--output", type=Path, default=Path("output.svg"), help="Path to write the SVG output")
    parser.add_argument("--margin-top", type=int, default=QST_MARGIN_TOP)
    parser.add_argument("--margin-right", type=int, default=QST_MARGIN_RIGHT)
    parser.add_argument("--margin-bottom", type=int, default=QST_MARGIN_BOTTOM)
    parser.add_argument("--margin-left", type=int, default=QST_MARGIN_LEFT)
    parser.add_argument("--title-gap", type=int, default=TITLE_GAP, help="Vertical gap between the title and qst")
    parser.add_argument("--gap", type=int, default=TEXT_GAP, help="Vertical gap between qst and text")
    parser.add_argument(
        "--background",
        type=str,
        default=BACKGROUND_COLOR,
        help="Background color for the SVG (use --transparent for no background)",
    )
    parser.add_argument(
        "--transparent",
        action="store_true",
        help="Make the SVG background transparent",
    )
    parser.add_argument(
        "--title-gradient",
        action="store_true",
        help="Fill title.txt with a top-to-bottom gradient instead of a solid color",
    )
    parser.add_argument(
        "--no-title",
        action="store_true",
        help="Hide the title ASCII art block",
    )
    parser.add_argument(
        "--title-gradient-top",
        type=str,
        default="#6464ff",
        help="Top color for the title gradient",
    )
    parser.add_argument(
        "--title-gradient-bottom",
        type=str,
        default="#c864ff",
        help="Bottom color for the title gradient",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    title_lines = read_lines(args.title) if args.title.exists() else []
    qst_lines = read_lines(args.qst)
    caption_lines = read_lines(args.text)

    svg = build_svg(
        title_lines=title_lines,
        qst_lines=qst_lines,
        caption_lines=caption_lines,
        margin_top=args.margin_top,
        margin_right=args.margin_right,
        margin_bottom=args.margin_bottom,
        margin_left=args.margin_left,
        title_gap=args.title_gap,
        text_gap=args.gap,
        background_color=None if args.transparent else args.background,
        title_gradient_top=args.title_gradient_top,
        title_gradient_bottom=args.title_gradient_bottom,
        use_title_gradient=args.title_gradient,
        show_title=not args.no_title,
    )

    args.output.write_text(svg, encoding="utf-8")


if __name__ == "__main__":
    main()