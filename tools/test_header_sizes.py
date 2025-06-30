#!/usr/bin/env python3
"""
Test different header sizes to find the correct alignment
"""

def test_header_sizes():
    """Test various header sizes to find correct alignment"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Read main header first
        f.seek(0)
        signature = f.read(12)
        ver3, ver2, ver1, ver0 = f.read(4)
        f.read(4)  # Skip reserved
        f.read(16)  # Skip dummy data
        
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little')
        
        print(f"Subheader offset: {subheader_offset}")
        print(f"Image count: {image_count}")
        
        # Test different header sizes
        test_sizes = [20, 22, 24, 26, 28, 30, 32]
        
        for header_size in test_sizes:
            print(f"\n--- Testing header size: {header_size} bytes ---")
            
            f.seek(subheader_offset)
            valid_count = 0
            
            for sprite_num in range(min(5, image_count)):
                pos = f.tell()
                
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
                
                # Read remaining bytes based on header size
                remaining = header_size - 26
                if remaining > 0:
                    extra_data = f.read(remaining)
                
                # Validation check
                valid = (
                    0 <= group <= 10000 and 
                    0 <= image <= 10000 and
                    0 < width < 2000 and 
                    0 < height < 2000 and
                    format_byte in [0, 2, 3, 4, 10] and
                    data_offset > 0 and data_length > 0
                )
                
                if valid:
                    valid_count += 1
                    print(f"  ✅ Sprite {sprite_num}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                else:
                    print(f"  ❌ Sprite {sprite_num}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                
                # Move to next sprite position
                f.seek(pos + header_size)
            
            print(f"Valid sprites found with {header_size}-byte headers: {valid_count}/5")

if __name__ == "__main__":
    test_header_sizes()
