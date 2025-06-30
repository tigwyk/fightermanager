#!/usr/bin/env python3
"""
Detailed analysis of SFF v2 header structure for Guile
"""

import struct
import os

def analyze_sff_structure():
    """Analyze SFF structure with careful attention to header layout"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    if not os.path.exists(guile_sff_path):
        print(f"❌ File not found: {guile_sff_path}")
        return
    
    with open(guile_sff_path, 'rb') as f:
        file_size = os.path.getsize(guile_sff_path)
        print(f"📁 File size: {file_size} bytes")
        
        # Read full header for SFF v2 (should be 48 bytes total)
        header = f.read(48)
        
        print("\n🔍 Full 48-byte header:")
        for i in range(0, 48, 16):
            offset = f"{i:02X}"
            hex_bytes = " ".join(f"{header[i+j]:02X}" for j in range(min(16, 48-i)))
            ascii_chars = "".join(chr(header[i+j]) if 32 <= header[i+j] <= 126 else '.' for j in range(min(16, 48-i)))
            print(f"{offset}: {hex_bytes:<47} {ascii_chars}")
        
        # Parse signature
        signature = header[0:12]
        print(f"\n📝 Signature: {signature}")
        
        # Parse version (offset 12, 4 bytes)
        version_bytes = header[12:16]
        version = struct.unpack('>I', version_bytes)[0]  # Big endian
        print(f"📝 Version: {version}")
        
        if version != 2:
            print("❌ Not SFF v2")
            return
        
        # For SFF v2, we need to account for dummy data
        # According to MUGEN spec:
        # Offset 16-31: Reserved/dummy data (16 bytes)
        # Offset 32-35: Number of sprites (4 bytes)
        # Offset 36-39: Number of palettes (4 bytes) 
        # Offset 40-43: Sprite data offset (4 bytes)
        # Offset 44-47: Palette data offset (4 bytes)
        
        reserved_data = header[16:32]
        print(f"📝 Reserved data: {reserved_data.hex()}")
        
        # Parse remaining header fields (all big-endian for SFF v2)
        sprite_count = struct.unpack('>I', header[32:36])[0]
        palette_count = struct.unpack('>I', header[36:40])[0]
        sprite_offset = struct.unpack('>I', header[40:44])[0]
        palette_offset = struct.unpack('>I', header[44:48])[0]
        
        print(f"📊 Sprite count: {sprite_count}")
        print(f"📊 Palette count: {palette_count}")
        print(f"📊 Sprite offset: {sprite_offset}")
        print(f"📊 Palette offset: {palette_offset}")
        
        # Validate offsets
        if sprite_offset > file_size or palette_offset > file_size:
            print("❌ Invalid offsets detected")
            return
        
        if sprite_count == 0:
            print("❌ No sprites found in file")
            return
        
        # Read first sprite header
        print(f"\n🎯 Reading sprite headers starting at offset {sprite_offset}:")
        f.seek(sprite_offset)
        
        for i in range(min(5, sprite_count)):
            pos = f.tell()
            print(f"\n--- Sprite {i} (at offset {pos}) ---")
            
            sprite_header = f.read(28)  # 26 bytes + 2 padding
            if len(sprite_header) < 28:
                print("❌ Incomplete sprite header")
                break
            
            # Parse sprite header (big-endian)
            group, image, x, y, width, height, linked_index, format_val, color_depth, data_offset, length = struct.unpack('>HHHHHHHBBI', sprite_header[:26])
            
            print(f"  Group: {group}, Image: {image}")
            print(f"  Position: ({x}, {y})")
            print(f"  Size: {width}x{height}")
            print(f"  Format: {format_val}")
            print(f"  Color depth: {color_depth}")
            print(f"  Data offset: {data_offset}")
            print(f"  Length: {length}")
            print(f"  Linked: {linked_index}")
            
            # Check sprite data
            if format_val == 10:  # PNG
                current_pos = f.tell()
                f.seek(data_offset)
                sprite_data = f.read(min(16, length))
                
                png_sig = b'\x89PNG\r\n\x1a\n'
                if sprite_data.startswith(png_sig):
                    print("  ✅ Valid PNG data")
                else:
                    print(f"  ❌ Invalid PNG data: {sprite_data.hex()}")
                
                f.seek(current_pos)

if __name__ == "__main__":
    analyze_sff_structure()
