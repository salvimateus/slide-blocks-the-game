extends SceneTree
# Loads each script under res://autoload and res://scripts, and checks that Nunito has each character of strings.gd.

const ROOTS: Array[String] = ["res://autoload", "res://scripts"]
const FONT_PATH := "res://ui/fonts/Nunito-VariableFont_wght.ttf"
const STRINGS_PATH := "res://scripts/ui/strings.gd"


func _initialize() -> void:
	var failed := PackedStringArray()
	var paths := PackedStringArray()
	for root in ROOTS:
		_collect(root, paths)
	var loaded := 0
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			failed.append(path)
		else:
			loaded += 1
	_check_glyphs(failed)
	if failed.is_empty():
		print("LOAD_OK %d" % loaded)
		quit(0)
		return
	for path in failed:
		print("LOAD_FAIL ", path)
	quit(1)


func _collect(dir_path: String, paths: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() == "gd":
			paths.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), paths)


func _check_glyphs(failed: PackedStringArray) -> void:
	if not ResourceLoader.exists(FONT_PATH):
		failed.append("%s (font missing or not imported)" % FONT_PATH)
		return
	var font := load(FONT_PATH) as FontFile
	var strings := load(STRINGS_PATH) as Script
	if font == null or strings == null:
		failed.append("%s or %s (cannot load)" % [FONT_PATH, STRINGS_PATH])
		return
	var chars := {}
	for value in strings.get_script_constant_map().values():
		_collect_chars(value, chars)
	var missing := ""
	for code in chars:
		if not font.has_char(code):
			missing += String.chr(code)
	if not missing.is_empty():
		failed.append("%s (glyphs missing: %s)" % [FONT_PATH, missing])


func _collect_chars(value: Variant, chars: Dictionary) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			var text := String(value)
			for i in text.length():
				var code := text.unicode_at(i)
				if code >= 32:
					chars[code] = true
		TYPE_ARRAY:
			for item in value:
				_collect_chars(item, chars)
		TYPE_DICTIONARY:
			for key in value:
				_collect_chars(key, chars)
				_collect_chars(value[key], chars)
