#!/usr/bin/env python3
"""
Final verification of header values for Guile
"""

import struct
import os

def verify_guile_header():
    """Final verification of what the header values should be"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    with open(guile_sff_path, 'rb') as f:
        # Read header
        header = f.read(64)
        
        print("🔍 Guile SFF v2 header analysis:")
        
        # Parse the fields at the positions the current Godot parser uses
        # After skipping signature(12) + version(4) + reserved(4) + dummy(16) = 36 bytes
        sprite_offset_36 = struct.unpack('<I', header[36:40])[0]
        sprite_count_40 = struct.unpack('<I', header[40:44])[0] 
        palette_offset_44 = struct.unpack('<I', header[44:48])[0]
        palette_count_48 = struct.unpack('<I', header[48:52])[0]
        
        print(f"Current Godot parser reads:")
        print(f"  Sprite offset: {sprite_offset_36}")
        print(f"  Sprite count: {sprite_count_40}")
        print(f"  Palette offset: {palette_offset_44}")
        print(f"  Palette count: {palette_count_48}")
        
        # Test if sprite offset 3936 has valid sprite headers
        print(f"\n🎯 Testing sprite headers at offset {sprite_offset_36}:")
        
        f.seek(sprite_offset_36)
        for i in range(5):
            pos = f.tell()
            data = f.read(28)
            
            if len(data) < 26:
                break
            
            # Parse sprite header
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
            
            print(f"  Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_val}")
            
            # Validate
            reasonable = (0 <= group <= 9999 and 0 <= image <= 9999 and
                         1 <= width <= 2048 and 1 <= height <= 2048 and
                         format_val in [0, 2, 3, 4, 10, 11, 12])
            print(f"    Reasonable: {reasonable}")
            
            if not reasonable:
                break
        
        # Count how many sprites we can actually parse
        print(f"\n📊 Counting valid sprites:")
        f.seek(sprite_offset_36)
        valid_count = 0
        
        try:
            while valid_count < 10000:  # Prevent infinite loop
                pos = f.tell()
                data = f.read(28)
                
                if len(data) < 26:
                    break
                
                # Quick validation
                group = struct.unpack('<H', data[0:2])[0]
                image = struct.unpack('<H', data[2:4])[0]
                width = struct.unpack('<H', data[8:10])[0]
                height = struct.unpack('<H', data[10:12])[0]
                format_val = data[14]
                
                if (0 <= group <= 9999 and 0 <= image <= 9999 and
                    1 <= width <= 2048 and 1 <= height <= 2048 and
                    format_val in [0, 2, 3, 4, 10, 11, 12]):
                    valid_count += 1
                else:
                    break
                    
        except:
            pass
        
        print(f"  Found {valid_count} valid sprites")
        print(f"  Header claims {sprite_count_40} sprites")
        
        if valid_count > 0 and valid_count != sprite_count_40:
            print(f"  ❌ Mismatch! Actual: {valid_count}, Header: {sprite_count_40}")
            print(f"  🔧 Correction needed: use {valid_count} as sprite count")
        else:
            print(f"  ✅ Header sprite count appears correct")

if __name__ == "__main__":
    verify_guile_header()
