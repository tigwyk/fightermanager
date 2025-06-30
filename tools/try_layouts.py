#!/usr/bin/env python3
"""
Try different SFF v2 header interpretations
"""

import struct
import os

def try_different_layouts():
    """Try different interpretations of the SFF v2 header"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    with open(guile_sff_path, 'rb') as f:
        header = f.read(48)
        
        print("🔬 Trying different header layouts for SFF v2:")
        
        # Layout 1: Standard interpretation (what we've been using)
        print("\n--- Layout 1: Standard ---")
        sprite_count = struct.unpack('>I', header[32:36])[0]
        palette_count = struct.unpack('>I', header[36:40])[0]
        sprite_offset = struct.unpack('>I', header[40:44])[0]
        palette_offset = struct.unpack('>I', header[44:48])[0]
        print(f"Sprites: {sprite_count}, Palettes: {palette_count}")
        print(f"Sprite offset: {sprite_offset}, Palette offset: {palette_offset}")
        
        # Layout 2: Different offset interpretation
        print("\n--- Layout 2: Alternative offsets ---")
        sprite_count = struct.unpack('>I', header[16:20])[0]
        palette_count = struct.unpack('>I', header[20:24])[0]
        sprite_offset = struct.unpack('>I', header[24:28])[0]
        palette_offset = struct.unpack('>I', header[28:32])[0]
        print(f"Sprites: {sprite_count}, Palettes: {palette_count}")
        print(f"Sprite offset: {sprite_offset}, Palette offset: {palette_offset}")
        
        # Layout 3: Try little-endian for data fields
        print("\n--- Layout 3: Mixed endianness ---")
        sprite_count = struct.unpack('<I', header[32:36])[0]
        palette_count = struct.unpack('<I', header[36:40])[0]
        sprite_offset = struct.unpack('<I', header[40:44])[0]
        palette_offset = struct.unpack('<I', header[44:48])[0]
        print(f"Sprites: {sprite_count}, Palettes: {palette_count}")
        print(f"Sprite offset: {sprite_offset}, Palette offset: {palette_offset}")
        
        # Layout 4: Check if data is at a known location
        print("\n--- Layout 4: Search for sprite directory ---")
        # Look for reasonable sprite count values in the header
        for offset in range(16, 40, 4):
            value_be = struct.unpack('>I', header[offset:offset+4])[0]
            value_le = struct.unpack('<I', header[offset:offset+4])[0]
            
            # Look for reasonable sprite counts (1-10000)
            if 1 <= value_be <= 10000:
                print(f"  Offset {offset}: BE value {value_be} looks like sprite count")
            if 1 <= value_le <= 10000:
                print(f"  Offset {offset}: LE value {value_le} looks like sprite count")
        
        # Layout 5: Look at bytes around offset 27 where we see "02"
        print("\n--- Layout 5: Examine specific bytes ---")
        print(f"Bytes 24-31: {header[24:32].hex()}")
        print(f"Bytes 26-30: {header[26:30].hex()}")
        
        # Try interpreting bytes 26-29 as sprite count
        if len(header) >= 30:
            count_bytes = header[26:30]
            count_be = struct.unpack('>I', count_bytes)[0]
            count_le = struct.unpack('<I', count_bytes)[0]
            print(f"Bytes 26-29 as BE: {count_be}")
            print(f"Bytes 26-29 as LE: {count_le}")

if __name__ == "__main__":
    try_different_layouts()
