# MUGEN Battle System Integration Guide

## Overview

The MUGEN Battle System Integration provides a complete, seamless battle experience from character selection through battle completion. This guide explains how to use the integrated system.

## Core Components

### 1. BattleFlowManager
The central orchestrator that manages the entire battle flow:
- Character selection
- Stage selection  
- Battle execution
- Results display
- Flow state management

### 2. MugenUIManager
Handles all UI elements:
- Character selection grid with portraits
- Battle HUD (health bars, timer, round indicator)
- MUGEN-authentic styling from system.def

### 3. MugenCharacterManager
Manages character data loading and caching:
- Asynchronous character loading
- Data container caching
- Loading progress tracking

### 4. BattleEngine
Executes the actual battle:
- Character node management
- Hit detection and damage
- Round/match logic
- Battle state management

## Quick Start

### Basic Usage

```gdscript
# Create and setup the battle flow manager
var battle_flow = BattleFlowManager.new()
add_child(battle_flow)

# Connect to flow events
battle_flow.battle_flow_changed.connect(_on_flow_changed)
battle_flow.character_selection_complete.connect(_on_characters_selected)
battle_flow.battle_complete.connect(_on_battle_complete)

# Start the battle flow
battle_flow.start_character_selection()
```

### Complete Integration Example

```gdscript
extends Control

var battle_flow_manager: BattleFlowManager

func _ready():
    # Setup battle flow
    battle_flow_manager = BattleFlowManager.new()
    add_child(battle_flow_manager)
    
    # Connect signals
    battle_flow_manager.battle_flow_changed.connect(_on_battle_flow_changed)
    battle_flow_manager.character_selection_complete.connect(_on_character_selection_complete)
    battle_flow_manager.stage_selection_complete.connect(_on_stage_selection_complete)
    battle_flow_manager.battle_complete.connect(_on_battle_complete)
    
    # Start character selection
    battle_flow_manager.start_character_selection()

func _on_battle_flow_changed(flow_state: String):
    print("Flow state: ", flow_state)

func _on_character_selection_complete(p1_data, p2_data):
    print("Characters selected: ", p1_data.display_name, " vs ", p2_data.display_name)

func _on_stage_selection_complete(stage_data):
    print("Stage selected: ", stage_data.name)

func _on_battle_complete(winner: String):
    print("Battle winner: ", winner)
```

## Flow States

The battle system progresses through these states:

1. **MENU** - Main menu state
2. **CHARACTER_SELECT** - Character selection screen
3. **STAGE_SELECT** - Stage selection (currently auto-selects)
4. **BATTLE** - Active battle
5. **RESULTS** - Battle results display

## Configuration

### Required Files

1. **system.def** - MUGEN system configuration
   - Location: `assets/mugen/data/system.def`
   - Defines UI positioning, colors, fonts

2. **select.def** - Character and stage selection
   - Location: `assets/mugen/data/select.def`
   - Lists available characters and stages

### File Structure

```
assets/mugen/
├── data/
│   ├── system.def
│   └── select.def
├── chars/
│   ├── Ryu/
│   │   ├── Ryu.def
│   │   ├── Ryu.sff
│   │   ├── Ryu.air
│   │   ├── Ryu.cmd
│   │   ├── Ryu.cns
│   │   └── portrait.pcx
│   └── Ken/
│       └── ...
└── stages/
    ├── stage1.def
    ├── stage1.sff
    └── ...
```

## Advanced Features

### Portrait Loading

The UI Manager automatically loads character portraits:

```gdscript
# Portraits are loaded from character directories:
# - portrait.pcx
# - face.pcx  
# - {character_name}.pcx

# Or specified in select.def:
char_data = {
    "name": "Ryu",
    "def_path": "assets/mugen/chars/Ryu/Ryu.def",
    "portrait": "assets/mugen/chars/Ryu/portrait.pcx"
}
```

### Character Data Integration

Characters are loaded as complete data containers:

```gdscript
# Access character data during battle
var char_data = battle_engine.character_a_data
print("Character name: ", char_data.display_name)
print("Character states: ", char_data.states.size())
print("Character commands: ", char_data.commands.size())
```

### Custom Battle Flow

You can customize the battle flow:

```gdscript
# Skip character selection and start with specific characters
battle_flow.selected_characters = [char1_data, char2_data]
battle_flow.start_stage_selection()

# Return to character select from anywhere
battle_flow.return_to_character_select()

# Access individual managers
var ui_manager = battle_flow.get_ui_manager()
var char_manager = battle_flow.get_character_manager()
var battle_engine = battle_flow.get_battle_engine()
```

## Input Handling

Default input mappings:
- **Enter/Accept** - Confirm selection, start battle
- **Escape/Cancel** - Return to previous screen
- **Arrow Keys** - Navigate character selection

## Signals Reference

### BattleFlowManager Signals

```gdscript
# Flow state changes
signal battle_flow_changed(flow_state: String)

# Selection events
signal character_selection_complete(p1_data, p2_data)
signal stage_selection_complete(stage_data)

# Battle events  
signal battle_complete(winner: String)
```

### MugenUIManager Signals

```gdscript
# User selections
signal character_selected(character_data)
signal screen_changed(screen_name)
```

### MugenCharacterManager Signals

```gdscript
# Loading events
signal character_loaded(character_name: String, character_data)
signal character_loading_progress(character_name: String, step: String, progress: float)
signal character_loading_error(character_name: String, error: String)
```

## Error Handling

The system handles common errors gracefully:

- Missing configuration files (uses defaults)
- Missing character files (shows error message)
- Invalid MUGEN data (continues with available data)
- Loading failures (provides fallback options)

## Performance Notes

- Characters are loaded asynchronously to prevent frame drops
- Character data is cached to avoid reloading
- Portraits are cached separately for quick access
- Cache limits prevent excessive memory usage

## Extending the System

### Custom UI Screens

```gdscript
# Add custom screens to the flow
func _show_custom_screen():
    ui_manager.show_screen("custom")
    # Add custom UI elements
```

### Custom Battle Logic

```gdscript
# Extend battle engine behavior
battle_engine.hit_landed.connect(_on_custom_hit_logic)

func _on_custom_hit_logic(attacker, defender, damage):
    # Add custom hit effects, scoring, etc.
    pass
```

### Additional File Format Support

```gdscript
# Add new parsers to character data container
character_data.add_custom_parser("new_format", custom_parser)
```

## Troubleshooting

### Common Issues

1. **Characters not loading**
   - Check file paths in select.def
   - Verify DEF files exist and are valid
   - Check console for loading errors

2. **UI elements not positioned correctly**
   - Verify system.def exists and is valid
   - Check system.def positioning values
   - Ensure screen resolution matches configuration

3. **Portraits not displaying**
   - Check portrait file paths
   - Verify PCX files are valid
   - Check portrait cache status

### Debug Information

Enable debug output:

```gdscript
# Enable detailed logging
battle_flow.debug_mode = true
```

This comprehensive integration provides a complete MUGEN-style battle experience while maintaining extensibility for future enhancements.
