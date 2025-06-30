#!/usr/bin/env python3
"""
Examine the exact byte structure around the first sprites in Guile's SFF v2
"""

def examine_exact_sprite_layout():
    """Examine exact sprite header layout"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Read main header first
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
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        
        # Go to sprite directory
        f.seek(subheader_offset)
        print(f"\nExamining raw bytes starting at offset {subheader_offset}:")
        
        # Read and display first 200 bytes as hex
        raw_data = f.read(200)
        for i in range(0, len(raw_data), 16):
            hex_chunk = ' '.join(f"{b:02X}" for b in raw_data[i:i+16])
            print(f"Offset {subheader_offset + i:04X}: {hex_chunk}")
        
        # Now try to parse first few sprites with 28-byte headers
        f.seek(subheader_offset)
        print(f"\n--- Parsing with 28-byte headers ---")
        
        for sprite_num in range(min(10, image_count)):
            pos = f.tell()
            print(f"\nSprite {sprite_num} at offset {pos}:")
            
            if pos + 28 > f.tell() + len(raw_data):
                print("  Not enough data remaining")
                break
            
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
            padding = int.from_bytes(f.read(2), 'little')
            
            print(f"  Group: {group}, Image: {image}")
            print(f"  Size: {width}x{height}")
            print(f"  Offset: {x_offset},{y_offset}")
            print(f"  Link: {link}, Format: {format_byte}, Depth: {color_depth}")
            print(f"  Data offset: {data_offset}, Length: {data_length}")
            print(f"  Palette: {palette_index}, Flags: {flags}, Padding: {padding:04X}")
            
            # Validation check
            valid = (
                0 <= group <= 10000 and 
                0 <= image <= 10000 and
                0 < width < 2000 and 
                0 < height < 2000 and
                format_byte in [0, 2, 3, 4, 10] and
                data_offset > 0 and data_length > 0
            )
            
            if valid:
                print(f"  ✅ Sprite looks valid")
            else:
                print(f"  ❌ Sprite looks invalid")
                # Stop parsing if we hit invalid data
                break

if __name__ == "__main__":
    examine_exact_sprite_layout()
