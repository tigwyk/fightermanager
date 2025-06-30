"""
Analyze Guile SFF file to understand the loading issue
"""

import struct

def analyze_sff_header(file_path):
    """Manually analyze SFF header bytes using correct Ikemen GO layout"""
    print(f"🔍 ANALYZING SFF HEADER: {file_path}")
    
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
            
            if detected_version == 1:
                print("\n--- SFF v1 Header Analysis ---")
                
                first_palette_offset = struct.unpack('<I', f.read(4))[0]
                num_palettes = struct.unpack('<I', f.read(4))[0]
                image_count = struct.unpack('<I', f.read(4))[0]
                subheader_offset = struct.unpack('<I', f.read(4))[0]
                subheader_length = struct.unpack('<I', f.read(4))[0]
                
                print(f"📊 First palette offset: {first_palette_offset}")
                print(f"📊 Number of palettes: {num_palettes}")
                print(f"📊 Images: {image_count}")
                print(f"📍 Subheader offset: {subheader_offset} (0x{subheader_offset:X})")
                print(f"📏 Subheader length: {subheader_length}")
                
                # Validate the header makes sense
                if 0 < image_count < 10000:
                    print("✅ Image count looks reasonable")
                else:
                    print(f"❌ Image count looks suspicious: {image_count}")
                    
                if 40 <= subheader_offset < file_size:
                    print("✅ Subheader offset looks reasonable")
                else:
                    print(f"❌ Subheader offset looks suspicious: {subheader_offset}")
                    
                # Try to read first sprite entry
                if subheader_offset > 0 and subheader_offset < file_size:
                    print("\n--- First Sprite Entry Analysis (SFF v1) ---")
                    f.seek(subheader_offset)
                    
                    next_offset = struct.unpack('<I', f.read(4))[0]
                    length = struct.unpack('<I', f.read(4))[0]
                    x = struct.unpack('<h', f.read(2))[0]  # signed 16-bit
                    y = struct.unpack('<h', f.read(2))[0]  # signed 16-bit
                    group = struct.unpack('<H', f.read(2))[0]
                    image = struct.unpack('<H', f.read(2))[0]
                    linked_index = struct.unpack('<H', f.read(2))[0]
                    palette_type = struct.unpack('<B', f.read(1))[0]
                    
                    print(f"🔗 Next offset: {next_offset}")
                    print(f"📏 Length: {length}")
                    print(f"📍 Position: ({x}, {y})")
                    print(f"🏷️ Group/Image: {group}/{image}")
                    print(f"🔗 Linked index: {linked_index}")
                    print(f"🎨 Palette type: {palette_type}")
                    
            elif detected_version == 2:
                print("\n--- SFF v2 Header Analysis ---")
                
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
                    
            else:
                print(f"❌ Unknown SFF version: {detected_version}")
                
    except Exception as e:
        print(f"❌ Error reading file: {e}")

if __name__ == "__main__":
    # Analyze Guile SFF file
    guile_sff_path = r"g:\GameDev\fightermanager\assets\mugen\chars\Guile\Guile.sff"
    analyze_sff_header(guile_sff_path)
