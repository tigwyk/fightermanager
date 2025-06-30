extends SceneTree

# Quick test script to validate our SFF parser migration
func _ready():
	test_sff_parser()
	quit()

func test_sff_parser():
	print("🧪 Testing migrated SFF parser functionality...")
	
	# Test file path - using system.sff as our primary test file
	var file_path = "assets/mugen/system.sff"
	print("📁 Testing file: ", file_path)
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		print("❌ File does not exist: ", file_path)
		return
	
	# Create and test the parser
	var parser = preload("res://scripts/mugen/sff_parser.gd").new()
	
	# Connect to signals
	parser.sprite_loaded.connect(_on_sprite_loaded)
	parser.parsing_complete.connect(_on_parsing_complete)
	parser.parsing_error.connect(_on_parsing_error)
	
	print("🔍 Starting SFF parsing...")
	var success = parser.parse_sff_file(file_path)
	print("📊 Parse result: ", success)
	
	if success:
		var sprites = parser.get_available_sprites()
		print("📈 Total sprites found: ", sprites.size())
		
		# Test palette manager
		if parser.palette_manager:
			var palette_count = parser.palette_manager.get_palette_count()
			print("🎨 Total palettes found: ", palette_count)
		
		# Test a few sprite loads
		print("🧪 Testing sprite texture loading...")
		for i in range(min(5, sprites.size())):
			var sprite_info = sprites[i]
			var group = sprite_info[0]
			var image = sprite_info[1]
			print("Testing sprite Group %d, Image %d..." % [group, image])
			var texture = parser.get_sprite_texture(group, image)
			if texture:
				print("  ✅ Loaded: %dx%d pixels" % [texture.get_width(), texture.get_height()])
			else:
				print("  ❌ Failed to load")
	else:
		print("❌ SFF parsing failed")

func _on_sprite_loaded(group: int, image: int, _texture: Texture2D):
	print("📨 Signal: Sprite loaded Group %d, Image %d" % [group, image])

func _on_parsing_complete(total_sprites: int):
	print("📨 Signal: Parsing complete with %d sprites" % total_sprites)

func _on_parsing_error(message: String):
	print("📨 Signal: Parsing error - %s" % message)
