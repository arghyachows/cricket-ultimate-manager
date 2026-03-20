from PIL import Image, ImageDraw, ImageFont
import os

# Create 1024x1024 icon (standard size)
size = 1024
img = Image.new('RGB', (size, size), color='#1a1a2e')
draw = ImageDraw.Draw(img)

# Draw gradient background
for i in range(size):
    alpha = i / size
    r = int(26 + (255 - 26) * alpha * 0.2)
    g = int(26 + (215 - 26) * alpha * 0.2)
    b = int(46 + (0 - 46) * alpha * 0.2)
    draw.line([(0, i), (size, i)], fill=(r, g, b))

# Draw cricket ball (simplified)
center_x, center_y = size // 2, size // 2
ball_radius = size // 3

# Ball shadow
shadow_offset = 20
draw.ellipse(
    [center_x - ball_radius + shadow_offset, center_y - ball_radius + shadow_offset,
     center_x + ball_radius + shadow_offset, center_y + ball_radius + shadow_offset],
    fill='#000000', outline=None
)

# Main ball
draw.ellipse(
    [center_x - ball_radius, center_y - ball_radius,
     center_x + ball_radius, center_y + ball_radius],
    fill='#ff6b35', outline='#ffffff', width=8
)

# Seam lines
seam_width = 6
seam_color = '#ffffff'
# Vertical seam
draw.line([(center_x, center_y - ball_radius + 40), (center_x, center_y + ball_radius - 40)],
          fill=seam_color, width=seam_width)

# Curved seams (simplified as arcs)
for offset in [-80, 80]:
    draw.arc(
        [center_x - ball_radius + 60, center_y - ball_radius + 60,
         center_x + ball_radius - 60, center_y + ball_radius - 60],
        start=offset - 30, end=offset + 30, fill=seam_color, width=seam_width
    )

# Add bat silhouette
bat_width = 60
bat_height = 280
bat_x = center_x + ball_radius + 80
bat_y = center_y - bat_height // 2

# Bat handle
draw.rectangle(
    [bat_x, bat_y, bat_x + bat_width // 3, bat_y + bat_height // 3],
    fill='#8b4513', outline='#ffffff', width=3
)

# Bat blade
draw.rectangle(
    [bat_x - bat_width // 4, bat_y + bat_height // 3,
     bat_x + bat_width, bat_y + bat_height],
    fill='#d2691e', outline='#ffffff', width=4
)

# Save main icon
output_path = 'assets/icon/app_icon.png'
img.save(output_path, 'PNG')
print(f'Created {output_path}')

# Create foreground for adaptive icon (transparent background)
img_fg = Image.new('RGBA', (size, size), color=(0, 0, 0, 0))
draw_fg = ImageDraw.Draw(img_fg)

# Draw cricket ball on transparent background
draw_fg.ellipse(
    [center_x - ball_radius, center_y - ball_radius,
     center_x + ball_radius, center_y + ball_radius],
    fill='#ff6b35', outline='#ffffff', width=8
)

# Seam lines
draw_fg.line([(center_x, center_y - ball_radius + 40), (center_x, center_y + ball_radius - 40)],
             fill=seam_color, width=seam_width)

for offset in [-80, 80]:
    draw_fg.arc(
        [center_x - ball_radius + 60, center_y - ball_radius + 60,
         center_x + ball_radius - 60, center_y + ball_radius - 60],
        start=offset - 30, end=offset + 30, fill=seam_color, width=seam_width
    )

# Save foreground
fg_path = 'assets/icon/app_icon_foreground.png'
img_fg.save(fg_path, 'PNG')
print(f'Created {fg_path}')

print('\nNow run: flutter pub get')
print('Then run: flutter pub run flutter_launcher_icons')
