# SFF Parser Debug Enhancement

## Current Issue
Guile's character loading shows:
```
Character loading error (Guile): Failed to parse SFF file: assets/mugen/chars/Guile/Guile.sff
```

## Debug Enhancements Applied

### 1. Enhanced Header Parsing Debug (`sff_parser.gd`)
Added detailed debug output to track SFF header parsing:

```gdscript
print("🔍 SFF Signature: '%s'" % header.signature)
print("🔍 SFF Version: %d.%d" % [header.version_hi, header.version_lo])
print("🔍 SFF Info: %d groups, %d images, subheader at %d" % [header.group_count, header.image_count, header.subheader_offset])
```

### 2. Enhanced SFF v1.0 Parsing Debug
Added comprehensive debug output for sprite parsing:

```gdscript
print("🎨 Reading shared palette...")
print("📋 Reading subheader at offset %d..." % header.subheader_offset)
print("  Sprite %d: Group=%d, Image=%d, Length=%d, Linked=%d" % [i, sprite.group, sprite.image, sprite.length, sprite.linked_index])
print("✅ Subheader read complete, %d sprites found" % sprites.size())
print("📦 Reading sprite data starting at offset %d..." % current_data_offset)
```

### 3. Enhanced Error Handling
Added validation for file bounds and corrupted data:

```gdscript
# Check if we can read the full sprite entry (32 bytes)
if file_buffer.get_position() + 32 > file_buffer.get_length():
    parsing_error.emit("File truncated while reading sprite %d header" % i)
    return false
```

### 4. Fixed Method Return Values
Corrected palette reading method calls that didn't return values.

## Test Suite Created

**`sff_debug_test.gd`** - Focused SFF parsing test with:
- File existence validation
- File size reporting
- Signal-based progress monitoring
- Detailed error reporting
- Sprite access testing

## Expected Debug Output

With the enhanced debugging, we should now see detailed output like:
```
🔍 SFF Signature: 'ElecbyteSpr'
🔍 SFF Version: 1.0
🔍 SFF Info: 150 groups, 500 images, subheader at 1024
📋 Reading subheader at offset 1024...
  Sprite 0: Group=0, Image=0, Length=2048, Linked=-1
  Sprite 1: Group=0, Image=1, Length=1536, Linked=-1
✅ Subheader read complete, 500 sprites found
📦 Reading sprite data starting at offset 17408...
```

This will help identify exactly where the SFF parsing is failing for Guile's character.

## Next Steps

1. Run the debug test to see specific error location
2. Based on debug output, fix the identified parsing issue
3. Verify Guile's sprites load correctly
4. Remove debug output once stable

## Status: DEBUGGING ENHANCED ✅

The SFF parser now has comprehensive debug output to identify the exact cause of Guile's SFF parsing failure.
