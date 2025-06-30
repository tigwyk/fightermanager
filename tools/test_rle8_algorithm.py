#!/usr/bin/env python3
"""
Test RLE8 decompression implementation for MUGEN SFF files
This script validates the RLE8 algorithm against known test cases
"""

def decompress_rle8_python(compressed_data, expected_size):
    """Python implementation of RLE8 decompression for validation"""
    decompressed = bytearray()
    i = 0
    
    while i < len(compressed_data) and len(decompressed) < expected_size:
        control_byte = compressed_data[i]
        i += 1
        
        if i >= len(compressed_data):
            break
        
        if control_byte == 0:
            # Literal run: next byte is count, followed by that many literal bytes
            count = compressed_data[i]
            i += 1
            
            for j in range(count):
                if i >= len(compressed_data) or len(decompressed) >= expected_size:
                    break
                decompressed.append(compressed_data[i])
                i += 1
        else:
            # RLE run: control_byte is count, next byte is the value to repeat
            value = compressed_data[i]
            i += 1
            
            for j in range(control_byte):
                if len(decompressed) >= expected_size:
                    break
                decompressed.append(value)
    
    return bytes(decompressed)

def test_rle8_cases():
    """Test various RLE8 compression cases"""
    print("🧪 Testing RLE8 decompression algorithm...")
    
    # Test case 1: Simple RLE run
    test1_compressed = bytes([5, 128])  # 5 bytes of value 128
    test1_expected = bytes([128, 128, 128, 128, 128])
    test1_result = decompress_rle8_python(test1_compressed, 5)
    print(f"Test 1: {'✅ PASS' if test1_result == test1_expected else '❌ FAIL'}")
    
    # Test case 2: Literal run  
    test2_compressed = bytes([0, 3, 10, 20, 30])  # Literal run of 3 bytes: 10, 20, 30
    test2_expected = bytes([10, 20, 30])
    test2_result = decompress_rle8_python(test2_compressed, 3)
    print(f"Test 2: {'✅ PASS' if test2_result == test2_expected else '❌ FAIL'}")
    
    # Test case 3: Mixed RLE and literal
    test3_compressed = bytes([3, 255, 0, 2, 10, 20])  # 3 bytes of 255, then literal 10, 20
    test3_expected = bytes([255, 255, 255, 10, 20])
    test3_result = decompress_rle8_python(test3_compressed, 5)
    print(f"Test 3: {'✅ PASS' if test3_result == test3_expected else '❌ FAIL'}")
    
    # Test case 4: Real MUGEN-style data
    test4_compressed = bytes([8, 0, 4, 128, 0, 3, 255, 64, 192])
    test4_expected = bytes([0, 0, 0, 0, 0, 0, 0, 0, 128, 128, 128, 128, 255, 64, 192])
    test4_result = decompress_rle8_python(test4_compressed, 15)
    print(f"Test 4: {'✅ PASS' if test4_result == test4_expected else '❌ FAIL'}")
    
    print("\n📋 RLE8 algorithm validation complete!")

if __name__ == "__main__":
    test_rle8_cases()
