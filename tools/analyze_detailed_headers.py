#!/usr/bin/env python3
"""
Detailed analysis of SFF v2 header structure
"""

def analyze_detailed_headers():
    """Analyze different possible header sizes"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Get header info
        f.seek(36)  # Skip to subheader offset position
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        
        # Try different header sizes
        for header_size in [28, 32, 36]:
            print(f"\n=== Testing header size: {header_size} bytes ===")
            f.seek(subheader_offset)
            
            for i in range(min(3, image_count)):
                pos = f.tell()
                print(f"\nSprite {i} at offset {pos}:")
                
                # Read the header
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
                
                # Skip remaining bytes for this header size
                remaining = header_size - 26
                if remaining > 0:
                    f.read(remaining)
                
                print(f"  Group: {group}, Image: {image}")
                print(f"  Size: {width}x{height}")
                print(f"  Offset: {x_offset},{y_offset}")
                print(f"  Link: {link}, Format: {format_byte}, Depth: {color_depth}")
                print(f"  Data offset: {data_offset}, Length: {data_length}")
                print(f"  Palette: {palette_index}, Flags: {flags}")
                
                # Check if values are reasonable
                reasonable = (
                    0 <= width <= 1000 and 0 <= height <= 1000 and
                    0 <= group <= 10000 and 0 <= image <= 10000 and
                    format_byte in [0, 2, 3, 4, 10] and
                    0 <= color_depth <= 32 and
                    data_offset > 0 and data_length > 0 and data_length < 1000000
                )
                
                if reasonable:
                    print("  ✅ Values look reasonable")
                else:
                    print("  ❌ Values look suspicious")
                    break  # Stop if we hit bad data
            
            if not reasonable:
                continue  # Try next header size
            
            # If we got here, this header size worked
            print(f"✅ Header size {header_size} seems correct!")
            break

if __name__ == "__main__":
    analyze_detailed_headers()
