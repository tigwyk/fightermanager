extends Node
class_name BattleEngine

## Advanced MUGEN-style Battle Engine (Godot 4)
## Manages two Character nodes with proper hitbox collision and damage
## Integrated with MugenCharacterData system

signal round_start
signal round_end(winner)
signal hit_landed(attacker, defender, damage)
signal character_data_updated(character_a_data, character_b_data)

var character_a: Character
var character_b: Character
var character_a_data # MugenCharacterData
var character_b_data # MugenCharacterData
var health_a: int = 1000
var health_b: int = 1000
var max_health_a: int = 1000
var max_health_b: int = 1000
var round_active: bool = false

# Hit tracking to prevent multi-hits from same attack
var last_hit_frame_a: int = -1
var last_hit_frame_b: int = -1

func start_battle(char_a: Character, char_b: Character):
	character_a = char_a
	character_b = char_b
	
	# Store character data references
	character_a_data = char_a.get_character_data()
	character_b_data = char_b.get_character_data()
	
	# Reset character health
	character_a.reset_health()
	character_b.reset_health()
	
	max_health_a = character_a.max_health
	max_health_b = character_b.max_health
	health_a = max_health_a
	health_b = max_health_b
	
	round_active = true
	last_hit_frame_a = -1
	last_hit_frame_b = -1
	
	# Emit character data for UI updates
	emit_signal("character_data_updated", character_a_data, character_b_data)
	emit_signal("round_start")

func _process(delta):
	if not round_active:
		return
	
	# Update both characters
	if character_a:
		character_a._physics_process(delta)
	if character_b:
		character_b._physics_process(delta)
	
	# Advanced hitbox-based collision detection
	_check_advanced_hits()
	
	# Check for round end
	if character_a and character_a.is_ko():
		round_active = false
		emit_signal("round_end", character_b)
	if character_b and character_b.is_ko():
		round_active = false
		emit_signal("round_end", character_a)

func _check_advanced_hits():
	# Check A hitting B
	if character_a and character_b:
		var hit_result = _check_hitbox_collision(character_a, character_b)
		if hit_result.hit and hit_result.frame != last_hit_frame_a:
			_apply_hit(character_a, character_b, hit_result)
			last_hit_frame_a = hit_result.frame
			emit_signal("hit_landed", character_a, character_b, hit_result.damage)
	
	# Check B hitting A
	if character_b and character_a:
		var hit_result = _check_hitbox_collision(character_b, character_a)
		if hit_result.hit and hit_result.frame != last_hit_frame_b:
			_apply_hit(character_b, character_a, hit_result)
			last_hit_frame_b = hit_result.frame
			emit_signal("hit_landed", character_b, character_a, hit_result.damage)

func _check_hitbox_collision(attacker: Character, defender: Character) -> Dictionary:
	# Returns {hit: bool, damage: int, frame: int, hitbox: Rect2, hurtbox: Rect2}
	var result = {"hit": false, "damage": 0, "frame": -1}
	
	if not attacker or not defender:
		return result
	
	var hitboxes = attacker.get_current_hitboxes()
	var hurtboxes = defender.get_current_hurtboxes()
	
	for hitbox in hitboxes:
		for hurtbox in hurtboxes:
			if hitbox.intersects(hurtbox):
				result.hit = true
				result.damage = _calculate_damage(attacker, defender, hitbox, hurtbox)
				result.frame = attacker.current_frame
				result.hitbox = hitbox
				result.hurtbox = hurtbox
				return result
	
	return result

func _calculate_damage(attacker: Character, _defender: Character, hitbox: Rect2, _hurtbox: Rect2) -> int:
	# Base damage calculation (can be expanded with character stats, attack properties, etc.)
	var base_damage = 50
	
	# Example: larger hitboxes do more damage
	var size_multiplier = (hitbox.size.x * hitbox.size.y) / 1000.0
	size_multiplier = clamp(size_multiplier, 0.5, 2.0)
	
	# Example: special moves do more damage (based on animation number)
	var special_multiplier = 1.0
	if attacker.current_anim > 10:  # Assume anims > 10 are special moves
		special_multiplier = 1.5
	
	var final_damage = int(base_damage * size_multiplier * special_multiplier)
	return max(final_damage, 1)  # Minimum 1 damage

func _apply_hit(attacker: Character, defender: Character, hit_result: Dictionary):
	# Calculate knockback
	var knockback_force = Vector2.ZERO
	knockback_force.x = 50 * attacker.facing  # Push away from attacker
	knockback_force.y = -20  # Slight upward force
	
	# Apply damage and knockback to defender
	defender.take_damage(hit_result.damage, knockback_force)
	
	# Update battle engine health tracking
	health_a = character_a.current_health
	health_b = character_b.current_health
	
	print("Hit landed! Damage: ", hit_result.damage, " Attacker: ", attacker.name, " Defender: ", defender.name)

func _apply_hit_effects(_attacker: Character, _defender: Character, _hit_result: Dictionary):
	# Hit effects are now handled in Character.take_damage()
	# Future: Add hit sparks, screen shake, sound effects, etc.
	pass

func get_health_percent_a() -> float:
	return float(health_a) / float(max_health_a)

func get_health_percent_b() -> float:
	return float(health_b) / float(max_health_b)

func get_character_a() -> Character:
	return character_a

func get_character_b() -> Character:
	return character_b

func get_character_a_data():
	return character_a_data

func get_character_b_data():
	return character_b_data

func get_character_a_name() -> String:
	if character_a_data:
		return character_a_data.get_display_name()
	if character_a:
		return character_a.name
	return "Player 1"

func get_character_b_name() -> String:
	if character_b_data:
		return character_b_data.get_display_name()
	if character_b:
		return character_b.name
	return "Player 2"
