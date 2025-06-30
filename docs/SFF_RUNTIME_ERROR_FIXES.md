# SFF Parser Runtime Error Fixes

## 🐛 **Issues Identified**
The runtime errors were caused by null parameter errors in the SFF parser, specifically:
- `Parameter "mem" is null` - occurring when trying to access sprite data that was null/uninitialized
- `Parameter "mem_new" is null` - occurring when trying to process empty/null data buffers

## 🔧 **Root Causes**
1. **SFF v2 sprites** have `data` field uninitialized (null) since they use PNG format, not PCX
2. **Null checks missing** when calling PCX parser functions with sprite data
3. **Buffer validation missing** for PNG data reading
4. **ImageTexture creation** without proper null validation

## ✅ **Fixes Applied**

### 1. SFF Parser Null Safety (`sff_parser.gd`)
```gdscript
# Before: sprite.data.size() > 0  (crashes if sprite.data is null)
# After: sprite.data != null and sprite.data.size() > 0

# Initialize sprite.data for SFF v2 to prevent null references
sprite.data = PackedByteArray()

# Added PNG data validation
if png_data == null or png_data.size() == 0:
    print("❌ Empty or null PNG data for sprite %d" % sprite_index)
    return false

# Added texture validation
if texture == null:
    print("❌ Failed to create texture for sprite %d" % sprite_index)
    return false
```

### 2. PCX Parser Null Safety (`pcx_parser.gd`)
```gdscript
# Added null checks for data parameters
if data == null or data.size() < 128:
    print("⚠️ PCX data too small or null")
    return null

# Fixed palette extraction
if data == null or data.size() < 769:
    return PackedColorArray()
```

### 3. Image Processing Validation
```gdscript
# Added image null checks before palette application
if image == null:
    print("⚠️ Cannot apply palette to null image")
    return null

# Added palette validation
if palette == null or palette.size() == 0:
    print("⚠️ Cannot apply null or empty palette")
    return image
```

### 4. Buffer Reading Validation
```gdscript
# Added sprite data buffer validation
if sprite.data == null:
    parsing_error.emit("Failed to read sprite data (buffer returned null)")
    return false
```

### 5. Integer Division Warnings Fixed
```gdscript
# Changed from: x / 8  (generates warning)
# To: x >> 3  (bit shift for divide by 8)

# Changed from: x / 2  (generates warning)  
# To: x >> 1  (bit shift for divide by 2)
```

## 🎯 **Expected Results**
- ✅ No more null parameter errors when loading SFF files
- ✅ Proper handling of both SFF v1 (PCX) and SFF v2 (PNG) formats
- ✅ Graceful degradation when sprite data is missing or corrupted
- ✅ Clear error messages for debugging
- ✅ No compiler warnings about integer division

## 🧪 **Testing**
The fixes ensure that:
1. **KFM character loading** won't crash with null errors
2. **PNG sprites** are handled safely even if data is missing
3. **PCX sprites** are validated before processing
4. **Error reporting** is clear and helpful for debugging

These fixes address the core stability issues while maintaining full SFF v1/v2 compatibility.
