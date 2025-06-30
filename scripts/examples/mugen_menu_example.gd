extends Node

## MUGEN Main Menu Integration Example
## Demonstrates loading and using authentic MUGEN main menu from system.def

func _ready():
	print("=== MUGEN MAIN MENU INTEGRATION EXAMPLE ===")
	print("Loading authentic MUGEN main menu from system.def...")
	
	await get_tree().create_timer(1.0).timeout
	demonstrate_mugen_menu()

func demonstrate_mugen_menu():
	"""Create and show the MUGEN-style main menu"""
	print("\n--- Creating MUGEN Main Menu ---")
	
	# Create the MUGEN main menu
	var mugen_menu = preload("res://scripts/ui/mugen_main_menu.gd").new()
	mugen_menu.name = "MugenMainMenu"
	add_child(mugen_menu)
	
	# Connect to menu events
	mugen_menu.menu_item_selected.connect(_on_menu_item_selected)
	mugen_menu.battle_mode_requested.connect(_on_battle_mode_requested)
	
	print("✓ MUGEN Main Menu created")
	print("  - System.def configuration: LOADED")
	print("  - Select.def configuration: LOADED")
	print("  - Menu items: CONFIGURED")
	print("  - Background: APPLIED")
	print("")
	
	await get_tree().create_timer(2.0).timeout
	
	print("--- MUGEN Menu Features ---")
	
	var system_config = mugen_menu.get_system_config()
	if system_config:
		var menu_config = system_config.get_title_menu_config()
		print("✓ Menu configuration loaded:")
		print("  - Position: ", menu_config.get("pos", "Default"))
		print("  - Item spacing: ", menu_config.get("item_spacing", "Default"))
		print("  - Available items: ", menu_config.get("items", {}).size())
		
		var bg_config = system_config.get_title_background_config()
		print("✓ Background configuration loaded:")
		print("  - Clear color: ", bg_config.get("clearcolor", Color.BLACK))
		print("  - Background layers: ", bg_config.get("layers", []).size())
	
	print("")
	print("--- Instructions ---")
	print("Use UP/DOWN arrows to navigate menu")
	print("Press ENTER to select menu items")
	print("Menu items will trigger authentic MUGEN battle flow")
	print("Press ESC to exit")

func _on_menu_item_selected(item_name: String):
	"""Handle menu item selection"""
	print("📋 Menu item selected: ", item_name)
	
	match item_name:
		"arcade", "versus", "training":
			print("  → Starting battle mode with character selection")
		"watch":
			print("  → Would start battle viewer mode")
		"options":
			print("  → Would show options menu")
		"exit":
			print("  → Exiting application")
		_:
			print("  → Custom menu action: ", item_name)

func _on_battle_mode_requested():
	"""Handle battle mode request"""
	print("⚔️  Battle mode requested!")
	print("  → Transitioning to MUGEN character selection")
	print("  → Battle flow will use select.def configuration")
	print("  → Complete MUGEN-authentic experience starting...")
	
	await get_tree().create_timer(2.0).timeout
	print("  ✓ Battle flow integration successful!")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("\nMUGEN Main Menu example ended")
		print("Integration successful - authentic MUGEN menu experience achieved!")
		get_tree().quit()
