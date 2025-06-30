#!/usr/bin/env python3
"""
Check what's actually at the suspected sprite offset
"""

import struct
import os

def check_sprite_offset():
    """Check the data at offset 2801 to see if it contains sprite headers"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    with open(guile_sff_path, 'rb') as f:
        # Based on Layout 3, sprite offset should be 2801
        sprite_offset = 2801
        
        print(f"🔍 Checking data at offset {sprite_offset}:")
        
        f.seek(sprite_offset)
        data = f.read(100)  # Read 100 bytes
        
        print("Hex dump:")
        for i in range(0, len(data), 16):
            offset = sprite_offset + i
            hex_bytes = " ".join(f"{data[i+j]:02X}" for j in range(min(16, len(data)-i)))
            ascii_chars = "".join(chr(data[i+j]) if 32 <= data[i+j] <= 126 else '.' for j in range(min(16, len(data)-i)))
            print(f"{offset:06X}: {hex_bytes:<47} {ascii_chars}")
        
        # Try to parse as sprite headers
        print(f"\n🎯 Trying to parse as sprite headers:")
        
        f.seek(sprite_offset)
        for i in range(5):  # Try first 5 sprites
            pos = f.tell()
            header_data = f.read(28)  # 26 + 2 padding
            
            if len(header_data) < 26:
                break
            
            print(f"\n--- Attempting sprite {i} at offset {pos} ---")
            
            # Try both endianness
            try:
                # Big-endian
                group, image, x, y, width, height, linked_index, format_val, color_depth, data_offset, length = struct.unpack('>HHHHHHHBBI', header_data[:26])
                print(f"BE: Group={group}, Image={image}, Size={width}x{height}, Format={format_val}, Offset={data_offset}, Length={length}")
                
                # Little-endian  
                group, image, x, y, width, height, linked_index, format_val, color_depth, data_offset, length = struct.unpack('<HHHHHHHBBI', header_data[:26])
                print(f"LE: Group={group}, Image={image}, Size={width}x{height}, Format={format_val}, Offset={data_offset}, Length={length}")
                
            except struct.error:
                print("Failed to parse header")
        
        # Also check the value at offset 24 that looked like sprite count
        f.seek(24)
        count_data = f.read(4)
        sprite_count_be = struct.unpack('>I', count_data)[0]
        sprite_count_le = struct.unpack('<I', count_data)[0]
        
        print(f"\n📊 Sprite count from offset 24:")
        print(f"BE: {sprite_count_be}")
        print(f"LE: {sprite_count_le}")

if __name__ == "__main__":
    check_sprite_offset()
