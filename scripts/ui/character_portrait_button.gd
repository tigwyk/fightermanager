extends Button
class_name CharacterPortraitButton

## Enhanced character portrait button with visual feedback

var character_data: Dictionary
var is_selected: bool = false
var hover_effect: ColorRect
var selection_border: ColorRect

signal character_selected(character_data)

func _init(char_data: Dictionary):
	character_data = char_data
	setup_button()

func setup_button():
	"""Initialize the button with character data"""
	text = character_data.get("name", "Unknown")
	custom_minimum_size = Vector2(80, 80)
	
	# Create hover effect
	hover_effect = ColorRect.new()
	hover_effect.name = "HoverEffect"
	hover_effect.color = Color(1, 1, 1, 0.2)
	hover_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_effect.visible = false
	add_child(hover_effect)
	
	# Create selection border
	selection_border = ColorRect.new()
	selection_border.name = "SelectionBorder"
	selection_border.color = Color.TRANSPARENT
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_border.visible = false
	add_child(selection_border)
	
	# Connect signals
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	
	# Try to load portrait
	_load_portrait()

func _load_portrait():
	"""Attempt to load character portrait"""
	# For now, create a colored rectangle as placeholder
	var placeholder = ColorRect.new()
	placeholder.name = "Portrait"
	placeholder.color = _get_character_color()
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(placeholder)
	
	# Move text above portrait
	move_child(get_children().back(), 0)  # Move placeholder to back

func _get_character_color() -> Color:
	"""Generate a unique color for this character"""
	var name_hash = character_data.get("name", "default").hash()
	var r = (name_hash & 0xFF) / 255.0
	var g = ((name_hash >> 8) & 0xFF) / 255.0  
	var b = ((name_hash >> 16) & 0xFF) / 255.0
	return Color(r, g, b, 0.8)

func _on_pressed():
	"""Handle button press"""
	set_selected(true)
	character_selected.emit(character_data)
	print("🥊 Character selected: %s" % character_data.get("name", "Unknown"))

func _on_hover_start():
	"""Show hover effect"""
	hover_effect.visible = true

func _on_hover_end():
	"""Hide hover effect"""
	hover_effect.visible = false

func set_selected(selected: bool):
	"""Set selection state with visual feedback"""
	is_selected = selected
	if selection_border:
		if selected:
			selection_border.color = Color.GOLD
			selection_border.visible = true
			# Add a slight glow effect
			modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			selection_border.visible = false
			modulate = Color.WHITE

func _ready():
	"""Ensure proper sizing when added to scene"""
	if hover_effect:
		hover_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if selection_border:
		selection_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
