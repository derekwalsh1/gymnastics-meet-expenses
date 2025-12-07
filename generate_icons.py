#!/usr/bin/env python3
"""Generate app icons for Gymnastics Judging Expense Tracker"""

from PIL import Image, ImageDraw, ImageFont
import os

# Icon sizes needed for iOS
ICON_SIZES = [
    (20, 1), (20, 2), (20, 3),
    (29, 1), (29, 2), (29, 3),
    (40, 1), (40, 2), (40, 3),
    (60, 2), (60, 3),
    (76, 1), (76, 2),
    (83.5, 2),
    (1024, 1)
]

def create_base_icon(size=1024):
    """Create a 1024x1024 base icon with professional design"""
    
    # Create image with gradient background
    img = Image.new('RGB', (size, size), '#FFFFFF')
    draw = ImageDraw.Draw(img)
    
    # Create gradient background (teal to blue)
    for y in range(size):
        # Gradient from teal (#1ABC9C) to blue (#3498DB)
        r = int(26 + (52 - 26) * y / size)
        g = int(188 + (152 - 188) * y / size)
        b = int(156 + (219 - 156) * y / size)
        draw.rectangle([(0, y), (size, y + 1)], fill=(r, g, b))
    
    # Add rounded rectangle overlay for modern look
    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    
    # White rounded rectangle in center
    margin = int(size * 0.15)
    rect_coords = [margin, margin, size - margin, size - margin]
    corner_radius = int(size * 0.12)
    
    # Draw rounded rectangle (white with slight transparency)
    overlay_draw.rounded_rectangle(
        rect_coords,
        radius=corner_radius,
        fill=(255, 255, 255, 230)
    )
    
    # Composite the overlay
    img = Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')
    draw = ImageDraw.Draw(img)
    
    # Try to load a system font
    font_size_large = int(size * 0.25)
    font_size_small = int(size * 0.12)
    
    try:
        # Try common macOS fonts
        font_large = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', font_size_large)
        font_small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', font_size_small)
    except:
        try:
            font_large = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', font_size_large)
            font_small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', font_size_small)
        except:
            # Fallback to default
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
    
    # Add text "GJ" in the center
    text_large = "GJ"
    text_color = (41, 128, 185)  # Blue color #2980B9
    
    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text_large, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Position for "GJ"
    x_large = (size - text_width) // 2
    y_large = (size - text_height) // 2 - int(size * 0.08)
    
    draw.text((x_large, y_large), text_large, font=font_large, fill=text_color)
    
    # Add smaller text "Expense Tracker" below
    text_small = "Expense"
    bbox_small = draw.textbbox((0, 0), text_small, font=font_small)
    text_width_small = bbox_small[2] - bbox_small[0]
    
    x_small = (size - text_width_small) // 2
    y_small = y_large + text_height + int(size * 0.05)
    
    draw.text((x_small, y_small), text_small, font=font_small, fill=(52, 73, 94))  # Dark gray
    
    return img

def generate_all_icons():
    """Generate all required icon sizes"""
    
    # Output directory
    output_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    
    print("Generating app icons...")
    
    # Create base 1024x1024 icon
    base_icon = create_base_icon(1024)
    
    # Generate all required sizes
    for base_size, scale in ICON_SIZES:
        pixel_size = int(base_size * scale)
        
        # Resize base icon
        if pixel_size == 1024:
            icon = base_icon
        else:
            icon = base_icon.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        
        # Generate filename
        if scale == 1:
            filename = f'Icon-App-{base_size}x{base_size}@1x.png'
        else:
            filename = f'Icon-App-{base_size}x{base_size}@{scale}x.png'
        
        filepath = os.path.join(output_dir, filename)
        
        # Save icon
        icon.save(filepath, 'PNG')
        print(f"✓ Generated {filename} ({pixel_size}x{pixel_size})")
    
    print("\n✓ All app icons generated successfully!")
    print(f"✓ Icons saved to {output_dir}")

if __name__ == '__main__':
    generate_all_icons()
