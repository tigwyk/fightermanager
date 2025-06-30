#!/usr/bin/env python3
"""
Precise byte analysis of SFF sprite headers
"""

def precise_byte_analysis():
    """Count exact bytes for sprite headers"""
    file_path = "g:/GameDev/fightermanager/assets/mugen/chars/Guile/Guile.sff"
    
    with open(file_path, 'rb') as f:
        f.seek(36)
        subheader_offset = int.from_bytes(f.read(4), 'little')
        
        print(f"Starting sprite header analysis at offset {subheader_offset}")
        
        f.seek(subheader_offset)
        
        # Read first sprite with precise byte counting
        pos = f.tell()
        print(f"\nFirst sprite at {pos}:")
        
        group = int.from_bytes(f.read(2), 'little')           # 2 bytes
        image = int.from_bytes(f.read(2), 'little')          # 2 bytes  
        width = int.from_bytes(f.read(2), 'little')          # 2 bytes
        height = int.from_bytes(f.read(2), 'little')         # 2 bytes
        x_offset = int.from_bytes(f.read(2), 'little', signed=True)  # 2 bytes
        y_offset = int.from_bytes(f.read(2), 'little', signed=True)  # 2 bytes
        link = int.from_bytes(f.read(2), 'little')           # 2 bytes
        format_byte = f.read(1)[0]                           # 1 byte
        color_depth = f.read(1)[0]                           # 1 byte
        data_offset = int.from_bytes(f.read(4), 'little')    # 4 bytes
        data_length = int.from_bytes(f.read(4), 'little')    # 4 bytes
        palette_index = int.from_bytes(f.read(2), 'little')  # 2 bytes
        flags = int.from_bytes(f.read(2), 'little')          # 2 bytes
        
        # Total so far: 2+2+2+2+2+2+2+1+1+4+4+2+2 = 26 bytes
        
        current_pos = f.tell()
        bytes_read = current_pos - pos
        print(f"Bytes read so far: {bytes_read}")
        print(f"Group: {group}, Image: {image}, Size: {width}x{height}")
        
        # Check what comes next
        next_bytes = f.read(10)
        print(f"Next 10 bytes: {next_bytes.hex()}")
        
        # Try to find where second sprite starts by looking for Group=0, Image=1
        f.seek(pos + 26)  # Skip exact 26 bytes
        test_group = int.from_bytes(f.read(2), 'little')
        test_image = int.from_bytes(f.read(2), 'little')
        print(f"At +26 bytes: Group={test_group}, Image={test_image}")
        
        f.seek(pos + 28)  # Skip 28 bytes
        test_group = int.from_bytes(f.read(2), 'little')
        test_image = int.from_bytes(f.read(2), 'little')
        print(f"At +28 bytes: Group={test_group}, Image={test_image}")
        
        f.seek(pos + 30)  # Skip 30 bytes
        test_group = int.from_bytes(f.read(2), 'little')
        test_image = int.from_bytes(f.read(2), 'little')
        print(f"At +30 bytes: Group={test_group}, Image={test_image}")
        
        f.seek(pos + 32)  # Skip 32 bytes
        test_group = int.from_bytes(f.read(2), 'little')
        test_image = int.from_bytes(f.read(2), 'little')
        print(f"At +32 bytes: Group={test_group}, Image={test_image}")

if __name__ == "__main__":
    precise_byte_analysis()
