#!/usr/bin/env python3
"""
Analyze PNG parsing errors in Guile SFF file
Check sprite formats and data to understand why PNG parsing is failing
"""

import struct
import os

def analyze_guile_sff():
    """Analyze Guile's SFF file to understand PNG parsing errors"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    if not os.path.exists(guile_sff_path):
        print(f"❌ File not found: {guile_sff_path}")
        return
    
    with open(guile_sff_path, 'rb') as f:
        # Read SFF v2 header
        signature = f.read(12)
        print(f"🔍 SFF signature: {signature}")
        
        if signature != b'ElecbyteSpr\x00':
            print("❌ Invalid SFF signature")
            return
        
        version_bytes = f.read(4)
        version_le = struct.unpack('<I', version_bytes)[0]
        version_be = struct.unpack('>I', version_bytes)[0]
        print(f"📋 SFF version (LE): {version_le}")
        print(f"📋 SFF version (BE): {version_be}")
        print(f"📋 Version bytes: {version_bytes.hex()}")
        
        # Try both byte orders
        version = version_le if version_le in [1, 2] else version_be
        print(f"📋 Using version: {version}")
        
        if version not in [1, 2]:
            print("❌ Unrecognized SFF version")
            return
        
        # Skip dummy data (16 bytes)
        f.seek(16, 1)
        
        # Read remaining header - use big-endian since version was big-endian
        sprite_count = struct.unpack('>I', f.read(4))[0]
        palette_count = struct.unpack('>I', f.read(4))[0]
        sprite_offset = struct.unpack('>I', f.read(4))[0]
        palette_offset = struct.unpack('>I', f.read(4))[0]
        
        print(f"📊 Sprite count: {sprite_count}")
        print(f"📊 Palette count: {palette_count}")
        print(f"📊 Sprite offset: {sprite_offset}")
        print(f"📊 Palette offset: {palette_offset}")
        
        # Read first few sprite headers
        f.seek(sprite_offset)
        
        print("\n🎯 Analyzing first 10 sprite headers:")
        
        for i in range(min(10, sprite_count)):
            pos = f.tell()
            print(f"\n--- Sprite {i} (at offset {pos}) ---")
            
            # Read 26-byte header - use big-endian
            header_data = f.read(26)
            if len(header_data) < 26:
                print("❌ Incomplete header")
                break
            
            # Parse header with big-endian
            group, image, x, y, width, height, linked_index, format_value, color_depth, data_offset, length = struct.unpack('>HHHHHHHBBL', header_data)
            
            print(f"  Group: {group}, Image: {image}")
            print(f"  Position: ({x}, {y})")
            print(f"  Size: {width}x{height}")
            print(f"  Format: {format_value}")
            print(f"  Color depth: {color_depth}")
            print(f"  Data offset: {data_offset}")
            print(f"  Data length: {length}")
            print(f"  Linked index: {linked_index}")
            
            # Check if this sprite claims to be PNG (format 10)
            if format_value == 10:
                print("  🖼️ Claimed format: PNG")
                
                # Save current position
                current_pos = f.tell()
                
                # Go to sprite data and check if it's actually PNG
                f.seek(data_offset)
                png_header = f.read(8)
                
                # PNG signature: 89 50 4E 47 0D 0A 1A 0A
                png_signature = b'\x89PNG\r\n\x1a\n'
                
                if png_header == png_signature:
                    print("  ✅ Data is actually PNG")
                else:
                    print(f"  ❌ Data is NOT PNG! First 8 bytes: {png_header.hex()}")
                    
                    # Check if it might be compressed data
                    # RLE8 typically starts with control bytes
                    if len(png_header) >= 2:
                        first_byte = png_header[0]
                        second_byte = png_header[1]
                        print(f"     First byte: {first_byte:02X} ({first_byte})")
                        print(f"     Second byte: {second_byte:02X} ({second_byte})")
                        
                        # Common patterns for RLE8:
                        # - First byte is often 0 (literal run) or small value (RLE run)
                        # - If first byte is 0, second byte is literal count
                        if first_byte == 0:
                            print(f"     Looks like RLE8 literal run with {second_byte} bytes")
                        elif first_byte < 128:
                            print(f"     Looks like RLE8 run of {first_byte} copies")
                        else:
                            print("     Unknown compression pattern")
                
                # Restore position
                f.seek(current_pos)
            else:
                format_names = {0: "Raw", 2: "RLE8", 3: "RLE5", 4: "LZ5", 10: "PNG", 11: "PNG", 12: "PNG"}
                format_name = format_names.get(format_value, f"Unknown({format_value})")
                print(f"  📋 Format: {format_name}")
            
            # Skip padding (2 bytes)
            f.seek(2, 1)
        
        print("\n📊 Summary:")
        print(f"Total sprites analyzed: {min(10, sprite_count)}")
        
        # Count sprites by format
        f.seek(sprite_offset)
        format_counts = {}
        
        for i in range(sprite_count):
            header_data = f.read(26)
            if len(header_data) < 26:
                break
            
            format_value = struct.unpack('>B', header_data[15:16])[0]
            format_counts[format_value] = format_counts.get(format_value, 0) + 1
            
            # Skip padding
            f.seek(2, 1)
        
        print("Format distribution:")
        format_names = {0: "Raw", 2: "RLE8", 3: "RLE5", 4: "LZ5", 10: "PNG", 11: "PNG", 12: "PNG"}
        for format_val, count in format_counts.items():
            format_name = format_names.get(format_val, f"Unknown({format_val})")
            print(f"  {format_name}: {count} sprites")

if __name__ == "__main__":
    print("🔬 Analyzing PNG parsing errors in Guile SFF...")
    analyze_guile_sff()
