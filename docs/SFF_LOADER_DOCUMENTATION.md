# SFF Loader System Documentation

## Overview

The SFF Loader system provides a clean, high-level interface for loading and managing MUGEN SFF (Sprite File Format) files in Godot. It abstracts away the complexity of SFF parsing and provides automatic version detection, caching, and sprite management.

## Components

### 1. SFFLoader (`scripts/mugen/sff_loader.gd`)
The core utility class that handles SFF file loading, version detection, and sprite access.

### 2. CharacterSFFManager (`scripts/mugen/character_sff_manager.gd`)
A higher-level manager specifically designed for character management systems.

### 3. SFFParser (`scripts/mugen/sff_parser.gd`)
The underlying parser that handles the actual SFF file format parsing (used internally by SFFLoader).

## Key Features

### ✅ **Automatic Version Detection**
- Detects SFF v1.0 and v2.0 automatically
- No need to specify version manually
- Handles different file structures transparently

### ✅ **Smart Caching**
- Caches loaded SFF files for performance
- Configurable cache system
- Memory usage tracking
- Cache statistics and management

### ✅ **Error Handling**
- Comprehensive validation before loading
- Graceful error handling and reporting
- File corruption detection
- Missing sprite validation

### ✅ **Batch Operations**
- Preload multiple SFF files
- Batch sprite loading for animations
- Performance optimized for large character rosters

### ✅ **Character-Specific Features**
- Character SFF loading with validation
- Required sprite checking (standing, portrait, etc.)
- Animation frame loading
- Character selection screen support

## Basic Usage

### Loading an SFF File

```gdscript
# Simple loading
var sff_info = SFFLoader.load_sff("res://assets/chars/ryu/ryu.sff")
if sff_info:
    print("Loaded %d sprites" % sff_info.sprite_count)

# Character-specific loading
var sff_info = SFFLoader.load_character_sff("res://assets/chars/ryu", "Ryu")
```

### Getting Sprites

```gdscript
# Get sprite texture
var texture = SFFLoader.get_sprite_texture(sff_info, 0, 0)  # Standing sprite

# Get sprite data dictionary
var sprite_data = SFFLoader.get_sprite_data(sff_info, 5000, 0)  # Portrait

# Check if sprite exists
var has_portrait = SFFLoader.has_sprite(sff_info, 5000, 0)
```

### Version Detection

```gdscript
# Detect version without loading
var version = SFFLoader.detect_sff_version("res://chars/ryu/ryu.sff")
match version:
    SFFLoader.SFFVersion.V1:
        print("SFF v1.0 file")
    SFFLoader.SFFVersion.V2:
        print("SFF v2.0 file")
    _:
        print("Unknown or invalid SFF")
```

## Advanced Usage

### Character Manager Integration

```gdscript
# Create character manager
var char_manager = CharacterSFFManager.new()

# Load character with validation
var success = char_manager.load_character_sff("Ryu", "res://chars/ryu")

# Get character sprites
var standing_texture = char_manager.get_character_sprite("Ryu", 0, 0)
var portrait_texture = char_manager.get_character_sprite("Ryu", 5000, 0)

# Get animation frames
var walk_frames = char_manager.get_character_animation_sprites("Ryu", 10, 5)
```

### Batch Operations

```gdscript
# Preload multiple files
var file_paths = [
    "res://chars/ryu/ryu.sff",
    "res://chars/ken/ken.sff",
    "res://chars/chun/chun.sff"
]
var loaded_sffs = SFFLoader.preload_sff_files(file_paths)

# Batch load sprites for animation
var sprite_list = [[0, 0], [0, 1], [0, 2], [10, 0], [10, 1]]
var textures = SFFLoader.batch_load_sprites(sff_info, sprite_list)
```

### Validation and Error Handling

```gdscript
# Validate file before loading
var validation = SFFLoader.validate_sff_file("res://chars/ryu/ryu.sff")
if not validation.valid:
    print("Invalid SFF: %s" % validation.error)
    return

print("File info:")
print("  Version: %s" % SFFLoader._version_to_string(validation.version))
print("  Sprites: %d" % validation.sprite_count)
print("  Size: %.2f MB" % (validation.file_size / (1024.0 * 1024.0)))
```

### Cache Management

```gdscript
# Get cache statistics
var stats = SFFLoader.get_cache_stats()
print("Cached files: %d" % stats.cached_files)
print("Total sprites: %d" % stats.total_sprites)
print("Memory usage: %.2f MB" % stats.total_size_mb)

# Clear cache
SFFLoader.clear_cache()

# Disable caching
SFFLoader.set_cache_enabled(false)
```

## Character Management Patterns

### Character Selection Screen

```gdscript
func setup_character_selection():
    var characters = ["Ryu", "Ken", "Chun-Li", "Guile"]
    var char_manager = CharacterSFFManager.new()
    
    # Preload all characters
    var character_list = []
    for name in characters:
        character_list.append({
            "name": name,
            "path": "res://chars/%s" % name.to_lower()
        })
    
    var results = char_manager.preload_characters(character_list)
    
    # Create selection data
    var selection_data = char_manager.prepare_character_selection_data()
    
    for data in selection_data:
        create_character_button(data.name, data.portrait, data.standing)
```

### Animation System Integration

```gdscript
func load_character_animations(character_name: String):
    var char_manager = CharacterSFFManager.new()
    
    # Load character
    if not char_manager.load_character_sff(character_name, "res://chars/" + character_name):
        return null
    
    # Get animation sprites
    var animations = {
        "standing": char_manager.get_character_animation_sprites(character_name, 0, 4),
        "walking": char_manager.get_character_animation_sprites(character_name, 10, 6),
        "jumping": char_manager.get_character_animation_sprites(character_name, 40, 3),
        "crouching": char_manager.get_character_animation_sprites(character_name, 15, 2)
    }
    
    return animations
```

### Required Sprite Validation

```gdscript
func validate_character_requirements(character_name: String) -> bool:
    var char_manager = CharacterSFFManager.new()
    
    if not char_manager.load_character_sff(character_name, "res://chars/" + character_name):
        return false
    
    var required_sprites = [
        [0, 0],    # Standing
        [5000, 0], # Portrait  
        [20, 0],   # Hit light
        [5000, 1], # Victory portrait
    ]
    
    for sprite_def in required_sprites:
        if not char_manager.has_character_sprite(character_name, sprite_def[0], sprite_def[1]):
            print("Missing sprite: %d,%d" % [sprite_def[0], sprite_def[1]])
            return false
    
    return true
```

## Performance Considerations

### Memory Management
- Use caching for frequently accessed characters
- Clear cache when memory is limited
- Unload unused characters in large rosters

### Loading Performance
- Preload characters during loading screens
- Use batch operations for multiple sprites
- Validate files before full loading

### Best Practices
- Enable caching for character selection screens
- Disable caching for one-time operations
- Use character manager for consistent character handling
- Validate sprite requirements early in development

## Error Handling

### Common Error Patterns

```gdscript
# File not found
var sff_info = SFFLoader.load_sff("nonexistent.sff")
if not sff_info:
    handle_file_not_found_error()

# Invalid format
var validation = SFFLoader.validate_sff_file("corrupted.sff")
if not validation.valid:
    handle_format_error(validation.error)

# Missing sprites
if not SFFLoader.has_sprite(sff_info, 0, 0):
    handle_missing_sprite_error()
```

### Signal-Based Error Handling

```gdscript
var char_manager = CharacterSFFManager.new()
char_manager.character_sff_loaded.connect(_on_character_loaded)
char_manager.character_sff_failed.connect(_on_character_failed)

func _on_character_loaded(character_name: String, sprite_count: int):
    print("Character loaded: %s (%d sprites)" % [character_name, sprite_count])

func _on_character_failed(character_name: String, error: String):
    print("Character load failed: %s - %s" % [character_name, error])
```

## Integration with Existing Systems

### SpriteBundle Compatibility

```gdscript
# Convert SFF to SpriteBundle format
var sprite_bundle = SFFLoader.create_sprite_bundle_from_sff(sff_info)

# Use with existing sprite systems
var character = MugenCharacter.new()
character.initialize_with_sprite_bundle(sprite_bundle)
```

### MugenCharacterManager Integration

```gdscript
# In MugenCharacterManager
func load_character_enhanced(def_path: String) -> MugenCharacterData:
    var character_data = MugenCharacterData.new()
    
    # Use SFFLoader instead of direct SFFParser
    var sff_path = def_path.get_base_dir() + "/" + character_data.sff_file
    var sff_info = SFFLoader.load_character_sff(def_path.get_base_dir(), character_data.name)
    
    if sff_info:
        character_data.sprite_bundle = SFFLoader.create_sprite_bundle_from_sff(sff_info)
        character_data.sprite_count = sff_info.sprite_count
    
    return character_data
```

## Testing and Validation

### Test Scripts Available
- `scripts/test/sff_loader_example.gd` - Basic usage examples
- `scenes/test/sff_loader_example.tscn` - Test scene

### Validation Tools
- `SFFLoader.validate_sff_file()` - File integrity check
- `SFFLoader.detect_sff_version()` - Version detection
- `CharacterSFFManager.validate_character_sprites()` - Character validation

## Migration Guide

### From Direct SFFParser Usage

**Before:**
```gdscript
var parser = SFFParser.new()
var success = parser.parse_sff_file(file_path)
if success:
    var texture = parser.get_sprite_texture(0, 0)
```

**After:**
```gdscript
var sff_info = SFFLoader.load_sff(file_path)
if sff_info:
    var texture = SFFLoader.get_sprite_texture(sff_info, 0, 0)
```

### Benefits of Migration
- Automatic caching
- Better error handling
- Version detection
- Performance optimizations
- Character-specific features
