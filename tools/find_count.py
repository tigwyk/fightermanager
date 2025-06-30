#!/usr/bin/env python3
"""
Find which header field contains the correct sprite count (164)
"""

import struct
import os

def find_sprite_count_field():
    """Find which header field contains the correct sprite count"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    with open(guile_sff_path, 'rb') as f:
        # Read full header
        header = f.read(64)
        
        print("🔍 Searching for sprite count value 164 in header:")
        
        # Check every 4-byte field as little-endian
        for offset in range(0, len(header) - 4, 4):
            value = struct.unpack('<I', header[offset:offset+4])[0]
            if value == 164:
                print(f"  ✅ Found 164 at offset {offset} (LE)")
        
        # Check every 4-byte field as big-endian
        for offset in range(0, len(header) - 4, 4):
            value = struct.unpack('>I', header[offset:offset+4])[0]
            if value == 164:
                print(f"  ✅ Found 164 at offset {offset} (BE)")
        
        # Check every 2-byte field as little-endian
        for offset in range(0, len(header) - 2, 2):
            value = struct.unpack('<H', header[offset:offset+2])[0]
            if value == 164:
                print(f"  ✅ Found 164 at offset {offset} (2-byte LE)")
        
        # Check every 2-byte field as big-endian
        for offset in range(0, len(header) - 2, 2):
            value = struct.unpack('>H', header[offset:offset+2])[0]
            if value == 164:
                print(f"  ✅ Found 164 at offset {offset} (2-byte BE)")
        
        # Also check for byte values
        for offset in range(len(header)):
            if header[offset] == 164:
                print(f"  ✅ Found 164 at offset {offset} (1-byte)")
        
        print("\n📋 Header values at key positions:")
        positions = [32, 36, 40, 44, 48, 52, 56, 60]
        for pos in positions:
            if pos + 4 <= len(header):
                value_le = struct.unpack('<I', header[pos:pos+4])[0]
                value_be = struct.unpack('>I', header[pos:pos+4])[0]
                print(f"  Offset {pos:2d}: LE={value_le:8d}, BE={value_be:8d}")

if __name__ == "__main__":
    find_sprite_count_field()
