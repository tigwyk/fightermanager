# SFF Loader System Documentation

## Overview

The SFF Loader System provides a comprehensive, high-level interface for loading and managing MUGEN SFF (Sprite File Format) files in Godot 4.4. It handles automatic version detection, caching, batch operations, and provides both basic sprite access and character-specific management functionality.

## Architecture

The system consists of three main components:

### 1. SFFParser (`scripts/mugen/sff_parser.gd`)
- **Core SFF file parsing engine**
- Handles both SFF v1.0 (PCX-based) and SFF v2.0 (PNG/compressed)
- Supports all MUGEN compression formats (RLE8, RLE5, LZ5)
- Based on Ikemen GO reference implementation
- Provides low-level sprite data access

### 2. SFFLoader (`scripts/mugen/sff_loader.gd`)
- **High-level SFF file management utility**
- Automatic version detection and validation
- File caching for performance optimization
- Batch loading operations
- Unified API for sprite access
- Static methods for global access

### 3. CharacterSFFManager (`scripts/mugen/character_sff_manager.gd`)
- **Character-specific SFF management**
- Character validation and sprite requirements checking
- Character selection screen integration
- Memory usage tracking
- Animation sprite grouping

## Features

### ✅ Automatic Version Detection
- Detects SFF v1.0 vs v2.0 automatically
- Handles version-specific parsing differences
- Compatible with both legacy and modern MUGEN files

### ✅ Intelligent Caching
- Automatic caching of loaded SFF files
- Cache statistics and management
- Performance optimization for repeated loads
- Configurable cache enable/disable

### ✅ Robust Error Handling
- Graceful handling of corrupted files
- Comprehensive validation before loading
- Detailed error reporting
- Fallback sprite generation for corrupted files

### ✅ Batch Operations
- Preload multiple SFF files efficiently
- Batch sprite texture loading
- Performance optimization for bulk operations

### ✅ Character Integration
- Character-specific SFF loading patterns
- Required sprite validation
- Character selection screen preparation
- Animation frame grouping

## Usage Examples

### Basic SFF Loading

```gdscript
# Load an SFF file with automatic version detection
var sff_info = SFFLoader.load_sff("res://assets/mugen/chars/Ryu/Ryu.sff")

if sff_info:
    print("Loaded %d sprites" % sff_info.sprite_count)
    
    # Get a specific sprite texture
    var standing_texture = SFFLoader.get_sprite_texture(sff_info, 0, 0)
    
    # Check if sprite exists
    var has_portrait = SFFLoader.has_sprite(sff_info, 5000, 0)
```

### Character Loading

```gdscript
# Load character with common patterns
var sff_info = SFFLoader.load_character_sff("res://assets/mugen/chars/Ryu", "Ryu")

if sff_info:
    # Create sprite bundle for rendering system
    var sprite_bundle = SFFLoader.create_sprite_bundle_from_sff(sff_info)
    
    # Validate character has required sprites
    var has_standing = SFFLoader.has_sprite(sff_info, 0, 0)
    var has_portrait = SFFLoader.has_sprite(sff_info, 5000, 0)
```

### Character Manager Integration

```gdscript
# Initialize character manager
var char_manager = CharacterSFFManager.new()

# Load multiple characters
var characters = [
    {"path": "res://assets/mugen/chars/Ryu", "name": "Ryu"},
    {"path": "res://assets/mugen/chars/Ken", "name": "Ken"}
]

for char_info in characters:
    char_manager.load_character_sff(char_info.name, char_info.path)

# Access character sprites
var ryu_standing = char_manager.get_character_sprite("Ryu", 0, 0)
var ken_portrait = char_manager.get_character_sprite("Ken", 5000, 0)

# Get character selection data
var selection_data = char_manager.prepare_character_selection_data()
```

### Batch Operations

```gdscript
# Preload multiple SFF files
var file_paths = [
    "res://assets/mugen/chars/Ryu/Ryu.sff",
    "res://assets/mugen/chars/Ken/Ken.sff",
    "res://assets/mugen/chars/Guile/Guile.sff"
]

var loaded_sffs = SFFLoader.preload_sff_files(file_paths)

# Batch load specific sprites
var sprite_list = [
    [0, 0], [0, 1], [0, 2],  # Standing frames
    [10, 0], [10, 1],        # Walk frames
    [5000, 0]                # Portrait
]

if loaded_sffs.size() > 0:
    var sff_info = loaded_sffs.values()[0]
    var textures = SFFLoader.batch_load_sprites(sff_info, sprite_list)
```

### Cache Management

```gdscript
# Get cache statistics
var stats = SFFLoader.get_cache_stats()
print("Cached files: %d" % stats.cached_files)
print("Cache size: %.2f MB" % stats.total_size_mb)

# Clear cache when needed
SFFLoader.clear_cache()

# Disable caching for debugging
SFFLoader.set_cache_enabled(false)
```

### File Validation

```gdscript
# Validate SFF file before loading
var validation = SFFLoader.validate_sff_file("res://path/to/character.sff")

if validation.valid:
    print("File is valid SFF %s with %d sprites" % [
        SFFLoader._version_to_string(validation.version),
        validation.sprite_count
    ])
else:
    print("Invalid SFF file: %s" % validation.error)
```

## API Reference

### SFFLoader Static Methods

#### File Operations
- `load_sff(file_path: String, use_cache: bool = true) -> SFFInfo`
- `detect_sff_version(file_path: String) -> SFFVersion`
- `validate_sff_file(file_path: String) -> Dictionary`
- `load_character_sff(character_path: String, character_name: String = "") -> SFFInfo`

#### Sprite Access
- `get_sprite_texture(sff_info: SFFInfo, group: int, image: int) -> Texture2D`
- `get_sprite_data(sff_info: SFFInfo, group: int, image: int) -> Dictionary`
- `has_sprite(sff_info: SFFInfo, group: int, image: int) -> bool`
- `get_available_sprites(sff_info: SFFInfo) -> Array`
- `get_sprite_groups(sff_info: SFFInfo) -> Array`

#### Batch Operations
- `preload_sff_files(file_paths: Array[String]) -> Dictionary`
- `batch_load_sprites(sff_info: SFFInfo, sprite_list: Array) -> Dictionary`

#### Cache Management
- `get_cache_stats() -> Dictionary`
- `clear_cache()`
- `set_cache_enabled(enabled: bool)`

#### Utility
- `get_sff_info_summary(sff_info: SFFInfo) -> Dictionary`
- `create_sprite_bundle_from_sff(sff_info: SFFInfo) -> Dictionary`
- `quick_sprite_check(file_path: String, group: int, image: int) -> bool`

### CharacterSFFManager Methods

#### Character Loading
- `load_character_sff(character_name: String, character_path: String) -> bool`
- `validate_character_sprites(sff_info) -> Dictionary`
- `preload_characters(character_list: Array) -> Dictionary`

#### Sprite Access
- `get_character_sprite(character_name: String, group: int, image: int) -> Texture2D`
- `get_character_sprite_data(character_name: String, group: int, image: int) -> Dictionary`
- `has_character_sprite(character_name: String, group: int, image: int) -> bool`
- `get_character_sprite_groups(character_name: String) -> Array`

#### Animation Support
- `get_character_animation_sprites(character_name: String, group: int, frame_count: int = 10) -> Array`
- `create_character_sprite_bundle(character_name: String) -> Dictionary`

#### Management
- `get_character_info(character_name: String) -> Dictionary`
- `get_all_characters_info() -> Array`
- `unload_character(character_name: String) -> bool`
- `clear_all_characters()`

#### Integration
- `prepare_character_selection_data() -> Array`
- `get_memory_stats() -> Dictionary`

## Data Structures

### SFFInfo Class
```gdscript
class SFFInfo:
    var file_path: String          # Path to SFF file
    var version: SFFVersion        # SFF version (V1 or V2)
    var sprite_count: int          # Number of sprites
    var group_count: int           # Number of sprite groups
    var parser: SFFParser          # Associated parser instance
    var load_time: float           # Time taken to load
    var file_size: int             # File size in bytes
```

### Validation Result Dictionary
```gdscript
{
    "valid": bool,                 # Whether file is valid
    "version": SFFVersion,         # Detected version
    "error": String,               # Error message if invalid
    "sprite_count": int,           # Expected sprite count
    "file_size": int               # File size in bytes
}
```

### Sprite Data Dictionary
```gdscript
{
    "image": Image,                # Godot Image object
    "x": int,                      # X offset
    "y": int,                      # Y offset
    "offset_x": int,               # X offset (alias)
    "offset_y": int,               # Y offset (alias)
    "group": int,                  # Sprite group
    "image_num": int,              # Image number
    "width": int,                  # Sprite width
    "height": int                  # Sprite height
}
```

## Integration with Existing Systems

### SpriteBundle Compatibility
The SFF Loader is fully compatible with the existing SpriteBundle system:

```gdscript
# Convert SFF to SpriteBundle format
var sprite_bundle = SFFLoader.create_sprite_bundle_from_sff(sff_info)

# Use with existing SpriteBundle code
var sprite_bundle_obj = SpriteBundle.new()
sprite_bundle_obj.sprites = sprite_bundle
```

### Character Node Integration
```gdscript
# In character setup
func setup_character_graphics(character_name: String):
    var char_manager = CharacterSFFManager.new()
    
    if char_manager.load_character_sff(character_name, character_path):
        var standing_texture = char_manager.get_character_sprite(character_name, 0, 0)
        if standing_texture:
            $CharacterSprite.texture = standing_texture
```

### Animation System Integration
```gdscript
# Get animation frames
func load_character_animation(character_name: String, animation_group: int):
    var char_manager = CharacterSFFManager.new()
    var frames = char_manager.get_character_animation_sprites(character_name, animation_group, 10)
    
    for frame_data in frames:
        animation_player.add_frame(frame_data.texture)
```

## Performance Considerations

### Memory Usage
- SFF files are cached to avoid repeated parsing
- Individual sprite textures are created on-demand
- Use `clear_cache()` to free memory when needed
- Monitor memory usage with `get_memory_stats()`

### Loading Performance
- Version detection is fast (header-only parsing)
- Validation avoids full parsing when possible
- Batch operations are optimized for multiple sprites
- Cache hits provide instant access

### Best Practices
1. **Preload during game startup** for frequently accessed characters
2. **Use batch operations** when loading multiple sprites
3. **Enable caching** for production builds
4. **Validate files** before attempting to load
5. **Monitor memory usage** in character selection screens

## Error Handling

### Common Error Scenarios
- **File not found**: Returns null/false, logs error
- **Invalid format**: Returns null/false with error message
- **Corrupted data**: Attempts fallback, logs warning
- **Missing sprites**: Creates placeholder sprites
- **Version unsupported**: Clear error message

### Error Recovery
- Fallback sprite generation for missing sprites
- Graceful degradation for corrupted files
- Detailed error reporting for debugging
- Safe cleanup on parsing failures

## Testing

Use the comprehensive test script to validate the system:

```gdscript
# Run comprehensive tests
# Load scene: scenes/test/sff_loader_comprehensive_test.tscn
```

Tests cover:
- Version detection for all character files
- File validation and error handling
- Basic and character-specific loading
- Sprite access methods
- Batch operations
- Cache management
- Character manager integration
- Memory and performance metrics

## Future Enhancements

### Planned Features
- **Palette management**: Support for character-specific palettes
- **Lazy loading**: Load sprites only when accessed
- **Background loading**: Async loading for large files
- **Compression optimization**: Better memory usage for compressed sprites
- **Asset validation tools**: Comprehensive character validation

### Integration Opportunities
- **Animation system**: Direct integration with AnimationPlayer
- **Shader support**: Palette swapping and effects
- **Asset pipeline**: Editor tools for SFF management
- **Modding support**: Runtime SFF loading from user files

## Conclusion

The SFF Loader System provides a robust, efficient, and easy-to-use interface for working with MUGEN SFF files in Godot. It handles the complexity of MUGEN file formats while providing a clean API that integrates well with existing game systems.

The combination of automatic version detection, intelligent caching, comprehensive error handling, and character-specific management makes it suitable for both development and production use in MUGEN-based fighting games.
