extends Control
class_name BattleSceneUI

## Battle Scene UI
## Handles the actual battle interface with MUGEN fighters

@onready var p1_name: Label = %P1Name
@onready var p1_health: ProgressBar = %P1Health
@onready var p2_name: Label = %P2Name
@onready var p2_health: ProgressBar = %P2Health
@onready var timer_label: Label = %Timer
@onready var round_label: Label = %Round
@onready var back_btn: Button = %BackButton
@onready var stage_bg: Sprite2D = %StageBackground
@onready var fighter1_spawn: Marker2D = %Fighter1Spawn
@onready var fighter2_spawn: Marker2D = %Fighter2Spawn

var battle_timer: float = 99.0
var current_round: int = 1
var fighter1: Node2D
var fighter2: Node2D

func _ready():
	print("⚔️ Battle Scene Ready")
	_connect_signals()
	_setup_battle()

func _connect_signals():
	"""Connect UI signals"""
	back_btn.pressed.connect(_on_back_pressed)

func _setup_battle():
	"""Setup the battle environment"""
	print("🥊 Setting up battle...")
	
	# Set fighter names (placeholder)
	p1_name.text = "Ryu"
	p2_name.text = "Chun-Li"
	
	# Reset health bars
	p1_health.value = 100
	p2_health.value = 100
	
	# Setup timer and round
	battle_timer = 99.0
	current_round = 1
	_update_timer_display()
	_update_round_display()
	
	# Load MUGEN fighters (placeholder)
	_load_fighters()

func _load_fighters():
	"""Load MUGEN fighters into the battle"""
	print("👥 Loading fighters...")
	
	# TODO: Integrate with actual MUGEN character loading system
	# For now, create placeholder fighter nodes
	
	# Create placeholder fighter representations
	fighter1 = _create_placeholder_fighter("Ryu", Color.BLUE)
	fighter2 = _create_placeholder_fighter("Chun-Li", Color.RED)
	
	# Position fighters
	add_child(fighter1)
	add_child(fighter2)
	fighter1.position = fighter1_spawn.position
	fighter2.position = fighter2_spawn.position
	
	print("✅ Fighters loaded successfully")

func _create_placeholder_fighter(fighter_name: String, color: Color) -> Node2D:
	"""Create a placeholder fighter node"""
	var fighter = Node2D.new()
	fighter.name = fighter_name
	
	# Add visual representation
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(64, 96, false, Image.FORMAT_RGB8)
	image.fill(color)
	texture.set_image(image)
	sprite.texture = texture
	fighter.add_child(sprite)
	
	# Add a simple label
	var label = Label.new()
	label.text = fighter_name
	label.position = Vector2(-20, -60)
	var label_settings = LabelSettings.new()
	label_settings.font_size = 16
	label_settings.font_color = Color("Yellow")
	label.label_settings = label_settings
	fighter.add_child(label)
	
	return fighter

func _process(delta):
	"""Update battle state"""
	if battle_timer > 0:
		battle_timer -= delta
		_update_timer_display()
		
		if battle_timer <= 0:
			_end_round("Time Up!")

func _update_timer_display():
	"""Update the timer display"""
	timer_label.text = str(max(0, int(battle_timer)))

func _update_round_display():
	"""Update the round display"""
	round_label.text = "Round %d" % current_round

func _end_round(reason: String):
	"""End the current round"""
	print("🏁 Round ended: %s" % reason)
	
	# TODO: Implement round ending logic
	# - Determine winner
	# - Update scores
	# - Start next round or end match
	
	var dialog = AcceptDialog.new()
	dialog.title = "Round Complete"
	dialog.dialog_text = "Round %d completed!\n\nReason: %s\n\n(Battle system coming soon!)" % [current_round, reason]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_back_pressed():
	"""Return to main menu"""
	print("🏠 Returning to main menu")
	var main_menu = load("res://scenes/core/main_menu.tscn")
	if main_menu:
		get_tree().change_scene_to_packed(main_menu)

func _input(event):
	"""Handle input for battle controls"""
	if event.is_action_pressed("ui_cancel"):
		_show_pause_menu()

func _show_pause_menu():
	"""Show battle pause menu"""
	var dialog = ConfirmationDialog.new()
	dialog.title = "Pause Menu"
	dialog.dialog_text = "Battle paused\n\nReturn to main menu?"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_on_back_pressed)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
