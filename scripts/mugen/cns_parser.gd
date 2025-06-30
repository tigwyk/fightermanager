extends RefCounted
class_name CNSParser

## MUGEN CNS (Constants/State) Parser with AI trigger extraction

var states: Dictionary = {} # state_no -> state_data
var ai_triggers: Array = [] # Extracted AI triggers for character

func parse_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		print("CNS file not found: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open CNS file: ", file_path)
		return false
	
	var current_state = null
	var current_state_controllers = []
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			continue
		
		# Remove inline comments (everything after first ; that's not in quotes)
		var comment_pos = _find_comment_position(line)
		if comment_pos != -1:
			line = line.substr(0, comment_pos).strip_edges()
		
		# Skip if line became empty after comment removal
		if line.is_empty():
			continue
		
		# State definition
		if line.begins_with("[Statedef "):
			# Save previous state if exists
			if current_state != null:
				_finalize_state(current_state, current_state_controllers)
			
			# Parse new state
			current_state = _parse_state_def(line)
			current_state_controllers = []
		
		# State controller
		elif line.begins_with("[State "):
			var controller = _parse_state_controller(file, line)
			if controller:
				current_state_controllers.append(controller)
		
		# Variable assignments (like velocity, etc.)
		elif current_state != null and "=" in line:
			_parse_state_variable(current_state, line)
	
	# Finalize last state
	if current_state != null:
		_finalize_state(current_state, current_state_controllers)
	
	file.close()
	_extract_ai_triggers()
	return true

func _parse_state_def(line: String) -> Dictionary:
	# Extract state number from [Statedef 200]
	var state_no_str = line.get_slice(" ", 1).rstrip("]")
	var state_no = int(state_no_str)
	
	var state_data = {
		"number": state_no,
		"type": "",
		"movetype": "",
		"physics": "",
		"anim": 0,
		"controllers": []
	}
	
	states[state_no] = state_data
	return state_data

func _parse_state_controller(file: FileAccess, _header_line: String) -> Dictionary:
	var controller = {
		"type": "",
		"triggers": [],
		"params": {}
	}
	
	# Continue reading until next section or EOF
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# Stop at next section
		if line.begins_with("["):
			# Put line back (simplified - in real implementation you'd need lookahead)
			break
		
		if line.is_empty() or line.begins_with(";"):
			continue
		
		# Remove inline comments (everything after first ; that's not in quotes)
		var comment_pos = _find_comment_position(line)
		if comment_pos != -1:
			line = line.substr(0, comment_pos).strip_edges()
		
		# Skip if line became empty after comment removal
		if line.is_empty():
			continue
		
		# Parse key = value
		if "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				
				# Remove quotes if present
				if value.begins_with("\"") and value.ends_with("\""):
					value = value.substr(1, value.length() - 2)
				
				if key == "type":
					controller.type = value
				elif key.begins_with("trigger") or key.begins_with("triggerall"):
					controller.triggers.append({
						"type": key,
						"condition": value
					})
				else:
					controller.params[key] = value
	
	return controller

func _parse_state_variable(state_data: Dictionary, line: String):
	var parts = line.split("=", false, 1)
	if parts.size() == 2:
		var key = parts[0].strip_edges()
		var value = parts[1].strip_edges()
		
		match key:
			"type":
				state_data.type = value
			"movetype":
				state_data.movetype = value
			"physics":
				state_data.physics = value
			"anim":
				state_data.anim = int(value)

func _finalize_state(state_data: Dictionary, controllers: Array):
	state_data.controllers = controllers

func _extract_ai_triggers():
	# Extract AI-related triggers from parsed states
	ai_triggers.clear()
	
	for state_no in states:
		var state_data = states[state_no]
		var ai_triggers_for_state = []
		
		for controller in state_data.controllers:
			# Look for AI-related triggers
			for trigger in controller.triggers:
				var condition = trigger.condition
				
				# Check if this is an AI trigger
				if _is_ai_trigger(condition):
					var action = _controller_to_action(controller)
					if action != "":
						ai_triggers_for_state.append({
							"condition": condition,
							"action": action
						})
		
		if ai_triggers_for_state.size() > 0:
			ai_triggers.append({
				"state": state_no,
				"triggers": ai_triggers_for_state
			})

func _is_ai_trigger(condition: String) -> bool:
	# Check if condition contains AI-related keywords
	var ai_keywords = ["AILevel", "AI", "Random", "P2Dist", "EnemyNear", "P2BodyDist"]
	
	for keyword in ai_keywords:
		if condition.find(keyword) != -1:
			return true
	
	return false

func _controller_to_action(controller: Dictionary) -> String:
	# Convert state controller to simplified action
	match controller.type:
		"ChangeState":
			if controller.params.has("value"):
				return "change_state:" + str(controller.params.value)
		"VelSet":
			if controller.params.has("x"):
				return "set_vel_x:" + str(controller.params.x)
			if controller.params.has("y"):
				return "set_vel_y:" + str(controller.params.y)
		"CtrlSet":
			return "set_ctrl:" + str(controller.params.get("value", "1"))
		"PosAdd":
			return "add_pos:" + str(controller.params.get("x", "0")) + "," + str(controller.params.get("y", "0"))
		"PlaySnd":
			return "play_sound:" + str(controller.params.get("value", "0,0"))
		# Add more controller types as needed
		_:
			# Generic action for unhandled controllers
			if controller.type != "":
				return "controller:" + controller.type
	
	return ""

func get_states() -> Dictionary:
	return states

func get_ai_triggers() -> Array:
	return ai_triggers

func get_state_data(state_no: int) -> Dictionary:
	return states.get(state_no, {})

# Debug function to print parsed AI triggers
func print_ai_triggers():
	print("=== AI Triggers ===")
	for entry in ai_triggers:
		print("State ", entry.state, ":")
		for trig in entry.triggers:
			print("  Condition: ", trig.condition)
			print("  Action: ", trig.action)
		print()

func _find_comment_position(line: String) -> int:
	"""Find the position of a comment (;) that's not inside quotes"""
	var in_quotes = false
	var escape_next = false
	
	for i in range(line.length()):
		var character = line[i]
		
		if escape_next:
			escape_next = false
			continue
		
		if character == "\\":
			escape_next = true
			continue
		
		if character == "\"":
			in_quotes = !in_quotes
			continue
		
		if character == ";" and not in_quotes:
			return i
	
	return -1
