#!/usr/bin/env python3
"""
Check what's at the sprite offsets for both KFM and Guile
"""

import struct
import os

def check_both_offsets():
    """Check sprite data at the suspected offsets"""
    
    files = {
        "KFM": ("../assets/mugen/chars/kfm/kfm.sff", 624, 281),
        "Guile": ("../assets/mugen/chars/Guile/Guile.sff", 3936, 2801)
    }
    
    for name, (path, offset, count) in files.items():
        if not os.path.exists(path):
            continue
            
        print(f"\n🔍 Checking {name} at offset {offset} (expected count: {count}):")
        
        with open(path, 'rb') as f:
            f.seek(offset)
            data = f.read(56)  # Read 2 sprite headers worth
            
            print("Raw bytes:")
            for i in range(0, len(data), 16):
                line = " ".join(f"{data[i+j]:02X}" for j in range(min(16, len(data)-i)))
                print(f"  {offset+i:06X}: {line}")
            
            # Try to parse as sprite headers
            f.seek(offset)
            for i in range(min(2, count if count < 1000 else 2)):  # Limit to 2 sprites
                header_data = f.read(28)  # 26 + 2 padding
                if len(header_data) < 26:
                    break
                
                # Try little-endian parsing
                try:
                    group, image, x, y, width, height, linked_index, format_val, color_depth, data_offset, length = struct.unpack('<HHHHHHHBBI', header_data[:26])
                    print(f"  Sprite {i} (LE): Group={group}, Image={image}, Size={width}x{height}, Format={format_val}, DataOffset={data_offset}, Length={length}")
                    
                    # Check if values are reasonable
                    reasonable = (0 <= group <= 9999 and 0 <= image <= 9999 and 
                                1 <= width <= 2048 and 1 <= height <= 2048 and
                                0 <= format_val <= 12 and data_offset > 0)
                    print(f"    Reasonable: {reasonable}")
                    
                except struct.error:
                    print(f"  Sprite {i}: Parse error")
                
                # Reset for next iteration
                f.seek(offset + (i+1) * 28)

if __name__ == "__main__":
    check_both_offsets()
