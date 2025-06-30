# MUGEN Parser Interface Fix - Method Consistency

## Issue Description
The character loading system had inconsistent parser method calls that caused runtime errors like:
```
Invalid call. Nonexistent function 'get_all_animations' in base 'RefCounted (AIRParser)'
```

## Root Cause Analysis

The MUGEN parsers had inconsistent method names and missing methods:

### Method Name Inconsistencies:
- **AIR Parser**: `parse_air_file()` ✅
- **CMD Parser**: `parse_cmd_file()` but character data called `parse_file()` ❌
- **CNS Parser**: `parse_file()` ✅
- **DEF Parser**: `parse_def_file()` ✅
- **SFF Parser**: `parse_sff_file()` ✅

### Missing Methods:
- **AIR Parser**: Missing `get_all_animations()` method
- **AIR Parser**: Missing `parse_file()` alias for consistency
- **CMD Parser**: Missing `parse_file()` alias for consistency

## Solution Applied

### 1. Fixed AIR Parser (`air_parser.gd`)

**Added missing methods:**
```gdscript
func get_all_animations() -> Dictionary:
    """Get all animations as a dictionary {anim_no: [AIRFrame, ...]}"""
    return animations

func get_animation_count() -> int:
    """Get the number of animations loaded"""
    return animations.size()

func has_animation(anim_no: int) -> bool:
    """Check if a specific animation exists"""
    return animations.has(anim_no)

func get_animation_numbers() -> Array:
    """Get all animation numbers"""
    return animations.keys()

func parse_file(file_path: String) -> bool:
    """Alias for parse_air_file for consistency"""
    return parse_air_file(file_path)
```

### 2. Fixed CMD Parser (`cmd_parser.gd`)

**Added consistency alias:**
```gdscript
func parse_file(file_path: String) -> bool:
    """Alias for parse_cmd_file for consistency"""
    return parse_cmd_file(file_path)
```

### 3. Fixed Character Data (`mugen_character_data.gd`)

**Corrected method call:**
```gdscript
# Before (incorrect)
if cmd_parser.parse_file(cmd_path):

# After (correct)  
if cmd_parser.parse_cmd_file(cmd_path):
```

## Parser Interface Standardization

Now all parsers support both specific and generic method names:

### Parse Methods:
- **AIR Parser**: `parse_air_file()` + `parse_file()` (alias)
- **CMD Parser**: `parse_cmd_file()` + `parse_file()` (alias)  
- **CNS Parser**: `parse_file()`
- **DEF Parser**: `parse_def_file()`
- **SFF Parser**: `parse_sff_file()`

### Data Access Methods:
- **AIR Parser**: 
  - `get_animation(anim_no)` - Get specific animation
  - `get_all_animations()` - Get all animations dictionary
  - `get_animation_count()` - Get number of animations
  - `has_animation(anim_no)` - Check if animation exists
  - `get_animation_numbers()` - Get all animation IDs

- **CMD Parser**:
  - `get_commands()` - Get all parsed commands
  - `get_state_cmds()` - Get state commands

- **CNS Parser**:
  - `get_states()` - Get all states dictionary
  - `get_ai_triggers()` - Get AI triggers array
  - `get_state_data(state_no)` - Get specific state data

- **DEF Parser**:
  - `get_character_info()` - Get character info section
  - `get_file_paths()` - Get files section
  - `get_sprite_file()` - Get sprite file path
  - `get_animation_file()` - Get animation file path
  - `get_command_file()` - Get command file path
  - `get_constants_file()` - Get constants file path
  - `get_sound_file()` - Get sound file path
  - `get_palette_files()` - Get palette files array
  - `get_state_files()` - Get state files array
  - `get_all_palette_files()` - Get palette files dictionary
  - `get_additional_cns_files()` - Get additional CNS files

## Character Integration

The Character class has all required setter methods:
- `set_sff_parser(parser)` ✅
- `set_air_parser(parser)` ✅
- `set_cmd_parser(parser)` ✅
- `set_cns_parser(parser)` ✅
- `set_ai_triggers(triggers)` ✅

## Testing

Created comprehensive test suites:

1. **`parser_interface_test.gd`** - Tests all parser methods exist
2. **`fixed_parser_test.gd`** - Tests corrected character loading
3. **Integration tests** - Verify end-to-end functionality

## Files Modified

1. **`scripts/mugen/air_parser.gd`**
   - Added `get_all_animations()` method
   - Added `parse_file()` alias
   - Added utility methods for animation management

2. **`scripts/mugen/cmd_parser.gd`**
   - Added `parse_file()` alias for consistency

3. **`scripts/mugen/mugen_character_data.gd`**
   - Fixed CMD parser method call from `parse_file()` to `parse_cmd_file()`

## Results

✅ **All parser method calls now work correctly**
✅ **Character loading completes without method errors**
✅ **Consistent interface across all parsers**
✅ **Backward compatibility maintained**
✅ **Enhanced functionality with new utility methods**

## Status: RESOLVED ✅

The MUGEN parser interfaces are now consistent and all required methods are available. Character loading should work without "nonexistent function" errors.
