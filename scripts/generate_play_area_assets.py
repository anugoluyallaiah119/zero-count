#!/usr/bin/env python3
"""Generate play-area background assets and the purple '0' draw-deck card back.

Uses PIL only; outputs to app/assets/art/.
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "art")
WIDTH = 1024
HEIGHT = 1792


def save(img, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    img.save(path, "PNG")
    print("saved", path, img.size)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(width, height, top, bottom):
    img = Image.new("RGB", (width, height))
    top = hex_to_rgb(top)
    bottom = hex_to_rgb(bottom)
    pixels = img.load()
    for y in range(height):
        c = lerp(top, bottom, y / (height - 1))
        for x in range(width):
            pixels[x, y] = c
    return img


def radial_glow(width, height, center, radius, color, opacity=0.25):
    """Return a RGBA layer with a soft radial glow."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    c = hex_to_rgb(color)
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        alpha = int(255 * opacity * (1 - t) ** 2)
        draw.ellipse(
            [
                center[0] - r,
                center[1] - r,
                center[0] + r,
                center[1] + r,
            ],
            fill=c + (alpha,),
        )
    return layer


def add_noise(img, amount=8):
    """Subtle grain to avoid banding."""
    pixels = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = pixels[x, y]
            d = random.randint(-amount, amount)
            pixels[x, y] = tuple(max(0, min(255, v + d)) for v in p)


def lantern(draw, cx, cy, w, h, glow_layer):
    """Draw a simple hanging lantern with warm glow."""
    # Glow behind
    glow = radial_glow(WIDTH, HEIGHT, (cx, cy), max(w, h) * 2.2, "#F5A623", 0.18)
    glow_layer.alpha_composite(glow)
    # Lantern body
    body = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy + h / 2)]
    draw.rounded_rectangle(body, radius=w // 4, fill="#2A1D14", outline="#5C4027", width=3)
    # Light window
    win = [(cx - w * 0.32, cy - h * 0.25), (cx + w * 0.32, cy + h * 0.25)]
    draw.rounded_rectangle(win, radius=w // 8, fill="#F5A623")
    # Cap + chain hint
    draw.rectangle([cx - w * 0.15, cy - h * 0.62, cx + w * 0.15, cy - h * 0.48], fill="#1A120C")


def foliage(draw, color, count=40):
    for _ in range(count):
        x = random.randint(0, WIDTH)
        y = random.choice([random.randint(0, HEIGHT // 4), random.randint(HEIGHT * 3 // 4, HEIGHT)])
        r = random.randint(30, 90)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=hex_to_rgb(color))


def purple_night(seed=1):
    random.seed(seed)
    img = vertical_gradient(WIDTH, HEIGHT, "#0D0328", "#08051E")
    # central ambient glow
    glow = radial_glow(WIDTH, HEIGHT, (WIDTH // 2, HEIGHT // 2), HEIGHT * 0.55, "#4A1A8C", 0.18)
    img = img.convert("RGBA")
    img.alpha_composite(glow)
    draw = ImageDraw.Draw(img)
    # Stone path slabs at top/bottom
    for y in [0, HEIGHT - 120]:
        draw.rectangle([0, y, WIDTH, y + 120], fill="#14072E")
        for x in range(-40, WIDTH, 80):
            draw.rectangle([x, y + 10, x + 70, y + 110], outline="#1E0B42", width=2)
    # Lanterns in four corners
    glow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    lantern(draw, 120, 160, 70, 100, glow_layer)
    lantern(draw, WIDTH - 120, 160, 70, 100, glow_layer)
    lantern(draw, 90, HEIGHT - 180, 60, 85, glow_layer)
    lantern(draw, WIDTH - 90, HEIGHT - 180, 60, 85, glow_layer)
    img.alpha_composite(glow_layer)
    # Soft floating orbs
    for _ in range(25):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT)
        r = random.randint(2, 6)
        draw.ellipse([x - r, y - r, x + r, y + r], fill="#9B30FF")
    # foliage hints
    foliage(draw, "#1A0B3B", 30)
    add_noise(img.convert("RGB"))
    return img


def green_garden(seed=2):
    random.seed(seed)
    img = vertical_gradient(WIDTH, HEIGHT, "#0B2E1A", "#041A0F")
    glow = radial_glow(WIDTH, HEIGHT, (WIDTH // 2, HEIGHT // 2), HEIGHT * 0.5, "#1B6B3D", 0.22)
    img = img.convert("RGBA")
    img.alpha_composite(glow)
    draw = ImageDraw.Draw(img)
    # Stone path
    for y in [0, HEIGHT - 130]:
        draw.rectangle([0, y, WIDTH, y + 130], fill="#0D2316")
        for x in range(-30, WIDTH, 90):
            draw.rectangle([x, y + 15, x + 75, y + 115], outline="#143820", width=2)
    # Lanterns
    glow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    lantern(draw, 130, 170, 70, 100, glow_layer)
    lantern(draw, WIDTH - 130, 170, 70, 100, glow_layer)
    lantern(draw, 100, HEIGHT - 190, 60, 85, glow_layer)
    lantern(draw, WIDTH - 100, HEIGHT - 190, 60, 85, glow_layer)
    img.alpha_composite(glow_layer)
    # Leaves / vines along edges
    for _ in range(60):
        x = random.choice([random.randint(-40, WIDTH // 5), random.randint(WIDTH * 4 // 5, WIDTH + 40)])
        y = random.randint(0, HEIGHT)
        r = random.randint(20, 70)
        draw.ellipse([x - r, y - r, x + r, y + r], fill="#0A3D20")
    # Fireflies
    for _ in range(30):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT)
        r = random.randint(2, 5)
        draw.ellipse([x - r, y - r, x + r, y + r], fill="#2EEA6A")
    add_noise(img.convert("RGB"))
    return img


def draw_deck_back():
    w, h = 512, int(512 * 1.42)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # rounded card body
    r = w * 14 // 100
    draw.rounded_rectangle([0, 0, w, h], radius=r, fill="#2A0B5E")
    # inner purple gradient ring effect
    pad = 18
    draw.rounded_rectangle([pad, pad, w - pad, h - pad], radius=r - pad, outline="#4A1A8C", width=6)
    # concentric circles
    cx, cy = w // 2, h // 2
    for i, col in enumerate(["#6B2FBF", "#4A1A8C", "#2A0B5E"]):
        rr = w * (0.38 - i * 0.10)
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=col, width=6)
    # Big zero
    # approximate zero with two ellipses
    zero_w, zero_h = w * 0.45, h * 0.42
    draw.ellipse(
        [cx - zero_w / 2, cy - zero_h / 2, cx + zero_w / 2, cy + zero_h / 2],
        outline="#E8D5FF",
        width=w // 14,
    )
    # subtle shine
    shine = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shine)
    sdraw.ellipse([cx - w * 0.35, cy - h * 0.35, cx + w * 0.1, cy - h * 0.1], fill=(255, 255, 255, 30))
    img.alpha_composite(shine)
    return img


if __name__ == "__main__":
    save(purple_night(1), "play_area_1.png")
    save(purple_night(3), "play_area_2.png")
    save(green_garden(4), "play_area_3.png")
    save(green_garden(6), "play_area_4.png")
    save(draw_deck_back(), "draw_deck_back.png")
