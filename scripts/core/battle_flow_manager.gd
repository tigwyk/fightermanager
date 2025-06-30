extends Node
class_name BattleFlowManager

## Battle Flow Manager - Orchestrates the complete MUGEN-style battle experience
## Handles character selection → stage selection → battle → results flow

signal battle_flow_changed(flow_state: String)
signal character_selection_complete(p1_data, p2_data)
signal stage_selection_complete(stage_data)
signal battle_complete(winner: String)

enum FlowState {
	MENU,
	CHARACTER_SELECT,
	STAGE_SELECT,
	BATTLE,
	RESULTS
}

var current_flow_state: FlowState = FlowState.MENU

# Core systems
var ui_manager: MugenUIManager
var character_manager # MugenCharacterManager
var battle_engine: BattleEngine
var stage_renderer # StageRenderer

# Selection state
var selected_characters: Array = []  # Array of MugenCharacterData
var selected_stage_data: Dictionary = {}
var battle_result: Dictionary = {}

# Configuration
var system_def_path: String = "data/mugen/system.def"
var select_def_path: String = "data/mugen/select.def"
var stages_path: String = "assets/mugen/stages"

func _ready():
	print("Battle Flow Manager initialized")
	_setup_systems()

func _setup_systems():
	# Create and configure UI Manager
	ui_manager = MugenUIManager.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	
	# Create Character Manager
	character_manager = preload("res://scripts/mugen/mugen_character_manager.gd").new()
	character_manager.name = "CharacterManager"
	add_child(character_manager)
	
	# Create Battle Engine
	battle_engine = BattleEngine.new()
	battle_engine.name = "BattleEngine"
	add_child(battle_engine)
	
	# Create Stage Renderer
	stage_renderer = preload("res://scripts/mugen/stage_renderer.gd").new()
	stage_renderer.name = "StageRenderer"
	add_child(stage_renderer)
	
	# Connect signals
	_connect_signals()
	
	# Load MUGEN configuration
	_load_mugen_config()

func _connect_signals():
	# UI Manager signals
	ui_manager.character_selected.connect(_on_character_selected)
	ui_manager.screen_changed.connect(_on_screen_changed)
	
	# Character Manager signals
	character_manager.character_loaded.connect(_on_character_loaded)
	character_manager.character_loading_error.connect(_on_character_loading_error)
	
	# Battle Engine signals
	battle_engine.round_start.connect(_on_round_start)
	battle_engine.round_end.connect(_on_round_end)
	battle_engine.hit_landed.connect(_on_hit_landed)
	battle_engine.character_data_updated.connect(_on_character_data_updated)

func _load_mugen_config():
	# Load system configuration
	if ui_manager.load_system_config(system_def_path):
		print("System config loaded successfully")
	else:
		print("Warning: Could not load system config from: ", system_def_path)
	
	# Load character selection configuration
	if ui_manager.load_select_config(select_def_path):
		print("Select config loaded successfully")
	else:
		print("Warning: Could not load select config from: ", select_def_path)

# PUBLIC API

func start_character_selection():
	"""Begin the character selection process"""
	selected_characters.clear()
	current_flow_state = FlowState.CHARACTER_SELECT
	ui_manager.show_screen("select")
	emit_signal("battle_flow_changed", "character_select")
	print("Character selection started")

func start_stage_selection():
	"""Begin stage selection after characters are chosen"""
	current_flow_state = FlowState.STAGE_SELECT
	# For now, auto-select first available stage
	var available_stages = ui_manager.get_available_stages()
	if available_stages.size() > 0:
		_select_stage(available_stages[0])
	else:
		# Fallback to default stage
		_select_default_stage()

func start_battle():
	"""Start the battle with selected characters and stage"""
	if selected_characters.size() < 2:
		print("Error: Need 2 characters to start battle")
		return false
	
	current_flow_state = FlowState.BATTLE
	ui_manager.show_screen("battle")
	
	# Load stage
	if not selected_stage_data.is_empty():
		_load_and_setup_stage()
	
	# Create character nodes
	var char_a = _create_character_node(selected_characters[0])
	var char_b = _create_character_node(selected_characters[1])
	
	if char_a and char_b:
		# Position characters
		char_a.global_position = Vector2(100, 300)
		char_b.global_position = Vector2(500, 300)
		char_b.set_facing(-1)  # Face left
		
		# Start battle
		battle_engine.start_battle(char_a, char_b)
		emit_signal("battle_flow_changed", "battle")
		print("Battle started!")
		return true
	else:
		print("Error: Failed to create character nodes")
		return false

func end_battle(winner: String):
	"""End the current battle and show results"""
	current_flow_state = FlowState.RESULTS
	battle_result = {
		"winner": winner,
		"p1_name": selected_characters[0].get_display_name() if selected_characters.size() > 0 else "Unknown",
		"p2_name": selected_characters[1].get_display_name() if selected_characters.size() > 1 else "Unknown"
	}
	emit_signal("battle_complete", winner)
	emit_signal("battle_flow_changed", "results")
	print("Battle ended. Winner: ", winner)

func return_to_character_select():
	"""Return to character selection from any state"""
	_cleanup_battle()
	start_character_selection()

func return_to_menu():
	"""Return to main menu"""
	_cleanup_battle()
	current_flow_state = FlowState.MENU
	emit_signal("battle_flow_changed", "menu")

# INTERNAL HANDLERS

func _on_character_selected(character_data: Dictionary):
	print("Character selected: ", character_data.name)
	
	# Load character data
	var mugen_character_data = character_manager.load_character_from_select(character_data)
	if mugen_character_data:
		# For now, we'll handle the loading asynchronously
		print("Loading character data for: ", character_data.name)

func _on_character_loaded(character_name: String, character_data):
	print("Character loaded: ", character_name)
	selected_characters.append(character_data)
	
	# Check if we have enough characters to proceed
	if selected_characters.size() >= 2:
		emit_signal("character_selection_complete", selected_characters[0], selected_characters[1])
		# Auto-proceed to stage selection
		start_stage_selection()
	elif selected_characters.size() == 1:
		print("Player 1 selected. Waiting for Player 2...")

func _on_character_loading_error(character_name: String, error: String):
	print("Character loading failed: ", character_name, " - ", error)

func _on_screen_changed(screen_name: String):
	print("Screen changed to: ", screen_name)

func _on_round_start():
	print("Round started")

func _on_round_end(winner: String):
	print("Round ended. Winner: ", winner)
	# For now, end battle after one round
	end_battle(winner)

func _on_hit_landed(attacker, defender, damage):
	print("Hit landed: ", damage, " damage")
	# Update UI health bars
	if attacker and defender:
		var p1_health = battle_engine.health_a / float(battle_engine.max_health_a)
		var p2_health = battle_engine.health_b / float(battle_engine.max_health_b)
		ui_manager.update_health_bars(p1_health, p2_health)

func _on_character_data_updated(_character_a_data, _character_b_data):
	print("Character data updated for battle UI")

func _select_stage(stage_data: Dictionary):
	selected_stage_data = stage_data
	emit_signal("stage_selection_complete", stage_data)
	print("Stage selected: ", stage_data.get("name", "Unknown"))
	# Auto-proceed to battle
	start_battle()

func _select_default_stage():
	# Create a default stage entry
	selected_stage_data = {
		"name": "Default Stage",
		"def_path": "assets/mugen/stages/sf2-airforce.def"
	}
	emit_signal("stage_selection_complete", selected_stage_data)
	print("Default stage selected")
	# Auto-proceed to battle
	start_battle()

func _load_and_setup_stage():
	var stage_def_path = selected_stage_data.get("def_path", "")
	if not stage_def_path.is_empty():
		stage_renderer.load_stage(stage_def_path)
		print("Stage loaded: ", stage_def_path)

func _create_character_node(character_data) -> Character:
	"""Create a Character node from MugenCharacterData"""
	var character = preload("res://scripts/mugen/character.gd").new()
	character.name = character_data.get_display_name()
	
	# Load character from data
	if character.load_from_character_data(character_data):
		add_child(character)
		print("Character node created: ", character_data.get_display_name())
		return character
	else:
		print("Error: Failed to load character from data: ", character_data.get_display_name())
		character.queue_free()
		return null

func _cleanup_battle():
	"""Clean up battle-related nodes and state"""
	# Remove character nodes
	for child in get_children():
		if child is Character:
			child.queue_free()
	
	# Reset battle state
	selected_characters.clear()
	selected_stage_data.clear()
	battle_result.clear()

# UTILITY FUNCTIONS

func get_current_flow_state() -> FlowState:
	return current_flow_state

func get_flow_state_name() -> String:
	match current_flow_state:
		FlowState.MENU:
			return "menu"
		FlowState.CHARACTER_SELECT:
			return "character_select"
		FlowState.STAGE_SELECT:
			return "stage_select"
		FlowState.BATTLE:
			return "battle"
		FlowState.RESULTS:
			return "results"
		_:
			return "unknown"

func get_selected_characters() -> Array:
	return selected_characters

func get_selected_stage() -> Dictionary:
	return selected_stage_data

func get_battle_result() -> Dictionary:
	return battle_result

func get_ui_manager() -> MugenUIManager:
	return ui_manager

func get_character_manager():
	return character_manager

func get_battle_engine() -> BattleEngine:
	return battle_engine

func get_stage_renderer():
	return stage_renderer
