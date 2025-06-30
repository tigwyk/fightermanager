#!/usr/bin/env python3
"""
Check the exact version bytes in Guile SFF
"""

import struct

def check_version_bytes():
    """Check how version bytes should be interpreted"""
    
    guile_sff_path = "../assets/mugen/chars/Guile/Guile.sff"
    
    with open(guile_sff_path, 'rb') as f:
        # Read first 20 bytes
        data = f.read(20)
        
        print("🔍 First 20 bytes:")
        print(" ".join(f"{b:02X}" for b in data))
        
        # Parse signature
        signature = data[0:12]
        print(f"\n📝 Signature: {signature}")
        
        # Parse version bytes individually
        ver3 = data[12]
        ver2 = data[13] 
        ver1 = data[14]
        ver0 = data[15]
        
        print(f"📝 Version bytes: Ver3={ver3}, Ver2={ver2}, Ver1={ver1}, Ver0={ver0}")
        
        # According to MUGEN/Ikemen GO:
        # Ver0 = main version (1 for SFF v1, 2 for SFF v2)
        print(f"📝 Detected version: {ver0}")
        
        # The next 4 bytes (16-19) are reserved
        reserved = data[16:20]
        print(f"📝 Reserved bytes: {reserved.hex()}")

if __name__ == "__main__":
    check_version_bytes()
