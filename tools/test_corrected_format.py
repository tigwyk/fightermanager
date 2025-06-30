#!/usr/bin/env python3
"""
Test the corrected 28-byte header format (26 bytes + 2 padding)
"""

def test_corrected_format():
    """Test reading sprites with the corrected format"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        f.seek(36)
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Testing corrected format for {image_count} sprites")
        print(f"Header size: 26 bytes + 2 padding = 28 bytes total")
        
        f.seek(subheader_offset)
        valid_count = 0
        
        for i in range(min(10, image_count)):
            pos = f.tell()
            
            # Read 26-byte header + 2 padding
            group = int.from_bytes(f.read(2), 'little')
            image = int.from_bytes(f.read(2), 'little')
            width = int.from_bytes(f.read(2), 'little')
            height = int.from_bytes(f.read(2), 'little')
            x_offset = int.from_bytes(f.read(2), 'little', signed=True)
            y_offset = int.from_bytes(f.read(2), 'little', signed=True)
            link = int.from_bytes(f.read(2), 'little')
            format_byte = f.read(1)[0]
            color_depth = f.read(1)[0]
            data_offset = int.from_bytes(f.read(4), 'little')
            data_length = int.from_bytes(f.read(4), 'little')
            palette_index = int.from_bytes(f.read(2), 'little')
            flags = int.from_bytes(f.read(2), 'little')
            padding = int.from_bytes(f.read(2), 'little')  # 2 bytes padding
            
            # Validate sprite
            if (0 <= group <= 10000 and 0 <= image <= 10000 and
                1 <= width <= 1000 and 1 <= height <= 1000 and
                format_byte in [0, 2, 3, 4, 10] and
                0 <= color_depth <= 32 and
                data_offset > 0 and data_length > 0 and data_length < 2000000):
                
                valid_count += 1
                print(f"✅ Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}, Offset={data_offset}, Length={data_length}")
            else:
                print(f"❌ Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                break
        
        print(f"\nResult: {valid_count}/10 sprites are valid")
        if valid_count >= 8:
            print("🎉 The corrected format is working!")
        else:
            print("❌ Still having issues")
        
        return valid_count >= 8

if __name__ == "__main__":
    test_corrected_format()
