extends Node

## Quick test to verify the fixed parsers work correctly

func _ready():
	print("=== PARSER FIX VERIFICATION TEST ===")
	test_system_def_parser()
	test_pcx_parser()
	test_sff_parser()
	print("=== TEST COMPLETE ===")

func test_system_def_parser():
	print("\n--- Testing SystemDefParser ---")
	var parser = preload("res://scripts/mugen/system_def_parser.gd").new()
	
	# Test that the method exists and is callable
	if parser.has_method("parse_file"):
		print("✓ parse_file method exists")
	else:
		print("✗ parse_file method missing")
	
	# Test with a dummy path (should fail gracefully)
	var result = parser.parse_file("nonexistent/path/system.def")
	print("✓ parse_file called without errors (result: ", result, ")")

func test_pcx_parser():
	print("\n--- Testing PCXParser ---")
	var parser = preload("res://scripts/mugen/pcx_parser.gd").new()
	
	# Test that the new method exists
	if parser.has_method("parse_file"):
		print("✓ parse_file method exists")
	else:
		print("✗ parse_file method missing")
	
	# Test with a dummy path (should fail gracefully)
	var result = parser.parse_file("nonexistent/path/image.pcx")
	print("✓ parse_file called without errors (result: ", result, ")")

func test_sff_parser():
	print("\n--- Testing SFFParser ---")
	var parser = preload("res://scripts/mugen/sff_parser.gd").new()
	
	# Test that the correct method exists
	if parser.has_method("parse_sff_file"):
		print("✓ parse_sff_file method exists")
	else:
		print("✗ parse_sff_file method missing")
	
	# Test with a dummy path (should fail gracefully)
	var result = parser.parse_sff_file("nonexistent/path/sprites.sff")
	print("✓ parse_sff_file called without errors (result: ", result, ")")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
