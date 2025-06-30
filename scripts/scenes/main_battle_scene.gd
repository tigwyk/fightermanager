extends Control

## Main Battle Scene - Entry point for the complete MUGEN battle experience
## Demonstrates the integrated battle flow system

var battle_flow_manager # BattleFlowManager

func _ready():
	print("Main Battle Scene initialized")
	
	# Create and setup battle flow manager
	battle_flow_manager = preload("res://scripts/core/battle_flow_manager.gd").new()
	battle_flow_manager.name = "BattleFlowManager"
	add_child(battle_flow_manager)
	
	# Connect to flow events
	battle_flow_manager.battle_flow_changed.connect(_on_battle_flow_changed)
	battle_flow_manager.character_selection_complete.connect(_on_character_selection_complete)
	battle_flow_manager.stage_selection_complete.connect(_on_stage_selection_complete)
	battle_flow_manager.battle_complete.connect(_on_battle_complete)
	
	# Start the battle flow
	_start_battle_flow()

func _start_battle_flow():
	"""Initialize the battle flow sequence"""
	print("Starting MUGEN battle flow...")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Start with character selection
	battle_flow_manager.start_character_selection()

func _input(event):
	"""Handle input for battle flow control"""
	if event.is_action_pressed("ui_cancel"):
		var flow_state = battle_flow_manager.get_current_flow_state()
		if flow_state == 1:  # CHARACTER_SELECT
			print("Returning to menu...")
			battle_flow_manager.return_to_menu()
		elif flow_state == 3:  # BATTLE
			print("Returning to character select...")
			battle_flow_manager.return_to_character_select()
		elif flow_state == 4:  # RESULTS
			print("Returning to character select...")
			battle_flow_manager.return_to_character_select()
	
	if event.is_action_pressed("ui_accept"):
		var flow_state = battle_flow_manager.get_current_flow_state()
		if flow_state == 0:  # MENU
			battle_flow_manager.start_character_selection()
		elif flow_state == 4:  # RESULTS
			battle_flow_manager.return_to_character_select()

# SIGNAL HANDLERS

func _on_battle_flow_changed(flow_state: String):
	print("Battle flow changed to: ", flow_state)
	
	# Update UI based on flow state
	match flow_state:
		"menu":
			_show_main_menu()
		"character_select":
			_show_character_select()
		"stage_select":
			_show_stage_select()
		"battle":
			_show_battle()
		"results":
			_show_results()

func _on_character_selection_complete(p1_data, p2_data):
	print("Character selection complete:")
	print("  Player 1: ", p1_data.display_name)
	print("  Player 2: ", p2_data.display_name)

func _on_stage_selection_complete(stage_data):
	print("Stage selection complete: ", stage_data.get("name", "Unknown"))

func _on_battle_complete(winner: String):
	print("Battle complete! Winner: ", winner)
	
	# Show results for a few seconds, then return to character select
	await get_tree().create_timer(3.0).timeout
	battle_flow_manager.return_to_character_select()

# UI STATE MANAGEMENT

func _show_main_menu():
	"""Display main menu UI"""
	print("Showing main menu")
	# TODO: Create main menu UI

func _show_character_select():
	"""Display character selection UI"""
	print("Showing character selection")
	# UI is handled by MugenUIManager in battle_flow_manager

func _show_stage_select():
	"""Display stage selection UI"""
	print("Showing stage selection")
	# For now, stage selection is automatic

func _show_battle():
	"""Display battle UI"""
	print("Showing battle UI")
	# UI is handled by MugenUIManager in battle_flow_manager

func _show_results():
	"""Display battle results UI"""
	print("Showing battle results")
	var result = battle_flow_manager.get_battle_result()
	if not result.is_empty():
		print("Winner: ", result.get("winner", "Unknown"))
		print("Players: ", result.get("p1_name", "P1"), " vs ", result.get("p2_name", "P2"))

# UTILITY FUNCTIONS

func get_battle_flow_manager():
	return battle_flow_manager
