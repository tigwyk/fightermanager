extends Node

## Test script to verify MugenCharacterData works correctly after parser fixes

func _ready():
	print("=== MUGEN CHARACTER DATA TEST ===")
	test_character_data_loading()

func test_character_data_loading():
	print("\n--- Testing MugenCharacterData ---")
	
	# Create character data instance
	var char_data = MugenCharacterData.new()
	
	print("✓ MugenCharacterData instance created")
	
	# Connect to signals to monitor loading
	char_data.loading_progress.connect(_on_loading_progress)
	char_data.loading_complete.connect(_on_loading_complete)
	char_data.loading_error.connect(_on_loading_error)
	
	# Test with a dummy character path (should fail gracefully)
	print("✓ Signals connected")
	
	# Try to load a character (this will fail gracefully since we don't have real assets)
	var test_result = char_data.load_character_async("assets/mugen/chars/testchar/testchar.def")
	print("✓ Load character called (result: ", test_result, ")")
	
	# Check that the parsers can be instantiated
	test_parser_instantiation()

func test_parser_instantiation():
	print("\n--- Testing Parser Instantiation ---")
	
	# Test each parser type
	var _def_parser = preload("res://scripts/mugen/def_parser.gd").new()
	var _sff_parser = preload("res://scripts/mugen/sff_parser.gd").new()
	var _air_parser = preload("res://scripts/mugen/air_parser.gd").new()
	var _cmd_parser = preload("res://scripts/mugen/cmd_parser.gd").new()
	var _cns_parser = preload("res://scripts/mugen/cns_parser.gd").new()
	
	print("✓ DEFParser instantiated successfully")
	print("✓ SFFParser instantiated successfully")
	print("✓ AIRParser instantiated successfully")
	print("✓ CMDParser instantiated successfully")
	print("✓ CNSParser instantiated successfully")

func _on_loading_progress(step: String, progress: float):
	print("Loading progress: ", step, " (", progress, ")")

func _on_loading_complete(success: bool):
	print("Loading complete: ", success)

func _on_loading_error(error: String):
	print("Loading error: ", error)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("\nTest completed")
		get_tree().quit()
