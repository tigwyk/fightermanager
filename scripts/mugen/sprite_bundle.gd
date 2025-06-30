class_name SpriteBundle
extends Resource

## SpriteBundle - Manages MUGEN SFF sprites and creates Godot textures
## Based on godot-mugen reference implementation for best practices

var sprites: Dictionary = {}

func _init(sprite_data: Dictionary = {}):
	if sprite_data:
		self.sprites = sprite_data

func get_sprite(path: Array) -> Dictionary:
	"""Get sprite data by group and image number [group, image]"""
	var key = "%s-%s" % [path[0], path[1]]
	
	if not sprites.has(key):
		if path[0] >= 0:  # Don't error for negative group numbers (shared sprites)
			push_error("Missing sprite: %s" % [key])
		return {}
	
	return sprites[key]

func create_texture(sprite_data: Dictionary, _flags: int = 0) -> ImageTexture:
	"""Create a Godot ImageTexture from sprite data"""
	if sprite_data.is_empty() or not sprite_data.has("image"):
		return create_empty_texture()
	
	var texture = ImageTexture.new()
	if sprite_data["image"] is Image:
		texture.set_image(sprite_data["image"])
	else:
		push_error("Invalid sprite data - no Image found")
		return create_empty_texture()
	
	return texture

func create_empty_texture() -> ImageTexture:
	"""Create a 1x1 transparent texture for missing sprites"""
	var empty_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_image.fill(Color(0, 0, 0, 0))  # Transparent
	
	var empty_texture = ImageTexture.new()
	empty_texture.set_image(empty_image)
	return empty_texture

func create_sprite_node(path: Array, facing: int = 1) -> Sprite2D:
	"""Create a Godot Sprite2D node from sprite data"""
	var sprite_data = get_sprite(path)
	var texture = create_texture(sprite_data)
	
	var sprite = Sprite2D.new()
	sprite.texture = texture
	
	# Apply MUGEN offset (sprite positioning)
	if sprite_data.has("offset_x") and sprite_data.has("offset_y"):
		sprite.offset = Vector2(-sprite_data["offset_x"], -sprite_data["offset_y"])
	elif sprite_data.has("x") and sprite_data.has("y"):
		sprite.offset = Vector2(-sprite_data["x"], -sprite_data["y"])
	
	sprite.centered = false
	
	# Handle facing direction
	if facing == -1:
		if sprite_data.has("image") and sprite_data["image"] is Image:
			sprite.offset.x = -sprite_data["image"].get_size().x - sprite.offset.x
		sprite.flip_h = true
	
	return sprite

func get_sprite_count() -> int:
	"""Get total number of sprites in the bundle"""
	return sprites.size()

func has_sprite(path: Array) -> bool:
	"""Check if sprite exists"""
	var key = "%s-%s" % [path[0], path[1]]
	return sprites.has(key)

func get_sprite_keys() -> Array:
	"""Get all sprite keys in the bundle"""
	return sprites.keys()

func set_sprites(sprite_data: Dictionary):
	"""Set the sprite data dictionary"""
	sprites = sprite_data

func get_sprites() -> Dictionary:
	"""Get the sprite data dictionary"""
	return sprites

func add_sprite(group: int, image: int, sprite_data: Dictionary):
	"""Add a single sprite to the bundle"""
	var key = "%s-%s" % [group, image]
	sprites[key] = sprite_data

func remove_sprite(group: int, image: int):
	"""Remove a sprite from the bundle"""
	var key = "%s-%s" % [group, image]
	sprites.erase(key)
