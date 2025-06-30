# SFF v2 Parser Fixes - PNG Parsing Errors Resolution

## Problem Summary

The SFF parser was experiencing PNG parsing errors when loading Guile and other SFF v2 character files:
- "Not a PNG file" errors
- ERR_FILE_CORRUPT and ERR_PARSE_ERROR when attempting to load PNG sprites
- Sprites marked as format 10 (PNG) were not actually PNG data

## Root Cause Analysis

Through detailed hex analysis and Python verification scripts, we discovered:

1. **Header parsing issues**: The sprite count in the SFF v2 header was being read incorrectly
   - Guile.sff header claimed 2801 sprites, but actually contains only 164 valid sprites
   - Sprite offset (3936) was correct, but sprite count field was wrong

2. **Misidentified sprite formats**: Sprites marked as format 10 (PNG) in the SFF directory were actually compressed data (RLE8/RLE5/LZ5)

3. **Standard sprite header layout was correct**: The MUGEN SFF v2 sprite header format (26 bytes) was being parsed correctly

## Solutions Implemented

### 1. Dynamic Sprite Counting
- Added `_count_valid_sprites()` function to count actual sprites by parsing headers until invalid data is encountered
- This replaces reliance on the potentially incorrect header sprite count field
- Prevents reading beyond valid sprite data

### 2. Enhanced PNG Parsing with Fallback
- Improved PNG signature validation in `_read_png_sprite_data_v2()`
- When data is not valid PNG despite format field claiming PNG, automatically fallback to compressed format parsing
- Uses `_try_parse_as_compressed()` to attempt RLE8, RLE5, or LZ5 decompression

### 3. Better Error Handling and Debugging
- Added detailed hex dump analysis in PNG parsing failures
- Enhanced debug output to show actual vs expected PNG signatures
- Improved validation of sprite header fields during counting

### 4. Byte Order Testing
- Added debugging code to test both little-endian and big-endian interpretations of header fields
- Confirmed little-endian is correct for SFF v2 files

## Code Changes

### Updated Functions:
- `_parse_sff_v2_header_ikemen()`: Added dynamic sprite counting and byte order testing
- `_read_png_sprite_data_v2()`: Enhanced fallback logic for misidentified PNG sprites
- Added `_count_valid_sprites()`: New helper function for accurate sprite counting

### Test Scripts Created:
- `tools/analyze_png_errors.py`: Analyzes PNG parsing errors in SFF files
- `tools/hex_dump_guile.py`: Raw hex dump analysis
- `tools/detailed_sff_analysis.py`: Detailed SFF structure analysis
- `tools/verify_final.py`: Final verification of header values
- `scripts/test/corrected_sff_v2_test.gd`: Godot test for the fixes

## Expected Results

After these fixes:
1. Guile.sff and other SFF v2 files should load without "PNG parsing" errors
2. Sprite count will be accurate (164 for Guile instead of 2801)
3. Sprites marked as PNG but containing compressed data will be properly parsed
4. RLE8, RLE5, and LZ5 compressed sprites will load correctly

## Validation Steps

1. Run `corrected_sff_v2_test.tscn` to verify Guile SFF parsing
2. Check that sprite count is correctly identified as 164
3. Verify that individual sprites load without PNG errors
4. Test sprite texture creation and display

## Files Modified

- `scripts/mugen/sff_parser.gd`: Main parser fixes
- `scripts/test/corrected_sff_v2_test.gd`: Test script
- `scenes/test/corrected_sff_v2_test.tscn`: Test scene
- Multiple analysis tools in `tools/` directory

## Next Steps

1. Run the test to verify fixes work correctly
2. Test with other SFF v2 character files (KFM, Ryu, Ken, etc.)
3. Integrate the fixes into the main character loading system
4. Continue with palette management and color application for complete sprite rendering
