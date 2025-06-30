#!/usr/bin/env python3
"""
Compare Guile and KFM SFF headers to understand the format differences
"""

import struct
import os

def compare_sff_headers():
    """Compare SFF headers between Guile and KFM"""
    
    files = {
        "Guile": "../assets/mugen/chars/Guile/Guile.sff",
        "KFM": "../assets/mugen/chars/kfm/kfm.sff"
    }
    
    for name, path in files.items():
        if not os.path.exists(path):
            print(f"❌ {name} file not found: {path}")
            continue
            
        print(f"\n🔍 Analyzing {name} SFF header:")
        
        with open(path, 'rb') as f:
            # Read first 64 bytes
            header = f.read(64)
            
            # Parse signature and version
            signature = header[0:12]
            ver0 = header[15]  # Main version
            
            print(f"  Signature: {signature}")
            print(f"  Version: {ver0}")
            
            if ver0 == 1:
                print("  📝 SFF v1 format")
                # SFF v1 layout: signature(12) + version(4) + reserved(4) + header fields
                num_sprites = struct.unpack('<I', header[28:32])[0]
                sprite_offset = struct.unpack('<I', header[32:36])[0]
                print(f"    Sprites: {num_sprites}")
                print(f"    Sprite offset: {sprite_offset}")
                
            elif ver0 == 2:
                print("  📝 SFF v2 format")
                # Show the raw bytes after version
                print("  Raw bytes 20-63:")
                for i in range(20, min(64, len(header)), 16):
                    line = " ".join(f"{header[j]:02X}" for j in range(i, min(i+16, len(header))))
                    print(f"    {i:02X}: {line}")
                
                # Try different interpretations
                print("  \n🧪 Different interpretations:")
                
                # Current Godot interpretation (skip 16 bytes dummy, then parse)
                sprite_offset_36 = struct.unpack('<I', header[36:40])[0] if len(header) >= 40 else 0
                sprite_count_40 = struct.unpack('<I', header[40:44])[0] if len(header) >= 44 else 0
                print(f"    Godot style - Sprite offset @36: {sprite_offset_36}, Count @40: {sprite_count_40}")
                
                # Alternative: data starts at offset 20
                sprite_count_20 = struct.unpack('<I', header[20:24])[0] if len(header) >= 24 else 0
                sprite_offset_24 = struct.unpack('<I', header[24:28])[0] if len(header) >= 28 else 0
                print(f"    Alt 1 - Count @20: {sprite_count_20}, Offset @24: {sprite_offset_24}")
                
                # Alternative: data starts at offset 24
                sprite_count_24 = struct.unpack('<I', header[24:28])[0] if len(header) >= 28 else 0
                sprite_offset_28 = struct.unpack('<I', header[28:32])[0] if len(header) >= 32 else 0
                print(f"    Alt 2 - Count @24: {sprite_count_24}, Offset @28: {sprite_offset_28}")
                
                # Alternative: different field order
                sprite_offset_32 = struct.unpack('<I', header[32:36])[0] if len(header) >= 36 else 0
                sprite_count_36 = struct.unpack('<I', header[36:40])[0] if len(header) >= 40 else 0
                print(f"    Alt 3 - Offset @32: {sprite_offset_32}, Count @36: {sprite_count_36}")

if __name__ == "__main__":
    compare_sff_headers()
