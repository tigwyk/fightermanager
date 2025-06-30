## Testing SFF v2 Parser Fix

### Expected Results for KFM

Based on the hex dump analysis, KFM should be detected as:
- **Version**: 2.0.1.0 (SFF v2)
- **Sprites**: 281
- **Subheader offset**: Will be read from SFF v2 header structure

### Key Changes Made

1. **Fixed version parsing**: Now reads 4 bytes (Ver3, Ver2, Ver1, Ver0)
2. **Added SFF v2 support**: Proper header parsing for v2 format
3. **Version detection**: Uses Ver0 as major version (2 = SFF v2)
4. **Header layout**: Different field positions for v1 vs v2

### Version Byte Interpretation

From hex: `00 01 00 02`
- Ver3 = 0
- Ver2 = 1  
- Ver1 = 0
- Ver0 = 2

This indicates **SFF version 2.0.1.0**, which should now be properly handled.

### Expected Output

```
🔍 Detected SFF v2.x format
🔍 Parsing SFF v2 header...
🔍 SFF v2 header parsed:
   Sprite header offset: [correct value]
   Number of sprites: [should be non-zero]
   Palette header offset: [valid offset]
   Number of palettes: [reasonable count]
```

The parser should now correctly identify KFM as SFF v2 and parse the header properly.
