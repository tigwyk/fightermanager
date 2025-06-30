extends Node
class_name TournamentSystem

## Tournament System - Manages tournament creation, brackets, and progression
## Handles different tournament types, scheduling, and rewards

signal tournament_created(tournament_id: String, tournament_data: Dictionary)
signal tournament_started(tournament_id: String)
signal match_scheduled(tournament_id: String, match_data: Dictionary)
signal match_completed(tournament_id: String, match_id: String, result: Dictionary)
signal tournament_completed(tournament_id: String, winner_id: String)
signal fighter_registered(tournament_id: String, fighter_id: String)

enum TournamentType {
	SINGLE_ELIMINATION,
	DOUBLE_ELIMINATION,
	ROUND_ROBIN,
	LEAGUE,
	KING_OF_THE_HILL
}

enum TournamentTier {
	LOCAL,
	REGIONAL,
	NATIONAL,
	INTERNATIONAL,
	EXHIBITION
}

enum MatchStatus {
	SCHEDULED,
	IN_PROGRESS,
	COMPLETED,
	CANCELLED
}

# Active tournaments
var active_tournaments: Dictionary = {}  # tournament_id -> TournamentData
var completed_tournaments: Array = []
var scheduled_matches: Array = []  # Array of match data

# Tournament settings
var registration_duration_days: int = 7
var default_entry_fee: int = 50
var prize_pool_multiplier: float = 8.0  # Total prizes = entry_fees * multiplier

# Tournament templates and configurations
var tournament_templates: Dictionary = {}

func _ready():
	print("Tournament System initialized")
	_setup_tournament_templates()
	
	# Daily tournament processing timer
	var timer = Timer.new()
	timer.wait_time = 86400.0  # Process daily
	timer.timeout.connect(_process_daily_updates)
	timer.autostart = true
	add_child(timer)

# PUBLIC API - Tournament Management

func create_tournament(
	tournament_name: String, 
	type: TournamentType, 
	tier: TournamentTier,
	max_participants: int = 16,
	entry_fee: int = -1,
	start_date: float = -1
) -> String:
	"""Create a new tournament"""
	
	var tournament_id = _generate_tournament_id()
	var tournament_data = TournamentData.new()
	
	# Basic tournament info
	tournament_data.tournament_id = tournament_id
	tournament_data.name = tournament_name
	tournament_data.type = type
	tournament_data.tier = tier
	tournament_data.max_participants = max_participants
	tournament_data.entry_fee = entry_fee if entry_fee > 0 else _calculate_default_entry_fee(tier)
	tournament_data.creation_date = Time.get_unix_time_from_system()
	
	# Schedule tournament
	if start_date > 0:
		tournament_data.start_date = start_date
	else:
		tournament_data.start_date = tournament_data.creation_date + (registration_duration_days * 86400)
	
	tournament_data.registration_deadline = tournament_data.start_date - 86400  # 1 day before start
	
	# Initialize tournament structure
	tournament_data.participants = []
	tournament_data.bracket = {}
	tournament_data.matches = {}
	tournament_data.current_round = 0
	tournament_data.status = "registration"
	
	# Calculate prize pool
	_calculate_prize_structure(tournament_data)
	
	active_tournaments[tournament_id] = tournament_data
	emit_signal("tournament_created", tournament_id, tournament_data.to_dict())
	
	print("Tournament created: ", tournament_name, " (ID: ", tournament_id, ")")
	return tournament_id

func register_fighter(tournament_id: String, fighter_id: String) -> bool:
	"""Register a fighter for a tournament"""
	var tournament = active_tournaments.get(tournament_id)
	if not tournament:
		print("Error: Tournament not found: ", tournament_id)
		return false
	
	# Check registration conditions
	if not _can_register_fighter(tournament, fighter_id):
		return false
	
	# Add fighter to tournament
	tournament.participants.append(fighter_id)
	tournament.entry_pool += tournament.entry_fee
	
	# Recalculate prize pool with actual participants
	_calculate_prize_structure(tournament)
	
	emit_signal("fighter_registered", tournament_id, fighter_id)
	print("Fighter registered for tournament: ", tournament.name)
	
	# Check if tournament is ready to start
	_check_tournament_ready(tournament)
	
	return true

func get_tournament(tournament_id: String) -> TournamentData:
	"""Get tournament data by ID"""
	return active_tournaments.get(tournament_id)

func get_available_tournaments() -> Array:
	"""Get all tournaments currently accepting registrations"""
	var available = []
	var current_time = Time.get_unix_time_from_system()
	
	for tournament in active_tournaments.values():
		if tournament.status == "registration" and current_time < tournament.registration_deadline:
			available.append(tournament)
	
	return available

func get_upcoming_tournaments() -> Array:
	"""Get tournaments that are scheduled to start soon"""
	var upcoming = []
	var current_time = Time.get_unix_time_from_system()
	
	for tournament in active_tournaments.values():
		if tournament.start_date > current_time and tournament.start_date < current_time + (7 * 86400):
			upcoming.append(tournament)
	
	return upcoming

func start_tournament(tournament_id: String) -> bool:
	"""Manually start a tournament (if conditions are met)"""
	var tournament = active_tournaments.get(tournament_id)
	if not tournament:
		return false
	
	if tournament.status != "registration":
		print("Tournament not in registration phase: ", tournament.name)
		return false
	
	if tournament.participants.size() < 2:
		print("Not enough participants to start tournament: ", tournament.name)
		return false
	
	_start_tournament_internal(tournament)
	return true

# MATCH MANAGEMENT

func simulate_match(tournament_id: String, match_id: String, fighter_manager) -> Dictionary:
	"""Simulate a tournament match"""
	var tournament = active_tournaments.get(tournament_id)
	if not tournament:
		return {}
	
	var match_data = tournament.matches.get(match_id)
	if not match_data:
		return {}
	
	# Get fighter data
	var fighter_a = fighter_manager.get_fighter(match_data.fighter_a_id)
	var fighter_b = fighter_manager.get_fighter(match_data.fighter_b_id)
	
	if not fighter_a or not fighter_b:
		print("Error: Could not find fighters for match")
		return {}
	
	# Simulate the fight
	var result = _simulate_fight(fighter_a, fighter_b)
	
	# Update match status
	match_data.status = MatchStatus.COMPLETED
	match_data.result = result
	match_data.completion_date = Time.get_unix_time_from_system()
	
	# Record fight results for both fighters
	fighter_manager.record_fight_result(
		match_data.fighter_a_id, 
		result.winner == "fighter_a",
		result.ko,
		0  # Tournament prize money distributed at end
	)
	
	fighter_manager.record_fight_result(
		match_data.fighter_b_id, 
		result.winner == "fighter_b",
		result.ko,
		0
	)
	
	emit_signal("match_completed", tournament_id, match_id, result)
	
	# Check if round is complete
	_check_round_completion(tournament)
	
	return result

func get_tournament_bracket(tournament_id: String) -> Dictionary:
	"""Get the bracket structure for a tournament"""
	var tournament = active_tournaments.get(tournament_id)
	if not tournament:
		return {}
	
	return tournament.bracket

func get_next_matches(tournament_id: String) -> Array:
	"""Get the next matches to be played in a tournament"""
	var tournament = active_tournaments.get(tournament_id)
	if not tournament:
		return []
	
	var next_matches = []
	for match in tournament.matches.values():
		if match.status == MatchStatus.SCHEDULED:
			next_matches.append(match)
	
	return next_matches

# INTERNAL SYSTEMS

func _setup_tournament_templates():
	"""Set up predefined tournament templates"""
	tournament_templates = {
		"local_weekly": {
			"name": "Weekly Local Tournament",
			"type": TournamentType.SINGLE_ELIMINATION,
			"tier": TournamentTier.LOCAL,
			"max_participants": 8,
			"entry_fee": 25
		},
		"regional_monthly": {
			"name": "Regional Monthly Championship",
			"type": TournamentType.DOUBLE_ELIMINATION,
			"tier": TournamentTier.REGIONAL,
			"max_participants": 16,
			"entry_fee": 100
		},
		"national_quarterly": {
			"name": "National Quarterly Series",
			"type": TournamentType.SINGLE_ELIMINATION,
			"tier": TournamentTier.NATIONAL,
			"max_participants": 32,
			"entry_fee": 500
		}
	}

func _process_daily_updates():
	"""Process daily tournament updates"""
	var current_time = Time.get_unix_time_from_system()
	
	# Check for tournaments ready to start
	for tournament in active_tournaments.values():
		if tournament.status == "registration" and current_time >= tournament.start_date:
			if tournament.participants.size() >= 2:
				_start_tournament_internal(tournament)
			else:
				_cancel_tournament(tournament, "Insufficient participants")

func _start_tournament_internal(tournament: TournamentData):
	"""Internal tournament start logic"""
	tournament.status = "active"
	tournament.current_round = 1
	
	# Generate bracket and initial matches
	_generate_bracket(tournament)
	_schedule_round_matches(tournament)
	
	emit_signal("tournament_started", tournament.tournament_id)
	print("Tournament started: ", tournament.name)

func _generate_bracket(tournament: TournamentData):
	"""Generate tournament bracket based on type"""
	match tournament.type:
		TournamentType.SINGLE_ELIMINATION:
			_generate_single_elimination_bracket(tournament)
		TournamentType.DOUBLE_ELIMINATION:
			_generate_double_elimination_bracket(tournament)
		TournamentType.ROUND_ROBIN:
			_generate_round_robin_bracket(tournament)
		_:
			print("Unsupported tournament type")

func _generate_single_elimination_bracket(tournament: TournamentData):
	"""Generate single elimination bracket"""
	var participants = tournament.participants.duplicate()
	participants.shuffle()  # Randomize seeding
	
	# Calculate number of rounds needed
	var num_participants = participants.size()
	var num_rounds = int(ceil(log(num_participants) / log(2)))
	tournament.total_rounds = num_rounds
	
	# Initialize bracket structure
	tournament.bracket = {
		"type": "single_elimination",
		"rounds": []
	}
	
	# Create first round matches
	var round_matches = []
	for i in range(0, num_participants, 2):
		if i + 1 < num_participants:
			var match_id = _generate_match_id(tournament.tournament_id, 1, i / 2)
			var match_data = {
				"match_id": match_id,
				"round": 1,
				"fighter_a_id": participants[i],
				"fighter_b_id": participants[i + 1],
				"status": MatchStatus.SCHEDULED,
				"winner_advances_to": null  # Will be set when creating next round
			}
			tournament.matches[match_id] = match_data
			round_matches.append(match_id)
	
	tournament.bracket.rounds.append(round_matches)

func _generate_double_elimination_bracket(tournament: TournamentData):
	"""Generate double elimination bracket (simplified version)"""
	# For now, implement as single elimination
	# TODO: Implement full double elimination with winner's and loser's brackets
	_generate_single_elimination_bracket(tournament)

func _generate_round_robin_bracket(tournament: TournamentData):
	"""Generate round robin bracket where everyone fights everyone"""
	var participants = tournament.participants
	var matches = []
	
	# Create matches for every pair
	for i in range(participants.size()):
		for j in range(i + 1, participants.size()):
			var match_id = _generate_match_id(tournament.tournament_id, 1, matches.size())
			var match_data = {
				"match_id": match_id,
				"round": 1,
				"fighter_a_id": participants[i],
				"fighter_b_id": participants[j],
				"status": MatchStatus.SCHEDULED
			}
			tournament.matches[match_id] = match_data
			matches.append(match_id)
	
	tournament.bracket = {
		"type": "round_robin",
		"rounds": [matches]
	}
	tournament.total_rounds = 1

func _schedule_round_matches(tournament: TournamentData):
	"""Schedule matches for the current round"""
	if tournament.current_round > tournament.bracket.rounds.size():
		return
	
	var round_matches = tournament.bracket.rounds[tournament.current_round - 1]
	for match_id in round_matches:
		var match = tournament.matches[match_id]
		emit_signal("match_scheduled", tournament.tournament_id, match)

func _check_round_completion(tournament: TournamentData):
	"""Check if the current round is complete and advance if needed"""
	if tournament.current_round > tournament.bracket.rounds.size():
		return
	
	var round_matches = tournament.bracket.rounds[tournament.current_round - 1]
	var all_complete = true
	
	for match_id in round_matches:
		var match = tournament.matches[match_id]
		if match.status != MatchStatus.COMPLETED:
			all_complete = false
			break
	
	if all_complete:
		_advance_tournament_round(tournament)

func _advance_tournament_round(tournament: TournamentData):
	"""Advance tournament to next round or complete it"""
	tournament.current_round += 1
	
	# Check if tournament is complete
	if tournament.type == TournamentType.ROUND_ROBIN:
		_complete_tournament(tournament)
		return
	
	# For elimination tournaments, check if we need another round
	if tournament.current_round > tournament.total_rounds:
		_complete_tournament(tournament)
		return
	
	# Create next round matches for elimination tournaments
	if tournament.type == TournamentType.SINGLE_ELIMINATION:
		_create_next_elimination_round(tournament)

func _create_next_elimination_round(tournament: TournamentData):
	"""Create matches for the next elimination round"""
	var previous_round = tournament.bracket.rounds[tournament.current_round - 2]
	var winners = []
	
	# Get winners from previous round
	for match_id in previous_round:
		var match = tournament.matches[match_id]
		if match.result:
			var winner_id = ""
			if match.result.winner == "fighter_a":
				winner_id = match.fighter_a_id
			else:
				winner_id = match.fighter_b_id
			winners.append(winner_id)
	
	# Create new round matches
	var new_round_matches = []
	for i in range(0, winners.size(), 2):
		if i + 1 < winners.size():
			var match_id = _generate_match_id(tournament.tournament_id, tournament.current_round, i / 2)
			var match_data = {
				"match_id": match_id,
				"round": tournament.current_round,
				"fighter_a_id": winners[i],
				"fighter_b_id": winners[i + 1],
				"status": MatchStatus.SCHEDULED
			}
			tournament.matches[match_id] = match_data
			new_round_matches.append(match_id)
	
	tournament.bracket.rounds.append(new_round_matches)
	_schedule_round_matches(tournament)

func _complete_tournament(tournament: TournamentData):
	"""Complete a tournament and distribute prizes"""
	tournament.status = "completed"
	tournament.completion_date = Time.get_unix_time_from_system()
	
	# Determine winner
	var winner_id = _determine_tournament_winner(tournament)
	tournament.winner_id = winner_id
	
	# Distribute prize money
	_distribute_prizes(tournament)
	
	# Move to completed tournaments
	completed_tournaments.append(tournament)
	active_tournaments.erase(tournament.tournament_id)
	
	emit_signal("tournament_completed", tournament.tournament_id, winner_id)
	print("Tournament completed: ", tournament.name, " Winner: ", winner_id)

func _determine_tournament_winner(tournament: TournamentData) -> String:
	"""Determine the winner of a completed tournament"""
	if tournament.type == TournamentType.ROUND_ROBIN:
		return _determine_round_robin_winner(tournament)
	else:
		# For elimination tournaments, winner is the winner of the final match
		var final_round = tournament.bracket.rounds[-1]
		if final_round.size() > 0:
			var final_match = tournament.matches[final_round[0]]
			if final_match.result:
				if final_match.result.winner == "fighter_a":
					return final_match.fighter_a_id
				else:
					return final_match.fighter_b_id
	
	return ""

func _determine_round_robin_winner(tournament: TournamentData) -> String:
	"""Determine winner of round robin tournament based on wins"""
	var win_counts = {}
	
	# Initialize win counts
	for participant in tournament.participants:
		win_counts[participant] = 0
	
	# Count wins for each fighter
	for match_data in tournament.matches.values():
		if match_data.result:
			var match_winner_id = ""
			if match_data.result.winner == "fighter_a":
				match_winner_id = match_data.fighter_a_id
			else:
				match_winner_id = match_data.fighter_b_id
			
			win_counts[match_winner_id] += 1
	
	# Find fighter with most wins
	var max_wins = -1
	var winner_id = ""
	for fighter_id in win_counts.keys():
		if win_counts[fighter_id] > max_wins:
			max_wins = win_counts[fighter_id]
			winner_id = fighter_id
	
	return winner_id

func _distribute_prizes(tournament: TournamentData):
	"""Distribute prize money to tournament participants"""
	# For now, winner takes all
	# TODO: Implement more sophisticated prize distribution
	if tournament.winner_id:
		var total_prize = tournament.entry_pool * prize_pool_multiplier
		# Prize distribution logic would go here
		print("Prize distributed: ", total_prize, " to ", tournament.winner_id)

func _simulate_fight(fighter_a, fighter_b) -> Dictionary:
	"""Simulate a fight between two fighters"""
	# Simple simulation based on fighter ratings and condition
	var rating_a = _calculate_fight_rating(fighter_a)
	var rating_b = _calculate_fight_rating(fighter_b)
	
	# Add some randomness
	var random_factor = randf_range(0.8, 1.2)
	rating_a *= random_factor
	rating_b *= (2.0 - random_factor)  # Inverse correlation
	
	# Determine winner
	var winner = "fighter_a" if rating_a > rating_b else "fighter_b"
	var margin = abs(rating_a - rating_b)
	
	# Determine if it's a KO (higher margin = more likely KO)
	var ko_chance = clamp(margin / 50.0, 0.1, 0.7)
	var ko = randf() < ko_chance
	
	return {
		"winner": winner,
		"ko": ko,
		"rating_a": rating_a,
		"rating_b": rating_b,
		"margin": margin
	}

func _calculate_fight_rating(fighter) -> float:
	"""Calculate a fighter's rating for this specific fight"""
	var base_rating = fighter.get_overall_rating()
	
	# Apply condition modifiers
	var health_mod = fighter.condition.health / 100.0
	var motivation_mod = fighter.condition.motivation / 100.0
	var fatigue_mod = (100.0 - fighter.condition.fatigue) / 100.0
	var confidence_mod = fighter.condition.confidence / 100.0
	
	var condition_modifier = (health_mod + motivation_mod + fatigue_mod + confidence_mod) / 4.0
	
	return base_rating * condition_modifier

func _can_register_fighter(tournament: TournamentData, fighter_id: String) -> bool:
	"""Check if a fighter can be registered for a tournament"""
	# Check registration period
	var current_time = Time.get_unix_time_from_system()
	if current_time > tournament.registration_deadline:
		print("Registration deadline passed")
		return false
	
	# Check if tournament is full
	if tournament.participants.size() >= tournament.max_participants:
		print("Tournament is full")
		return false
	
	# Check if fighter is already registered
	if fighter_id in tournament.participants:
		print("Fighter already registered")
		return false
	
	# Check if fighter meets requirements (level, rating, etc.)
	# TODO: Add more sophisticated requirements checking
	
	return true

func _check_tournament_ready(tournament: TournamentData):
	"""Check if tournament is ready to start automatically"""
	if tournament.participants.size() >= tournament.max_participants:
		# Tournament is full, can start early
		_start_tournament_internal(tournament)

func _cancel_tournament(tournament: TournamentData, reason: String):
	"""Cancel a tournament"""
	tournament.status = "cancelled"
	print("Tournament cancelled: ", tournament.name, " Reason: ", reason)
	# TODO: Refund entry fees

func _calculate_default_entry_fee(tier: TournamentTier) -> int:
	"""Calculate default entry fee based on tournament tier"""
	match tier:
		TournamentTier.LOCAL:
			return 25
		TournamentTier.REGIONAL:
			return 100
		TournamentTier.NATIONAL:
			return 500
		TournamentTier.INTERNATIONAL:
			return 2000
		TournamentTier.EXHIBITION:
			return 0
		_:
			return default_entry_fee

func _calculate_prize_structure(tournament: TournamentData):
	"""Calculate prize structure based on entry pool"""
	tournament.prize_pool = int(tournament.entry_pool * prize_pool_multiplier)

func _generate_tournament_id() -> String:
	"""Generate unique tournament ID"""
	return "tournament_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

func _generate_match_id(tournament_id: String, round_num: int, match_num: int) -> String:
	"""Generate unique match ID"""
	return tournament_id + "_r" + str(round_num) + "_m" + str(match_num)

# TournamentData class definition
class TournamentData:
	var tournament_id: String
	var name: String
	var type: int  # TournamentType
	var tier: int  # TournamentTier
	var max_participants: int
	var entry_fee: int
	var entry_pool: int = 0
	var prize_pool: int = 0
	
	var creation_date: float
	var start_date: float
	var registration_deadline: float
	var completion_date: float = 0
	
	var participants: Array = []
	var bracket: Dictionary = {}
	var matches: Dictionary = {}
	var current_round: int = 0
	var total_rounds: int = 0
	var status: String = "registration"  # registration, active, completed, cancelled
	var winner_id: String = ""
	
	func to_dict() -> Dictionary:
		return {
			"tournament_id": tournament_id,
			"name": name,
			"type": type,
			"tier": tier,
			"max_participants": max_participants,
			"entry_fee": entry_fee,
			"participants": participants.size(),
			"status": status,
			"current_round": current_round,
			"total_rounds": total_rounds
		}
	
	func get_type_name() -> String:
		match type:
			TournamentSystem.TournamentType.SINGLE_ELIMINATION:
				return "Single Elimination"
			TournamentSystem.TournamentType.DOUBLE_ELIMINATION:
				return "Double Elimination"
			TournamentSystem.TournamentType.ROUND_ROBIN:
				return "Round Robin"
			TournamentSystem.TournamentType.LEAGUE:
				return "League"
			TournamentSystem.TournamentType.KING_OF_THE_HILL:
				return "King of the Hill"
			_:
				return "Unknown"
	
	func get_tier_name() -> String:
		match tier:
			TournamentSystem.TournamentTier.LOCAL:
				return "Local"
			TournamentSystem.TournamentTier.REGIONAL:
				return "Regional"
			TournamentSystem.TournamentTier.NATIONAL:
				return "National"
			TournamentSystem.TournamentTier.INTERNATIONAL:
				return "International"
			TournamentSystem.TournamentTier.EXHIBITION:
				return "Exhibition"
			_:
				return "Unknown"
