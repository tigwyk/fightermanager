extends Control
class_name FighterManagementUI

## Fighter Management UI
## Handles fighter training, stats, and career management

@onready var back_btn: Button = %BackButton
@onready var fighter_list: ItemList = %FighterList
@onready var add_fighter_btn: Button = %AddFighterButton
@onready var strength_btn: Button = %StrengthButton
@onready var speed_btn: Button = %SpeedButton
@onready var technique_btn: Button = %TechniqueButton
@onready var defense_btn: Button = %DefenseButton
@onready var stats_display: RichTextLabel = %StatsDisplay

var current_fighter: Dictionary = {}

func _ready():
	print("🏋️ Fighter Management UI Ready")
	_connect_signals()
	_load_fighter_data()

func _connect_signals():
	"""Connect UI signals"""
	back_btn.pressed.connect(_on_back_pressed)
	add_fighter_btn.pressed.connect(_on_add_fighter_pressed)
	fighter_list.item_selected.connect(_on_fighter_selected)
	strength_btn.pressed.connect(func(): _train_attribute("strength"))
	speed_btn.pressed.connect(func(): _train_attribute("speed"))
	technique_btn.pressed.connect(func(): _train_attribute("technique"))
	defense_btn.pressed.connect(func(): _train_attribute("defense"))

func _on_back_pressed():
	"""Return to main menu"""
	print("🏠 Returning to main menu")
	var main_menu = load("res://scenes/core/main_menu.tscn")
	if main_menu:
		get_tree().change_scene_to_packed(main_menu)

func _load_fighter_data():
	"""Load available fighters"""
	# TODO: Load from save system
	# For now, add some placeholder fighters
	fighter_list.add_item("🥊 Rocky Balboa (Rookie)")
	fighter_list.add_item("🔥 Ryu Hoshi (Fighter)")
	fighter_list.add_item("⚡ Chun-Li (Champion)")
	
	# Select first fighter by default
	if fighter_list.get_item_count() > 0:
		fighter_list.select(0)
		_on_fighter_selected(0)

func _on_fighter_selected(index: int):
	"""Fighter selected from list"""
	var fighter_name = fighter_list.get_item_text(index)
	print("👤 Selected fighter: %s" % fighter_name)
	
	# TODO: Load actual fighter data
	current_fighter = _get_placeholder_fighter_data(index)
	_update_stats_display()

func _get_placeholder_fighter_data(index: int) -> Dictionary:
	"""Get placeholder fighter data"""
	var fighters = [
		{
			"name": "Rocky Balboa",
			"level": 1,
			"strength": 65,
			"speed": 55,
			"technique": 45,
			"defense": 70,
			"stamina": 80,
			"experience": 120,
			"condition": "Fresh",
			"wins": 2,
			"losses": 1
		},
		{
			"name": "Ryu Hoshi", 
			"level": 15,
			"strength": 85,
			"speed": 75,
			"technique": 90,
			"defense": 80,
			"stamina": 85,
			"experience": 1500,
			"condition": "Good",
			"wins": 18,
			"losses": 3
		},
		{
			"name": "Chun-Li",
			"level": 25,
			"strength": 75,
			"speed": 95,
			"technique": 92,
			"defense": 85,
			"stamina": 90,
			"experience": 3200,
			"condition": "Peak",
			"wins": 35,
			"losses": 2
		}
	]
	
	return fighters[index] if index < fighters.size() else {}

func _update_stats_display():
	"""Update the stats display with current fighter"""
	if current_fighter.is_empty():
		return
	
	var stats_text = "[b]%s (Level %d)[/b]\n\n" % [current_fighter.name, current_fighter.level]
	stats_text += "[color=yellow]Combat Stats:[/color]\n"
	stats_text += "💪 Strength: %d/100\n" % current_fighter.strength
	stats_text += "🏃 Speed: %d/100\n" % current_fighter.speed
	stats_text += "🎯 Technique: %d/100\n" % current_fighter.technique
	stats_text += "🛡️ Defense: %d/100\n\n" % current_fighter.defense
	
	stats_text += "[color=green]Career Info:[/color]\n"
	stats_text += "📊 Experience: %d XP\n" % current_fighter.experience
	stats_text += "💚 Condition: %s\n" % current_fighter.condition
	stats_text += "🏆 Record: %d-%d\n\n" % [current_fighter.wins, current_fighter.losses]
	
	stats_text += "[color=cyan]Training Available:[/color]\n"
	stats_text += "Click training buttons to improve stats!"
	
	stats_display.text = stats_text

func _on_add_fighter_pressed():
	"""Add a new fighter"""
	print("➕ Adding new fighter")
	var dialog = AcceptDialog.new()
	dialog.title = "Add New Fighter"
	dialog.dialog_text = "Create new fighter functionality coming soon!\n\nThis will allow you to:\n• Choose fighter name and style\n• Select starting attributes\n• Pick MUGEN character representation\n• Set initial career goals"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _train_attribute(attribute: String):
	"""Train a specific attribute"""
	if current_fighter.is_empty():
		_show_error("Please select a fighter first!")
		return
	
	print("🏋️ Training %s for %s" % [attribute, current_fighter.name])
	
	# TODO: Implement actual training system with costs and progression
	var cost = 100  # Base training cost
	var improvement = randi_range(1, 5)  # Random improvement
	
	var dialog = AcceptDialog.new()
	dialog.title = "Training Session"
	dialog.dialog_text = "Training %s for %s\n\nCost: $%d\nPotential improvement: +%d points\n\n(Training system coming soon!)" % [
		attribute.capitalize(), current_fighter.name, cost, improvement
	]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_error(message: String):
	"""Show error dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
