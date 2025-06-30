extends Node
class_name SFFDiagnostic

## SFF File Diagnostic Tool
## Helps identify and explain SFF file issues

static func diagnose_sff_file(file_path: String) -> Dictionary:
	"""Diagnose an SFF file and return detailed information"""
	var result = {
		"file_exists": false,
		"file_size": 0,
		"signature_valid": false,
		"version": {"major": 0, "minor": 0},
		"sprite_counts": {"groups": 0, "images": 0},
		"diagnosis": "",
		"recommendations": []
	}
	
	# Check file existence
	if not FileAccess.file_exists(file_path):
		result.diagnosis = "File not found"
		result.recommendations.append("Check file path: " + file_path)
		return result
	
	result.file_exists = true
	
	# Open file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.diagnosis = "Cannot open file"
		result.recommendations.append("Check file permissions")
		return result
	
	result.file_size = file.get_length()
	
	# Check minimum size
	if result.file_size < 36:
		result.diagnosis = "File too small for SFF header"
		result.recommendations.append("File may be corrupted or truncated")
		file.close()
		return result
	
	# Read header
	file.seek(0)
	file.set_big_endian(false)
	
	# Check signature
	var sig_bytes = file.get_buffer(12)
	var signature = ""
	for i in range(11):
		if i < sig_bytes.size():
			signature += char(sig_bytes[i])
	
	result.signature_valid = signature == "ElecbyteSpr"
	
	if not result.signature_valid:
		result.diagnosis = "Invalid SFF signature: " + signature
		result.recommendations.append("File is not a valid MUGEN SFF file")
		file.close()
		return result
	
	# Read version
	result.version.minor = file.get_8()
	result.version.major = file.get_8()
	
	# Skip reserved bytes
	file.get_buffer(2)
	
	# Read counts
	result.sprite_counts.groups = file.get_32()
	result.sprite_counts.images = file.get_32()
	
	file.close()
	
	# Analyze results
	if result.version.major == 0 and result.version.minor == 0:
		result.diagnosis = "Invalid version 0.0 - placeholder or corrupted file"
		result.recommendations.append("This appears to be a placeholder or corrupted SFF file")
		result.recommendations.append("The file has the correct signature but invalid version")
		result.recommendations.append("Replace with a proper MUGEN SFF file")
	elif result.sprite_counts.groups == 0 and result.sprite_counts.images == 0:
		result.diagnosis = "Empty SFF file - no sprites defined"
		result.recommendations.append("File contains no sprite data")
		result.recommendations.append("This may be an incomplete or template file")
	elif result.version.major == 1:
		result.diagnosis = "Valid SFF v1.0 file"
	elif result.version.major == 2:
		result.diagnosis = "Valid SFF v2.0 file"
	else:
		result.diagnosis = "Unknown SFF version: %d.%d" % [result.version.major, result.version.minor]
		result.recommendations.append("Unsupported SFF version")
	
	return result

static func print_diagnosis(file_path: String):
	"""Print a detailed diagnosis of an SFF file"""
	print("\n=== SFF FILE DIAGNOSIS ===")
	print("File: ", file_path)
	
	var diag = diagnose_sff_file(file_path)
	
	print("📁 File exists: ", diag.file_exists)
	if diag.file_exists:
		print("📏 File size: ", diag.file_size, " bytes")
	
	print("🔏 Signature valid: ", diag.signature_valid)
	print("📋 Version: ", diag.version.major, ".", diag.version.minor)
	print("🎨 Sprites: ", diag.sprite_counts.groups, " groups, ", diag.sprite_counts.images, " images")
	
	print("\n🔍 DIAGNOSIS: ", diag.diagnosis)
	
	if diag.recommendations.size() > 0:
		print("\n💡 RECOMMENDATIONS:")
		for rec in diag.recommendations:
			print("  • ", rec)
	
	print("=========================\n")
