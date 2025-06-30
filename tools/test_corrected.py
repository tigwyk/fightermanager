#!/usr/bin/env python3
"""
Test corrected sprite header layout
"""

import struct
import os

def test_corrected_layout():
    """Test with corrected sprite header layout"""
    
    files = {
        "KFM": ("../assets/mugen/chars/kfm/kfm.sff", 624),
        "Guile": ("../assets/mugen/chars/Guile/Guile.sff", 3936)
    }
    
    for name, (path, offset) in files.items():
        if not os.path.exists(path):
            continue
            
        print(f"\n🔍 Testing {name} with corrected layout:")
        
        with open(path, 'rb') as f:
            f.seek(offset)
            
            for i in range(3):  # Test first 3 sprites
                pos = f.tell()
                data = f.read(28)  # 26 + 2 padding
                
                if len(data) < 26:
                    break
                
                print(f"\n--- Sprite {i} at offset {pos} ---")
                
                # Try corrected layout based on our analysis
                # It seems like width/height might be at different positions
                group = struct.unpack('<H', data[0:2])[0]
                
                # Try different interpretations for the rest
                print("Interpretation 1 (standard):")
                image = struct.unpack('<H', data[2:4])[0]
                x = struct.unpack('<H', data[4:6])[0]
                y = struct.unpack('<H', data[6:8])[0]
                width = struct.unpack('<H', data[8:10])[0]
                height = struct.unpack('<H', data[10:12])[0]
                print(f"  Group={group}, Image={image}, Pos=({x},{y}), Size={width}x{height}")
                
                print("Interpretation 2 (width/height shifted):")
                width2 = struct.unpack('<H', data[2:4])[0]
                height2 = struct.unpack('<H', data[4:6])[0]
                image2 = struct.unpack('<H', data[6:8])[0]
                x2 = struct.unpack('<H', data[8:10])[0]
                y2 = struct.unpack('<H', data[10:12])[0]
                print(f"  Group={group}, Image={image2}, Pos=({x2},{y2}), Size={width2}x{height2}")
                
                # Get remaining fields
                linked = struct.unpack('<H', data[12:14])[0]
                format_val = data[14]
                color_depth = data[15]
                data_offset = struct.unpack('<I', data[16:20])[0]
                length = struct.unpack('<I', data[20:24])[0]
                
                print(f"  Linked={linked}, Format={format_val}, Depth={color_depth}")
                print(f"  DataOffset={data_offset}, Length={length}")
                
                # Check which interpretation seems more reasonable
                reasonable1 = (1 <= width <= 2048 and 1 <= height <= 2048)
                reasonable2 = (1 <= width2 <= 2048 and 1 <= height2 <= 2048)
                
                print(f"  Interpretation 1 reasonable: {reasonable1}")
                print(f"  Interpretation 2 reasonable: {reasonable2}")

if __name__ == "__main__":
    test_corrected_layout()
