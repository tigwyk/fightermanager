#!/usr/bin/env python3
"""
MUGEN SFF Parser Prototype - Robust Implementation
Based on Ikemen GO SFF parsing logic with comprehensive sprite format support
Run: python mugen_prototype.py
"""

import struct
import os
import io
import zlib
from pathlib import Path

# For graphics - we'll use PIL first (simpler than pygame)
try:
    from PIL import Image, ImageDraw, ImageFont, ImageTk
    import tkinter as tk
    from tkinter import ttk
    HAS_GUI = True
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.check_call(["pip", "install", "Pillow"])
    from PIL import Image, ImageDraw, ImageFont, ImageTk
    import tkinter as tk
    from tkinter import ttk
    HAS_GUI = True

def load_act_palette(act_file_path):
    """Load a MUGEN .act palette file (768 bytes, 256 RGB triplets)"""
    try:
        with open(act_file_path, 'rb') as f:
            data = f.read(768)  # 256 colors * 3 bytes (RGB)
            if len(data) != 768:
                print(f"Warning: ACT file {act_file_path} is {len(data)} bytes, expected 768")
                return None
            
            palette = []
            for i in range(256):
                r = data[i * 3]
                g = data[i * 3 + 1] 
                b = data[i * 3 + 2]
                palette.append((r, g, b))
            
            # Color 0 is transparent
            palette[0] = (0, 0, 0, 0)  # RGBA with alpha=0 for transparency
            
            return palette
    except Exception as e:
        print(f"Error loading ACT file {act_file_path}: {e}")
        return None

class SFFHeader:
    def __init__(self):
        self.signature = None
        self.ver0 = 0
        self.ver1 = 0
        self.ver2 = 0
        self.ver3 = 0
        self.first_sprite_header_offset = 0
        self.first_palette_header_offset = 0
        self.number_of_sprites = 0
        self.number_of_palettes = 0
        
    def read(self, f):
        """Read SFF header from file"""
        # Read signature
        self.signature = f.read(12)
        if self.signature != b"ElecbyteSpr\0":
            raise ValueError(f"Invalid SFF signature: {self.signature}")
        
        # Read version bytes
        self.ver3, self.ver2, self.ver1, self.ver0 = struct.unpack('<BBBB', f.read(4))
        
        # Skip reserved bytes
        f.read(4)
        
        if self.ver0 == 1:
            # SFF v1 format
            palette_offset, self.number_of_palettes, self.number_of_sprites, \
            self.first_sprite_header_offset, header_length = struct.unpack('<IIIII', f.read(20))
            self.first_palette_header_offset = palette_offset
        elif self.ver0 == 2:
            # SFF v2 format
            f.read(16)  # Skip reserved
            self.first_sprite_header_offset = struct.unpack('<I', f.read(4))[0]
            self.number_of_sprites = struct.unpack('<I', f.read(4))[0]
            self.first_palette_header_offset = struct.unpack('<I', f.read(4))[0]
            self.number_of_palettes = struct.unpack('<I', f.read(4))[0]
            f.read(8)  # Skip ldata and tdata offsets for now
        else:
            raise ValueError(f"Unsupported SFF version: {self.ver0}")

class SFFSprite:
    def __init__(self):
        self.group = 0
        self.number = 0
        self.size = [0, 0]  # width, height
        self.offset = [0, 0]  # axis offset
        self.rle = 0
        self.coldepth = 8
        self.palette_index = -1
        self.palette = None
        self.pixels = None
        self.is_linked = False
        self.linked_index = 0
        
    def read_header_v1(self, f):
        """Read SFF v1 sprite header"""
        data = f.read(32)
        if len(data) < 32:
            raise ValueError("Incomplete sprite header")
            
        # Parse sprite header - based on Ikemen GO format
        next_offset, data_length, x, y, self.group, self.number, \
        self.linked_index, palette_same = struct.unpack('<IIHHHHHB', data[:19])
        
        # The linked_index indicates if this sprite shares data with another
        self.is_linked = self.linked_index != 0
        
        return next_offset, data_length, palette_same
        
    def read_header_v2(self, f, lofs, tofs):
        """Read SFF v2 sprite header"""
        data = f.read(28)
        if len(data) < 28:
            raise ValueError("Incomplete sprite header v2")
            
        self.group, self.number, self.size[0], self.size[1], \
        self.offset[0], self.offset[1], self.linked_index, fmt, \
        self.coldepth, data_offset, data_length = struct.unpack('<HHHHhhHBBII', data)
        
        self.rle = -fmt if fmt != 0 else 0
        self.is_linked = data_length == 0
        
        return data_offset, data_length

class PaletteList:
    def __init__(self):
        self.palettes = []  # List of 256-color palettes
        self.palette_map = {}  # Maps sprite palette indices to actual palette indices
        
    def add_palette(self, palette_data):
        """Add a palette to the list"""
        if len(palette_data) == 256:
            self.palettes.append(palette_data)
            return len(self.palettes) - 1
        return -1
        
    def get_palette(self, index):
        """Get palette by index"""
        if 0 <= index < len(self.palettes):
            return self.palettes[index]
        return None

class SFFParser:
    def __init__(self):
        self.header = SFFHeader()
        self.sprites = {}  # Dict mapping (group, number) to SFFSprite
        self.palette_list = PaletteList()
        
    def parse_file(self, filepath):
        """Parse SFF file and extract sprites"""
        print(f"🎨 Parsing SFF file: {filepath}")
        
        if not os.path.exists(filepath):
            print(f"❌ File not found: {filepath}")
            return False
            
        try:
            with open(filepath, 'rb') as f:
                # Read header
                self.header.read(f)
                print(f"📝 Signature: '{self.header.signature.decode('ascii', errors='ignore')}'")
                print(f"� Version: [{self.header.ver3}, {self.header.ver2}, {self.header.ver1}, {self.header.ver0}]")
                print(f"📊 SFF Info:")
                print(f"  Sprite count: {self.header.number_of_sprites}")
                print(f"  Palette count: {self.header.number_of_palettes}")
                print(f"  First sprite header offset: {self.header.first_sprite_header_offset}")
                print(f"  First palette header offset: {self.header.first_palette_header_offset}")
                
                # Get file size for validation
                f.seek(0, 2)
                file_size = f.tell()
                print(f"� File size: {file_size} bytes")
                
                # Parse palettes first
                if self.header.ver0 == 1:
                    self._parse_palettes_v1(f, file_size)
                    return self._parse_sprites_v1(f, file_size)
                elif self.header.ver0 == 2:
                    self._parse_palettes_v2(f, file_size)
                    return self._parse_sprites_v2(f, file_size)
                else:
                    print(f"❌ Unsupported SFF version: {self.header.ver0}")
                    return False
                    
        except Exception as e:
            print(f"❌ Error parsing SFF file: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _parse_palettes_v1(self, f, file_size):
        """Parse SFF v1 palettes"""
        if self.header.number_of_palettes == 0 or self.header.first_palette_header_offset == 0:
            print("⚠️ No palettes defined, creating default palette")
            self._create_default_palette()
            return
            
        # For v1, palettes are stored as raw RGB data
        palette_offset = self.header.first_palette_header_offset
        
        # Validate palette offset
        if palette_offset >= file_size:
            print(f"⚠️ Palette offset {palette_offset} exceeds file size {file_size}")
            self._create_default_palette()
            return
            
        print(f"🎨 Reading {self.header.number_of_palettes} v1 palettes from offset {palette_offset}")
        
        # Each palette is 768 bytes (256 colors * 3 RGB bytes)
        total_palette_size = self.header.number_of_palettes * 768
        if palette_offset + total_palette_size > file_size:
            print(f"⚠️ Palette data would exceed file size, limiting palette count")
            max_palettes = (file_size - palette_offset) // 768
            self.header.number_of_palettes = max_palettes
        
        try:
            f.seek(palette_offset)
            for i in range(self.header.number_of_palettes):
                palette = []
                for j in range(256):
                    rgb_data = f.read(3)
                    if len(rgb_data) < 3:
                        break
                    r, g, b = struct.unpack('BBB', rgb_data)
                    # Convert to RGBA format with alpha
                    alpha = 0 if j == 0 else 255  # Color 0 is typically transparent
                    palette.append((r, g, b, alpha))
                
                if len(palette) == 256:
                    self.palette_list.add_palette(palette)
                    print(f"  ✅ Loaded palette {i}")
                else:
                    print(f"  ❌ Incomplete palette {i}")
                    break
                    
        except Exception as e:
            print(f"⚠️ Error reading palettes: {e}")
            self._create_default_palette()
    
    def _parse_palettes_v2(self, f, file_size):
        """Parse SFF v2 palettes (with headers)"""
        if self.header.number_of_palettes == 0:
            print("⚠️ No palettes defined in v2, creating default")
            self._create_default_palette()
            return
            
        print(f"🎨 Reading {self.header.number_of_palettes} v2 palette headers")
        
        f.seek(self.header.first_palette_header_offset)
        
        for i in range(self.header.number_of_palettes):
            try:
                # Read palette header (16 bytes)
                header_data = f.read(16)
                if len(header_data) < 16:
                    break
                    
                group, number, numcols, link, data_offset, data_size = struct.unpack('<HHHIII', header_data)
                
                if data_size == 0:
                    # Linked palette
                    print(f"  Palette {i}: [{group},{number}] linked to {link}")
                    continue
                    
                # Read palette data
                current_pos = f.tell()
                f.seek(data_offset)
                
                palette = []
                colors_to_read = min(256, data_size // 4)  # 4 bytes per RGBA color
                
                for j in range(colors_to_read):
                    rgba_data = f.read(4)
                    if len(rgba_data) < 4:
                        break
                    r, g, b, a = struct.unpack('BBBB', rgba_data)
                    
                    # Handle alpha properly for v2
                    if self.header.ver2 == 0 and j == 0:
                        a = 0  # First color transparent
                    elif self.header.ver2 == 0:
                        a = 255
                        
                    palette.append((r, g, b, a))
                
                # Pad to 256 colors if needed
                while len(palette) < 256:
                    palette.append((0, 0, 0, 0))
                
                if len(palette) == 256:
                    self.palette_list.add_palette(palette)
                    print(f"  ✅ Loaded palette {i}: [{group},{number}] with {colors_to_read} colors")
                
                f.seek(current_pos)
                
            except Exception as e:
                print(f"⚠️ Error reading palette {i}: {e}")
                break
    
    def _create_default_palette(self):
        """Create a default grayscale palette"""
        palette = []
        for i in range(256):
            gray = i
            alpha = 0 if i == 0 else 255
            palette.append((gray, gray, gray, alpha))
        self.palette_list.add_palette(palette)
        print("🎨 Created default grayscale palette")
    
    def _parse_sprites_v1(self, f, file_size):
        """Parse SFF v1 sprites - handle non-standard header layout"""
        if self.header.number_of_sprites == 0:
            print("❌ No sprites defined")
            return False
            
        print(f"📋 Reading {self.header.number_of_sprites} v1 sprite headers")
        
        # This SFF file has a non-standard layout where sprite headers are not at offset 0
        # Let's scan for the actual sprite data locations
        sprites_loaded = 0
        
        # First, let's find all PCX headers in the file
        f.seek(0)
        file_data = f.read()
        
        pcx_positions = []
        for i in range(len(file_data) - 128):
            if file_data[i] == 10:  # PCX manufacturer byte
                # Validate this looks like a real PCX header
                f.seek(i)
                header = f.read(16)
                if len(header) >= 16:
                    manufacturer, version, encoding, bpp = header[:4]
                    if bpp == 8:  # 8-bit color depth
                        xmin, ymin, xmax, ymax = struct.unpack('<HHHH', header[4:12])
                        width = xmax - xmin + 1
                        height = ymax - ymin + 1
                        if 1 <= width <= 2048 and 1 <= height <= 2048:  # Reasonable dimensions
                            pcx_positions.append((i, width, height))
        
        print(f"🔍 Found {len(pcx_positions)} potential sprite locations")
        
        # Now let's look for sprite headers that point to these PCX locations
        # The sprite headers should be somewhere after the palettes
        palette_end = self.header.first_palette_header_offset + (len(self.palette_list.palettes) * 768)
        
        # Search for sprite headers starting from various positions
        search_start = max(32, palette_end)
        search_positions = [
            search_start,
            512,   # Common offset
            1024,  # Another common offset
            2048,  # Yet another
        ]
        
        found_headers = False
        for start_pos in search_positions:
            if start_pos >= file_size - 32:
                continue
                
            print(f"🔍 Searching for sprite headers starting at {start_pos}")
            
            # Try to read sprite headers from this position
            current_pos = start_pos
            temp_sprites = []
            
            for i in range(self.header.number_of_sprites):
                if current_pos + 32 > file_size:
                    break
                    
                f.seek(current_pos)
                header_data = f.read(32)
                if len(header_data) < 32:
                    break
                
                try:
                    next_offset, data_length, x, y, group, number, linked_index, palette_same = struct.unpack('<IIHHHHHB', header_data[:19])
                    
                    # Check if this points to one of our PCX locations
                    pcx_found = False
                    for pcx_pos, pcx_width, pcx_height in pcx_positions:
                        if abs(next_offset - pcx_pos) < 10:  # Allow for small offset differences
                            pcx_found = True
                            break
                    
                    if pcx_found and 0 <= group < 1000 and 0 <= number < 1000:
                        sprite = SFFSprite()
                        sprite.group = group
                        sprite.number = number
                        sprite.size = [pcx_width, pcx_height]
                        sprite.offset = [x, y]
                        sprite.is_linked = linked_index != 0
                        sprite.linked_index = linked_index
                        sprite.data_offset = next_offset
                        sprite.data_length = data_length
                        # Assign palette based on group number (common MUGEN pattern)
                        sprite.palette_index = min(group, len(self.palette_list.palettes) - 1)
                        
                        temp_sprites.append(sprite)
                        print(f"  Found sprite header {i}: [{group},{number}] -> PCX at {next_offset}")
                
                except struct.error:
                    break
                
                current_pos += 32
            
            # If we found reasonable number of sprite headers, use them
            if len(temp_sprites) >= self.header.number_of_sprites // 2:  # At least half
                found_headers = True
                for sprite in temp_sprites:
                    if not sprite.is_linked:  # Only store non-linked sprites for now
                        sprite_key = (sprite.group, sprite.number)
                        self.sprites[sprite_key] = sprite
                        sprites_loaded += 1
                        print(f"    ✅ Loaded sprite [{sprite.group},{sprite.number}] {sprite.size[0]}x{sprite.size[1]}")
                break
        
        # If we still can't find headers, create sprites directly from PCX positions
        if not found_headers and pcx_positions:
            print(f"🔧 Could not find sprite headers, creating sprites from PCX data directly")
            
            for i, (pcx_pos, width, height) in enumerate(pcx_positions[:self.header.number_of_sprites]):
                # Create sprite with estimated group/number
                group = i // 10  # Rough grouping
                number = i % 10
                
                sprite = SFFSprite()
                sprite.group = group
                sprite.number = number
                sprite.size = [width, height]
                sprite.offset = [0, 0]
                sprite.is_linked = False
                sprite.data_offset = pcx_pos
                sprite.data_length = 0  # We'll calculate on demand
                # Assign palette based on group number (common MUGEN pattern)
                sprite.palette_index = min(group, len(self.palette_list.palettes) - 1)
                
                sprite_key = (sprite.group, sprite.number)
                self.sprites[sprite_key] = sprite
                sprites_loaded += 1
                print(f"    ✅ Created sprite [{sprite.group},{sprite.number}] {sprite.size[0]}x{sprite.size[1]} from PCX at {pcx_pos}")
        
        print(f"✅ Loaded {sprites_loaded} v1 sprites")
        return sprites_loaded > 0
    
    def _test_sprite_header_v1(self, f):
        """Test if current position contains a valid v1 sprite header"""
        pos = f.tell()
        try:
            # Read a few headers and see if they look reasonable
            for i in range(min(3, self.header.number_of_sprites)):
                header_data = f.read(32)
                if len(header_data) < 32:
                    return False
                
                next_offset, data_length, x, y, group, number, linked_index = struct.unpack('<IIHHHHI', header_data[:20])
                
                # Basic sanity checks
                if (data_length < 1000000 and  # Reasonable size
                    0 <= group < 1000 and     # Reasonable group
                    0 <= number < 1000 and    # Reasonable number
                    abs(x) < 10000 and abs(y) < 10000):  # Reasonable coordinates
                    continue
                else:
                    return False
            
            return True
        except:
            return False
        finally:
            f.seek(pos)  # Reset position
    
    def _parse_sprites_v2(self, f, file_size):
        """Parse SFF v2 sprites"""
        print(f"📋 Reading {self.header.number_of_sprites} v2 sprite headers")
        
        f.seek(self.header.first_sprite_header_offset)
        sprites_loaded = 0
        
        for i in range(self.header.number_of_sprites):
            try:
                sprite = SFFSprite()
                # For v2, we need lofs and tofs (but we'll use 0 for now)
                data_offset, data_length = sprite.read_header_v2(f, 0, 0)
                
                print(f"  Sprite {i}: [{sprite.group},{sprite.number}] {sprite.size[0]}x{sprite.size[1]} fmt={sprite.rle}")
                
                if sprite.is_linked:
                    print(f"    ⏭️ Linked sprite")
                    continue
                
                if data_length > 0:
                    sprite_key = (sprite.group, sprite.number)
                    self.sprites[sprite_key] = sprite
                    sprites_loaded += 1
                    print(f"    ✅ Loaded sprite [{sprite.group},{sprite.number}]")
                
            except Exception as e:
                print(f"  ❌ Error reading sprite {i}: {e}")
                break
        
        print(f"✅ Loaded {sprites_loaded} v2 sprites")
        return sprites_loaded > 0
    
    def _read_pcx_header(self, f, sprite):
        """Read PCX header to get sprite dimensions"""
        try:
            pcx_header = f.read(128)
            if len(pcx_header) < 128:
                return False
            
            # Parse PCX header
            manufacturer = pcx_header[0]
            version = pcx_header[1] 
            encoding = pcx_header[2]
            bits_per_pixel = pcx_header[3]
            
            if manufacturer != 10:  # Not PCX
                return False
            
            # Get image dimensions
            xmin, ymin, xmax, ymax = struct.unpack('<HHHH', pcx_header[4:12])
            sprite.size[0] = xmax - xmin + 1
            sprite.size[1] = ymax - ymin + 1
            
            # Get bytes per line for RLE decoding
            bytes_per_line = struct.unpack('<H', pcx_header[66:68])[0]
            sprite.rle = bytes_per_line if encoding == 1 else 0
            
            return True
            
        except Exception as e:
            print(f"    ❌ Error reading PCX header: {e}")
            return False
    
    def get_sprite_list(self):
        """Get list of available sprites"""
        return list(self.sprites.keys())
    
    def has_sprite(self, group, number):
        """Check if sprite exists"""
        return (group, number) in self.sprites
    
    def decode_rle_pcx(self, data, width, height, bytes_per_line):
        """Decode RLE-compressed PCX data"""
        if not data:
            return None
            
        pixels = bytearray(width * height)
        i = 0
        j = 0
        k = 0
        
        while j < len(pixels) and i < len(data):
            byte = data[i]
            i += 1
            
            if byte >= 0xC0:
                # RLE run
                count = byte & 0x3F
                if i < len(data):
                    value = data[i]
                    i += 1
                else:
                    break
            else:
                # Single byte
                count = 1
                value = byte
            
            # Write pixels
            for _ in range(count):
                if k < bytes_per_line and j < len(pixels):
                    pixels[j] = value
                    j += 1
                k += 1
                if k >= bytes_per_line:
                    k = 0
                    if count > 1:
                        count = 1  # Stop run at line boundary
        
        return bytes(pixels)
    
    def decode_rle8(self, data, width, height):
        """Decode RLE8 compressed sprite data (SFF v2)"""
        if not data:
            return None
            
        pixels = bytearray(width * height)
        i = 0
        j = 0
        
        while j < len(pixels) and i < len(data):
            if i >= len(data):
                break
                
            byte = data[i]
            i += 1
            
            if byte == 0:
                # Escape sequence
                if i >= len(data):
                    break
                count = data[i]
                i += 1
                
                if count == 0:
                    # End of line
                    continue
                elif count == 1:
                    # End of bitmap
                    break
                elif count == 2:
                    # Delta
                    if i + 1 < len(data):
                        dx = data[i]
                        dy = data[i + 1]
                        j += dx + dy * width
                        i += 2
                else:
                    # Absolute mode
                    for _ in range(count):
                        if i < len(data) and j < len(pixels):
                            pixels[j] = data[i]
                            j += 1
                            i += 1
                    # Align to word boundary
                    if count % 2 == 1:
                        i += 1
            else:
                # Encoded mode
                if i < len(data):
                    value = data[i]
                    i += 1
                    for _ in range(byte):
                        if j < len(pixels):
                            pixels[j] = value
                            j += 1
        
        return bytes(pixels)
    
    def extract_sprite_image(self, filepath, group, number):
        """Extract and decode a specific sprite to PIL Image"""
        sprite_key = (group, number)
        if sprite_key not in self.sprites:
            print(f"❌ Sprite [{group},{number}] not found")
            return None
            
        sprite = self.sprites[sprite_key]
        
        try:
            with open(filepath, 'rb') as f:
                if self.header.ver0 == 1:
                    return self._extract_sprite_v1(f, sprite, group, number)
                elif self.header.ver0 == 2:
                    return self._extract_sprite_v2(f, sprite, group, number)
                else:
                    print(f"❌ Unsupported SFF version for extraction: {self.header.ver0}")
                    return None
                    
        except Exception as e:
            print(f"❌ Error extracting sprite [{group},{number}]: {e}")
            import traceback
            traceback.print_exc()
            return self._create_placeholder_image(group, number, 64, 64)
    
    def _extract_sprite_v1(self, f, sprite, group, number):
        """Extract SFF v1 sprite"""
        # Check if sprite has stored data offset
        if not hasattr(sprite, 'data_offset'):
            print(f"❌ Sprite [{group},{number}] missing data offset info")
            return self._create_placeholder_image(group, number, 64, 64)
        
        data_offset = sprite.data_offset
        data_length = getattr(sprite, 'data_length', 0)
        
        print(f"📷 Extracting sprite [{group},{number}] from offset {data_offset}")
        
        try:
            # Read PCX header first to determine actual data size
            f.seek(data_offset)
            pcx_header = f.read(128)
            
            if len(pcx_header) < 128:
                print(f"❌ PCX header too short: {len(pcx_header)} bytes")
                return self._create_placeholder_image(group, number, 64, 64)
            
            # Parse PCX header
            manufacturer = pcx_header[0]
            version = pcx_header[1]
            encoding = pcx_header[2]
            bits_per_pixel = pcx_header[3]
            
            if manufacturer != 10:
                print(f"❌ Not a PCX file (manufacturer={manufacturer})")
                return self._create_placeholder_image(group, number, 64, 64)
            
            # Get dimensions
            xmin, ymin, xmax, ymax = struct.unpack('<HHHH', pcx_header[4:12])
            width = xmax - xmin + 1
            height = ymax - ymin + 1
            
            print(f"📐 Sprite dimensions: {width}x{height}, encoding={encoding}")
            
            # Get bytes per line
            bytes_per_line = struct.unpack('<H', pcx_header[66:68])[0]
            
            # Calculate data size if not provided
            if data_length == 0:
                # Estimate data size - for RLE, this is tricky, so we'll read conservatively
                if encoding == 1:  # RLE
                    # For RLE, read until we find the palette at the end or hit another PCX header
                    max_read = min(100000, f.seek(0, 2) - (data_offset + 128))  # Don't read beyond file
                    f.seek(data_offset + 128)
                    estimated_pixel_data = f.read(max_read)
                    
                    # Look for palette signature (we expect 768 bytes of palette at the end)
                    pixel_data_end = len(estimated_pixel_data) - 768
                    if pixel_data_end < 0:
                        pixel_data_end = len(estimated_pixel_data)
                    
                else:  # Uncompressed
                    pixel_data_end = width * height
                
            else:
                # Use provided data length
                f.seek(data_offset + 128)
                pixel_data_end = data_length - 128 - 768  # Subtract header and palette
                if pixel_data_end < 0:
                    pixel_data_end = data_length - 128
            
            # Read pixel data
            f.seek(data_offset + 128)
            pixel_data = f.read(pixel_data_end)
            
            # Decode pixels
            if encoding == 1:  # RLE encoded
                pixels = self.decode_rle_pcx(pixel_data, width, height, bytes_per_line)
            else:  # Uncompressed
                pixels = pixel_data[:width * height]
            
            if not pixels:
                print(f"❌ Failed to decode pixel data")
                return self._create_placeholder_image(group, number, width, height)
            
            # Get palette
            palette_index = getattr(sprite, 'palette_index', 0)
            palette = self.palette_list.get_palette(palette_index)
            
            if not palette and len(self.palette_list.palettes) > 0:
                palette = self.palette_list.palettes[0]
            
            if not palette:
                print(f"⚠️ No palette available, creating grayscale image")
                # Create PIL image from raw pixel data (grayscale)
                img = Image.new('L', (width, height))
                if len(pixels) >= width * height:
                    img.putdata(pixels[:width * height])
                return img.convert('RGBA')
            
            # Create PIL image with palette
            img = Image.new('P', (width, height))
            if len(pixels) >= width * height:
                img.putdata(pixels[:width * height])
            
            # Convert palette to PIL format
            pil_palette = []
            for r, g, b, a in palette:
                pil_palette.extend([r, g, b])
            
            img.putpalette(pil_palette)
            
            # Convert to RGBA to handle transparency
            rgba_img = img.convert('RGBA')
            
            # Make color 0 transparent
            if len(palette) > 0:
                datas = rgba_img.getdata()
                new_data = []
                transparent_color = palette[0][:3]  # RGB of color 0
                
                for item in datas:
                    if item[:3] == transparent_color:  # If it matches color 0
                        new_data.append((item[0], item[1], item[2], 0))  # Make transparent
                    else:
                        new_data.append(item)
                
                rgba_img.putdata(new_data)
            
            print(f"✅ Successfully extracted sprite [{group},{number}] as {width}x{height} image")
            return rgba_img
            
        except Exception as e:
            print(f"❌ Error extracting sprite data: {e}")
            import traceback
            traceback.print_exc()
            return self._create_placeholder_image(group, number, 64, 64)
    
    def _extract_sprite_v2(self, f, sprite, group, number):
        """Extract SFF v2 sprite"""
        # This would implement v2 sprite extraction with proper format handling
        print(f"⚠️ SFF v2 sprite extraction not fully implemented yet")
        return self._create_placeholder_image(group, number, 64, 64)
    
    def _create_placeholder_image(self, group, number, width=64, height=64):
        """Create a placeholder image for missing/invalid sprites"""
        img = Image.new('RGBA', (width, height), color=(255, 0, 0, 128))
        draw = ImageDraw.Draw(img)
        draw.rectangle([2, 2, width-3, height-3], outline='white', width=2)
        
        # Draw text if image is big enough
        if width >= 40 and height >= 20:
            try:
                font = ImageFont.load_default()
                text = f"[{group},{number}]"
                text_bbox = draw.textbbox((0, 0), text, font=font)
                text_width = text_bbox[2] - text_bbox[0]
                text_height = text_bbox[3] - text_bbox[1]
                
                x = max(5, (width - text_width) // 2)
                y = max(5, (height - text_height) // 2)
                draw.text((x, y), text, fill='white', font=font)
            except:
                pass
        
        return img

class MUGENViewer:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("MUGEN SFF Viewer - Robust Prototype")
        self.root.geometry("1000x700")
        
        self.parser = SFFParser()
        self.current_image = None
        
        self.setup_gui()
    
    def setup_gui(self):
        # Create main frame with paned window
        paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        paned.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Left panel for controls and sprite list
        left_frame = ttk.Frame(paned)
        paned.add(left_frame, weight=1)
        
        # Right panel for image display
        right_frame = ttk.Frame(paned)
        paned.add(right_frame, weight=2)
        
        # File selection
        file_frame = ttk.Frame(left_frame)
        file_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Label(file_frame, text="SFF File:").pack(anchor=tk.W)
        self.file_var = tk.StringVar(value="data/mugen/system.sff")
        file_entry = ttk.Entry(file_frame, textvariable=self.file_var)
        file_entry.pack(fill=tk.X, pady=(2, 5))
        
        button_frame = ttk.Frame(file_frame)
        button_frame.pack(fill=tk.X)
        ttk.Button(button_frame, text="Load SFF", command=self.load_file).pack(side=tk.LEFT)
        ttk.Button(button_frame, text="Test Title Sprites", command=self.test_title_sprites).pack(side=tk.LEFT, padx=(5, 0))
        
        # Status
        self.status_var = tk.StringVar(value="Ready to load SFF file")
        status_label = ttk.Label(left_frame, textvariable=self.status_var, wraplength=300)
        status_label.pack(fill=tk.X, pady=(0, 10))
        
        # Sprite list with search
        ttk.Label(left_frame, text="Available Sprites:").pack(anchor=tk.W)
        
        search_frame = ttk.Frame(left_frame)
        search_frame.pack(fill=tk.X, pady=(2, 5))
        ttk.Label(search_frame, text="Search:").pack(side=tk.LEFT)
        self.search_var = tk.StringVar()
        self.search_var.trace('w', self.filter_sprites)
        search_entry = ttk.Entry(search_frame, textvariable=self.search_var)
        search_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(5, 0))
        
        # Listbox with scrollbar
        list_container = ttk.Frame(left_frame)
        list_container.pack(fill=tk.BOTH, expand=True)
        
        self.sprite_listbox = tk.Listbox(list_container)
        scrollbar = ttk.Scrollbar(list_container, orient=tk.VERTICAL, command=self.sprite_listbox.yview)
        self.sprite_listbox.config(yscrollcommand=scrollbar.set)
        
        self.sprite_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.sprite_listbox.bind('<<ListboxSelect>>', self.on_sprite_select)
        self.sprite_listbox.bind('<Double-Button-1>', self.on_sprite_double_click)
        
        # Palette selection controls
        palette_frame = ttk.LabelFrame(left_frame, text="Palette Selection", padding=5)
        palette_frame.pack(fill=tk.X, pady=(10, 0))
        
        ttk.Label(palette_frame, text="Palette Index:").pack(anchor=tk.W)
        
        palette_control_frame = ttk.Frame(palette_frame)
        palette_control_frame.pack(fill=tk.X, pady=(2, 5))
        
        self.palette_var = tk.StringVar(value="0")
        palette_entry = ttk.Entry(palette_control_frame, textvariable=self.palette_var, width=8)
        palette_entry.pack(side=tk.LEFT)
        
        ttk.Button(palette_control_frame, text="Apply", command=self.apply_palette).pack(side=tk.LEFT, padx=(5, 0))
        ttk.Button(palette_control_frame, text="Next", command=self.next_palette).pack(side=tk.LEFT, padx=(2, 0))
        ttk.Button(palette_control_frame, text="Prev", command=self.prev_palette).pack(side=tk.LEFT, padx=(2, 0))
        
        # ACT file loading
        act_frame = ttk.Frame(palette_frame)
        act_frame.pack(fill=tk.X, pady=(5, 0))
        
        ttk.Button(act_frame, text="Load ACT File", command=self.load_act_file).pack(side=tk.LEFT)
        ttk.Label(act_frame, text="(External palette)").pack(side=tk.LEFT, padx=(5, 0))
        
        self.palette_info_var = tk.StringVar(value="No palettes loaded")
        ttk.Label(palette_frame, textvariable=self.palette_info_var, wraplength=250).pack(anchor=tk.W, pady=(2, 0))
        
        # Image display area
        image_frame = ttk.LabelFrame(right_frame, text="Sprite Display", padding=10)
        image_frame.pack(fill=tk.BOTH, expand=True)
        
        # Scrollable image canvas
        canvas_frame = ttk.Frame(image_frame)
        canvas_frame.pack(fill=tk.BOTH, expand=True)
        
        self.image_canvas = tk.Canvas(canvas_frame, bg='gray90')
        h_scroll = ttk.Scrollbar(canvas_frame, orient=tk.HORIZONTAL, command=self.image_canvas.xview)
        v_scroll = ttk.Scrollbar(canvas_frame, orient=tk.VERTICAL, command=self.image_canvas.yview)
        self.image_canvas.config(xscrollcommand=h_scroll.set, yscrollcommand=v_scroll.set)
        
        self.image_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        h_scroll.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Image info
        self.image_info_var = tk.StringVar(value="No sprite selected")
        ttk.Label(image_frame, textvariable=self.image_info_var).pack(pady=(5, 0))
        
        # Store all sprites for filtering
        self.all_sprites = []
        self.current_sprite = None  # Track currently displayed sprite for palette changes
        
    def apply_palette(self):
        """Apply selected palette to current sprite"""
        if not self.current_sprite:
            self.status_var.set("❌ No sprite selected")
            return
            
        try:
            palette_index = int(self.palette_var.get())
            if 0 <= palette_index < len(self.parser.palette_list.palettes):
                group, number = self.current_sprite
                sprite = self.parser.sprites.get((group, number))
                if sprite:
                    sprite.palette_index = palette_index
                    self.display_sprite(group, number)
                    self.status_var.set(f"✅ Applied palette {palette_index} to sprite [{group},{number}]")
                else:
                    self.status_var.set("❌ Sprite data not found")
            else:
                self.status_var.set(f"❌ Invalid palette index: {palette_index} (0-{len(self.parser.palette_list.palettes)-1})")
        except ValueError:
            self.status_var.set("❌ Invalid palette index format")
    
    def next_palette(self):
        """Switch to next palette"""
        try:
            current = int(self.palette_var.get())
            max_palette = len(self.parser.palette_list.palettes) - 1
            next_palette = min(current + 1, max_palette)
            self.palette_var.set(str(next_palette))
            self.apply_palette()
        except ValueError:
            self.palette_var.set("0")
    
    def prev_palette(self):
        """Switch to previous palette"""
        try:
            current = int(self.palette_var.get())
            prev_palette = max(current - 1, 0)
            self.palette_var.set(str(prev_palette))
            self.apply_palette()
        except ValueError:
            self.palette_var.set("0")
    
    def load_act_file(self):
        """Load an external ACT palette file"""
        from tkinter import filedialog
        
        act_file = filedialog.askopenfilename(
            title="Load ACT Palette File",
            filetypes=[("ACT files", "*.act"), ("All files", "*.*")],
            initialdir="assets/mugen"
        )
        
        if act_file:
            try:
                palette = load_act_palette(act_file)
                if palette:
                    # Add palette to the list
                    palette_index = self.parser.palette_list.add_palette(palette)
                    if palette_index >= 0:
                        self.palette_var.set(str(palette_index))
                        self.apply_palette()
                        self.status_var.set(f"✅ Loaded ACT palette from {os.path.basename(act_file)} as palette {palette_index}")
                        
                        # Update palette info
                        palette_count = len(self.parser.palette_list.palettes)
                        self.palette_info_var.set(f"Loaded {palette_count} palettes (0-{palette_count-1})")
                    else:
                        self.status_var.set("❌ Failed to add ACT palette")
                else:
                    self.status_var.set(f"❌ Failed to load ACT file: {os.path.basename(act_file)}")
            except Exception as e:
                self.status_var.set(f"❌ Error loading ACT file: {e}")
    
    def load_file(self):
        filepath = self.file_var.get()
        self.status_var.set(f"Loading {filepath}...")
        self.root.update()
        
        try:
            if self.parser.parse_file(filepath):
                sprites = self.parser.get_sprite_list()
                self.all_sprites = sorted(sprites)
                self.status_var.set(f"✅ Loaded {len(sprites)} sprites from SFF v{self.parser.header.ver0}")
                
                # Populate listbox
                self.update_sprite_list()
                
                # Update palette info
                palette_count = len(self.parser.palette_list.palettes)
                self.palette_info_var.set(f"Loaded {palette_count} palettes (0-{palette_count-1})")
                
                # Show basic stats
                print(f"\n📈 SFF Analysis Summary:")
                print(f"   Version: {self.parser.header.ver0}")
                print(f"   Sprites: {len(sprites)}")
                print(f"   Palettes: {len(self.parser.palette_list.palettes)}")
                
                # Group analysis
                groups = {}
                for group, number in sprites:
                    if group not in groups:
                        groups[group] = []
                    groups[group].append(number)
                
                print(f"   Groups: {len(groups)}")
                for group in sorted(groups.keys())[:10]:  # Show first 10 groups
                    numbers = sorted(groups[group])
                    print(f"     Group {group}: {len(numbers)} sprites (numbers: {numbers[:5]}{'...' if len(numbers) > 5 else ''})")
                
            else:
                self.status_var.set("❌ Failed to parse SFF file")
        except Exception as e:
            self.status_var.set(f"❌ Error: {e}")
            print(f"Error loading file: {e}")
            import traceback
            traceback.print_exc()
    
    def test_title_sprites(self):
        """Test loading the specific sprites needed for title background"""
        if not self.parser.sprites:
            self.status_var.set("❌ No SFF file loaded")
            return
            
        title_sprites = [(5, 1), (5, 2), (5, 0), (0, 0), (1, 0), (1, 1)]
        found_sprites = []
        
        print(f"\n🎯 Testing title background sprites:")
        for group, number in title_sprites:
            if self.parser.has_sprite(group, number):
                found_sprites.append((group, number))
                print(f"  ✅ Found [{group},{number}]")
                
                # Try to extract the sprite
                img = self.parser.extract_sprite_image(self.file_var.get(), group, number)
                if img:
                    print(f"     Successfully extracted as {img.size} image")
                else:
                    print(f"     Failed to extract image data")
            else:
                print(f"  ❌ Missing [{group},{number}]")
        
        if found_sprites:
            self.status_var.set(f"🎉 Found {len(found_sprites)} title sprites!")
            # Display the first found sprite
            group, number = found_sprites[0]
            self.display_sprite(group, number)
        else:
            self.status_var.set("😞 No title background sprites found")
    
    def filter_sprites(self, *args):
        """Filter sprite list based on search text"""
        search_text = self.search_var.get().lower()
        if not search_text:
            filtered_sprites = self.all_sprites
        else:
            filtered_sprites = []
            for group, number in self.all_sprites:
                sprite_text = f"[{group},{number}]"
                if search_text in sprite_text.lower():
                    filtered_sprites.append((group, number))
        
        self.sprite_listbox.delete(0, tk.END)
        for group, number in filtered_sprites:
            self.sprite_listbox.insert(tk.END, f"[{group},{number}]")
    
    def update_sprite_list(self):
        """Update the sprite listbox with all sprites"""
        self.sprite_listbox.delete(0, tk.END)
        for group, number in self.all_sprites:
            self.sprite_listbox.insert(tk.END, f"[{group},{number}]")
    
    def on_sprite_select(self, event):
        """Handle sprite selection"""
        selection = self.sprite_listbox.curselection()
        if selection:
            sprite_text = self.sprite_listbox.get(selection[0])
            # Parse "[group,number]" format
            import re
            match = re.match(r'\[(\d+),(\d+)\]', sprite_text)
            if match:
                group, number = int(match.group(1)), int(match.group(2))
                self.image_info_var.set(f"Selected: [{group},{number}] - Click to load")
                self.current_sprite = (group, number)  # Update current sprite for palette actions
    
    def on_sprite_double_click(self, event):
        """Handle double-click to load sprite"""
        selection = self.sprite_listbox.curselection()
        if selection:
            sprite_text = self.sprite_listbox.get(selection[0])
            import re
            match = re.match(r'\[(\d+),(\d+)\]', sprite_text)
            if match:
                group, number = int(match.group(1)), int(match.group(2))
                self.display_sprite(group, number)
    
    def display_sprite(self, group, number):
        """Display the selected sprite"""
        try:
            self.current_sprite = (group, number)  # Track current sprite
            self.status_var.set(f"Loading sprite [{group},{number}]...")
            self.root.update()
            
            # Get sprite info to show current palette
            sprite = self.parser.sprites.get((group, number))
            current_palette_index = sprite.palette_index if sprite else 0
            self.palette_var.set(str(current_palette_index))
            
            img = self.parser.extract_sprite_image(self.file_var.get(), group, number)
            if img:
                # Clear canvas
                self.image_canvas.delete("all")
                
                # Convert to PhotoImage
                photo = ImageTk.PhotoImage(img)
                
                # Add to canvas
                self.image_canvas.create_image(0, 0, anchor=tk.NW, image=photo)
                self.image_canvas.image = photo  # Keep reference
                
                # Update scroll region
                self.image_canvas.config(scrollregion=self.image_canvas.bbox("all"))
                
                # Update info with palette information
                mode = img.mode
                has_alpha = mode in ('RGBA', 'LA') or 'transparency' in img.info
                alpha_info = " (with transparency)" if has_alpha else ""
                palette_info = f", palette {current_palette_index}"
                self.image_info_var.set(f"Sprite [{group},{number}]: {img.size[0]}x{img.size[1]}, {mode}{alpha_info}{palette_info}")
                
                self.status_var.set(f"✅ Displayed sprite [{group},{number}] with palette {current_palette_index}")
                
                # Auto-select this sprite in the list if not already selected
                sprite_text = f"[{group},{number}]"
                for i in range(self.sprite_listbox.size()):
                    if self.sprite_listbox.get(i) == sprite_text:
                        self.sprite_listbox.selection_clear(0, tk.END)
                        self.sprite_listbox.selection_set(i)
                        self.sprite_listbox.see(i)
                        break
                
                self.current_sprite = (group, number)  # Update current sprite for palette actions
                
            else:
                self.status_var.set(f"❌ Could not load sprite [{group},{number}]")
                self.image_info_var.set("Failed to load sprite")
                
        except Exception as e:
            self.status_var.set(f"❌ Error displaying sprite: {e}")
            self.image_info_var.set(f"Error: {e}")
            print(f"Error displaying sprite [{group},{number}]: {e}")
            import traceback
            traceback.print_exc()
    

            print(f"Error selecting next palette: {e}")
    
    def prev_palette(self):
        """Select the previous palette in the list"""
        try:
            current_index = int(self.palette_var.get())
            prev_index = (current_index - 1) % len(self.parser.palette_list.palettes)
            self.palette_var.set(str(prev_index))
            self.apply_palette()
        except Exception as e:
            self.status_var.set(f"❌ Error selecting previous palette: {e}")
            print(f"Error selecting previous palette: {e}")
    
    def run(self):
        """Run the GUI application"""
        self.root.mainloop()

def test_console_mode():
    """Test SFF parsing in console mode with comprehensive analysis"""
    print("🚀 MUGEN SFF Parser Prototype - Console Mode")
    print("=" * 60)
    
    sff_path = "data/mugen/system.sff"
    if not os.path.exists(sff_path):
        print(f"❌ SFF file not found: {sff_path}")
        return
    
    parser = SFFParser()
    success = parser.parse_file(sff_path)
    
    if success:
        sprites = parser.get_sprite_list()
        print(f"\n✅ Successfully parsed {len(sprites)} sprites")
        print(f"📦 SFF Version: {parser.header.ver0}")
        print(f"🎨 Palettes loaded: {len(parser.palette_list.palettes)}")
        
        # Analyze sprite groups
        groups = {}
        for group, number in sprites:
            if group not in groups:
                groups[group] = []
            groups[group].append(number)
        
        print(f"\n📊 Sprite Group Analysis:")
        print(f"   Total groups: {len(groups)}")
        
        # Show group details
        for group in sorted(groups.keys())[:20]:  # First 20 groups
            numbers = sorted(groups[group])
            print(f"   Group {group:2d}: {len(numbers):3d} sprites (numbers: {numbers[:10]}{'...' if len(numbers) > 10 else ''})")
        
        if len(groups) > 20:
            print(f"   ... and {len(groups) - 20} more groups")
        
        # Test specific title sprites
        title_sprites = [(5, 1), (5, 2), (5, 0), (0, 0), (1, 0), (1, 1)]
        print(f"\n🎯 Testing title background sprites:")
        found_any = False
        for group, number in title_sprites:
            if (group, number) in sprites:
                print(f"  ✅ Found [{group},{number}]")
                found_any = True
                
                # Try to extract
                try:
                    img = parser.extract_sprite_image(sff_path, group, number)
                    if img:
                        print(f"     Successfully extracted: {img.size[0]}x{img.size[1]} {img.mode}")
                    else:
                        print(f"     Failed to extract image")
                except Exception as e:
                    print(f"     Extraction error: {e}")
            else:
                print(f"  ❌ Missing [{group},{number}]")
        
        if found_any:
            print(f"\n🎉 SUCCESS! Found title background sprites in SFF v{parser.header.ver0}!")
        else:
            print(f"\n😞 No title background sprites found")
            
        # Show some sample sprites from different groups
        print(f"\n📋 Sample sprites from different groups:")
        sample_count = 0
        for group in sorted(groups.keys())[:5]:
            numbers = sorted(groups[group])[:3]  # First 3 sprites from each group
            for number in numbers:
                if sample_count >= 15:  # Limit output
                    break
                print(f"  [{group},{number}]")
                sample_count += 1
            if sample_count >= 15:
                break
        
        print(f"\n🔍 For detailed sprite viewing, run without --console flag")
    else:
        print("❌ Failed to parse SFF file")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--console":
        test_console_mode()
    else:
        print("🚀 MUGEN SFF Parser Prototype - Robust Implementation")
        print("This robust parser handles both SFF v1 and v2 formats")
        print("Based on Ikemen GO parsing logic")
        print("=" * 60)
        
        if HAS_GUI:
            viewer = MUGENViewer()
            viewer.run()
        else:
            print("GUI not available, running console mode...")
            test_console_mode()
