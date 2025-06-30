#!/usr/bin/env python3
"""
Analyze the raw sprite header data in Guile's SFF v2 file
"""

def analyze_sff_headers():
    """Analyze the sprite headers to understand the format"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Read header info first
        f.seek(0)
        signature = f.read(12)
        print(f"Signature: {signature}")
        
        # Read version info
        ver3, ver2, ver1, ver0 = f.read(4)
        print(f"Version: {ver0}.{ver1}.{ver2}.{ver3}")
        
        # Skip reserved bytes
        f.read(4)
        
        # SFF v2 header continuation
        f.read(16)  # Skip 16 bytes of dummy data
        
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        palette_offset = int.from_bytes(f.read(4), 'little')
        num_palettes = int.from_bytes(f.read(4), 'little')
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        print(f"Palette offset: {palette_offset}")
        print(f"Num palettes: {num_palettes}")
        
        # Check if there might be a different structure
        # Some SFF v2 files have the sprite directory split into multiple parts
        print(f"\nAnalyzing possible sprite directory structure...")
        
        # Check if sprites are at the palette offset instead
        for test_offset in [subheader_offset, palette_offset, subheader_offset + 512, palette_offset + (num_palettes * 1024)]:
            print(f"\n--- Testing offset {test_offset} ---")
            
            f.seek(test_offset)
            
            # Try to read a few sprite entries with different sizes
            for header_size in [20, 24, 28, 32]:
                print(f"  Header size {header_size}:")
                
                f.seek(test_offset)
                valid_sprites = 0
                
                for i in range(min(5, image_count)):
                    try:
                        group = int.from_bytes(f.read(2), 'little')
                        image = int.from_bytes(f.read(2), 'little')
                        width = int.from_bytes(f.read(2), 'little')
                        height = int.from_bytes(f.read(2), 'little')
                        x_offset = int.from_bytes(f.read(2), 'little', signed=True)
                        y_offset = int.from_bytes(f.read(2), 'little', signed=True)
                        link = int.from_bytes(f.read(2), 'little')
                        format_byte = f.read(1)[0]
                        color_depth = f.read(1)[0]
                        data_offset = int.from_bytes(f.read(4), 'little')
                        data_length = int.from_bytes(f.read(4), 'little')
                        
                        # Read remaining bytes based on header size
                        remaining = header_size - 26
                        if remaining > 0:
                            extra_data = f.read(remaining)
                        
                        # Check if this looks like a valid sprite
                        if (0 <= group <= 10000 and 0 <= image <= 10000 and
                            1 <= width <= 1000 and 1 <= height <= 1000 and
                            format_byte in [0, 2, 3, 4, 10] and
                            0 <= color_depth <= 32 and
                            data_offset > 0 and data_length > 0 and data_length < 2000000):
                            
                            valid_sprites += 1
                            if i < 3:
                                print(f"    ✅ Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                        else:
                            if i < 3:
                                print(f"    ❌ Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                            break
                            
                    except Exception as e:
                        print(f"    ❌ Error reading sprite {i}: {e}")
                        break
                
                if valid_sprites >= 3:
                    print(f"    🎉 Found {valid_sprites} valid sprites with {header_size}-byte headers at offset {test_offset}!")
                    
                    # If we found a good format, examine the sprite data
                    if valid_sprites >= 3:
                        print(f"\n=== DETAILED ANALYSIS FOR WORKING FORMAT ===")
                        f.seek(test_offset)
                        
                        for i in range(min(3, image_count)):
                            pos = f.tell()
                            print(f"\nSprite {i} at offset {pos}:")
                            
                            group = int.from_bytes(f.read(2), 'little')
                            image = int.from_bytes(f.read(2), 'little')
                            width = int.from_bytes(f.read(2), 'little')
                            height = int.from_bytes(f.read(2), 'little')
                            x_offset = int.from_bytes(f.read(2), 'little', signed=True)
                            y_offset = int.from_bytes(f.read(2), 'little', signed=True)
                            link = int.from_bytes(f.read(2), 'little')
                            format_byte = f.read(1)[0]
                            color_depth = f.read(1)[0]
                            data_offset = int.from_bytes(f.read(4), 'little')
                            data_length = int.from_bytes(f.read(4), 'little')
                            
                            remaining = header_size - 26
                            if remaining > 0:
                                extra_data = f.read(remaining)
                                print(f"  Extra bytes: {extra_data.hex()}")
                            
                            print(f"  Group: {group}, Image: {image}")
                            print(f"  Size: {width}x{height}")
                            print(f"  Offset: {x_offset},{y_offset}")
                            print(f"  Link: {link}, Format: {format_byte}, Depth: {color_depth}")
                            print(f"  Data offset: {data_offset}, Length: {data_length}")
                        
                        return  # Found the correct format
                        
                print(f"    Found {valid_sprites} valid sprites")

if __name__ == "__main__":
    analyze_sff_headers()
