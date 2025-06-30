extends Node2D
class_name StageRenderer

## MUGEN Stage Renderer (Ikemen GO parity, Godot 4)
## Loads and renders all background layers from a stage DEF and SFF

var def_parser: DEFParser
var sff_parser: SFFParser
var stage_data: Dictionary
var bg_layers: Array = []
var animated_sprites: Array = []

func load_stage(def_path: String, sff_path: String = ""):
	# Parse DEF
	def_parser = DEFParser.new()
	stage_data = def_parser.parse_def_file(def_path)
	if sff_path == "":
		sff_path = def_parser.get_stage_sprite_file()
	if not sff_path.begins_with("res://"):
		sff_path = "res://" + sff_path.replace("\\", "/")

	# Parse SFF
	sff_parser = SFFParser.new()
	if not sff_parser.parse_sff_file(sff_path):
		push_error("Failed to load SFF: %s" % sff_path)
		return

	# Parse BG layers
	_parse_bg_layers()
	_render_bg_layers()

func _parse_bg_layers():
	bg_layers.clear()
	if not stage_data.has("bg"):
		return
	var bg_section = stage_data["bg"]
	for key in bg_section.keys():
		if key.begins_with("bgdef"):
			continue # skip BGDef, handled elsewhere
		if key.begins_with("bgctrl"):
			continue # skip BGCtrl, handled elsewhere
		# Each BG layer is a sub-section
		var layer = bg_section[key]
		bg_layers.append(layer)

func _render_bg_layers():
	# Remove old children
	for c in get_children():
		remove_child(c)
	animated_sprites.clear()
	# Render each BG layer as a Sprite2D or AnimatedSprite2D
	for layer in bg_layers:
		var group = int(layer.get("spriteno", "0,0").split(",")[0])
		var image = int(layer.get("spriteno", "0,0").split(",")[1])
		var sprite_tex = sff_parser.get_sprite_texture(group, image)
		if not sprite_tex:
			continue

		# Animation support
		var anim_frames = []
		if layer.has("anim"):
			# anim = "group,image,group,image,...,framedelay,..."
			var anim_data = layer["anim"].split(",")
			for i in range(0, anim_data.size(), 3):
				if i+2 < anim_data.size():
					var g = int(anim_data[i])
					var img = int(anim_data[i+1])
					var delay = int(anim_data[i+2])
					var tex = sff_parser.get_sprite_texture(g, img)
					if tex:
						anim_frames.append({"texture": tex, "delay": delay})

		if anim_frames.size() > 0:
			var anim_sprite = AnimatedSprite2D.new()
			var frames = SpriteFrames.new()
			frames.add_animation("default")
			var total = 0
			for i in range(anim_frames.size()):
				frames.add_frame("default", anim_frames[i]["texture"])
				frames.set_frame_duration("default", i, anim_frames[i]["delay"] / 60.0) # MUGEN uses ticks, 60fps
			anim_sprite.frames = frames
			anim_sprite.animation = "default"
			anim_sprite.play()
			anim_sprite.position = Vector2(layer.get("startx", "0").to_float(), layer.get("starty", "0").to_float())
			_add_bg_layer_properties(anim_sprite, layer)
			add_child(anim_sprite)
			animated_sprites.append({"node": anim_sprite, "layer": layer})
		else:
			var sprite = Sprite2D.new()
			sprite.texture = sprite_tex
			sprite.position = Vector2(layer.get("startx", "0").to_float(), layer.get("starty", "0").to_float())
			_add_bg_layer_properties(sprite, layer)
			add_child(sprite)

func _add_bg_layer_properties(sprite: Node2D, layer: Dictionary):
	# Parallax/delta
	if layer.has("delta"):
		var delta = layer["delta"].split(",")
			# Store as metadata for camera to use
		if delta.size() == 2:
			sprite.set_meta("delta", Vector2(delta[0].to_float(), delta[1].to_float()))
	# Tiling
	if layer.has("tile"):
		var tile = layer["tile"].split(",")
		if tile.size() == 2:
			sprite.set_meta("tile", Vector2(tile[0].to_int(), tile[1].to_int()))
	# Velocity
	if layer.has("velocity"):
		var vel = layer["velocity"].split(",")
		if vel.size() == 2:
			sprite.set_meta("velocity", Vector2(vel[0].to_float(), vel[1].to_float()))
	# Blending
	if layer.has("trans"):
		var trans = layer["trans"].to_lower()
		if trans == "add" or trans == "addalpha":
			sprite.modulate = Color(1,1,1,0.7)
			sprite.material = CanvasItemMaterial.new()
			sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		elif trans == "sub":
			sprite.modulate = Color(1,1,1,0.7)
			sprite.material = CanvasItemMaterial.new()
			sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	# Window (clipping)
	if layer.has("window"):
		# Not implemented: Godot 4 needs custom shaders or Viewport for per-layer clipping
		pass

# Animation, velocity, tiling update
func _process(delta):
	for entry in animated_sprites:
		var node = entry["node"]
		var layer = entry["layer"]
		# Velocity
		if node.has_meta("velocity"):
			var v = node.get_meta("velocity")
			node.position += v * delta
		# Tiling (TODO: implement for Sprite2D, AnimatedSprite2D)
		# Parallax (handled by camera, not here)
		# Animation handled by AnimatedSprite2D
