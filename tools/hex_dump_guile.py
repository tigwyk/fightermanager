#!/usr/bin/env python3
"""
Raw hex dump analysis of Guile SFF file
"""

import os

def hex_dump_guile_sff():
    """Dump the first 100 bytes of Guile SFF for analysis"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    if not os.path.exists(guile_sff_path):
        print(f"❌ File not found: {guile_sff_path}")
        return
    
    with open(guile_sff_path, 'rb') as f:
        data = f.read(100)
        
        print("🔍 First 100 bytes of Guile.sff:")
        print("Offset   00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F   ASCII")
        print("------   -----------------------------------------------   -----")
        
        for i in range(0, len(data), 16):
            offset = f"{i:06X}"
            hex_bytes = " ".join(f"{b:02X}" for b in data[i:i+16])
            ascii_chars = "".join(chr(b) if 32 <= b <= 126 else '.' for b in data[i:i+16])
            
            # Pad hex_bytes to consistent width
            hex_bytes = f"{hex_bytes:<47}"
            
            print(f"{offset}   {hex_bytes}   {ascii_chars}")
        
        # Manual header parsing
        print("\n🔬 Manual header parsing:")
        
        # Signature (12 bytes)
        signature = data[0:12]
        print(f"Signature: {signature} -> {signature.decode('ascii', errors='ignore')}")
        
        # Version (4 bytes)
        version_bytes = data[12:16]
        print(f"Version bytes: {version_bytes.hex()}")
        
        import struct
        version_le = struct.unpack('<I', version_bytes)[0]
        version_be = struct.unpack('>I', version_bytes)[0]
        print(f"Version LE: {version_le}")
        print(f"Version BE: {version_be}")
        
        # The next section should be 16 bytes of dummy data for SFF v2
        dummy_data = data[16:32]
        print(f"Dummy data (16 bytes): {dummy_data.hex()}")
        
        # Then the rest of header
        rest_header = data[32:48]
        print(f"Rest of header (16 bytes): {rest_header.hex()}")
        
        # Try to parse as little-endian 4-byte values
        if len(rest_header) >= 16:
            sprite_count = struct.unpack('<I', rest_header[0:4])[0]
            palette_count = struct.unpack('<I', rest_header[4:8])[0] 
            sprite_offset = struct.unpack('<I', rest_header[8:12])[0]
            palette_offset = struct.unpack('<I', rest_header[12:16])[0]
            
            print(f"LE: Sprite count: {sprite_count}, Palette count: {palette_count}")
            print(f"LE: Sprite offset: {sprite_offset}, Palette offset: {palette_offset}")
        
        # Try as big-endian
        if len(rest_header) >= 16:
            sprite_count = struct.unpack('>I', rest_header[0:4])[0]
            palette_count = struct.unpack('>I', rest_header[4:8])[0] 
            sprite_offset = struct.unpack('>I', rest_header[8:12])[0]
            palette_offset = struct.unpack('>I', rest_header[12:16])[0]
            
            print(f"BE: Sprite count: {sprite_count}, Palette count: {palette_count}")
            print(f"BE: Sprite offset: {sprite_offset}, Palette offset: {palette_offset}")

if __name__ == "__main__":
    hex_dump_guile_sff()
