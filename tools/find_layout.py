#!/usr/bin/env python3
"""
Try to find the correct sprite header layout by looking for width/height values
that make sense
"""

import struct
import os

def find_sprite_layout():
    """Try to determine correct sprite header layout"""
    
    kfm_path = "../assets/mugen/chars/kfm/kfm.sff"
    offset = 624
    
    with open(kfm_path, 'rb') as f:
        f.seek(offset)
        data = f.read(32)
        
        print("🔍 Raw bytes:")
        print(" ".join(f"{data[i]:02X}" for i in range(len(data))))
        
        print("\n🔬 Trying different field interpretations:")
        
        # Try different starting points for width/height
        for start in range(0, 16, 2):  # Try every 2 bytes
            if start + 4 <= len(data):
                width = struct.unpack('<H', data[start:start+2])[0]
                height = struct.unpack('<H', data[start+2:start+4])[0]
                
                # Look for reasonable width/height values
                if 1 <= width <= 2048 and 1 <= height <= 2048:
                    print(f"  Offset {start:2d}: width={width}, height={height} ✓")
                else:
                    print(f"  Offset {start:2d}: width={width}, height={height}")
        
        # Also try the documented MUGEN SFF v2 layout from specs
        print("\n📋 Documented SFF v2 sprite header layout:")
        print("  0-1:   Group number (2 bytes)")
        print("  2-3:   Image number (2 bytes)") 
        print("  4-5:   X position (2 bytes)")
        print("  6-7:   Y position (2 bytes)")
        print("  8-9:   Width (2 bytes)")
        print("  10-11: Height (2 bytes)")
        print("  12-13: Linked index (2 bytes)")
        print("  14:    Format (1 byte)")
        print("  15:    Color depth (1 byte)")
        print("  16-19: Data offset (4 bytes)")
        print("  20-23: Data length (4 bytes)")
        print("  24-25: Palette index (2 bytes)")
        
        # Parse with documented layout
        if len(data) >= 26:
            group = struct.unpack('<H', data[0:2])[0]
            image = struct.unpack('<H', data[2:4])[0]
            x = struct.unpack('<H', data[4:6])[0]  
            y = struct.unpack('<H', data[6:8])[0]
            width = struct.unpack('<H', data[8:10])[0]
            height = struct.unpack('<H', data[10:12])[0]
            linked = struct.unpack('<H', data[12:14])[0]
            format_val = data[14]
            color_depth = data[15]
            data_offset = struct.unpack('<I', data[16:20])[0]
            length = struct.unpack('<I', data[20:24])[0]
            palette = struct.unpack('<H', data[24:26])[0] if len(data) >= 26 else 0
            
            print(f"\n📝 Parsed header:")
            print(f"  Group: {group}, Image: {image}")
            print(f"  Position: ({x}, {y})")  
            print(f"  Size: {width}x{height}")
            print(f"  Linked: {linked}")
            print(f"  Format: {format_val}, Depth: {color_depth}")
            print(f"  Data: offset={data_offset}, length={length}")
            print(f"  Palette: {palette}")
            
            # Check if this looks reasonable
            reasonable = (0 <= group <= 9999 and 0 <= image <= 9999 and
                         1 <= width <= 2048 and 1 <= height <= 2048 and
                         format_val in [0, 2, 3, 4, 10, 11, 12] and
                         data_offset > 0 and length > 0)
            print(f"  Reasonable: {reasonable}")

if __name__ == "__main__":
    find_sprite_layout()
