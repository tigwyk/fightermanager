#!/usr/bin/env python3
"""
Try different struct formats for sprite headers
"""

import struct
import os

def try_different_formats():
    """Try different struct formats for parsing sprite headers"""
    
    # Test with KFM first since it's simpler
    kfm_path = "../assets/mugen/chars/kfm/kfm.sff"
    offset = 624
    
    if not os.path.exists(kfm_path):
        print("KFM file not found")
        return
    
    with open(kfm_path, 'rb') as f:
        f.seek(offset)
        header_data = f.read(32)  # Read more than 26 bytes
        
        print("🔍 Raw header bytes:")
        print(" ".join(f"{b:02X}" for b in header_data))
        
        print("\n🧪 Trying different struct formats:")
        
        # Format 1: Original (little-endian, HHHHHHHBBI)
        try:
            values = struct.unpack('<HHHHHHHBBI', header_data[:26])
            print(f"1. <HHHHHHHBBI: {values}")
        except:
            print("1. <HHHHHHHBBI: Failed")
        
        # Format 2: Big-endian
        try:
            values = struct.unpack('>HHHHHHHBBI', header_data[:26])
            print(f"2. >HHHHHHHBBI: {values}")
        except:
            print("2. >HHHHHHHBBI: Failed")
        
        # Format 3: All as bytes, then combine
        print("\n🔬 Manual byte parsing:")
        if len(header_data) >= 26:
            group = struct.unpack('<H', header_data[0:2])[0]
            image = struct.unpack('<H', header_data[2:4])[0]
            x = struct.unpack('<H', header_data[4:6])[0]
            y = struct.unpack('<H', header_data[6:8])[0]
            width = struct.unpack('<H', header_data[8:10])[0]
            height = struct.unpack('<H', header_data[10:12])[0]
            linked = struct.unpack('<H', header_data[12:14])[0]
            format_val = header_data[14]
            color_depth = header_data[15]
            data_offset = struct.unpack('<I', header_data[16:20])[0]
            length = struct.unpack('<I', header_data[20:24])[0]
            
            print(f"Manual LE: Group={group}, Image={image}, Size={width}x{height}")
            print(f"         Format={format_val}, Depth={color_depth}, Offset={data_offset}, Length={length}")
        
        # Format 4: Try big-endian for 32-bit values
        if len(header_data) >= 26:
            group = struct.unpack('<H', header_data[0:2])[0]
            image = struct.unpack('<H', header_data[2:4])[0]
            x = struct.unpack('<H', header_data[4:6])[0]
            y = struct.unpack('<H', header_data[6:8])[0]
            width = struct.unpack('<H', header_data[8:10])[0]
            height = struct.unpack('<H', header_data[10:12])[0]
            linked = struct.unpack('<H', header_data[12:14])[0]
            format_val = header_data[14]
            color_depth = header_data[15]
            data_offset = struct.unpack('>I', header_data[16:20])[0]  # Big-endian
            length = struct.unpack('>I', header_data[20:24])[0]       # Big-endian
            
            print(f"Mixed:   Group={group}, Image={image}, Size={width}x{height}")
            print(f"         Format={format_val}, Depth={color_depth}, Offset={data_offset}, Length={length}")

if __name__ == "__main__":
    try_different_formats()
