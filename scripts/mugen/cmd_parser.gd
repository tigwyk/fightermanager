extends RefCounted
class_name CMDParser

## MUGEN CMD (Command) File Parser
## Parses command definitions and input sequences for special moves

# Command structure
class Command:
	var name: String
	var input: Array = [] # e.g. ["D", "DF", "F", "x"]
	var time: int = 15 # default buffer window

# State/command mapping
class StateCmd:
	var name: String
	var command: String
	var state: int

var commands: Array = [] # Array of Command
var state_cmds: Array = [] # Array of StateCmd

func parse_cmd_file(file_path: String) -> bool:
	"""Parse a CMD file and extract commands"""
	print("📄 Parsing CMD file: ", file_path)
	
	commands.clear()
	state_cmds.clear()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open CMD file: " + file_path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	_parse_content(content)
	return true

func parse_file(file_path: String) -> bool:
	"""Alias for parse_cmd_file for consistency"""
	return parse_cmd_file(file_path)

func _parse_content(content: String):
	var lines = content.split("\n")
	var current_cmd: Command = null
	var state_cmd: StateCmd = null
	for line in lines:
		line = line.strip_edges()
		
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
		
		if line.begins_with("[Command"):
			if current_cmd != null:
				commands.append(current_cmd)
			current_cmd = Command.new()
			continue
		if current_cmd != null:
			if line.begins_with("name ="):
				current_cmd.name = line.split("=", false, 1)[1].strip_edges()
			elif line.begins_with("command ="):
				var seq = line.split("=", false, 1)[1].strip_edges()
				current_cmd.input = seq.split(",")
			elif line.begins_with("time ="):
				current_cmd.time = int(line.split("=", false, 1)[1].strip_edges())
			continue
		if line.begins_with("[State"):
			if state_cmd != null:
				state_cmds.append(state_cmd)
			state_cmd = StateCmd.new()
			continue
		if state_cmd != null:
			if line.begins_with("command ="):
				state_cmd.command = line.split("=", false, 1)[1].strip_edges()
			elif line.begins_with("state ="):
				state_cmd.state = int(line.split("=", false, 1)[1].strip_edges())
				state_cmds.append(state_cmd)
				state_cmd = null
			continue
		# For now, skip triggers (basic parser)

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

func get_commands() -> Array:
	return commands

func get_state_cmds() -> Array:
	return state_cmds
