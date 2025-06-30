# MUGEN Parser Method Names - Corrected

## Issue
I was incorrectly using `parse_file()` for the main DEF parser when the correct method is `parse_def_file()`.

## Correct Method Names

### DEFParser (Character/Stage Definition Parser)
- **Correct**: `parse_def_file(file_path: String) -> Dictionary`
- **Usage**: `def_parser.parse_def_file(def_path)`

### SystemDefParser (System Definition Parser)
- **Correct**: `parse_file(file_path: String) -> bool`
- **Usage**: `system_def_parser.parse_file(system_def_path)`

### SelectDefParser (Character Select Definition Parser)
- **Correct**: `parse_file(file_path: String) -> bool`
- **Usage**: `select_def_parser.parse_file(select_def_path)`

### SFFParser (Sprite File Parser)
- **Correct**: `parse_sff_file(file_path: String) -> bool`
- **Usage**: `sff_parser.parse_sff_file(sff_path)`

### AIRParser (Animation File Parser)
- **Correct**: `parse_air_file(file_path: String) -> bool`
- **Usage**: `air_parser.parse_air_file(air_path)`

### CMDParser (Command File Parser)
- **Correct**: `parse_cmd_file(file_path: String) -> bool`
- **Alias**: `parse_file(file_path: String) -> bool` (for consistency)
- **Usage**: `cmd_parser.parse_cmd_file(cmd_path)`

### CNSParser (Constants/State File Parser)
- **Correct**: `parse_file(file_path: String) -> bool`
- **Usage**: `cns_parser.parse_file(cns_path)`

## Files Fixed
- `scripts/mugen/mugen_character_manager.gd` - Fixed DEF parser method call
- `scripts/ui/main_menu_ui.gd` - Fixed SFF diagnostic method call

## Files Already Correct
- `scripts/mugen/mugen_character_data.gd` - All parser calls correct
- `scripts/mugen/stage_renderer.gd` - DEF parser call correct
- `scripts/ui/mugen_main_menu.gd` - System/Select DEF parser calls correct

## Key Insight
The main confusion was that different parsers have different primary method names:
- **DEF files**: Use `parse_def_file()` (more specific)
- **Most others**: Use `parse_file()` (generic)
- **Some specialty**: Use specific names like `parse_sff_file()`, `parse_air_file()`, etc.

All method names are now consistent with their actual implementations.
