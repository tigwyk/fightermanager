extends Node
class_name EconomicsManager

## Economics Manager - Handles all financial aspects of the game
## Manages money, sponsorships, contracts, expenses, and economic progression

signal money_changed(old_amount: int, new_amount: int)
signal sponsorship_offered(sponsor_data: Dictionary)
signal sponsorship_signed(sponsor_id: String, contract_data: Dictionary)
signal expense_incurred(expense_type: String, amount: int, description: String)
signal income_received(income_type: String, amount: int, description: String)

enum ExpenseType {
	TRAINING,
	GYM_RENTAL,
	TRAVEL,
	EQUIPMENT,
	MEDICAL,
	MANAGEMENT_FEE,
	TOURNAMENT_ENTRY,
	MISCELLANEOUS
}

enum IncomeType {
	PRIZE_MONEY,
	SPONSORSHIP,
	EXHIBITION_MATCH,
	ENDORSEMENT,
	TRAINING_OTHERS,
	INVESTMENT_RETURN
}

enum SponsorshipTier {
	LOCAL_BUSINESS,
	REGIONAL_COMPANY,
	NATIONAL_BRAND,
	INTERNATIONAL_CORPORATION,
	EXCLUSIVE_PARTNERSHIP
}

# Financial state
var current_money: int = 1000  # Starting money
var total_earned: int = 0
var total_spent: int = 0
var monthly_expenses: int = 0
var monthly_income: int = 0

# Sponsorships and contracts
var active_sponsorships: Dictionary = {}  # sponsor_id -> SponsorshipContract
var available_sponsors: Array = []  # Array of SponsorData
var sponsorship_offers: Array = []  # Pending offers

# Financial tracking
var transaction_history: Array = []  # Array of transaction records
var monthly_reports: Array = []  # Array of monthly financial reports

# Economic settings
var base_living_expenses: int = 500  # Monthly living costs
var reputation_multiplier: float = 1.0  # Affects sponsorship values
var market_conditions: float = 1.0  # Economic boom/bust modifier

func _ready():
	print("Economics Manager initialized")
	_setup_initial_sponsors()
	
	# Monthly financial processing timer
	var timer = Timer.new()
	timer.wait_time = 2592000.0  # 30 days in seconds (for testing, use smaller values)
	timer.timeout.connect(_process_monthly_finances)
	timer.autostart = true
	add_child(timer)

# PUBLIC API - Money Management

func get_current_money() -> int:
	"""Get current money amount"""
	return current_money

func can_afford(amount: int) -> bool:
	"""Check if player can afford a purchase"""
	return current_money >= amount

func spend_money(amount: int, expense_type: ExpenseType, description: String = "") -> bool:
	"""Spend money if available"""
	if not can_afford(amount):
		print("Cannot afford expense: ", amount, " (Current: ", current_money, ")")
		return false
	
	var old_amount = current_money
	current_money -= amount
	total_spent += amount
	monthly_expenses += amount
	
	# Record transaction
	_record_transaction(false, amount, ExpenseType.keys()[expense_type], description)
	
	emit_signal("money_changed", old_amount, current_money)
	emit_signal("expense_incurred", ExpenseType.keys()[expense_type], amount, description)
	
	print("Spent: $", amount, " for ", description, " (Remaining: $", current_money, ")")
	return true

func earn_money(amount: int, income_type: IncomeType, description: String = "") -> void:
	"""Earn money from various sources"""
	var old_amount = current_money
	current_money += amount
	total_earned += amount
	monthly_income += amount
	
	# Record transaction
	_record_transaction(true, amount, IncomeType.keys()[income_type], description)
	
	emit_signal("money_changed", old_amount, current_money)
	emit_signal("income_received", IncomeType.keys()[income_type], amount, description)
	
	print("Earned: $", amount, " from ", description, " (Total: $", current_money, ")")

# SPONSORSHIP SYSTEM

func generate_sponsorship_offers(fighter_manager, _tournament_system):
	"""Generate new sponsorship offers based on fighter performance"""
	var fighters = fighter_manager.get_all_fighters()
	if fighters.is_empty():
		return
	
	# Get best fighter for sponsorship calculation
	var best_fighter = _get_highest_rated_fighter(fighters)
	var fighter_rating = fighter_manager.get_fighter_rating(best_fighter.fighter_id)
	
	# Calculate number of offers based on performance
	var offer_count = _calculate_sponsorship_offer_count(fighter_rating)
	
	for i in range(offer_count):
		var sponsor = _generate_random_sponsor(fighter_rating)
		var offer = _create_sponsorship_offer(sponsor, best_fighter)
		sponsorship_offers.append(offer)
		emit_signal("sponsorship_offered", offer)

func accept_sponsorship(offer_id: String) -> bool:
	"""Accept a sponsorship offer"""
	var offer_index = -1
	for i in range(sponsorship_offers.size()):
		if sponsorship_offers[i].offer_id == offer_id:
			offer_index = i
			break
	
	if offer_index == -1:
		print("Sponsorship offer not found: ", offer_id)
		return false
	
	var offer = sponsorship_offers[offer_index]
	
	# Check for conflicts with existing sponsorships
	if _has_sponsorship_conflict(offer):
		print("Sponsorship conflict detected")
		return false
	
	# Create contract
	var contract = SponsorshipContract.new()
	contract.sponsor_id = offer.sponsor.sponsor_id
	contract.sponsor_data = offer.sponsor
	contract.contract_type = offer.contract_type
	contract.monthly_payment = offer.monthly_payment
	contract.bonus_per_win = offer.bonus_per_win
	contract.duration_months = offer.duration_months
	contract.start_date = Time.get_unix_time_from_system()
	contract.end_date = contract.start_date + (offer.duration_months * 30 * 86400)
	contract.exclusivity_clause = offer.exclusivity_clause
	
	# Add to active sponsorships
	active_sponsorships[contract.sponsor_id] = contract
	
	# Remove offer from pending
	sponsorship_offers.remove_at(offer_index)
	
	# Pay signing bonus if any
	if offer.signing_bonus > 0:
		earn_money(offer.signing_bonus, IncomeType.SPONSORSHIP, "Signing bonus from " + offer.sponsor.name)
	
	emit_signal("sponsorship_signed", contract.sponsor_id, contract.to_dict())
	print("Sponsorship signed with: ", offer.sponsor.name)
	
	return true

func get_active_sponsorships() -> Array:
	"""Get all active sponsorship contracts"""
	return active_sponsorships.values()

func get_pending_offers() -> Array:
	"""Get all pending sponsorship offers"""
	return sponsorship_offers

func calculate_monthly_sponsorship_income() -> int:
	"""Calculate total monthly income from sponsorships"""
	var total = 0
	for contract in active_sponsorships.values():
		total += contract.monthly_payment
	return total

# EXPENSE MANAGEMENT

func calculate_training_cost(fighter_id: String, training_type: int, duration_hours: int, fighter_manager) -> int:
	"""Calculate the cost of training for a fighter"""
	var base_cost = 25  # Base cost per hour
	var type_multiplier = 1.0
	
	# Different training types have different costs
	match training_type:
		0, 1, 2, 3, 4:  # Basic attribute training
			type_multiplier = 1.0
		5:  # Mental training
			type_multiplier = 1.5
		6:  # Sparring
			type_multiplier = 2.0
		7:  # Combo practice
			type_multiplier = 1.3
	
	# Fighter level affects cost
	var fighter = fighter_manager.get_fighter(fighter_id)
	var level_multiplier = 1.0
	if fighter:
		level_multiplier = 1.0 + (fighter.level * 0.2)
	
	var total_cost = int(base_cost * duration_hours * type_multiplier * level_multiplier)
	return total_cost

func pay_training_cost(fighter_id: String, training_type: int, duration_hours: int, fighter_manager) -> bool:
	"""Pay for fighter training"""
	var cost = calculate_training_cost(fighter_id, training_type, duration_hours, fighter_manager)
	var fighter = fighter_manager.get_fighter(fighter_id)
	var description = "Training for " + (fighter.fighter_name if fighter else "Unknown Fighter")
	
	return spend_money(cost, ExpenseType.TRAINING, description)

func pay_tournament_entry(_tournament_id: String, fighter_id: String, entry_fee: int, fighter_manager) -> bool:
	"""Pay tournament entry fee"""
	var fighter = fighter_manager.get_fighter(fighter_id)
	var description = "Tournament entry for " + (fighter.fighter_name if fighter else "Unknown Fighter")
	
	return spend_money(entry_fee, ExpenseType.TOURNAMENT_ENTRY, description)

func pay_monthly_expenses() -> int:
	"""Pay monthly living and operational expenses"""
	var total_expenses = base_living_expenses
	
	# Add gym rental costs (if any)
	# Add equipment maintenance
	# Add other recurring costs
	
	if spend_money(total_expenses, ExpenseType.MISCELLANEOUS, "Monthly living expenses"):
		return total_expenses
	else:
		# Player is broke, handle consequences
		_handle_bankruptcy()
		return 0

# PRIZE MONEY AND REWARDS

func award_prize_money(fighter_id: String, amount: int, tournament_name: String, fighter_manager):
	"""Award prize money from tournament wins"""
	var fighter = fighter_manager.get_fighter(fighter_id)
	var description = "Prize money for " + (fighter.fighter_name if fighter else "Unknown Fighter") + " in " + tournament_name
	
	# Calculate manager's cut (usually 10-20%)
	var manager_cut = int(amount * 0.15)
	var fighter_earnings = amount - manager_cut
	
	earn_money(manager_cut, IncomeType.PRIZE_MONEY, description + " (Manager cut)")
	
	# Track fighter earnings separately if needed
	if fighter:
		if not fighter.career_stats.has("total_earnings"):
			fighter.career_stats.total_earnings = 0
		fighter.career_stats.total_earnings += fighter_earnings

func process_sponsorship_bonuses(fighter_id: String, won_fight: bool, fighter_manager):
	"""Process sponsorship bonuses for fight results"""
	for contract in active_sponsorships.values():
		if won_fight and contract.bonus_per_win > 0:
			var fighter = fighter_manager.get_fighter(fighter_id)
			var description = "Win bonus from " + contract.sponsor_data.name + " for " + (fighter.fighter_name if fighter else "Unknown Fighter")
			earn_money(contract.bonus_per_win, IncomeType.SPONSORSHIP, description)

# FINANCIAL REPORTING

func get_financial_summary() -> Dictionary:
	"""Get current financial summary"""
	return {
		"current_money": current_money,
		"total_earned": total_earned,
		"total_spent": total_spent,
		"monthly_income": monthly_income,
		"monthly_expenses": monthly_expenses,
		"net_worth": current_money,
		"sponsorship_income": calculate_monthly_sponsorship_income(),
		"active_sponsorships": active_sponsorships.size()
	}

func get_transaction_history(limit: int = 50) -> Array:
	"""Get recent transaction history"""
	var history = transaction_history.duplicate()
	if history.size() > limit:
		return history.slice(-limit)
	return history

# INTERNAL SYSTEMS

func _setup_initial_sponsors():
	"""Create initial pool of available sponsors"""
	available_sponsors = [
		_create_sponsor_data("Local Gym", SponsorshipTier.LOCAL_BUSINESS, 200, 50),
		_create_sponsor_data("Regional Sports Store", SponsorshipTier.REGIONAL_COMPANY, 500, 100),
		_create_sponsor_data("Martial Arts Equipment Co.", SponsorshipTier.REGIONAL_COMPANY, 800, 150),
		_create_sponsor_data("National Sports Drink", SponsorshipTier.NATIONAL_BRAND, 2000, 500),
		_create_sponsor_data("Athletic Wear Brand", SponsorshipTier.NATIONAL_BRAND, 1500, 300)
	]

func _process_monthly_finances():
	"""Process monthly financial obligations and income"""
	print("Processing monthly finances...")
	
	# Pay monthly sponsorship income
	var sponsorship_income = calculate_monthly_sponsorship_income()
	if sponsorship_income > 0:
		earn_money(sponsorship_income, IncomeType.SPONSORSHIP, "Monthly sponsorship payments")
	
	# Pay monthly expenses
	pay_monthly_expenses()
	
	# Generate monthly report
	_generate_monthly_report()
	
	# Reset monthly counters
	monthly_income = 0
	monthly_expenses = 0
	
	# Check for expired sponsorships
	_check_expired_sponsorships()

func _generate_monthly_report():
	"""Generate monthly financial report"""
	var report = {
		"date": Time.get_unix_time_from_system(),
		"starting_money": current_money - monthly_income + monthly_expenses,
		"income": monthly_income,
		"expenses": monthly_expenses,
		"ending_money": current_money,
		"net_change": monthly_income - monthly_expenses
	}
	
	monthly_reports.append(report)
	
	# Keep only last 12 months of reports
	if monthly_reports.size() > 12:
		monthly_reports.pop_front()

func _check_expired_sponsorships():
	"""Check for and remove expired sponsorships"""
	var current_time = Time.get_unix_time_from_system()
	var expired_sponsors = []
	
	for sponsor_id in active_sponsorships.keys():
		var contract = active_sponsorships[sponsor_id]
		if current_time >= contract.end_date:
			expired_sponsors.append(sponsor_id)
	
	for sponsor_id in expired_sponsors:
		print("Sponsorship expired: ", active_sponsorships[sponsor_id].sponsor_data.name)
		active_sponsorships.erase(sponsor_id)

func _record_transaction(is_income: bool, amount: int, type: String, description: String):
	"""Record a financial transaction"""
	var transaction = {
		"timestamp": Time.get_unix_time_from_system(),
		"is_income": is_income,
		"amount": amount,
		"type": type,
		"description": description,
		"balance_after": current_money
	}
	
	transaction_history.append(transaction)
	
	# Keep only last 500 transactions
	if transaction_history.size() > 500:
		transaction_history.pop_front()

func _get_highest_rated_fighter(fighters: Array):
	"""Get the fighter with the highest rating"""
	var best_fighter = null
	var highest_rating = -1
	
	for fighter in fighters:
		var rating = fighter.get_overall_rating()
		if rating > highest_rating:
			highest_rating = rating
			best_fighter = fighter
	
	return best_fighter

func _calculate_sponsorship_offer_count(fighter_rating: int) -> int:
	"""Calculate how many sponsorship offers to generate"""
	if fighter_rating < 30:
		return 0
	elif fighter_rating < 50:
		return 1
	elif fighter_rating < 70:
		return randi() % 2 + 1  # 1-2 offers
	else:
		return randi() % 3 + 2  # 2-4 offers

func _generate_random_sponsor(fighter_rating: int) -> Dictionary:
	"""Generate a random sponsor based on fighter rating"""
	var tier = SponsorshipTier.LOCAL_BUSINESS
	
	if fighter_rating > 80:
		tier = SponsorshipTier.INTERNATIONAL_CORPORATION
	elif fighter_rating > 65:
		tier = SponsorshipTier.NATIONAL_BRAND
	elif fighter_rating > 45:
		tier = SponsorshipTier.REGIONAL_COMPANY
	
	var base_payment = _get_base_payment_for_tier(tier)
	var bonus = _get_base_bonus_for_tier(tier)
	
	# Add some randomness
	base_payment = int(base_payment * randf_range(0.8, 1.3))
	bonus = int(bonus * randf_range(0.7, 1.5))
	
	return _create_sponsor_data(_generate_sponsor_name(tier), tier, base_payment, bonus)

func _create_sponsor_data(sponsor_name: String, tier: SponsorshipTier, monthly_payment: int, win_bonus: int) -> Dictionary:
	"""Create sponsor data structure"""
	return {
		"sponsor_id": _generate_sponsor_id(),
		"name": sponsor_name,
		"tier": tier,
		"monthly_payment": monthly_payment,
		"win_bonus": win_bonus,
		"reputation_requirement": _get_reputation_requirement_for_tier(tier),
		"exclusivity": tier >= SponsorshipTier.NATIONAL_BRAND
	}

func _create_sponsorship_offer(sponsor: Dictionary, fighter) -> Dictionary:
	"""Create a sponsorship offer"""
	var duration = randi_range(6, 24)  # 6-24 months
	var signing_bonus = sponsor.monthly_payment * randf_range(0.5, 2.0)
	
	return {
		"offer_id": _generate_offer_id(),
		"sponsor": sponsor,
		"fighter_id": fighter.fighter_id,
		"contract_type": "standard",
		"monthly_payment": sponsor.monthly_payment,
		"bonus_per_win": sponsor.win_bonus,
		"signing_bonus": int(signing_bonus),
		"duration_months": duration,
		"exclusivity_clause": sponsor.exclusivity,
		"offer_expires": Time.get_unix_time_from_system() + (7 * 86400)  # 1 week
	}

func _has_sponsorship_conflict(offer: Dictionary) -> bool:
	"""Check if sponsorship offer conflicts with existing contracts"""
	if not offer.exclusivity_clause:
		return false
	
	# Check for exclusive contracts in same category
	for contract in active_sponsorships.values():
		if contract.exclusivity_clause:
			return true  # Already have exclusive contract
	
	return false

func _get_base_payment_for_tier(tier: SponsorshipTier) -> int:
	"""Get base monthly payment for sponsorship tier"""
	match tier:
		SponsorshipTier.LOCAL_BUSINESS:
			return 200
		SponsorshipTier.REGIONAL_COMPANY:
			return 600
		SponsorshipTier.NATIONAL_BRAND:
			return 2000
		SponsorshipTier.INTERNATIONAL_CORPORATION:
			return 5000
		SponsorshipTier.EXCLUSIVE_PARTNERSHIP:
			return 10000
		_:
			return 100

func _get_base_bonus_for_tier(tier: SponsorshipTier) -> int:
	"""Get base win bonus for sponsorship tier"""
	match tier:
		SponsorshipTier.LOCAL_BUSINESS:
			return 50
		SponsorshipTier.REGIONAL_COMPANY:
			return 150
		SponsorshipTier.NATIONAL_BRAND:
			return 500
		SponsorshipTier.INTERNATIONAL_CORPORATION:
			return 1000
		SponsorshipTier.EXCLUSIVE_PARTNERSHIP:
			return 2000
		_:
			return 25

func _get_reputation_requirement_for_tier(tier: SponsorshipTier) -> int:
	"""Get reputation requirement for sponsorship tier"""
	match tier:
		SponsorshipTier.LOCAL_BUSINESS:
			return 0
		SponsorshipTier.REGIONAL_COMPANY:
			return 30
		SponsorshipTier.NATIONAL_BRAND:
			return 60
		SponsorshipTier.INTERNATIONAL_CORPORATION:
			return 80
		SponsorshipTier.EXCLUSIVE_PARTNERSHIP:
			return 95
		_:
			return 0

func _generate_sponsor_name(tier: SponsorshipTier) -> String:
	"""Generate a random sponsor name based on tier"""
	var prefixes = []
	var suffixes = []
	
	match tier:
		SponsorshipTier.LOCAL_BUSINESS:
			prefixes = ["Local", "Downtown", "City", "Neighborhood"]
			suffixes = ["Gym", "Dojo", "Fitness", "Sports"]
		SponsorshipTier.REGIONAL_COMPANY:
			prefixes = ["Regional", "State", "Metro", "Valley"]
			suffixes = ["Sports", "Athletics", "Equipment", "Gear"]
		SponsorshipTier.NATIONAL_BRAND:
			prefixes = ["National", "American", "Pro", "Elite"]
			suffixes = ["Sports", "Energy", "Nutrition", "Apparel"]
		SponsorshipTier.INTERNATIONAL_CORPORATION:
			prefixes = ["Global", "International", "World", "Universal"]
			suffixes = ["Corporation", "Industries", "Sports", "Group"]
		_:
			prefixes = ["Generic"]
			suffixes = ["Company"]
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + " " + suffix

func _handle_bankruptcy():
	"""Handle bankruptcy scenario"""
	print("WARNING: Insufficient funds for monthly expenses!")
	# TODO: Implement bankruptcy consequences
	# - Forced sale of assets
	# - Loss of sponsorships
	# - Credit system
	current_money = 0

func _generate_sponsor_id() -> String:
	"""Generate unique sponsor ID"""
	return "sponsor_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

func _generate_offer_id() -> String:
	"""Generate unique offer ID"""
	return "offer_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

# SponsorshipContract class definition
class SponsorshipContract:
	var sponsor_id: String
	var sponsor_data: Dictionary
	var contract_type: String
	var monthly_payment: int
	var bonus_per_win: int
	var duration_months: int
	var start_date: float
	var end_date: float
	var exclusivity_clause: bool
	
	func to_dict() -> Dictionary:
		return {
			"sponsor_id": sponsor_id,
			"sponsor_name": sponsor_data.name,
			"monthly_payment": monthly_payment,
			"bonus_per_win": bonus_per_win,
			"duration_months": duration_months,
			"start_date": start_date,
			"end_date": end_date,
			"exclusivity_clause": exclusivity_clause
		}
	
	func get_remaining_months() -> int:
		var current_time = Time.get_unix_time_from_system()
		var remaining_seconds = end_date - current_time
		return int(remaining_seconds / (30 * 86400))  # Convert to months
	
	func is_expired() -> bool:
		return Time.get_unix_time_from_system() >= end_date
