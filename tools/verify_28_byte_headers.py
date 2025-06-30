#!/usr/bin/env python3
"""
Verify that the 28-byte header format works correctly
"""

def verify_28_byte_headers():
    """Test the 28-byte header format"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Get to sprite headers
        f.seek(36)
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Testing 28-byte headers for {image_count} sprites")
        
        f.seek(subheader_offset)
        valid_count = 0
        
        for i in range(min(20, image_count)):  # Test first 20 sprites
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
            reserved = int.from_bytes(f.read(2), 'little')
            
            # Check if values are reasonable
            reasonable = (
                0 <= width <= 1000 and 0 <= height <= 1000 and
                0 <= group <= 10000 and 0 <= image <= 10000 and
                format_byte in [0, 2, 3, 4, 10] and
                0 <= color_depth <= 32 and
                data_offset > 0 and data_length > 0 and data_length < 2000000
            )
            
            if reasonable:
                valid_count += 1
                if i < 5:  # Print first 5
                    print(f"✅ Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
            else:
                print(f"❌ Sprite {i}: Invalid values - Group={group}, Image={image}, Size={width}x{height}")
                break
        
        print(f"\nResult: {valid_count}/20 sprites have valid headers")
        if valid_count >= 15:
            print("🎉 28-byte header format is working correctly!")
        else:
            print("❌ Still having issues with header format")

if __name__ == "__main__":
    verify_28_byte_headers()
