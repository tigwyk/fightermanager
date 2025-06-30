"""
Corrected SFF Header Analysis for KFM file using Ikemen GO header layout
"""

import struct

def analyze_sff_header(file_path):
    """Manually analyze SFF header bytes using correct Ikemen GO layout"""
    print(f"🔍 ANALYZING SFF HEADER (CORRECTED): {file_path}")
    
    try:
        with open(file_path, 'rb') as f:
            # Read first 70 bytes for full analysis
            f.seek(0)
            header_data = f.read(70)
            
            file_size = f.seek(0, 2)  # Seek to end to get size
            f.seek(0)  # Back to start
            
            print(f"📁 File size: {file_size} bytes")
            print("🔢 First 70 bytes (hex):")
            
            # Print hex dump
            for i in range(0, len(header_data), 16):
                hex_str = ' '.join(f'{b:02X}' for b in header_data[i:i+16])
                ascii_str = ''.join(chr(b) if 32 <= b <= 126 else '.' for b in header_data[i:i+16])
                print(f"  {i:04X}: {hex_str:<48} | {ascii_str}")
            
            print()
            
            # Parse signature (12 bytes)
            f.seek(0)
            signature_bytes = f.read(12)
            signature = signature_bytes[:11].decode('ascii', errors='replace')  # Skip null terminator
            print(f"📋 Signature: '{signature}'")
            
            # Read version bytes (little-endian)
            ver3 = struct.unpack('<B', f.read(1))[0]
            ver2 = struct.unpack('<B', f.read(1))[0]
            ver1 = struct.unpack('<B', f.read(1))[0]
            ver0 = struct.unpack('<B', f.read(1))[0]
            
            print(f"🔢 Version bytes: Ver3={ver3}, Ver2={ver2}, Ver1={ver1}, Ver0={ver0}")
            
            # Determine version (Ver0 is the key)
            detected_version = ver0
            print(f"🎯 Detected SFF version: v{detected_version}")
            
            # Skip reserved bytes (4 bytes) 
            f.read(4)
            
            if detected_version == 2:
                print("\n--- SFF v2 Header Analysis (CORRECTED) ---")
                
                # Ikemen GO SFF v2 header layout:
                # Position 20-35: 16 bytes of dummy/reserved data (skip 4 x 4 bytes)
                # Position 36: First sprite header offset (4 bytes)  
                # Position 40: Number of sprites (4 bytes)
                # Position 44: First palette header offset (4 bytes)
                # Position 48: Number of palettes (4 bytes)
                # Position 52: Low data offset (4 bytes)
                # Position 56: 4 bytes dummy (skip)
                # Position 60: High data offset (4 bytes)
                
                print(f"Current position: {f.tell()}")
                
                # Skip 16 bytes of dummy/reserved data (4 x 4 bytes)
                dummy1 = struct.unpack('<I', f.read(4))[0]
                dummy2 = struct.unpack('<I', f.read(4))[0]
                dummy3 = struct.unpack('<I', f.read(4))[0]
                dummy4 = struct.unpack('<I', f.read(4))[0]
                
                print(f"After skipping 16 dummy bytes, position: {f.tell()}")
                
                subheader_offset = struct.unpack('<I', f.read(4))[0]
                image_count = struct.unpack('<I', f.read(4))[0]
                palette_offset = struct.unpack('<I', f.read(4))[0]
                num_palettes = struct.unpack('<I', f.read(4))[0]
                lofs = struct.unpack('<I', f.read(4))[0]
                dummy5 = struct.unpack('<I', f.read(4))[0]
                tofs = struct.unpack('<I', f.read(4))[0]
                
                print(f"🔧 Dummy bytes: {dummy1}, {dummy2}, {dummy3}, {dummy4}, {dummy5}")
                print(f"📍 Subheader offset: {subheader_offset} (0x{subheader_offset:X})")
                print(f"📊 Images: {image_count}")
                print(f"🎨 Palette offset: {palette_offset}")
                print(f"🎨 Number of palettes: {num_palettes}")
                print(f"📦 Low data offset: {lofs}")
                print(f"📦 High data offset: {tofs}")
                
                # Validate the header makes sense
                if 0 < image_count < 10000:
                    print("✅ Image count looks reasonable")
                else:
                    print(f"❌ Image count looks suspicious: {image_count}")
                    
                if 64 <= subheader_offset < file_size:
                    print("✅ Subheader offset looks reasonable")
                else:
                    print(f"❌ Subheader offset looks suspicious: {subheader_offset}")
                    
                # Try to read first sprite entry for SFF v2
                if subheader_offset > 0 and subheader_offset < file_size:
                    print("\n--- First Sprite Entry Analysis (SFF v2) ---")
                    f.seek(subheader_offset)
                    
                    # SFF v2 sprite header format (28 bytes per entry):
                    # Group (2), Number (2), Width (2), Height (2), X offset (2), Y offset (2)
                    # Index link (2), Format (1), Color depth (1), Data offset (4), Data length (4)
                    # Palette index (2), Flags (2)
                    
                    group = struct.unpack('<H', f.read(2))[0]
                    image_num = struct.unpack('<H', f.read(2))[0]
                    width = struct.unpack('<H', f.read(2))[0]
                    height = struct.unpack('<H', f.read(2))[0]
                    x = struct.unpack('<h', f.read(2))[0]  # signed
                    y = struct.unpack('<h', f.read(2))[0]  # signed
                    link = struct.unpack('<H', f.read(2))[0]
                    format_type = struct.unpack('<B', f.read(1))[0]
                    color_depth = struct.unpack('<B', f.read(1))[0]
                    data_offset = struct.unpack('<I', f.read(4))[0]
                    data_length = struct.unpack('<I', f.read(4))[0]
                    palette_index = struct.unpack('<H', f.read(2))[0]
                    flags = struct.unpack('<H', f.read(2))[0]
                    
                    print(f"🏷️ Group/Image: {group}/{image_num}")
                    print(f"📏 Size: {width}x{height}")
                    print(f"📍 Position: ({x}, {y})")
                    print(f"🔗 Link: {link}")
                    print(f"🎨 Format: {format_type} (0=raw, 10=PNG)")
                    print(f"🎨 Color depth: {color_depth}")
                    print(f"📦 Data offset: {data_offset}")
                    print(f"📏 Data length: {data_length}")
                    print(f"🎨 Palette index: {palette_index}")
                    print(f"🏳️ Flags: {flags}")
                    
                    # Check if the sprite data seems reasonable
                    final_offset = data_offset
                    if flags & 1 == 0:
                        final_offset += lofs
                    else:
                        final_offset += tofs
                        
                    print(f"📍 Final data offset: {final_offset}")
                    
                    if final_offset < file_size and data_length > 0 and data_length < file_size:
                        print("✅ Sprite data looks reasonable")
                    else:
                        print("❌ Sprite data looks suspicious")
                        
            else:
                print(f"❌ Expected SFF v2, got v{detected_version}")
                
    except Exception as e:
        print(f"❌ Error reading file: {e}")

if __name__ == "__main__":
    # Analyze KFM SFF file
    kfm_sff_path = r"g:\GameDev\fightermanager\assets\mugen\chars\kfm\kfm.sff"
    analyze_sff_header(kfm_sff_path)
