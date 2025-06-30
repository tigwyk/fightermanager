#!/usr/bin/env python3
"""
Analyze compression formats used in MUGEN SFF files
"""
import os
import struct

def analyze_compression_formats():
    """Analyze what compression formats are used in our character files"""
    
    chars_dir = "g:/GameDev/fightermanager/assets/mugen/chars"
    
    if not os.path.exists(chars_dir):
        print(f"Characters directory not found: {chars_dir}")
        return
    
    format_names = {
        0: "Raw",
        2: "RLE8", 
        3: "RLE5",
        4: "LZ5",
        10: "PNG"
    }
    
    total_stats = {}
    
    for char_dir in os.listdir(chars_dir):
        char_path = os.path.join(chars_dir, char_dir)
        if not os.path.isdir(char_path):
            continue
            
        sff_file = os.path.join(char_path, f"{char_dir}.sff")
        if not os.path.exists(sff_file):
            # Try other variations
            for f in os.listdir(char_path):
                if f.endswith('.sff'):
                    sff_file = os.path.join(char_path, f)
                    break
            else:
                continue
        
        print(f"\n--- Analyzing {char_dir} ---")
        
        try:
            with open(sff_file, 'rb') as f:
                # Read header
                signature = f.read(12)
                if signature != b'ElecbyteSpr\x00':
                    print(f"  Invalid signature: {signature}")
                    continue
                
                # Read version
                ver_bytes = f.read(4)
                version = ver_bytes[3]  # Major version
                
                if version == 1:
                    print(f"  SFF v1 - skipping detailed analysis")
                    continue
                elif version != 2:
                    print(f"  Unknown version: {version}")
                    continue
                
                f.read(4)  # Skip reserved
                f.read(16)  # Skip dummy data
                
                subheader_offset = struct.unpack('<I', f.read(4))[0]
                image_count = struct.unpack('<I', f.read(4))[0]
                
                print(f"  SFF v2, {image_count} sprites")
                
                # Analyze sprite formats
                f.seek(subheader_offset)
                format_counts = {}
                
                for i in range(min(100, image_count)):  # Sample first 100 sprites
                    try:
                        # Read 28-byte header
                        group = struct.unpack('<H', f.read(2))[0]
                        image = struct.unpack('<H', f.read(2))[0]
                        width = struct.unpack('<H', f.read(2))[0]
                        height = struct.unpack('<H', f.read(2))[0]
                        x_offset = struct.unpack('<h', f.read(2))[0]
                        y_offset = struct.unpack('<h', f.read(2))[0]
                        link = struct.unpack('<H', f.read(2))[0]
                        format_byte = f.read(1)[0]
                        color_depth = f.read(1)[0]
                        data_offset = struct.unpack('<I', f.read(4))[0]
                        data_length = struct.unpack('<I', f.read(4))[0]
                        f.read(4)  # Skip palette_index and flags and padding
                        
                        # Validate sprite
                        if (0 <= group <= 10000 and 0 <= image <= 10000 and
                            1 <= width <= 2000 and 1 <= height <= 2000 and
                            format_byte in [0, 2, 3, 4, 10]):
                            
                            if format_byte not in format_counts:
                                format_counts[format_byte] = 0
                            format_counts[format_byte] += 1
                            
                            if format_byte not in total_stats:
                                total_stats[format_byte] = 0
                            total_stats[format_byte] += 1
                        else:
                            break  # Stop on invalid sprite
                    except:
                        break
                
                # Report formats for this character
                for format_id in sorted(format_counts.keys()):
                    format_name = format_names.get(format_id, f"Unknown({format_id})")
                    print(f"    Format {format_id} ({format_name}): {format_counts[format_id]} sprites")
                    
        except Exception as e:
            print(f"  Error: {e}")
    
    # Report overall statistics
    print(f"\n=== OVERALL COMPRESSION FORMAT USAGE ===")
    total_sprites = sum(total_stats.values())
    
    for format_id in sorted(total_stats.keys()):
        count = total_stats[format_id]
        percentage = (count / total_sprites) * 100
        format_name = format_names.get(format_id, f"Unknown({format_id})")
        print(f"Format {format_id} ({format_name}): {count} sprites ({percentage:.1f}%)")
    
    print(f"\nTotal sprites analyzed: {total_sprites}")

if __name__ == "__main__":
    analyze_compression_formats()
