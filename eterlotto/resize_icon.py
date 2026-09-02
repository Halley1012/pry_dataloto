from PIL import Image

def resize_and_pad(input_path, output_padded, output_solid, scale_factor=0.65, bg_color=(30, 30, 30, 255)):
    # 30, 30, 30 is roughly #1E1E1E
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    new_w = int(w * scale_factor)
    new_h = int(h * scale_factor)
    
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    
    # Create new blank transparent image for Android foreground
    img_padded = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Create new solid image for iOS
    img_solid = Image.new("RGBA", (w, h), bg_color)
    
    # Calculate padding to center
    x = (w - new_w) // 2
    y = (h - new_h) // 2
    
    # Paste resized image onto blank canvases
    img_padded.paste(resized, (x, y), resized)
    img_solid.paste(resized, (x, y), resized)
    
    img_padded.save(output_padded)
    img_solid.save(output_solid)
    print(f"Saved {output_padded}")
    print(f"Saved {output_solid}")

if __name__ == "__main__":
    resize_and_pad('assets/images/logo_icon_black.png', 
                   'assets/images/logo_icon_black_padded.png',
                   'assets/images/logo_icon_black_solid.png')
