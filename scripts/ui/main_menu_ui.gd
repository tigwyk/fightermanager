extends Control
class_name MainMenuUI

## Main Menu UI for Fighter Manager
## Entry point for the game with navigation to different systems

@onready var new_career_btn: Button = %NewCareerButton
@onready var load_career_btn: Button = %LoadCareerButton
@onready var battle_viewer_btn: Button = %BattleViewerButton
@onready var fighter_management_btn: Button = %FighterManagementButton
@onready var tournament_btn: Button = %TournamentButton
@onready var settings_btn: Button = %SettingsButton
@onready var character_test_btn: Button = %CharacterTestButton
@onready var exit_btn: Button = %ExitButton
@onready var status_label: Label = %StatusLabel

func _ready():
	print("🏠 Fighter Manager Main Menu Ready")
	
	# Debug SFF file issue
	debug_sff_issue()
	
	_connect_signals()
	_update_status("Fighter Manager v0.1.0 - Ready")

func debug_sff_issue():
	"""Debug the SFF parsing issue with SFF v2 PNG support - FIXED VERSION"""
	print("\n=== SFF v2 PNG LOADING TEST (VERSION DETECTION FIX) ===")
	
	# Test system.sff first (should now be detected as SFF v2)
	print("🎯 Testing system.sff with VERSION DETECTION FIX:")
	var system_sff_path = "res://data/mugen/system.sff"
	test_sff_file(system_sff_path, "System UI sprites")
	
	# Test the KFM file specifically with the FIXED SFF v2 PNG parser
	var kfm_path = "res://assets/mugen/chars/kfm/kfm.sff"
	print("\n🎯 Testing KFM SFF with VERSION DETECTION FIX:")
	test_sff_file(kfm_path, "KFM character sprites")
	
	print("=== ANALYSIS COMPLETE ===\n")

func test_sff_file(file_path: String, description: String):
	print("Testing %s: %s" % [description, file_path])
	
	var sff_parser = preload("res://scripts/mugen/sff_parser.gd").new()
	
	# Connect to signals to monitor PNG loading
	sff_parser.sprite_loaded.connect(_on_sprite_loaded)
	sff_parser.parsing_complete.connect(_on_parsing_complete)
	sff_parser.parsing_error.connect(_on_parsing_error)
	
	print("🔧 TESTING: Fixed SFF v2 header parsing and version detection")
	print("🔧 EXPECTED: Should now correctly detect v2 and load PNG sprites")
	
	if sff_parser.parse_sff_file(file_path):
		print("✅ SFF parsing succeeded!")
		print("📊 Detected version: v%d" % sff_parser.header.detected_version)
		var sprites = sff_parser.get_available_sprites()
		print("📊 Total sprites available: %d" % sprites.size())
		
		if sprites.size() > 0:
			print("🎨 Testing PNG sprite loading:")
			var success_count = 0
			for i in range(min(5, sprites.size())):  # Test first 5 sprites
				var sprite_info = sprites[i]
				var group = sprite_info[0]
				var image = sprite_info[1]
				
				print("   Testing sprite %d,%d..." % [group, image])
				var texture = sff_parser.get_sprite_texture(group, image)
				if texture:
					print("   ✅ Loaded PNG sprite %d,%d: %s" % [group, image, texture.get_size()])
					success_count += 1
				else:
					print("   ❌ Failed to load PNG texture")
			
			print("🎯 RESULTS for %s:" % description)
			print("   ✅ %d/%d sprites loaded successfully" % [success_count, min(5, sprites.size())])
			if success_count > 0:
				print("   🎉 SFF v2 PNG SUPPORT IS WORKING! 🎉")
			else:
				print("   ⚠️ PNG loading still has issues")
		else:
			print("⚠️ No sprites found - header parsing may need more work")
	else:
		print("❌ SFF v2 parsing failed for %s" % description)
	
	print("🔍 EXPECTED RESULTS:")
	print("   - KFM SFF should now be detected as v2.0.1.0")
	print("   - PNG sprites should be loaded successfully")  
	print("   - Character should load with actual sprite data")
	print("   - Street Fighter characters still have placeholder files (expected)")

func _connect_signals():
	"""Connect button signals"""
	new_career_btn.pressed.connect(_on_new_career_pressed)
	load_career_btn.pressed.connect(_on_load_career_pressed)
	battle_viewer_btn.pressed.connect(_on_battle_viewer_pressed)
	fighter_management_btn.pressed.connect(_on_fighter_management_pressed)
	tournament_btn.pressed.connect(_on_tournament_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	character_test_btn.pressed.connect(_on_character_test_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func _on_new_career_pressed():
	"""Start a new career"""
	_update_status("Starting new career...")
	print("🚀 New Career selected")
	# TODO: Navigate to career creation screen
	_create_career_creation_scene()

func _on_load_career_pressed():
	"""Load an existing career"""
	_update_status("Loading career...")
	print("📂 Load Career selected")
	# TODO: Show save file browser

func _on_fighter_management_pressed():
	"""Open fighter management screen"""
	_update_status("Opening fighter management...")
	print("🏋️ Fighter Management selected")
	
	# Load the fighter management scene
	var fighter_scene = load("res://scenes/management/fighter_management.tscn")
	if fighter_scene:
		get_tree().change_scene_to_packed(fighter_scene)
	else:
		_update_status("Error: Fighter management scene not found")

func _on_tournament_pressed():
	"""Open tournament browser"""
	_update_status("Opening tournament browser...")
	print("🏆 Tournament Browser selected")
	
	# Load the tournament browser scene
	var tournament_scene = load("res://scenes/management/tournament_browser.tscn")
	if tournament_scene:
		get_tree().change_scene_to_packed(tournament_scene)
	else:
		_update_status("Error: Tournament browser scene not found")

func _on_battle_viewer_pressed():
	"""Open battle viewer"""
	_update_status("Opening battle viewer...")
	print("⚔️ Battle Viewer selected")
	
	# Load battle scene for testing
	var battle_scene = load("res://scenes/battles/battle_scene.tscn")
	if battle_scene:
		get_tree().change_scene_to_packed(battle_scene)
	else:
		_update_status("Error: Battle scene not found")

func _on_settings_pressed():
	"""Open settings"""
	_update_status("Opening settings...")
	#print("⚙️ Settings selected")
	# TODO: Create settings UI

func _on_character_test_pressed():
	"""Test character loading system"""
	_update_status("Testing character loading...")
	#print("🧪 Testing character loading...")
	
	# Test MUGEN system
	_test_mugen_system()

func _on_exit_pressed():
	"""Exit the game"""
	print("🚪 Exiting game")
	get_tree().quit()

func _test_mugen_system():
	"""Test the MUGEN character loading system"""
	_update_status("Testing MUGEN system...")
	
	# Check if MugenSystem is available as an autoload
	var mugen_system = get_node_or_null("/root/MugenSystem")
	if not mugen_system:
		_update_status("❌ MugenSystem autoload not found")
		print("❌ MugenSystem autoload not available. Check project.godot autoload settings.")
		_show_error("MUGEN System not found!\n\nThe MugenSystem autoload is not available. Please check:\n• project.godot autoload configuration\n• MugenSystem script exists")
		return
	
	print("✅ MugenSystem autoload found")
	
	# Test basic functionality first
	_show_mugen_system_info(mugen_system)

func _show_mugen_system_info(mugen_system):
	"""Show basic MUGEN system info without loading characters"""
	var char_dirs = mugen_system.get_character_list()
	print("📂 Found %d character directories" % char_dirs.size())
	
	if char_dirs.is_empty():
		_update_status("⚠️ No characters found")
		_show_error("No MUGEN characters found!\n\nNo characters found in assets/mugen/chars/\n\nPlease add some MUGEN character folders to test the system.")
		return
	
	_update_status("✅ MUGEN System working - %d characters found" % char_dirs.size())
	
	# Show info dialog with character list
	var dialog = AcceptDialog.new()
	dialog.title = "MUGEN System Test - Basic Info"
	var char_list = ""
	for i in range(min(10, char_dirs.size())):  # Show first 10 characters
		char_list += "• " + char_dirs[i].get_file() + "\n"
	
	if char_dirs.size() > 10:
		char_list += "... and %d more" % (char_dirs.size() - 10)
	
	dialog.dialog_text = "✅ MUGEN System is running!\n\nFound %d character directories:\n\n%s\n\nWould you like to test character loading?\n(This may show errors if SFF files have issues)" % [
		char_dirs.size(),
		char_list
	]
	
	# Add buttons for advanced testing
	dialog.add_button("Test Character Loading", false, "test_loading")
	dialog.add_button("Safe Test (No SFF)", false, "safe_test")
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.custom_action.connect(func(action): _on_mugen_test_action(action, char_dirs[0], mugen_system))

func _on_mugen_test_action(action: String, char_dir: String, mugen_system):
	"""Handle advanced MUGEN testing actions"""
	if action == "test_loading":
		print("🧪 User requested character loading test")
		_update_status("Testing character loading...")
		call_deferred("_load_test_character", char_dir, mugen_system)
	elif action == "safe_test":
		print("🛡️ User requested safe test (no SFF parsing)")
		_update_status("Running safe test...")
		call_deferred("_safe_character_test", char_dir)

func _load_test_character(char_dir: String, mugen_system):
	"""Load test character in deferred call with enhanced error handling"""
	print("🔄 Attempting to load character from: %s" % char_dir)
	
	# Connect to MugenSystem error signals to catch loading errors
	if not mugen_system.character_loading_error.is_connected(_on_character_loading_error):
		mugen_system.character_loading_error.connect(_on_character_loading_error)
	
	# Try a safer approach - test character directory structure first
	if not _validate_character_directory(char_dir):
		_update_status("❌ Invalid character directory")
		_show_error("Invalid Character Directory!\n\nThe directory %s does not contain the required MUGEN files.\n\nRequired files:\n• .def file (character definition)\n• .sff file (sprite file)\n• .air file (animation file)" % char_dir.get_file())
		return
	
	print("✅ Character directory structure validated")
	
	# Try to create a MugenCharacter object without loading sprites
	var mugen_character_script = load("res://scripts/mugen/mugen_character.gd")
	if not mugen_character_script:
		_update_status("❌ MugenCharacter script not found")
		_show_error("MugenCharacter script not found!\n\nCannot load character class. Check if the script exists at:\nres://scripts/mugen/mugen_character.gd")
		return
	
	print("✅ MugenCharacter script found")
	
	# Create character instance and test basic loading
	var character = mugen_character_script.new()
	
	# Connect error signal
	character.loading_error.connect(_on_character_loading_error_detailed)
	
	print("🧪 Testing basic character loading (may trigger SFF errors)...")
	_update_status("Loading character data...")
	
	# Attempt character loading with error capture
	var loading_success = false
	
	# This is where the SFF error likely occurs, so we'll catch it
	loading_success = character.load_from_directory(char_dir)
	
	if loading_success:
		print("✅ Character loaded successfully!")
		var info = character.get_character_info()
		_update_status("✅ Character loaded successfully!")
		
		# Show success dialog
		var dialog = AcceptDialog.new()
		dialog.title = "MUGEN Character Loading Test - Success!"
		dialog.dialog_text = "✅ MUGEN character loaded successfully!\n\nCharacter: %s\nAuthor: %s\nDirectory: %s\n\n🎉 The character loading system is working!\n\nNote: Some SFF parsing warnings may appear in debug output but don't prevent character loading." % [
			info.get("display_name", "Unknown"),
			info.get("author", "Unknown"),
			char_dir.get_file()
		]
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func(): dialog.queue_free())
		
		# Print detailed info
		if character.has_method("debug_print"):
			character.debug_print()
	else:
		print("❌ Character loading failed")
		_update_status("❌ Character loading failed")
		_show_error("Character Loading Failed!\n\nThe character could not be loaded from:\n%s\n\nThis is likely due to SFF parsing errors. The character files may be:\n• Corrupted or incomplete\n• Using unsupported SFF format\n• Missing required sprite data\n\nCheck the debug output for specific errors." % char_dir.get_file())

func _validate_character_directory(char_dir: String) -> bool:
	"""Validate that a character directory has required files"""
	print("🔍 Validating character directory: %s" % char_dir)
	
	var dir = DirAccess.open(char_dir)
	if not dir:
		print("❌ Cannot open directory: %s" % char_dir)
		return false
	
	var has_def = false
	var has_sff = false
	var has_air = false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var lower_name = file_name.to_lower()
		if lower_name.ends_with(".def"):
			has_def = true
			print("✓ Found DEF file: %s" % file_name)
		elif lower_name.ends_with(".sff"):
			has_sff = true
			print("✓ Found SFF file: %s" % file_name)
		elif lower_name.ends_with(".air"):
			has_air = true
			print("✓ Found AIR file: %s" % file_name)
		file_name = dir.get_next()
	
	print("📋 Validation results - DEF: %s, SFF: %s, AIR: %s" % [has_def, has_sff, has_air])
	return has_def and has_sff  # AIR is optional for basic testing

func _on_character_loading_error_detailed(message: String):
	"""Handle detailed character loading errors"""
	print("❌ Character loading error (detailed): %s" % message)
	# Don't show dialog here since _load_test_character will handle the final result

func _on_character_loading_error(path: String, error: String):
	"""Handle character loading errors from MugenSystem"""
	print("❌ Character loading error received: %s" % error)
	_update_status("❌ Character loading error")
	_show_error("Character Loading Error!\n\nPath: %s\n\nError: %s\n\nThe character could not be loaded due to the above error." % [path, error])

func _update_status(text: String):
	"""Update the status label"""
	status_label.text = text
	print("📊 Status: %s" % text)

func _on_sprite_loaded(group: int, image: int, texture: Texture2D):
	"""Handle sprite loaded signal from SFF parser"""
	print("📷 PNG Sprite loaded: Group %d, Image %d, Size %dx%d" % [group, image, texture.get_width(), texture.get_height()])

func _on_parsing_complete(total_sprites: int):
	"""Handle parsing complete signal from SFF parser"""
	print("🏁 SFF parsing complete: %d total sprites" % total_sprites)

func _on_parsing_error(message: String):
	"""Handle parsing error signal from SFF parser"""
	print("🚨 SFF parsing error: %s" % message)

func _create_career_creation_scene():
	"""Create and load career creation scene"""
	_update_status("Creating career creation screen...")
	print("📝 Creating career creation interface")
	# TODO: Create proper career creation scene
	# For now, show a placeholder message
	_show_placeholder_message("Career Creation", "Career creation system coming soon!\n\nThis will allow you to:\n• Create a new fighter\n• Choose starting attributes\n• Select fighting style\n• Set career goals")

func _show_placeholder_message(title: String, message: String):
	"""Show a placeholder message for unimplemented features"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_error(message: String):
	"""Show an error dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _safe_character_test(char_dir: String):
	"""Run a safe character test that avoids SFF parsing"""
	print("🛡️ Running safe character test for: %s" % char_dir)
	
	# First validate directory structure
	if not _validate_character_directory(char_dir):
		_update_status("❌ Invalid character directory")
		_show_error("Invalid Character Directory!\n\nThe directory %s does not contain required MUGEN files." % char_dir.get_file())
		return
	
	# Try to read just the DEF file
	var def_file_path = _find_def_file_in_directory(char_dir)
	if def_file_path.is_empty():
		_update_status("❌ No DEF file found")
		_show_error("No DEF file found in directory: %s" % char_dir.get_file())
		return
	
	print("✅ Found DEF file: %s" % def_file_path)
	
	# Parse DEF file without loading sprites
	var def_parser = load("res://scripts/mugen/def_parser.gd")
	if not def_parser:
		_update_status("❌ DEF parser not found")
		_show_error("DEF parser script not found!")
		return
	
	var parser = def_parser.new()
	var def_data = parser.parse_def_file(def_file_path)
	
	if def_data.is_empty():
		_update_status("❌ Failed to parse DEF file")
		_show_error("Failed to parse DEF file: %s" % def_file_path.get_file())
		return
	
	print("✅ DEF file parsed successfully")
	
	# Extract character info from DEF data
	var info_section = def_data.get("Info", {})
	var character_name = info_section.get("name", "Unknown")
	var character_author = info_section.get("author", "Unknown") 
	var display_name = info_section.get("displayname", character_name)
	
	# Show success dialog
	_update_status("✅ Safe test completed successfully!")
	
	var dialog = AcceptDialog.new()
	dialog.title = "Safe Character Test - Success!"
	dialog.dialog_text = "✅ Safe character test completed!\n\nCharacter: %s\nDisplay Name: %s\nAuthor: %s\nDirectory: %s\n\nDEF file parsed successfully!\nSFF parsing was skipped to avoid errors.\n\n🛡️ Basic character structure is valid!" % [
		character_name,
		display_name, 
		character_author,
		char_dir.get_file()
	]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _find_def_file_in_directory(char_dir: String) -> String:
	"""Find the main DEF file in a character directory"""
	var dir = DirAccess.open(char_dir)
	if not dir:
		return ""
	
	var dir_name = char_dir.get_file().to_lower()
	var preferred_def = char_dir.path_join(dir_name + ".def")
	
	# Check if there's a DEF file matching the directory name
	if FileAccess.file_exists(preferred_def):
		return preferred_def
	
	# Otherwise find any DEF file
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.to_lower().ends_with(".def") and not file_name.to_lower().begins_with("ending") and not file_name.to_lower().begins_with("intro"):
			return char_dir.path_join(file_name)
		file_name = dir.get_next()
	
	return ""
