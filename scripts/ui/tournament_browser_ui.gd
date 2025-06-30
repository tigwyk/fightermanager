extends Control
class_name TournamentBrowserUI

## Tournament Browser UI
## Handles tournament registration, viewing, and management

@onready var back_btn: Button = %BackButton
@onready var tournament_tree: Tree = %TournamentTree
@onready var tournament_info: RichTextLabel = %TournamentInfo
@onready var register_btn: Button = %RegisterButton
@onready var view_bracket_btn: Button = %ViewBracketButton
@onready var schedule_btn: Button = %ScheduleButton
@onready var create_tournament_btn: Button = %CreateTournamentButton
@onready var refresh_btn: Button = %RefreshButton

var current_tournament: Dictionary = {}

func _ready():
	print("🏆 Tournament Browser UI Ready")
	_connect_signals()
	_setup_tournament_tree()
	_load_tournament_data()

func _connect_signals():
	"""Connect UI signals"""
	back_btn.pressed.connect(_on_back_pressed)
	tournament_tree.item_selected.connect(_on_tournament_selected)
	register_btn.pressed.connect(_on_register_pressed)
	view_bracket_btn.pressed.connect(_on_view_bracket_pressed)
	schedule_btn.pressed.connect(_on_schedule_pressed)
	create_tournament_btn.pressed.connect(_on_create_tournament_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)

func _setup_tournament_tree():
	"""Setup the tournament tree display"""
	tournament_tree.set_column_titles_visible(true)
	tournament_tree.set_columns(4)
	tournament_tree.set_column_title(0, "Tournament")
	tournament_tree.set_column_title(1, "Type")
	tournament_tree.set_column_title(2, "Prize")
	tournament_tree.set_column_title(3, "Status")

func _on_back_pressed():
	"""Return to main menu"""
	print("🏠 Returning to main menu")
	var main_menu = load("res://scenes/core/main_menu.tscn")
	if main_menu:
		get_tree().change_scene_to_packed(main_menu)

func _load_tournament_data():
	"""Load available tournaments"""
	var root = tournament_tree.create_item()
	tournament_tree.hide_root = true
	
	# Add tournament categories
	var local_category = tournament_tree.create_item(root)
	local_category.set_text(0, "Local Tournaments")
	local_category.set_selectable(0, false)
	
	_add_tournament_item(local_category, {
		"name": "Downtown Boxing Arena",
		"type": "Elimination",
		"prize": "$5,000",
		"status": "Open",
		"entry_fee": 100,
		"participants": 16,
		"description": "Local amateur tournament for upcoming fighters."
	})
	
	_add_tournament_item(local_category, {
		"name": "City Championship",
		"type": "Round Robin",
		"prize": "$12,000",
		"status": "Registration",
		"entry_fee": 250,
		"participants": 8,
		"description": "City-wide championship for intermediate fighters."
	})
	
	var regional_category = tournament_tree.create_item(root)
	regional_category.set_text(0, "Regional Tournaments")
	regional_category.set_selectable(0, false)
	
	_add_tournament_item(regional_category, {
		"name": "State Fighting League",
		"type": "League",
		"prize": "$25,000",
		"status": "Invite Only",
		"entry_fee": 500,
		"participants": 32,
		"description": "Professional regional league tournament."
	})
	
	_add_tournament_item(regional_category, {
		"name": "National Qualifiers",
		"type": "Swiss",
		"prize": "$50,000",
		"status": "Closed",
		"entry_fee": 1000,
		"participants": 64,
		"description": "Qualifier tournament for national championships."
	})

func _add_tournament_item(parent: TreeItem, tournament_data: Dictionary):
	"""Add a tournament item to the tree"""
	var item = tournament_tree.create_item(parent)
	item.set_text(0, tournament_data.name)
	item.set_text(1, tournament_data.type)
	item.set_text(2, tournament_data.prize)
	item.set_text(3, tournament_data.status)
	item.set_metadata(0, tournament_data)

func _on_tournament_selected():
	"""Tournament selected from tree"""
	var selected = tournament_tree.get_selected()
	if not selected:
		return
	
	var tournament_data = selected.get_metadata(0)
	if not tournament_data:
		return
	
	current_tournament = tournament_data
	print("🏆 Selected tournament: %s" % current_tournament.name)
	_update_tournament_info()
	_update_action_buttons()

func _update_tournament_info():
	"""Update tournament information display"""
	if current_tournament.is_empty():
		return
	
	var info_text = "[b]%s[/b]\n\n" % current_tournament.name
	info_text += "[color=yellow]Tournament Details:[/color]\n"
	info_text += "🏆 Type: %s\n" % current_tournament.type
	info_text += "💰 Prize Pool: %s\n" % current_tournament.prize
	info_text += "💳 Entry Fee: $%d\n" % current_tournament.entry_fee
	info_text += "👥 Participants: %d fighters\n" % current_tournament.participants
	info_text += "📊 Status: %s\n\n" % current_tournament.status
	
	info_text += "[color=cyan]Description:[/color]\n"
	info_text += current_tournament.description + "\n\n"
	
	info_text += "[color=green]Requirements:[/color]\n"
	match current_tournament.status:
		"Open":
			info_text += "✅ Registration is open\n"
			info_text += "✅ Pay entry fee to register\n"
		"Registration":
			info_text += "⏰ Registration period active\n"
			info_text += "✅ Meet skill requirements\n"
		"Invite Only":
			info_text += "🔒 Invitation required\n"
			info_text += "⭐ High skill rating needed\n"
		"Closed":
			info_text += "❌ Registration closed\n"
			info_text += "👀 View results only\n"
	
	tournament_info.text = info_text

func _update_action_buttons():
	"""Update action button states"""
	var can_register = current_tournament.get("status", "") in ["Open", "Registration"]
	var is_active = current_tournament.get("status", "") != "Closed"
	
	register_btn.disabled = not can_register 
	view_bracket_btn.disabled = not is_active
	schedule_btn.disabled = not is_active

func _on_register_pressed():
	"""Register fighter for tournament"""
	print("🎫 Registering for tournament: %s" % current_tournament.name)
	var dialog = AcceptDialog.new()
	dialog.title = "Tournament Registration"
	dialog.dialog_text = "Register for %s\n\nEntry Fee: $%d\nPrize Pool: %s\n\n(Registration system coming soon!)" % [
		current_tournament.name, current_tournament.entry_fee, current_tournament.prize
	]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_view_bracket_pressed():
	"""View tournament bracket"""
	print("🏆 Viewing bracket for: %s" % current_tournament.name)
	var dialog = AcceptDialog.new()
	dialog.title = "Tournament Bracket"
	dialog.dialog_text = "Tournament bracket for %s\n\nBracket visualization coming soon!\n\nWill show:\n• Match pairings\n• Round progression\n• Fighter advancement\n• Match results" % current_tournament.name
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_schedule_pressed():
	"""View tournament schedule"""
	print("📅 Viewing schedule for: %s" % current_tournament.name)
	var dialog = AcceptDialog.new()
	dialog.title = "Tournament Schedule"
	dialog.dialog_text = "Schedule for %s\n\nSchedule system coming soon!\n\nWill show:\n• Match times\n• Venue locations\n• Round dates\n• Registration deadlines" % current_tournament.name
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_create_tournament_pressed():
	"""Create new tournament"""
	print("➕ Creating new tournament")
	var dialog = AcceptDialog.new()
	dialog.title = "Create Tournament"
	dialog.dialog_text = "Tournament creation coming soon!\n\nThis will allow you to:\n• Set tournament type and format\n• Configure prize pools\n• Set entry requirements\n• Schedule tournament dates\n• Invite specific fighters"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_refresh_pressed():
	"""Refresh tournament list"""
	print("🔄 Refreshing tournament list")
	tournament_tree.clear()
	_setup_tournament_tree()
	_load_tournament_data()
	current_tournament.clear()
	tournament_info.text = "[b]Select a tournament to view details[/b]\n\nTournament information will include:\n• Entry requirements\n• Prize pool\n• Tournament format\n• Participating fighters\n• Registration deadline"
	_update_action_buttons()
