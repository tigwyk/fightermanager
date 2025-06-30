extends SceneTree

func _initialize():
	print("=== SFF FILE DEBUG TOOL ===")
	
	var file_path = "assets/mugen/chars/Guile/Guile.sff"
	
	# Check file existence
	if not FileAccess.file_exists(file_path):
		print("File not found: ", file_path)
		quit(1)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Cannot open file: ", file_path)
		quit(1)
		return
	
	var size = file.get_length()
	print("File size: ", size, " bytes")
	
	# Read first 100 bytes
	file.seek(0)
	var data = file.get_buffer(100)
	
	print("\nFirst 100 bytes (hex + ASCII):")
	for i in range(0, data.size(), 16):
		var hex_line = "%04x: " % i
		var ascii_line = ""
		for j in range(16):
			if i + j < data.size():
				var b = data[i + j]
				hex_line += "%02x " % b
				ascii_line += char(b) if b >= 32 and b <= 126 else "."
			else:
				hex_line += "   "
		print(hex_line + " |" + ascii_line + "|")
	
	# Try manual header parsing
	print("\nManual header parsing:")
	file.seek(0)
	file.set_big_endian(false)
	
	# Signature (12 bytes)
	var sig_bytes = file.get_buffer(12)
	var signature = ""
	for i in range(11):  # Skip null terminator
		if i < sig_bytes.size():
			signature += char(sig_bytes[i])
	print("Signature: '", signature, "'")
	
	# Version (2 bytes)
	var ver_lo = file.get_8()
	var ver_hi = file.get_8()
	print("Version: ", ver_hi, ".", ver_lo)
	
	# Reserved (2 bytes)
	file.get_buffer(2)
	
	# Counts (4 bytes each)
	var group_count = file.get_32()
	var image_count = file.get_32()
	print("Groups: ", group_count, ", Images: ", image_count)
	
	# Offsets (4 bytes each)
	var subheader_offset = file.get_32()
	var subheader_length = file.get_32()
	print("Subheader offset: ", subheader_offset, ", length: ", subheader_length)
	
	file.close()
	
	print("\n=== DONE ===")
	quit(0)
