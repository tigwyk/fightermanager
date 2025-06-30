extends Control
class_name BattleViewerUI

## Placeholder Battle Viewer UI - Will be expanded later

@onready var back_btn: Button = $CenterContainer/VBoxContainer/BackButton

func _ready():
	print("⚔️ Battle Viewer UI Ready (Placeholder)")
	back_btn.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	"""Return to main menu"""
	print("🏠 Returning to main menu")
	get_tree().change_scene_to_file("res://scenes/core/main_menu.tscn")
