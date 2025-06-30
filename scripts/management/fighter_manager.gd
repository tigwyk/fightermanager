extends Node
class_name FighterManager

## Fighter Management System - Core management mechanics for fighter careers
## Handles fighter progression, attributes, training, and career development

signal fighter_stat_changed(fighter_id: String, stat_name: String, old_value: float, new_value: float)
signal fighter_level_up(fighter_id: String, old_level: int, new_level: int)
signal fighter_training_complete(fighter_id: String, training_type: String, results: Dictionary)
signal fighter_condition_changed(fighter_id: String, condition_type: String, value: float)

enum FighterLevel {
	ROOKIE,
	AMATEUR, 
	SEMI_PRO,
	PROFESSIONAL,
	CHAMPION,
	LEGEND
}

enum TrainingType {
	STRENGTH,
	SPEED,
	TECHNIQUE,
	DEFENSE,
	STAMINA,
	MENTAL,
	SPARRING,
	COMBO_PRACTICE
}

enum ConditionType {
	HEALTH,
	MOTIVATION,
	FATIGUE,
	CONFIDENCE
}

# Managed fighters data
var managed_fighters: Dictionary = {}  # fighter_id -> FighterData
var training_queue: Array = []  # Array of training sessions
var fighter_schedules: Dictionary = {}  # fighter_id -> schedule data

# Training and progression settings
var base_training_cost: int = 100
var training_duration_hours: int = 4
var fatigue_recovery_rate: float = 0.1  # per hour
var motivation_decay_rate: float = 0.05  # per day

func _ready():
	print("Fighter Manager initialized")
	# Start the daily progression timer
	var timer = Timer.new()
	timer.wait_time = 60.0  # Process every minute (1 game hour)
	timer.timeout.connect(_process_hourly_updates)
	timer.autostart = true
	add_child(timer)

# PUBLIC API - Fighter Management

func create_fighter(fighter_name: String, character_data = null) -> String:
	"""Create a new managed fighter with base stats"""
	var fighter_id = _generate_fighter_id()
	var fighter_data = FighterData.new()
	
	# Basic info
	fighter_data.fighter_id = fighter_id
	fighter_data.fighter_name = fighter_name
	fighter_data.character_data = character_data
	fighter_data.level = FighterLevel.ROOKIE
	fighter_data.experience = 0
	fighter_data.creation_date = Time.get_unix_time_from_system()
	
	# Initialize base attributes (0-100 scale)
	fighter_data.attributes = {
		"strength": randf_range(20, 40),
		"speed": randf_range(20, 40),
		"technique": randf_range(20, 40),
		"defense": randf_range(20, 40),
		"stamina": randf_range(20, 40),
		"mental": randf_range(20, 40)
	}
	
	# Initialize condition (0-100 scale)
	fighter_data.condition = {
		"health": 100.0,
		"motivation": randf_range(70, 90),
		"fatigue": randf_range(0, 20),
		"confidence": 50.0
	}
	
	# Career stats
	fighter_data.career_stats = {
		"total_fights": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"ko_wins": 0,
		"tournaments_won": 0,
		"prize_money": 0,
		"training_sessions": 0
	}
	
	# Skills and specialization
	fighter_data.skills = {}
	fighter_data.specialization = ""
	fighter_data.fighting_style = ""
	
	managed_fighters[fighter_id] = fighter_data
	print("Created fighter: ", fighter_name, " (ID: ", fighter_id, ")")
	
	return fighter_id

func get_fighter(fighter_id: String) -> FighterData:
	"""Get fighter data by ID"""
	return managed_fighters.get(fighter_id)

func get_all_fighters() -> Array:
	"""Get all managed fighters"""
	return managed_fighters.values()

func get_fighter_names() -> Array:
	"""Get list of all fighter names"""
	var names = []
	for fighter in managed_fighters.values():
		names.append(fighter.fighter_name)
	return names

# TRAINING SYSTEM

func start_training(fighter_id: String, training_type: TrainingType, duration_hours: int = 4) -> bool:
	"""Start a training session for a fighter"""
	var fighter = get_fighter(fighter_id)
	if not fighter:
		print("Error: Fighter not found: ", fighter_id)
		return false
	
	# Check if fighter can train
	if not _can_fighter_train(fighter):
		print("Fighter cannot train right now: ", fighter.fighter_name)
		return false
	
	# Calculate training cost
	var cost = _calculate_training_cost(fighter, training_type, duration_hours)
	
	# Create training session
	var training_session = {
		"fighter_id": fighter_id,
		"training_type": training_type,
		"duration_hours": duration_hours,
		"cost": cost,
		"start_time": Time.get_unix_time_from_system(),
		"completion_time": Time.get_unix_time_from_system() + (duration_hours * 60)  # minutes for testing
	}
	
	training_queue.append(training_session)
	fighter.current_training = training_session
	
	print("Started training for ", fighter.fighter_name, ": ", TrainingType.keys()[training_type])
	return true

func get_training_progress(fighter_id: String) -> float:
	"""Get current training progress (0.0 to 1.0)"""
	var fighter = get_fighter(fighter_id)
	if not fighter or not fighter.current_training:
		return 0.0
	
	var session = fighter.current_training
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - session.start_time
	var total_duration = session.completion_time - session.start_time
	
	return clamp(elapsed / total_duration, 0.0, 1.0)

func is_fighter_training(fighter_id: String) -> bool:
	"""Check if fighter is currently training"""
	var fighter = get_fighter(fighter_id)
	return fighter and fighter.current_training != null

# ATTRIBUTE PROGRESSION

func add_experience(fighter_id: String, amount: int):
	"""Add experience points to a fighter"""
	var fighter = get_fighter(fighter_id)
	if not fighter:
		return
	
	var old_level = fighter.level
	fighter.experience += amount
	
	# Check for level up
	var new_level = _calculate_level(fighter.experience)
	if new_level > old_level:
		fighter.level = new_level
		_apply_level_up_bonuses(fighter)
		emit_signal("fighter_level_up", fighter_id, old_level, new_level)
		print("Level up! ", fighter.fighter_name, " is now level ", new_level)

func modify_attribute(fighter_id: String, attribute: String, change: float):
	"""Modify a fighter's attribute"""
	var fighter = get_fighter(fighter_id)
	if not fighter or not fighter.attributes.has(attribute):
		return
	
	var old_value = fighter.attributes[attribute]
	var new_value = clamp(old_value + change, 0.0, 100.0)
	fighter.attributes[attribute] = new_value
	
	emit_signal("fighter_stat_changed", fighter_id, attribute, old_value, new_value)

func modify_condition(fighter_id: String, condition: String, change: float):
	"""Modify a fighter's condition"""
	var fighter = get_fighter(fighter_id)
	if not fighter or not fighter.condition.has(condition):
		return
	
	var old_value = fighter.condition[condition]
	var new_value = clamp(old_value + change, 0.0, 100.0)
	fighter.condition[condition] = new_value
	
	emit_signal("fighter_condition_changed", fighter_id, condition, new_value)

# CAREER MANAGEMENT

func record_fight_result(fighter_id: String, won: bool, ko: bool = false, prize_money: int = 0):
	"""Record the result of a fight"""
	var fighter = get_fighter(fighter_id)
	if not fighter:
		return
	
	fighter.career_stats.total_fights += 1
	fighter.career_stats.prize_money += prize_money
	
	if won:
		fighter.career_stats.wins += 1
		if ko:
			fighter.career_stats.ko_wins += 1
		
		# Boost confidence and experience for wins
		modify_condition(fighter_id, "confidence", randf_range(5, 15))
		add_experience(fighter_id, int(randf_range(50, 100)))
	else:
		fighter.career_stats.losses += 1
		
		# Reduce confidence for losses
		modify_condition(fighter_id, "confidence", randf_range(-10, -5))
		add_experience(fighter_id, int(randf_range(20, 50)))
	
	# Increase fatigue and reduce motivation after fights
	modify_condition(fighter_id, "fatigue", randf_range(10, 25))
	modify_condition(fighter_id, "motivation", randf_range(-5, -2))
	
	print("Fight result recorded for ", fighter.fighter_name, ": ", "WIN" if won else "LOSS")

func get_fighter_rating(fighter_id: String) -> int:
	"""Calculate overall fighter rating"""
	var fighter = get_fighter(fighter_id)
	if not fighter:
		return 0
	
	# Weighted average of attributes
	var total = 0.0
	total += fighter.attributes.strength * 0.2
	total += fighter.attributes.speed * 0.2
	total += fighter.attributes.technique * 0.2
	total += fighter.attributes.defense * 0.15
	total += fighter.attributes.stamina * 0.15
	total += fighter.attributes.mental * 0.1
	
	# Apply level and condition modifiers
	var level_bonus = fighter.level * 5
	var condition_modifier = (fighter.condition.health + fighter.condition.motivation - fighter.condition.fatigue) / 200.0
	
	return int(total + level_bonus) * (1.0 + condition_modifier)

# INTERNAL SYSTEMS

func _process_hourly_updates():
	"""Process hourly game updates (fatigue recovery, training progress, etc.)"""
	var current_time = Time.get_unix_time_from_system()
	
	# Process training completion
	_process_training_completion(current_time)
	
	# Process condition changes
	for fighter in managed_fighters.values():
		_process_fighter_condition_updates(fighter)

func _process_training_completion(current_time: float):
	"""Check and complete finished training sessions"""
	for i in range(training_queue.size() - 1, -1, -1):
		var session = training_queue[i]
		if current_time >= session.completion_time:
			_complete_training_session(session)
			training_queue.remove_at(i)

func _complete_training_session(session: Dictionary):
	"""Complete a training session and apply benefits"""
	var fighter = get_fighter(session.fighter_id)
	if not fighter:
		return
	
	# Clear current training
	fighter.current_training = null
	
	# Calculate training benefits
	var benefits = _calculate_training_benefits(fighter, session.training_type, session.duration_hours)
	
	# Apply attribute improvements
	for attr in benefits.attributes:
		modify_attribute(session.fighter_id, attr, benefits.attributes[attr])
	
	# Apply condition changes
	for condition in benefits.conditions:
		modify_condition(session.fighter_id, condition, benefits.conditions[condition])
	
	# Add experience
	add_experience(session.fighter_id, benefits.experience)
	
	# Update career stats
	fighter.career_stats.training_sessions += 1
	
	emit_signal("fighter_training_complete", session.fighter_id, TrainingType.keys()[session.training_type], benefits)
	print("Training completed for ", fighter.fighter_name, ": ", TrainingType.keys()[session.training_type])

func _calculate_training_benefits(fighter: FighterData, training_type: TrainingType, duration: int) -> Dictionary:
	"""Calculate the benefits from a training session"""
	var benefits = {
		"attributes": {},
		"conditions": {},
		"experience": 0
	}
	
	# Base improvement amount (affected by duration and fighter level)
	var base_improvement = duration * 0.5 * (1.0 + fighter.level * 0.1)
	var fatigue_increase = duration * 2.0
	
	# Training-specific benefits
	match training_type:
		TrainingType.STRENGTH:
			benefits.attributes["strength"] = base_improvement * randf_range(0.8, 1.2)
			benefits.experience = 20 * duration
		TrainingType.SPEED:
			benefits.attributes["speed"] = base_improvement * randf_range(0.8, 1.2)
			benefits.experience = 20 * duration
		TrainingType.TECHNIQUE:
			benefits.attributes["technique"] = base_improvement * randf_range(0.8, 1.2)
			benefits.experience = 25 * duration
		TrainingType.DEFENSE:
			benefits.attributes["defense"] = base_improvement * randf_range(0.8, 1.2)
			benefits.experience = 20 * duration
		TrainingType.STAMINA:
			benefits.attributes["stamina"] = base_improvement * randf_range(0.8, 1.2)
			benefits.experience = 15 * duration
		TrainingType.MENTAL:
			benefits.attributes["mental"] = base_improvement * randf_range(0.8, 1.2)
			benefits.conditions["confidence"] = randf_range(2, 5)
			benefits.experience = 30 * duration
		TrainingType.SPARRING:
			# Balanced improvement across multiple attributes
			benefits.attributes["technique"] = base_improvement * 0.4
			benefits.attributes["speed"] = base_improvement * 0.3
			benefits.attributes["mental"] = base_improvement * 0.3
			benefits.experience = 40 * duration
			fatigue_increase *= 1.5  # Sparring is more tiring
		TrainingType.COMBO_PRACTICE:
			benefits.attributes["technique"] = base_improvement * 0.6
			benefits.attributes["mental"] = base_improvement * 0.4
			benefits.experience = 35 * duration
	
	# Apply fatigue
	benefits.conditions["fatigue"] = fatigue_increase
	benefits.conditions["motivation"] = randf_range(-1, 1)  # Slight motivation change
	
	return benefits

func _process_fighter_condition_updates(fighter: FighterData):
	"""Process natural condition changes over time"""
	# Fatigue recovery
	if fighter.condition.fatigue > 0:
		modify_condition(fighter.fighter_id, "fatigue", -fatigue_recovery_rate)
	
	# Motivation decay (if not training)
	if not fighter.current_training:
		modify_condition(fighter.fighter_id, "motivation", -motivation_decay_rate)

func _can_fighter_train(fighter: FighterData) -> bool:
	"""Check if a fighter can start training"""
	if fighter.current_training:
		return false  # Already training
	
	if fighter.condition.health < 30:
		return false  # Too injured
	
	if fighter.condition.fatigue > 80:
		return false  # Too tired
	
	return true

func _calculate_training_cost(fighter: FighterData, training_type: TrainingType, duration: int) -> int:
	"""Calculate the cost of a training session"""
	var base_cost = base_training_cost
	var duration_multiplier = duration / 4.0  # Base duration is 4 hours
	var level_multiplier = 1.0 + (fighter.level * 0.2)
	
	# Some training types cost more
	var type_multiplier = 1.0
	match training_type:
		TrainingType.SPARRING:
			type_multiplier = 1.5
		TrainingType.MENTAL:
			type_multiplier = 1.3
		TrainingType.COMBO_PRACTICE:
			type_multiplier = 1.2
	
	return int(base_cost * duration_multiplier * level_multiplier * type_multiplier)

func _calculate_level(experience: int) -> int:
	"""Calculate fighter level based on experience"""
	# Simple exponential leveling
	if experience < 100:
		return FighterLevel.ROOKIE
	elif experience < 500:
		return FighterLevel.AMATEUR
	elif experience < 1500:
		return FighterLevel.SEMI_PRO
	elif experience < 3500:
		return FighterLevel.PROFESSIONAL
	elif experience < 7000:
		return FighterLevel.CHAMPION
	else:
		return FighterLevel.LEGEND

func _apply_level_up_bonuses(fighter: FighterData):
	"""Apply bonuses when a fighter levels up"""
	# Attribute point bonuses based on level
	var bonus_points = randf_range(2, 5)
	
	# Distribute bonus points randomly across attributes
	var attributes = fighter.attributes.keys()
	for i in range(int(bonus_points)):
		var random_attr = attributes[randi() % attributes.size()]
		fighter.attributes[random_attr] = clamp(fighter.attributes[random_attr] + 1, 0, 100)
	
	# Restore some condition
	modify_condition(fighter.fighter_id, "motivation", randf_range(5, 15))
	modify_condition(fighter.fighter_id, "confidence", randf_range(3, 8))

func _generate_fighter_id() -> String:
	"""Generate a unique fighter ID"""
	return "fighter_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

# FighterData class definition
class FighterData:
	var fighter_id: String
	var fighter_name: String
	var character_data  # MugenCharacterData reference
	var level: int
	var experience: int
	var creation_date: float
	
	# Core attributes (0-100)
	var attributes: Dictionary = {}
	
	# Current condition (0-100)
	var condition: Dictionary = {}
	
	# Career statistics
	var career_stats: Dictionary = {}
	
	# Skills and specialization
	var skills: Dictionary = {}
	var specialization: String = ""
	var fighting_style: String = ""
	
	# Current status
	var current_training = null
	var last_fight_date: float = 0
	var next_scheduled_fight: float = 0
	
	func get_display_name() -> String:
		return fighter_name
	
	func get_level_name() -> String:
		match level:
			FighterManager.FighterLevel.ROOKIE:
				return "Rookie"
			FighterManager.FighterLevel.AMATEUR:
				return "Amateur"
			FighterManager.FighterLevel.SEMI_PRO:
				return "Semi-Pro"
			FighterManager.FighterLevel.PROFESSIONAL:
				return "Professional"
			FighterManager.FighterLevel.CHAMPION:
				return "Champion"
			FighterManager.FighterLevel.LEGEND:
				return "Legend"
			_:
				return "Unknown"
	
	func get_win_rate() -> float:
		if career_stats.total_fights == 0:
			return 0.0
		return float(career_stats.wins) / float(career_stats.total_fights)
	
	func get_overall_rating() -> int:
		var total = 0.0
		for attr_value in attributes.values():
			total += attr_value
		return int(total / attributes.size())
