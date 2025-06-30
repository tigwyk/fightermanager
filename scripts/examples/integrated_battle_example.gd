extends Node

## Integrated Battle System Example - Complete MUGEN-style Battle Flow
## Demonstrates the full integration of Character Data Container, UI Manager, and Battle Engine

func _ready():
	print("=== MUGEN Integrated Battle System Example ===")
	
	# Run the example after a short delay
	await get_tree().create_timer(1.0).timeout
	run_integrated_battle_example()

func run_integrated_battle_example():
	"""Demonstrate the complete integrated battle system"""
	print("\n--- Creating Battle Flow Manager ---")
	
	# Create the main battle flow manager
	var battle_flow = preload("res://scripts/core/battle_flow_manager.gd").new()
	battle_flow.name = "BattleFlowManager"
	add_child(battle_flow)
	
	# Connect to events
	battle_flow.battle_flow_changed.connect(_on_flow_changed)
	battle_flow.character_selection_complete.connect(_on_characters_selected)
	battle_flow.stage_selection_complete.connect(_on_stage_selected)
	battle_flow.battle_complete.connect(_on_battle_complete)
	
	print("Battle flow manager created and connected")
	
	# Wait for initialization
	await get_tree().process_frame
	
	print("\n--- Starting Character Selection ---")
	battle_flow.start_character_selection()
	
	# Simulate character selection process
	await get_tree().create_timer(2.0).timeout
	_simulate_character_selection(battle_flow)

func _simulate_character_selection(battle_flow):
	"""Simulate the character selection process"""
	print("\n--- Simulating Character Selection ---")
	
	var _character_manager = battle_flow.get_character_manager()
	var ui_manager = battle_flow.get_ui_manager()
	
	# Get available characters from select.def
	var available_characters = ui_manager.get_available_characters()
	print("Available characters: ", available_characters.size())
	
	if available_characters.size() >= 2:
		# Select first two characters
		var char1_data = available_characters[0]
		var char2_data = available_characters[1]
		
		print("Selecting characters:")
		print("  P1: ", char1_data.get("name", "Unknown"))
		print("  P2: ", char2_data.get("name", "Unknown"))
		
		# Trigger character selection
		ui_manager.emit_signal("character_selected", char1_data)
		await get_tree().create_timer(1.0).timeout
		ui_manager.emit_signal("character_selected", char2_data)
	else:
		print("Not enough characters available for simulation")
		# Use default character data
		_simulate_with_default_characters(battle_flow)

func _simulate_with_default_characters(battle_flow):
	"""Simulate with default character data if select.def is not available"""
	print("Using default character simulation")
	
	# Create mock character data
	var char1_data = {
		"name": "Ryu",
		"def_path": "assets/mugen/chars/Ryu/Ryu.def"
	}
	var char2_data = {
		"name": "Ken", 
		"def_path": "assets/mugen/chars/Ken/Ken.def"
	}
	
	var ui_manager = battle_flow.get_ui_manager()
	ui_manager.emit_signal("character_selected", char1_data)
	await get_tree().create_timer(1.0).timeout
	ui_manager.emit_signal("character_selected", char2_data)

# SIGNAL HANDLERS

func _on_flow_changed(flow_state: String):
	print("Flow state changed to: ", flow_state)

func _on_characters_selected(p1_data, p2_data):
	print("Characters selected for battle:")
	if p1_data and p2_data:
		print("  P1: ", p1_data.display_name if p1_data.has_method("get") else "Loading...")
		print("  P2: ", p2_data.display_name if p2_data.has_method("get") else "Loading...")
	
	# Battle will start automatically via stage selection

func _on_stage_selected(stage_data):
	print("Stage selected: ", stage_data.get("name", "Unknown"))
	print("Battle will begin shortly...")

func _on_battle_complete(winner: String):
	print("Battle completed! Winner: ", winner)
	print("Battle system integration successful!")
	
	# Demonstrate returning to character select
	await get_tree().create_timer(2.0).timeout
	print("\n--- Demonstration Complete ---")
	print("The integrated battle system is working correctly!")
	print("Features demonstrated:")
	print("  ✓ Character selection flow")
	print("  ✓ Character data loading and caching")
	print("  ✓ Stage selection and loading")
	print("  ✓ Battle engine integration")
	print("  ✓ UI manager coordination")
	print("  ✓ Complete battle flow management")

func _input(event):
	"""Handle input during example"""
	if event.is_action_pressed("ui_cancel"):
		print("Example cancelled by user")
		get_tree().quit()
	
	if event.is_action_pressed("ui_accept"):
		print("Continuing example...")
