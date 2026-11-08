from PIL import Image, ImageDraw, ImageFont
import math
import os

os.makedirs('assets/images', exist_ok=True)

W = H = 1024
img = Image.new('RGBA', (W, H), (255, 255, 255, 255))
draw = ImageDraw.Draw(img)

# Outer badge / ring
outer = (80, 80, 944, 944)
draw.ellipse(outer, outline=(255, 193, 7, 255), width=54, fill=(255, 255, 255, 255))
ring = (120, 120, 904, 904)
draw.ellipse(ring, outline=(255, 193, 7, 255), width=30, fill=(255, 255, 255, 255))

# Sun and rays
sun_center = (586, 205)
draw.ellipse((432, 60, 742, 368), fill=(255, 204, 0, 255), outline=(255, 193, 7, 255), width=12)
for i in range(18):
    angle = i * 20 * math.pi / 180
    x1 = sun_center[0] + 165 * math.cos(angle)
    y1 = sun_center[1] + 165 * math.sin(angle)
    x2 = sun_center[0] + 225 * math.cos(angle)
    y2 = sun_center[1] + 225 * math.sin(angle)
    draw.line((x1, y1, x2, y2), fill=(255, 193, 7, 255), width=10)

# Field stripes / hills
for y in range(540, 1024, 25):
    draw.polygon([(0, y), (W, y), (W, H), (0, H)], fill=(235, 245, 220, 255))
for i in range(6):
    y = 560 + i * 60
    draw.arc((0, y - 40, W + 100, y + 220), start=180, end=360, fill=(29, 146, 51, 255), width=26)

# House
house = (760, 230, 905, 385)
draw.rectangle(house, fill=(31, 110, 45, 255))
draw.polygon([(734, 230), (832, 165), (930, 230)], fill=(31, 110, 45, 255))
draw.rectangle((783, 255, 822, 295), fill=(246, 226, 118, 255))
draw.rectangle((820, 290, 885, 385), fill=(245, 212, 84, 255))

# Tree
trunk = (170, 240, 220, 470)
draw.rectangle(trunk, fill=(121, 85, 57, 255))
for cx, cy, r in [(195, 185, 76), (150, 240, 62), (240, 235, 66), (165, 300, 58), (230, 290, 62)]:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(34, 139, 34, 255))

# Shopping cart
cart_body = (300, 410, 670, 540)
draw.rounded_rectangle(cart_body, radius=18, fill=(17, 146, 51, 255), outline=(255, 193, 7, 255), width=11)
draw.line((300, 420, 670, 420), fill=(255, 193, 7, 255), width=14)
draw.line((375, 410, 410, 350, 475, 350), fill=(255, 193, 7, 255), width=14)
for x in (350, 560):
    draw.ellipse((x - 30, 540, x + 30, 600), fill=(20, 20, 20, 255))

produce_colors = [(239, 120, 30), (243, 198, 56), (244, 153, 34), (62, 145, 52), (243, 210, 46)]
for i, color in enumerate(produce_colors):
    x = 350 + i * 65
    y = 435 + (i % 2) * 20
    draw.ellipse((x, y, x + 60, y + 60), fill=color + (255,))
for i in range(5):
    x = 410 + i * 48
    draw.rounded_rectangle((x, 450, x + 20, 500), radius=8, fill=(26, 155, 73, 255))

# Fonts
try:
    font_slogan = ImageFont.truetype('DejaVuSans-Bold.ttf', 52)
    font_big = ImageFont.truetype('DejaVuSans-ExtraLight.ttf', 170)
    font_small = ImageFont.truetype('DejaVuSans-Bold.ttf', 120)
except Exception:
    font_slogan = ImageFont.load_default()
    font_big = ImageFont.load_default()
    font_small = ImageFont.load_default()

# Slogan banner
for dy in (0, 2):
    draw.rounded_rectangle((190, 820, 834, 900), radius=22, fill=(255, 193, 7, 255), outline=(16, 123, 40, 255), width=10)
    draw.text((275, 840 + dy), 'Market . Connect . Grow', font=font_slogan, fill=(18, 98, 35, 255), anchor='la')

# Hero text
for dx, dy in [(5, 7), (0, 0)]:
    draw.text((230 + dx, 470 + dy), 'Buy From', font=font_big, fill=(17, 125, 49, 255), anchor='la')
    draw.text((246 + dx, 620 + dy), 'Lango', font=font_small, fill=(17, 125, 49, 255), anchor='la')
for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
    draw.text((230 + dx, 470 + dy), 'Buy From', font=font_big, fill=(255, 193, 7, 255), anchor='la')
    draw.text((246 + dx, 620 + dy), 'Lango', font=font_small, fill=(255, 193, 7, 255), anchor='la')

output_path = os.path.join('assets', 'images', 'buy_from_lango_logo.png')
img.save(output_path)
print(f'Saved {output_path}')
