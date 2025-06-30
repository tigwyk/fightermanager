extends RefCounted
class_name PCXParser

## PCX Image Format Parser for MUGEN SFF files
## Handles RLE decompression and converts to Godot Image format

# PCX Header structure
class PCXHeader:
	var manufacturer: int
	var version: int
	var encoding: int
	var bits_per_pixel: int
	var xmin: int
	var ymin: int
	var xmax: int
	var ymax: int
	var hdpi: int
	var vdpi: int
	var colormap: PackedByteArray
	var reserved: int
	var nplanes: int
	var bytes_per_line: int
	var palette_info: int
	var hscreen_size: int
	var vscreen_size: int

func parse_pcx_data(data: PackedByteArray) -> Image:
	"""Parse PCX data and return a Godot Image"""
	if data == null or data.size() < 128:  # PCX header is 128 bytes
		print("⚠️ PCX data too small or null")
		return null
	
	var header = _parse_header(data)
	if not header:
		return null
	
	var width = header.xmax - header.xmin + 1
	var height = header.ymax - header.ymin + 1
	
	print("📏 PCX dimensions: %dx%d, %d bpp, %d planes" % [
		width, height, header.bits_per_pixel, header.nplanes
	])
	
	# Decompress image data
	var image_data = _decompress_rle(data, 128, header)
	if not image_data:
		print("⚠️ Failed to decompress PCX data")
		return null
	
	# Convert to Godot Image format
	return _convert_to_image(image_data, header, width, height)

func _parse_header(data: PackedByteArray) -> PCXHeader:
	"""Parse PCX header from data"""
	var header = PCXHeader.new()
	
	header.manufacturer = data[0]
	header.version = data[1]
	header.encoding = data[2]
	header.bits_per_pixel = data[3]
	
	# Check for valid PCX signature
	if header.manufacturer != 0x0A:
		print("⚠️ Invalid PCX manufacturer byte: 0x%02X" % header.manufacturer)
		return null
	
	# Read coordinates (little-endian)
	header.xmin = data[4] | (data[5] << 8)
	header.ymin = data[6] | (data[7] << 8)
	header.xmax = data[8] | (data[9] << 8)
	header.ymax = data[10] | (data[11] << 8)
	
	header.hdpi = data[12] | (data[13] << 8)
	header.vdpi = data[14] | (data[15] << 8)
	
	# EGA colormap (48 bytes)
	header.colormap = data.slice(16, 64)
	
	header.reserved = data[64]
	header.nplanes = data[65]
	header.bytes_per_line = data[66] | (data[67] << 8)
	header.palette_info = data[68] | (data[69] << 8)
	header.hscreen_size = data[70] | (data[71] << 8)
	header.vscreen_size = data[72] | (data[73] << 8)
	
	return header

func _decompress_rle(data: PackedByteArray, start_offset: int, header: PCXHeader) -> PackedByteArray:
	"""Decompress RLE-encoded PCX data"""
	var result = PackedByteArray()
	var pos = start_offset
	var _width = header.xmax - header.xmin + 1
	var height = header.ymax - header.ymin + 1
	var bytes_per_scanline = header.bytes_per_line * header.nplanes
	var total_bytes = height * bytes_per_scanline
	
	result.resize(total_bytes)
	var output_pos = 0
	
	while pos < data.size() and output_pos < total_bytes:
		var byte_val = data[pos]
		pos += 1
		
		if (byte_val & 0xC0) == 0xC0:  # RLE run
			var run_length = byte_val & 0x3F
			if pos >= data.size():
				print("⚠️ Unexpected end of PCX data during RLE run")
				break
			
			var run_value = data[pos]
			pos += 1
			
			for i in range(run_length):
				if output_pos < total_bytes:
					result[output_pos] = run_value
					output_pos += 1
		else:  # Single byte
			if output_pos < total_bytes:
				result[output_pos] = byte_val
				output_pos += 1
	
	if output_pos != total_bytes:
		print("⚠️ PCX decompression size mismatch: expected %d, got %d" % [total_bytes, output_pos])
	
	return result

func _convert_to_image(data: PackedByteArray, header: PCXHeader, width: int, height: int) -> Image:
	"""Convert decompressed PCX data to Godot Image"""
	var image: Image
	
	if header.bits_per_pixel == 8 and header.nplanes == 1:
		# 8-bit indexed color
		image = Image.create_from_data(width, height, false, Image.FORMAT_L8, data)
	elif header.bits_per_pixel == 1 and header.nplanes == 8:
		# EGA 8-plane format
		image = _convert_ega_planes(data, header, width, height)
	elif header.bits_per_pixel == 4 and header.nplanes == 1:
		# 4-bit indexed color
		image = _convert_4bit_indexed(data, header, width, height)
	elif header.bits_per_pixel == 24 and header.nplanes == 1:
		# 24-bit RGB
		image = _convert_24bit_rgb(data, header, width, height)
	else:
		print("⚠️ Unsupported PCX format: %d bpp, %d planes" % [header.bits_per_pixel, header.nplanes])
		return null
	
	return image

func _convert_ega_planes(data: PackedByteArray, header: PCXHeader, width: int, height: int) -> Image:
	"""Convert EGA 8-plane format to indexed image"""
	var result_data = PackedByteArray()
	result_data.resize(width * height)
	
	var bytes_per_line = header.bytes_per_line
	var pos = 0
	
	for y in range(height):
		for x in range(width):
			var pixel_value = 0
			var byte_x = x >> 3  # Divide by 8 using bit shift
			var bit_x = 7 - (x % 8)
			
			# Combine bits from all 8 planes
			for plane in range(8):
				var plane_offset = y * bytes_per_line * 8 + plane * bytes_per_line + byte_x
				if plane_offset < data.size():
					var plane_byte = data[plane_offset]
					if (plane_byte >> bit_x) & 1:
						pixel_value |= (1 << plane)
			
			result_data[pos] = pixel_value
			pos += 1
	
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, result_data)

func _convert_4bit_indexed(data: PackedByteArray, header: PCXHeader, width: int, height: int) -> Image:
	"""Convert 4-bit indexed color to 8-bit indexed"""
	var result_data = PackedByteArray()
	result_data.resize(width * height)
	
	var pos = 0
	var bytes_per_line = header.bytes_per_line
	
	for y in range(height):
		var line_start = y * bytes_per_line
		for x in range(width):
			var byte_pos = line_start + (x >> 1)  # Divide by 2 using bit shift
			if byte_pos < data.size():
				var byte_val = data[byte_pos]
				var pixel_val: int
				if x % 2 == 0:
					pixel_val = (byte_val >> 4) & 0x0F
				else:
					pixel_val = byte_val & 0x0F
				result_data[pos] = pixel_val
			pos += 1
	
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, result_data)

func _convert_24bit_rgb(data: PackedByteArray, header: PCXHeader, width: int, height: int) -> Image:
	"""Convert 24-bit RGB to RGBA format"""
	var result_data = PackedByteArray()
	result_data.resize(width * height * 4)  # RGBA
	
	var _input_pos = 0
	var output_pos = 0
	var bytes_per_line = header.bytes_per_line
	
	for y in range(height):
		# RGB planes are stored separately
		var r_start = y * bytes_per_line * 3
		var g_start = r_start + bytes_per_line
		var b_start = g_start + bytes_per_line
		
		for x in range(width):
			if r_start + x < data.size() and g_start + x < data.size() and b_start + x < data.size():
				result_data[output_pos] = data[r_start + x]     # R
				result_data[output_pos + 1] = data[g_start + x] # G
				result_data[output_pos + 2] = data[b_start + x] # B
				result_data[output_pos + 3] = 255               # A
			output_pos += 4
	
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, result_data)

func extract_vga_palette(data: PackedByteArray) -> PackedColorArray:
	"""Extract VGA palette from end of PCX file (if present)"""
	if data == null or data.size() < 769:  # 768 palette bytes + 1 signature byte
		return PackedColorArray()
	
	# Check for palette signature (0x0C) at end - 769 bytes
	var palette_start = data.size() - 769
	if data[palette_start] != 0x0C:
		return PackedColorArray()
	
	var palette = PackedColorArray()
	palette_start += 1  # Skip signature
	
	for i in range(256):
		var r = data[palette_start + i * 3]
		var g = data[palette_start + i * 3 + 1]
		var b = data[palette_start + i * 3 + 2]
		palette.append(Color8(r, g, b, 255))
	
	return palette

func parse_file(file_path: String) -> Dictionary:
	"""Parse PCX file from file path and return image data"""
	if not FileAccess.file_exists(file_path):
		print("PCX file not found: ", file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open PCX file: ", file_path)
		return {}
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	var image = parse_pcx_data(data)
	if image:
		return {"image": image}
	else:
		return {}
