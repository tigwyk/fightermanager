#!/usr/bin/env python3
"""
Examine the exact bytes around sprite headers to understand the format
"""

def examine_sprite_boundary():
    """Look at bytes around the first and second sprite headers"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Get to the sprite headers
        f.seek(36)
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        
        # Read first sprite header (we know this one is correct)
        f.seek(subheader_offset)
        print("\nFirst sprite header (26 bytes minimum):")
        
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
        palette_index = int.from_bytes(f.read(2), 'little')
        flags = int.from_bytes(f.read(2), 'little')
        
        print(f"Group: {group}, Image: {image}, Size: {width}x{height}")
        print(f"Offset: {x_offset},{y_offset}, Link: {link}")
        print(f"Format: {format_byte}, Depth: {color_depth}")
        print(f"Data offset: {data_offset}, Length: {data_length}")
        print(f"Palette: {palette_index}, Flags: {flags}")
        
        # Now examine the next 20 bytes to see what pattern emerges
        current_pos = f.tell()
        print(f"\nCurrent position after first header: {current_pos}")
        print(f"Bytes from position {current_pos}:")
        
        next_bytes = f.read(64)  # Read a good chunk
        for i in range(0, min(64, len(next_bytes)), 16):
            chunk = next_bytes[i:i+16]
            hex_str = " ".join(f"{b:02X}" for b in chunk)
            ascii_str = "".join(chr(b) if 32 <= b <= 126 else '.' for b in chunk)
            print(f"{current_pos + i:04X}: {hex_str:<48} {ascii_str}")
        
        # Try to find the pattern by looking for the second sprite
        # We expect it to start with small group/image numbers
        f.seek(subheader_offset + 26)  # Start right after basic header
        
        for offset in range(0, 20):  # Try different offsets
            f.seek(subheader_offset + 26 + offset)
            try:
                group2 = int.from_bytes(f.read(2), 'little')
                image2 = int.from_bytes(f.read(2), 'little')
                width2 = int.from_bytes(f.read(2), 'little')
                height2 = int.from_bytes(f.read(2), 'little')
                
                if (0 <= group2 <= 100 and 0 <= image2 <= 100 and 
                    1 <= width2 <= 500 and 1 <= height2 <= 500):
                    print(f"\nPossible second sprite at offset +{26 + offset}:")
                    print(f"Group: {group2}, Image: {image2}, Size: {width2}x{height2}")
                    
            except:
                pass

if __name__ == "__main__":
    examine_sprite_boundary()
