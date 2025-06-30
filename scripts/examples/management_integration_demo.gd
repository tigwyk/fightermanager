extends Node

## Management Systems Integration Example
## Demonstrates the complete management layer working together:
## Fighter Management + Tournament System + Economics Manager

func _ready():
	print("=== MANAGEMENT SYSTEMS INTEGRATION DEMO ===")
	print("This demonstration shows:")
	print("• Complete fighter career management")
	print("• Tournament registration and progression")
	print("• Economic simulation with sponsorships")
	print("• Training cost management")
	print("• Prize money distribution")
	print("• Sponsorship contracts and bonuses")
	print("")
	
	await get_tree().create_timer(2.0).timeout
	start_management_demo()

func start_management_demo():
	print("--- PHASE 1: Setting Up Management Systems ---")
	
	# Create the core management systems
	var fighter_manager = preload("res://scripts/management/fighter_manager.gd").new()
	fighter_manager.name = "FighterManager"
	add_child(fighter_manager)
	
	var tournament_system = preload("res://scripts/management/tournament_system.gd").new()
	tournament_system.name = "TournamentSystem"
	add_child(tournament_system)
	
	var economics_manager = preload("res://scripts/management/economics_manager.gd").new()
	economics_manager.name = "EconomicsManager"
	add_child(economics_manager)
	
	print("✓ Fighter Manager created")
	print("✓ Tournament System created")
	print("✓ Economics Manager created")
	
	# Connect signals for integration
	fighter_manager.fighter_training_complete.connect(_on_training_complete)
	tournament_system.tournament_completed.connect(_on_tournament_completed)
	economics_manager.sponsorship_signed.connect(_on_sponsorship_signed)
	economics_manager.money_changed.connect(_on_money_changed)
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 2: Creating and Managing Fighters ---")
	
	# Create some fighters
	var fighter_a_id = fighter_manager.create_fighter("Alex Thunder")
	var fighter_b_id = fighter_manager.create_fighter("Maya Storm")
	var _fighter_c_id = fighter_manager.create_fighter("Rico Blaze")
	
	print("Created 3 fighters:")
	for fighter in fighter_manager.get_all_fighters():
		print("  • ", fighter.fighter_name, " (Level: ", fighter.get_level_name(), ")")
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 3: Economic Management ---")
	
	print("Starting money: $", economics_manager.get_current_money())
	
	# Demonstrate training costs
	print("\nTraining Economics:")
	var training_cost = economics_manager.calculate_training_cost(fighter_a_id, 0, 4, fighter_manager)
	print("  Training cost for ", fighter_manager.get_fighter(fighter_a_id).fighter_name, ": $", training_cost)
	
	if economics_manager.can_afford(training_cost):
		print("  ✓ Can afford training")
		if economics_manager.pay_training_cost(fighter_a_id, 0, 4, fighter_manager):
			fighter_manager.start_training(fighter_a_id, fighter_manager.TrainingType.STRENGTH, 4)
			print("  ✓ Training started and paid for")
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 4: Tournament Management ---")
	
	# Create a tournament
	var tournament_id = tournament_system.create_tournament(
		"Local Championship",
		tournament_system.TournamentType.SINGLE_ELIMINATION,
		tournament_system.TournamentTier.LOCAL,
		8,  # max participants
		50  # entry fee
	)
	
	print("Tournament created: ", tournament_system.get_tournament(tournament_id).name)
	
	# Register fighters
	print("Registering fighters...")
	for fighter in fighter_manager.get_all_fighters():
		if economics_manager.can_afford(50):  # Entry fee
			if economics_manager.pay_tournament_entry(tournament_id, fighter.fighter_id, 50, fighter_manager):
				if tournament_system.register_fighter(tournament_id, fighter.fighter_id):
					print("  ✓ ", fighter.fighter_name, " registered and entry fee paid")
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 5: Sponsorship System ---")
	
	# Generate sponsorship offers
	economics_manager.generate_sponsorship_offers(fighter_manager, tournament_system)
	
	var offers = economics_manager.get_pending_offers()
	print("Generated ", offers.size(), " sponsorship offers:")
	
	for offer in offers:
		print("  • ", offer.sponsor.name)
		print("    Monthly: $", offer.monthly_payment, " Win Bonus: $", offer.bonus_per_win)
		print("    Duration: ", offer.duration_months, " months")
	
	# Accept the first offer if available
	if offers.size() > 0:
		var best_offer = offers[0]
		if economics_manager.accept_sponsorship(best_offer.offer_id):
			print("  ✓ Accepted sponsorship from: ", best_offer.sponsor.name)
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 6: Tournament Simulation ---")
	
	# Start the tournament
	if tournament_system.start_tournament(tournament_id):
		print("Tournament started!")
		
		# Simulate some matches
		var matches = tournament_system.get_next_matches(tournament_id)
		print("Simulating ", matches.size(), " matches...")
		
		for match_data in matches:
			print("  Match: ", 
				fighter_manager.get_fighter(match_data.fighter_a_id).fighter_name, 
				" vs ", 
				fighter_manager.get_fighter(match_data.fighter_b_id).fighter_name)
			
			var result = tournament_system.simulate_match(tournament_id, match_data.match_id, fighter_manager)
			var winner_name = ""
			if result.winner == "fighter_a":
				winner_name = fighter_manager.get_fighter(match_data.fighter_a_id).fighter_name
			else:
				winner_name = fighter_manager.get_fighter(match_data.fighter_b_id).fighter_name
			
			print("    Winner: ", winner_name, " (KO: ", result.ko, ")")
			
			# Process sponsorship bonuses
			if result.winner == "fighter_a":
				economics_manager.process_sponsorship_bonuses(match_data.fighter_a_id, true, fighter_manager)
			else:
				economics_manager.process_sponsorship_bonuses(match_data.fighter_b_id, true, fighter_manager)
	
	await get_tree().create_timer(2.0).timeout
	
	print("\n--- PHASE 7: Career Progression ---")
	
	# Show fighter development
	print("Fighter Development:")
	for fighter in fighter_manager.get_all_fighters():
		var rating = fighter_manager.get_fighter_rating(fighter.fighter_id)
		print("  ", fighter.fighter_name, ":")
		print("    Level: ", fighter.get_level_name(), " | Rating: ", rating)
		print("    Record: ", fighter.career_stats.wins, "-", fighter.career_stats.losses)
		print("    Experience: ", fighter.experience)
		print("    Condition: Health ", int(fighter.condition.health), " | Motivation ", int(fighter.condition.motivation))
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 8: Financial Summary ---")
	
	var financial_summary = economics_manager.get_financial_summary()
	print("Financial Summary:")
	print("  Current Money: $", financial_summary.current_money)
	print("  Total Earned: $", financial_summary.total_earned)
	print("  Total Spent: $", financial_summary.total_spent)
	print("  Monthly Sponsorship Income: $", financial_summary.sponsorship_income)
	print("  Active Sponsorships: ", financial_summary.active_sponsorships)
	
	var transaction_history = economics_manager.get_transaction_history(10)
	print("\nRecent Transactions:")
	for transaction in transaction_history:
		var type_str = "+" if transaction.is_income else "-"
		print("  ", type_str, "$", transaction.amount, " - ", transaction.description)
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n--- PHASE 9: Advanced Management Features ---")
	
	# Demonstrate training queue and progression
	print("Training Queue Management:")
	var available_fighters = []
	for fighter in fighter_manager.get_all_fighters():
		if not fighter_manager.is_fighter_training(fighter.fighter_id):
			available_fighters.append(fighter)
	
	if available_fighters.size() > 0:
		var fighter = available_fighters[0]
		print("  Starting advanced training for: ", fighter.fighter_name)
		
		# Try different training types if we can afford them
		var training_types = [
			{"type": 1, "name": "Speed Training"},
			{"type": 2, "name": "Technique Training"},
			{"type": 6, "name": "Sparring Session"}
		]
		
		for training in training_types:
			var cost = economics_manager.calculate_training_cost(fighter.fighter_id, training.type, 4, fighter_manager)
			if economics_manager.can_afford(cost):
				print("    ", training.name, " - Cost: $", cost)
			else:
				print("    ", training.name, " - Too expensive ($", cost, ")")
	
	# Show tournament opportunities
	print("\nAvailable Tournaments:")
	var available_tournaments = tournament_system.get_available_tournaments()
	for tournament_data in available_tournaments:
		print("  • ", tournament_data.name, " (", tournament_data.get_tier_name(), ")")
		print("    Entry Fee: $", tournament_data.entry_fee)
		print("    Participants: ", tournament_data.participants.size(), "/", tournament_data.max_participants)
	
	await get_tree().create_timer(1.0).timeout
	
	_show_management_summary()

func _show_management_summary():
	"""Display the final management systems summary"""
	print("\n" + "=".repeat(70))
	print("🏆 MANAGEMENT SYSTEMS INTEGRATION COMPLETE! 🏆")
	print("=".repeat(70))
	print("")
	print("✅ SUCCESSFULLY INTEGRATED MANAGEMENT SYSTEMS:")
	print("   👤 Fighter Management - Complete career progression system")
	print("   🏟️  Tournament System - Tournament creation, brackets, and simulation")
	print("   💰 Economics Manager - Financial simulation with sponsorships")
	print("   🎯 Training System - Cost-based training with attribute progression")
	print("   🏆 Prize Distribution - Tournament winnings and sponsorship bonuses")
	print("   📊 Financial Tracking - Complete transaction history and reporting")
	print("")
	print("🔧 MANAGEMENT FEATURES DEMONSTRATED:")
	print("   • Fighter creation and attribute management")
	print("   • Training cost calculation and payment processing")
	print("   • Tournament registration with entry fee handling")
	print("   • Sponsorship offer generation and contract management")
	print("   • Tournament simulation with prize money distribution")
	print("   • Career progression tracking and experience systems")
	print("   • Economic balance with income, expenses, and cash flow")
	print("   • Multi-fighter management with scheduling and planning")
	print("")
	print("🚀 READY FOR NEXT PHASE:")
	print("   • Advanced UI development for management screens")
	print("   • Save/load system for persistent career progression")
	print("   • Relationship systems (rivals, mentors, fans)")
	print("   • Injury system and recovery mechanics")
	print("   • Regional circuits and international competition")
	print("   • Gym ownership and facility management")
	print("")
	print("The complete Management Layer is now operational and ready")
	print("for integration with the UI layer and advanced features!")
	print("=".repeat(70))

# Event handlers for monitoring integration

func _on_training_complete(fighter_id: String, training_type: String, results: Dictionary):
	print("🎯 Training Complete: ", training_type, " for fighter ", fighter_id)
	print("    Benefits: ", results.attributes.keys() if results.has("attributes") else "No attribute benefits")

func _on_tournament_completed(_tournament_id: String, winner_id: String):
	print("🏆 Tournament Complete: Winner is ", winner_id)

func _on_sponsorship_signed(_sponsor_id: String, contract_data: Dictionary):
	print("🤝 Sponsorship Signed: ", contract_data.sponsor_name)
	print("    Monthly Payment: $", contract_data.monthly_payment)

func _on_money_changed(old_amount: int, new_amount: int):
	var change = new_amount - old_amount
	var type_str = "Earned" if change > 0 else "Spent"
	print("💰 ", type_str, ": $", abs(change), " (Balance: $", new_amount, ")")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("\nManagement systems demonstration ended by user")
		get_tree().quit()
