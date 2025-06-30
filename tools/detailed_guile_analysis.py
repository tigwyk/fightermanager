#!/usr/bin/env python3
"""
Compare Python and Godot sprite header parsing for Guile
"""

def analyze_guile_headers_detailed():
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Read main header
        f.seek(0)
        signature = f.read(12)
        ver3, ver2, ver1, ver0 = f.read(4)
        f.read(4)  # Skip reserved
        f.read(16)  # Skip dummy data
        
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        
        # Go to sprite directory and parse exactly like Godot
        f.seek(subheader_offset)
        
        print("\nFirst 10 sprite headers (28-byte format):")
        for i in range(min(10, image_count)):
            pos = f.tell()
            
            # Parse exactly like our Godot code
            group = int.from_bytes(f.read(2), 'little')
            image = int.from_bytes(f.read(2), 'little') 
            width = int.from_bytes(f.read(2), 'little')
            height = int.from_bytes(f.read(2), 'little')
            x_offset = int.from_bytes(f.read(2), 'little', signed=True)
            y_offset = int.from_bytes(f.read(2), 'little', signed=True)
            link = int.from_bytes(f.read(2), 'little')
            format_byte = f.read(1)[0]  # This is the format field
            color_depth = f.read(1)[0]
            data_offset = int.from_bytes(f.read(4), 'little')
            data_length = int.from_bytes(f.read(4), 'little')
            palette_index = int.from_bytes(f.read(2), 'little')
            flags = int.from_bytes(f.read(2), 'little')
            padding = int.from_bytes(f.read(2), 'little')
            
            print(f"Sprite {i} at offset {pos}:")
            print(f"  Group: {group}, Image: {image}")
            print(f"  Size: {width}x{height}")
            print(f"  Format: {format_byte} ({get_format_name(format_byte)})")
            print(f"  Color depth: {color_depth}")
            print(f"  Data offset: {data_offset}, Length: {data_length}")
            print(f"  Link: {link}, Palette: {palette_index}, Flags: {flags}")
            
            # Examine the actual data at data_offset
            current_pos = f.tell()
            f.seek(data_offset)
            data_sample = f.read(min(16, data_length))
            f.seek(current_pos)
            
            hex_data = ' '.join(f'{b:02X}' for b in data_sample)
            print(f"  First {len(data_sample)} bytes: {hex_data}")
            
            # Check PNG signature
            png_sig = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            is_png = data_sample.startswith(png_sig[:min(len(data_sample), 8)])
            print(f"  PNG signature: {'Yes' if is_png else 'No'}")
            print()

def get_format_name(format_id):
    formats = {
        0: "Raw",
        2: "RLE8", 
        3: "RLE5",
        4: "LZ5",
        10: "PNG"
    }
    return formats.get(format_id, f"Unknown({format_id})")

if __name__ == "__main__":
    analyze_guile_headers_detailed()
