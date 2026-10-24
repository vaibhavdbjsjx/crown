"""Compose App Store screenshots (1320x2868) from raw simulator captures."""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

raw, out = sys.argv[1], sys.argv[2]
W, H = 1320, 2868
INK, IVORY, CHAMP, BRONZE = (9, 9, 11), (244, 239, 230), (234, 215, 168), (180, 133, 74)
items = [
    ("today", "Your hairline,\nmeasured.", "A clear score, stage and trend from every check-in"),
    ("onboarding", "Guided scans.\nReal numbers.", "On-device analysis of hairline, temples and crown"),
    ("progress", "See real change\nover time.", "Trends, journal markers, compare and timelapse"),
    ("routine", "Stay consistent.\nSee it pay off.", "Routine streaks and a daily shed counter"),
    ("profile", "Private by\ndesign.", "Photos stay on your iPhone. Lock with Face ID"),
    ("paywall", "Unlock the\nfull picture.", "Doctor-ready PDF reports and full history"),
]
serif = ImageFont.truetype("/System/Library/Fonts/NewYork.ttf", 132)
sans = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 44)
eyebrow = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 34)

def glow(img, box, color, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(220))
    img.alpha_composite(layer)

for i, (name, title, sub) in enumerate(items):
    img = Image.new("RGBA", (W, H), INK + (255,))
    glow(img, (500, -300, 1700, 900), CHAMP, 70)
    glow(img, (-500, 1900, 700, 3100), BRONZE, 60)
    d = ImageDraw.Draw(img)
    d.text((110, 170), "C R O W N", font=eyebrow, fill=CHAMP)
    d.multiline_text((104, 250), title, font=serif, fill=IVORY, spacing=4)
    d.text((110, 580), sub, font=sans, fill=IVORY + (160,))
    shot = Image.open(f"{raw}/{name}.png").convert("RGBA")
    sw = 1000
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), radius=110, fill=255)
    x, y = (W - sw) // 2, 760
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 30, x + sw, y + sh), radius=110, fill=(0, 0, 0, 200))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(50)))
    img.paste(shot, (x, y), mask)
    ImageDraw.Draw(img).rounded_rectangle((x, y, x + sw, y + sh), radius=110, outline=CHAMP + (110,), width=4)
    img.convert("RGB").save(f"{out}/0{i + 1}-{name}.png")
print("ok")
