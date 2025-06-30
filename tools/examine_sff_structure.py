#!/usr/bin/env python3
"""
Examine the structure around the palette area and look for sprite indices
"""

def examine_sff_structure():
    """Look at the overall SFF v2 structure"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        # Get basic info
        f.seek(36)
        subheader_offset = int.from_bytes(f.read(4), 'little')
        image_count = int.from_bytes(f.read(4), 'little') 
        palette_offset = int.from_bytes(f.read(4), 'little')
        num_palettes = int.from_bytes(f.read(4), 'little')
        lofs = int.from_bytes(f.read(4), 'little')
        f.read(4)  # dummy
        tofs = int.from_bytes(f.read(4), 'little')
        
        print(f"SFF v2 Structure:")
        print(f"  Sprite headers at: {subheader_offset}")
        print(f"  Image count: {image_count}")
        print(f"  Palette data at: {palette_offset}")
        print(f"  Number of palettes: {num_palettes}")
        print(f"  lofs (low data): {lofs}")
        print(f"  tofs (high data): {tofs}")
        
        file_size = f.seek(0, 2)  # Go to end
        print(f"  File size: {file_size}")
        
        # Check if there might be an index or directory after the palettes
        expected_palette_size = num_palettes * 1024  # Typical palette size
        sprite_index_start = palette_offset + expected_palette_size
        
        print(f"\nLooking for sprite index after palettes at offset {sprite_index_start}:")
        
        # The sprite directory might be after the palettes
        for test_offset in [sprite_index_start, lofs, tofs]:
            if test_offset > file_size:
                continue
                
            print(f"\n--- Testing sprite directory at {test_offset} ---")
            f.seek(test_offset)
            
            # Check if this looks like sprite indices (4 bytes each pointing to sprite headers)
            indices_look_valid = True
            sprite_header_positions = []
            
            for i in range(min(10, image_count)):
                try:
                    index_value = int.from_bytes(f.read(4), 'little')
                    
                    # Check if this could be a valid offset in the file
                    if subheader_offset <= index_value < file_size:
                        sprite_header_positions.append(index_value)
                        if i < 5:
                            print(f"  Index {i}: {index_value} (looks valid)")
                    else:
                        if i < 5:
                            print(f"  Index {i}: {index_value} (invalid - outside file bounds)")
                        indices_look_valid = False
                        break
                        
                except:
                    indices_look_valid = False
                    break
            
            if indices_look_valid and len(sprite_header_positions) >= 3:
                print(f"  🎉 Found valid sprite header index at {test_offset}!")
                
                # Test reading sprites from these positions
                print(f"\n  Testing sprite headers from indexed positions:")
                for i, pos in enumerate(sprite_header_positions[:3]):
                    f.seek(pos)
                    
                    try:
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
                        
                        print(f"    Sprite {i}: Group={group}, Image={image}, Size={width}x{height}, Format={format_byte}")
                        
                        if (0 <= group <= 10000 and 0 <= image <= 10000 and
                            1 <= width <= 1000 and 1 <= height <= 1000 and
                            format_byte in [0, 2, 3, 4, 10]):
                            print(f"      ✅ Valid sprite!")
                        else:
                            print(f"      ❌ Invalid sprite data")
                            
                    except Exception as e:
                        print(f"    Error reading sprite {i}: {e}")
                
                return test_offset  # Found it!
        
        # If no indexed directory found, maybe the sprites are just concatenated differently
        print(f"\nNo indexed directory found. The sprites might be stored in a different format.")
        print(f"Checking if there's a simple sequential format with variable headers...")
        
        # Check around the first sprite to see if we can find the second one manually
        f.seek(subheader_offset)
        
        # Read first sprite completely
        first_sprite_data = f.read(32)  # Read extra to be safe
        print(f"\nFirst sprite raw data:")
        print(" ".join(f"{b:02X}" for b in first_sprite_data))
        
        # Try to find patterns that might indicate where the second sprite starts
        print(f"\nSearching for second sprite starting from offset {subheader_offset + 20}...")
        
        for offset in range(20, 60, 2):  # Try every 2 bytes
            f.seek(subheader_offset + offset)
            try:
                # Look for group=0, image=1 (expected second sprite)
                potential_group = int.from_bytes(f.read(2), 'little') 
                potential_image = int.from_bytes(f.read(2), 'little')
                
                if potential_group == 0 and potential_image == 1:
                    print(f"  Found potential second sprite (0,1) at offset +{offset}")
                    
                    # Read the rest to validate
                    width = int.from_bytes(f.read(2), 'little')
                    height = int.from_bytes(f.read(2), 'little')
                    
                    if 1 <= width <= 1000 and 1 <= height <= 1000:
                        print(f"    Size: {width}x{height} - looks valid!")
                        return subheader_offset + offset
                    
            except:
                pass
        
        return None

if __name__ == "__main__":
    result = examine_sff_structure()
    if result:
        print(f"\n🎉 SOLUTION: Use offset {result} for sprite directory!")
    else:
        print(f"\n❌ Could not determine correct sprite directory format")
