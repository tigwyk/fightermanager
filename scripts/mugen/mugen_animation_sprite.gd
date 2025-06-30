class_name MugenAnimationSprite
extends AnimatedSprite2D

## MugenAnimationSprite - Handles MUGEN animation rendering and collision
## Based on godot-mugen reference implementation

signal element_update(element, collisions)

@export var sprite_bundle_ref : SpriteBundle
var frame_mapping: Dictionary = {}
var image_mapping: Dictionary = {}
var is_facing_right: bool = true
var flip_v_override: bool = false
var flip_h_override: bool = false
var debug_collisions: bool = false

# Collision areas
var attacking_area_2d: Area2D = null
var collision_area_2d: Area2D = null
var boxes = {1: [], 2: []}  # 1 = attack boxes, 2 = collision boxes
var boxes_facing_right: bool = true

func _init(sprite_bundle: SpriteBundle, animations: Dictionary = {}):
	self.sprite_bundle_ref = sprite_bundle
	
	if animations.size() > 0:
		load_sprite_frames(animations)
	
	setup_sprite()

func setup_sprite():
	"""Initialize sprite properties"""
	centered = false
	name = "MugenAnimationSprite"

func load_sprite_frames(animations: Dictionary):
	"""Load all sprite frames from animations into Godot SpriteFrames"""
	var frames = SpriteFrames.new()
	var frame_index = 1
	var images: Dictionary = {}
	
	# Collect all unique images from animations
	for animation_key in animations:
		var anim_data = animations[animation_key]
		if anim_data.has("elements"):
			for element in anim_data["elements"]:
				if element.has("groupno") and element.has("imageno"):
					var image_key = "%s-%s" % [element["groupno"], element["imageno"]]
					if not images.has(image_key):
						var sprite_data = sprite_bundle_ref.get_sprite([element["groupno"], element["imageno"]])
						if not sprite_data.is_empty():
							images[image_key] = sprite_data
	
	# Add default empty frame
	frames.add_animation("default")
	frames.add_frame("default", sprite_bundle_ref.create_empty_texture())
	
	# Add all unique images as frames
	for image_key in images:
		var sprite_data = images[image_key]
		frame_mapping[image_key] = frame_index
		
		# Store image mapping for offset calculations
		if sprite_data.has("image") and sprite_data["image"] is Image:
			var offset_x = sprite_data.get("offset_x", sprite_data.get("x", 0))
			var offset_y = sprite_data.get("offset_y", sprite_data.get("y", 0))
			
			image_mapping[image_key] = {
				"offset": Vector2(-offset_x, -offset_y),
				"size": sprite_data["image"].get_size(),
			}
		else:
			image_mapping[image_key] = {
				"offset": Vector2.ZERO,
				"size": Vector2(1, 1),
			}
		
		frame_index += 1
		frames.add_frame("default", sprite_bundle_ref.create_texture(sprite_data))
	
	set_sprite_frames(frames)
	if frames.get_frame_count("default") > 0:
		set_animation("default")
		set_frame(0)

func set_sprite_image(groupno: int, imageno: int, sprite_offset: Vector2 = Vector2.ZERO):
	"""Set the current sprite image and apply offset"""
	var frame_key = '%s-%s' % [groupno, imageno]
	var frame_value = 0
	var frame_width = 0
	var image_offset = Vector2.ZERO
	
	if groupno >= 0 and frame_mapping.has(frame_key):
		frame_value = frame_mapping[frame_key]
		frame_width = image_mapping[frame_key]['size'].x
		image_offset = image_mapping[frame_key]['offset']
	elif groupno >= 0:
		push_error("Image not found: %s,%s" % [groupno, imageno])
	
	# Calculate final offset
	var frame_offset = Vector2(
		image_offset.x + sprite_offset.x,
		image_offset.y + sprite_offset.y
	)
	
	# Handle facing direction
	if not is_facing_right:
		frame_offset.x = -frame_width - frame_offset.x
	
	set_frame(frame_value)
	self.offset = frame_offset
	
	update_image_flip()

func set_facing_right(value: bool):
	"""Set the facing direction"""
	if is_facing_right == value:
		return
		
	is_facing_right = value
	update_image_flip()
	fix_boxes_direction()

func update_image_flip():
	"""Update sprite flipping based on facing direction and overrides"""
	set_flip_h(!is_facing_right != flip_h_override)
	set_flip_v(flip_v_override)

func set_collisions(collisions: Dictionary):
	"""Set collision boxes for attack and collision detection"""
	boxes = {}
	if collisions.has(1) and collisions[1] != null:
		boxes[1] = collisions[1].get("boxes", [])
	if collisions.has(2) and collisions[2] != null:
		boxes[2] = collisions[2].get("boxes", [])
	
	boxes_facing_right = true  # By default boxes are directed to right
	fix_boxes_direction()
	update_collision_boxes()
	queue_redraw()

func update_collision_boxes():
	"""Create collision areas and shapes"""
	# Clean up existing collision areas
	if attacking_area_2d:
		attacking_area_2d.queue_free()
	if collision_area_2d:
		collision_area_2d.queue_free()
	
	# Create new collision areas
	attacking_area_2d = Area2D.new()
	attacking_area_2d.set_collision_layer(1)
	attacking_area_2d.set_collision_mask_value(1, true)
	attacking_area_2d.set_collision_mask_value(2, true)
	
	collision_area_2d = Area2D.new()
	collision_area_2d.set_collision_layer(2)
	collision_area_2d.set_collision_mask_value(1, true)
	collision_area_2d.set_collision_mask_value(2, true)
	
	# Create collision shapes for each box
	for type in boxes:
		for points in boxes[type]:
			create_collision_box(type, points)
	
	add_child(attacking_area_2d)
	add_child(collision_area_2d)

func create_collision_box(type: int, points: Array):
	"""Create a collision box from four points [x1, y1, x2, y2]"""
	if points.size() < 4:
		return
	
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(abs(points[2] - points[0]), abs(points[3] - points[1]))
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.position = Vector2(
		points[0] + (points[2] - points[0]) / 2,
		points[1] + (points[3] - points[1]) / 2
	)
	collision_shape.set_shape(rectangle_shape)
	
	if type == 1:  # Attack box
		attacking_area_2d.add_child(collision_shape)
	else:  # Collision box
		collision_area_2d.add_child(collision_shape)

func fix_boxes_direction():
	"""Flip collision boxes when facing direction changes"""
	if boxes_facing_right == is_facing_right or is_facing_right:
		return
	
	var left_boxes = {1: [], 2: []}
	for type in boxes:
		for box in boxes[type]:
			left_boxes[type].push_back([
				-box[2],  # Flip x coordinates
				box[1],
				-box[0],
				box[3],
			])
	
	boxes = left_boxes
	boxes_facing_right = false

func check_collision(other_sprite: MugenAnimationSprite, type: int) -> bool:
	"""Check collision with another sprite"""
	if not other_sprite.collision_area_2d or not collision_area_2d or \
	   not other_sprite.attacking_area_2d or not attacking_area_2d:
		return false
	
	if type == 1:  # Attack collision
		return overlaps_area(attacking_area_2d, other_sprite.collision_area_2d) or \
			   overlaps_area(attacking_area_2d, other_sprite.attacking_area_2d)
	elif type == 2:  # Body collision
		return overlaps_area(collision_area_2d, other_sprite.collision_area_2d) or \
			   overlaps_area(collision_area_2d, other_sprite.attacking_area_2d)
	
	return false

func check_attack_collision(other_sprite: MugenAnimationSprite) -> bool:
	"""Check if this sprite's attack area overlaps with other's collision area"""
	if not other_sprite.collision_area_2d or not attacking_area_2d:
		return false
	
	return overlaps_area(attacking_area_2d, other_sprite.collision_area_2d)

func overlaps_area(area1: Area2D, area2: Area2D) -> bool:
	"""Check if two areas overlap using physics queries"""
	if not area1 or not area2:
		return false
		
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	
	for shape_owner in area1.get_shape_owners():
		for shape_idx in area1.shape_owner_get_shape_count(shape_owner):
			var shape = area1.shape_owner_get_shape(shape_owner, shape_idx)
			var shape_transform = area1.shape_owner_get_owner(shape_owner).get_global_transform()
			
			var query = PhysicsShapeQueryParameters2D.new()
			query.set_shape(shape)
			query.set_transform(shape_transform)
			query.set_collision_mask(area2.get_collision_layer())
			query.set_collide_with_areas(true)
			
			var results = space_state.intersect_shape(query, 64)
			for result in results:
				if result['collider'] == area2:
					return true
	
	return false

func _draw():
	"""Draw debug information if enabled"""
	if debug_collisions:
		draw_collision_boxes()

func draw_collision_boxes():
	"""Draw collision boxes for debugging"""
	for type in boxes:
		var points = boxes[type]
		var color = Color.RED if type == 1 else Color.BLUE
		
		for point in points:
			if point.size() >= 4:
				# Draw rectangle outline
				var rect = Rect2(Vector2(point[0], point[1]), Vector2(point[2] - point[0], point[3] - point[1]))
				draw_rect(rect, color, false, 2.0)

func get_sprite_bundle() -> SpriteBundle:
	"""Get the sprite bundle"""
	return sprite_bundle_ref

func set_debug_collisions(enabled: bool):
	"""Enable/disable collision box debugging"""
	debug_collisions = enabled
	queue_redraw()
