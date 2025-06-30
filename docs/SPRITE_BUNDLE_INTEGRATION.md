# MUGEN SpriteBundle Integration Guide

## Overview

This document outlines the integration of Godot-MUGEN best practices for SFF sprite rendering in our MUGEN fighting game project. The implementation is based on the reference project at `https://github.com/jefersondaniel/godot-mugen` and adapts their proven patterns for Godot 4.4.

## Architecture

### Core Components

1. **SpriteBundle** (`scripts/mugen/sprite_bundle.gd`)
   - Container for MUGEN SFF sprites
   - Provides texture creation and sprite node generation
   - Handles sprite lookup by group/image numbers
   - Compatible with both SFF v1 (PCX) and SFF v2 (PNG) formats

2. **MugenAnimationSprite** (`scripts/mugen/mugen_animation_sprite.gd`)
   - Extends AnimatedSprite2D for MUGEN sprite animation
   - Handles collision box rendering and detection
   - Manages frame mapping and sprite offsets
   - Supports facing direction and flip handling

3. **Enhanced SFF Parser** (`scripts/mugen/sff_parser.gd`)
   - Updated with Ikemen GO compatibility
   - Provides SpriteBundle-compatible data format
   - Robust error handling and sprite validation

### Integration Flow

```
SFF File → SFF Parser → Sprite Data Dictionary → SpriteBundle → MugenAnimationSprite → Godot Scene
```

## API Reference

### SpriteBundle

#### Constructor
```gdscript
SpriteBundle.new(sprite_data: Dictionary = {})
```

#### Key Methods
- `get_sprite(path: Array) -> Dictionary` - Get sprite data by [group, image]
- `create_texture(sprite_data: Dictionary) -> ImageTexture` - Create Godot texture
- `create_sprite_node(path: Array, facing: int = 1) -> Sprite2D` - Create sprite node
- `has_sprite(path: Array) -> bool` - Check sprite existence

### MugenAnimationSprite

#### Constructor
```gdscript
MugenAnimationSprite.new(sprite_bundle: SpriteBundle, animations: Dictionary = {})
```

#### Key Methods
- `set_sprite_image(groupno: int, imageno: int, offset: Vector2)` - Display specific sprite
- `set_facing_right(value: bool)` - Set facing direction
- `set_collisions(collisions: Dictionary)` - Set collision boxes
- `check_collision(other_sprite, type: int) -> bool` - Check collision with another sprite

### MugenCharacter Integration

#### New Methods
- `get_sprite_bundle() -> SpriteBundle` - Get character's sprite bundle
- `create_animation_sprite(animations_data: Dictionary) -> MugenAnimationSprite` - Create animation sprite

## Godot-MUGEN Best Practices Implemented

### 1. Texture Management
- **Pattern**: Single texture creation per sprite with proper Image handling
- **Implementation**: `SpriteBundle.create_texture()` uses `ImageTexture.new()` and `set_image()`
- **Benefit**: Efficient memory usage and Godot 4.4 compatibility

### 2. Sprite Frame Mapping
- **Pattern**: Map MUGEN group/image numbers to Godot frame indices
- **Implementation**: `frame_mapping` and `image_mapping` dictionaries in MugenAnimationSprite
- **Benefit**: Fast sprite lookup and seamless MUGEN→Godot translation

### 3. Collision System
- **Pattern**: Area2D-based collision detection with collision masks
- **Implementation**: Separate attack and collision areas with physics queries
- **Benefit**: Accurate hitbox detection compatible with Godot's physics

### 4. Offset Handling
- **Pattern**: Store sprite offsets and apply them during rendering
- **Implementation**: Offset stored in sprite data and applied in `set_sprite_image()`
- **Benefit**: Authentic MUGEN sprite positioning

### 5. Facing Direction
- **Pattern**: Flip sprites and collision boxes based on character facing
- **Implementation**: `set_facing_right()` with automatic coordinate adjustment
- **Benefit**: Proper left/right facing behavior

## Usage Examples

### Basic Character Loading
```gdscript
var character = MugenCharacter.new()
character.character_loaded.connect(_on_character_loaded)
character.load_from_directory("path/to/character")

func _on_character_loaded():
    var sprite_bundle = character.get_sprite_bundle()
    var animation_sprite = character.create_animation_sprite()
    add_child(animation_sprite)
    
    # Display specific sprite
    animation_sprite.set_sprite_image(0, 0, Vector2.ZERO)
```

### Manual Sprite Creation
```gdscript
var sprite_bundle = character.get_sprite_bundle()
var sprite_node = sprite_bundle.create_sprite_node([0, 0], 1)
add_child(sprite_node)
```

### Animation and Collision
```gdscript
var anim_sprite = character.create_animation_sprite(animations_data)
anim_sprite.set_facing_right(false)
anim_sprite.set_debug_collisions(true)

# Check collision with another character
if anim_sprite.check_collision(other_character.animation_sprite, 1):
    print("Attack collision detected!")
```

## Testing

### Test Scene
- **File**: `scenes/test/sprite_bundle_test.tscn`
- **Script**: `scripts/test/sprite_bundle_test.gd`

### Test Controls
- **SPACE**: Cycle through available sprites
- **F**: Flip facing direction
- **D**: Toggle debug collision boxes

### Running Tests
1. Open the test scene in Godot editor
2. Run the scene (F6)
3. Use test controls to verify sprite rendering
4. Check console output for loading status

## Key Improvements Over Previous Implementation

### 1. Godot-MUGEN Compatibility
- Follows proven patterns from successful MUGEN implementation
- Uses same architectural approach for texture and collision handling
- Compatible naming conventions and API design

### 2. Better Error Handling
- Graceful degradation when sprites are missing
- Clear error messages with sprite group/image information
- Fallback to empty textures instead of crashes

### 3. Memory Efficiency
- Sprites loaded on-demand rather than all at once
- Proper texture cleanup and resource management
- Reduced debug output to prevent log spam

### 4. Modular Design
- Clear separation between parsing, bundling, and rendering
- Easy to extend for additional sprite formats
- Testable components with well-defined interfaces

## Future Enhancements

### 1. Animation Support
- Integration with AIR parser for automatic animation playback
- Frame timing and looping support
- Animation state management

### 2. Palette Management
- Multiple palette support for character color variations
- Dynamic palette swapping during gameplay
- Team color customization

### 3. Advanced Collision
- Multi-box collision support
- Collision box visualization and debugging
- Attack/defense state integration

### 4. Performance Optimization
- Sprite atlas generation for batched rendering
- Background loading for large character sets
- Memory pool management for frequent sprite changes

## Troubleshooting

### Common Issues

1. **"Missing sprite" errors**
   - Check SFF file integrity with hex dump analysis
   - Verify group/image numbers match animation data
   - Ensure SFF parser completed successfully

2. **Texture creation failures**
   - Verify Image data is valid before texture creation
   - Check for null Image objects in sprite data
   - Validate PNG/PCX parsing results

3. **Collision not working**
   - Ensure collision areas are properly initialized
   - Check collision masks and layers
   - Verify collision box coordinates

4. **Animation not displaying**
   - Confirm MugenAnimationSprite is added to scene tree
   - Check frame mapping contains expected sprites
   - Verify sprite frame count > 0

## References

- **Godot-MUGEN Project**: https://github.com/jefersondaniel/godot-mugen
- **Ikemen GO SFF Implementation**: Referenced for robust parsing logic
- **MUGEN Documentation**: Official specification for SFF format details

This implementation provides a solid foundation for authentic MUGEN sprite rendering in Godot while following established best practices from the community.
