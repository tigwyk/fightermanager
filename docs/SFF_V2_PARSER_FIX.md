# SFF Parser Bug Fix - KFM Loading Issue Resolution

## Problem Summary
The KFM.sff file (and likely other SFF v2 files) were not loading correctly in our Godot MUGEN implementation, even though they work perfectly in MUGEN itself. The issue was that our SFF v2 header parsing was reading the wrong byte positions.

## Root Cause Analysis
Using manual hex analysis and comparing with the Ikemen GO reference implementation, we discovered that our SFF v2 header parsing was incorrect:

### Incorrect Header Layout (Before Fix)
```
Position 20: 4 reserved bytes (skip)
Position 24: First sprite header offset (4 bytes)  
Position 28: Number of sprites (4 bytes)
Position 32: First palette header offset (4 bytes)
Position 36: Number of palettes (4 bytes)
Position 40: Low data offset (4 bytes)
Position 44: High data offset (4 bytes)
```

### Correct Header Layout (After Fix - Ikemen GO Compatible)
```
Position 20-35: 16 bytes of dummy/reserved data (skip 4 x 4 bytes)
Position 36: First sprite header offset (4 bytes)  
Position 40: Number of sprites (4 bytes)
Position 44: First palette header offset (4 bytes)
Position 48: Number of palettes (4 bytes)
Position 52: Low data offset (4 bytes)
Position 56: 4 bytes dummy (skip)
Position 60: High data offset (4 bytes)
```

## Results of Manual Analysis

### Before Fix (Incorrect Parsing)
- Images: **0** ❌
- Subheader offset: **33,554,432** ❌ (clearly wrong - 32MB in a 206KB file)

### After Fix (Correct Parsing)
- Images: **281** ✅
- Subheader offset: **624** ✅ (reasonable)
- First sprite: Group 9000, Image 1, 120x140 pixels ✅
- Format: RLE8 compressed ✅
- Color depth: 8-bit ✅

## Files Modified

### 1. SFF Parser (`scripts/mugen/sff_parser.gd`)
**Function**: `_parse_sff_v2_header_ikemen()`
- Fixed the header parsing to skip the correct number of dummy bytes
- Now matches Ikemen GO's implementation exactly

### 2. Analysis Tools
- Created `tools/sff_corrected_analysis.py` to verify the fix
- Updated header parsing logic to match Ikemen GO

### 3. Test Scripts
- Created `scripts/test/corrected_sff_test.gd` to test the fix
- Created corresponding test scene

## Expected Impact
With this fix, the following should now work correctly:

1. **KFM character loading** - Should now load all 281 sprites
2. **Other SFF v2 characters** - Guile, Ryu, Ken, etc. should also load
3. **Character selection UI** - Should show real portraits instead of colored placeholders
4. **Battle scenes** - Characters should display their actual sprites

## Verification Steps
1. Run the corrected SFF test to verify KFM loads properly
2. Test character selection to see if portraits appear
3. Start a battle with KFM to confirm sprites render correctly
4. Test other characters (Guile, Ryu, Ken) to ensure the fix is universal

## Related Files
- `scripts/mugen/sff_parser.gd` - Main fix
- `tools/sff_corrected_analysis.py` - Analysis tool
- `scripts/test/corrected_sff_test.gd` - Test script
- `scenes/test/corrected_sff_test.tscn` - Test scene

## Technical Notes
This fix aligns our parser with the Ikemen GO implementation, which is a well-tested, production-ready MUGEN engine. The header parsing discrepancy was causing all sprite data to be misread, leading to the appearance of "corrupted" files when the files were actually valid.
