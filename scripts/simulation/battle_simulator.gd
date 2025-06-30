extends RefCounted
class_name BattleSimulator

## Simple Battle Simulator for Auto-Battle System
## Simulates fights between MUGEN characters using stats

signal battle_started(fighter1: Dictionary, fighter2: Dictionary)
signal battle_round_complete(round_num: int, winner: String, details: Dictionary)
signal battle_complete(winner: Dictionary, loser: Dictionary, details: Dictionary)

# Battle configuration
var rounds_to_win: int = 2
var max_rounds: int = 5
var battle_speed: float = 1.0

# Battle state
var fighter1_data: Dictionary
var fighter2_data: Dictionary
var current_round: int = 0
var fighter1_rounds_won: int = 0
var fighter2_rounds_won: int = 0
var battle_log: Array[String] = []

func start_battle(fighter1: Dictionary, fighter2: Dictionary):
	"""Start a battle between two fighters"""
	fighter1_data = fighter1.duplicate(true)
	fighter2_data = fighter2.duplicate(true)
	
	# Reset battle state
	current_round = 0
	fighter1_rounds_won = 0
	fighter2_rounds_won = 0
	battle_log.clear()
	
	# Apply random stat variations
	_apply_battle_variations()
	
	print("⚔️ Battle Started: %s vs %s" % [fighter1_data.name, fighter2_data.name])
	battle_started.emit(fighter1_data, fighter2_data)
	
	_log_event("Battle begins: %s vs %s" % [fighter1_data.name, fighter2_data.name])

func simulate_next_round() -> Dictionary:
	"""Simulate the next round of battle"""
	if _is_battle_complete():
		return {}
	
	current_round += 1
	_log_event("Round %d begins!" % current_round)
	
	# Simulate round
	var round_result = _simulate_round()
	
	# Update round wins
	if round_result.winner == "fighter1":
		fighter1_rounds_won += 1
	else:
		fighter2_rounds_won += 1
	
	var round_details = {
		"round": current_round,
		"winner": round_result.winner,
		"winner_name": round_result.winner_name,
		"loser_name": round_result.loser_name,
		"damage_dealt": round_result.damage_dealt,
		"round_time": round_result.round_time,
		"finishing_move": round_result.finishing_move
	}
	
	battle_round_complete.emit(current_round, round_result.winner_name, round_details)
	_log_event("Round %d winner: %s" % [current_round, round_result.winner_name])
	
	# Check if battle is complete
	if _is_battle_complete():
		_complete_battle()
	
	return round_details

func _simulate_round() -> Dictionary:
	"""Simulate a single round"""
	var f1_stats = fighter1_data.stats
	var f2_stats = fighter2_data.stats
	
	# Calculate fighter capabilities
	var f1_power = f1_stats.power + f1_stats.technique
	var f2_power = f2_stats.power + f2_stats.technique
	var f1_defense = f1_stats.defense + f1_stats.speed
	var f2_defense = f2_stats.defense + f2_stats.speed
	
	# Add some randomness
	f1_power += randi_range(-20, 20)
	f2_power += randi_range(-20, 20)
	f1_defense += randi_range(-15, 15)
	f2_defense += randi_range(-15, 15)
	
	# Calculate net advantage
	var f1_advantage = f1_power - f2_defense
	var f2_advantage = f2_power - f1_defense
	
	# Determine winner based on advantage
	var winner_data: Dictionary
	var loser_data: Dictionary
	var winner_id: String
	
	if f1_advantage > f2_advantage:
		winner_data = fighter1_data
		loser_data = fighter2_data
		winner_id = "fighter1"
	else:
		winner_data = fighter2_data
		loser_data = fighter1_data
		winner_id = "fighter2"
	
	# Calculate round details
	var damage_dealt = abs(max(f1_advantage, f2_advantage))
	var round_time = randf_range(15.0, 45.0)  # 15-45 seconds
	var finishing_moves = ["combo", "special", "super", "throw", "counter"]
	var finishing_move = finishing_moves[randi() % finishing_moves.size()]
	
	return {
		"winner": winner_id,
		"winner_name": winner_data.name,
		"loser_name": loser_data.name,
		"damage_dealt": damage_dealt,
		"round_time": round_time,
		"finishing_move": finishing_move
	}

func _apply_battle_variations():
	"""Apply random variations to make battles more interesting"""
	# Apply stamina/condition modifiers
	var f1_condition = randf_range(0.85, 1.15)
	var f2_condition = randf_range(0.85, 1.15)
	
	# Modify stats based on condition
	for stat in fighter1_data.stats.keys():
		fighter1_data.stats[stat] = int(fighter1_data.stats[stat] * f1_condition)
		fighter2_data.stats[stat] = int(fighter2_data.stats[stat] * f2_condition)

func _is_battle_complete() -> bool:
	"""Check if battle is complete"""
	return fighter1_rounds_won >= rounds_to_win or fighter2_rounds_won >= rounds_to_win or current_round >= max_rounds

func _complete_battle():
	"""Complete the battle and emit results"""
	var winner_data: Dictionary
	var loser_data: Dictionary
	
	if fighter1_rounds_won > fighter2_rounds_won:
		winner_data = fighter1_data
		loser_data = fighter2_data
	else:
		winner_data = fighter2_data
		loser_data = fighter1_data
	
	var battle_details = {
		"total_rounds": current_round,
		"winner_rounds": max(fighter1_rounds_won, fighter2_rounds_won),
		"loser_rounds": min(fighter1_rounds_won, fighter2_rounds_won),
		"battle_log": battle_log.duplicate()
	}
	
	_log_event("Battle complete! Winner: %s (%d-%d)" % [
		winner_data.name, 
		max(fighter1_rounds_won, fighter2_rounds_won),
		min(fighter1_rounds_won, fighter2_rounds_won)
	])
	
	battle_complete.emit(winner_data, loser_data, battle_details)
	print("🏆 Battle Winner: %s" % winner_data.name)

func _log_event(event: String):
	"""Log a battle event"""
	battle_log.append(event)
	print("📝 Battle Log: %s" % event)

func get_battle_state() -> Dictionary:
	"""Get current battle state"""
	return {
		"current_round": current_round,
		"fighter1_rounds": fighter1_rounds_won,
		"fighter2_rounds": fighter2_rounds_won,
		"is_complete": _is_battle_complete(),
		"battle_log": battle_log.duplicate()
	}

func auto_simulate_battle() -> Dictionary:
	"""Automatically simulate the entire battle"""
	while not _is_battle_complete():
		simulate_next_round()
		# Add small delay for visual effect
		await Engine.get_main_loop().process_frame
	
	return get_battle_state()
