extends Node
## Scripted-run arguments and the screenshot service. The agent harness adds the scripted play in Wave 1.
## Arguments come after `--` on the Godot command line, in the form --key=value or --flag.

const DEFAULT_SHOT_FRAMES := 60
const DEFAULT_TIMEOUT := 60.0
const ALL_EVENTS := "*"

var _args: Dictionary = {}
var _shots_dir := ""
var _shot_on := PackedStringArray()
var _single_shot_path := ""
var _single_shot_frames := 0
var _frames := 0
var _pending_shots := 0
var _quit_code := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_args = _parse(OS.get_cmdline_user_args())
	if not active():
		return
	if has_arg("shots"):
		_shots_dir = _os_path(arg("shots"))
		_shot_on = arg("shot-on").split(",", false)
		if _shot_on.is_empty():
			push_warning("Harness: --shots has no effect without --shot-on")
	elif has_arg("shot-on"):
		push_warning("Harness: --shot-on has no effect without --shots")
	if has_arg("shot"):
		_single_shot_path = _os_path(arg("shot"))
		_single_shot_frames = maxi(arg("frames", str(DEFAULT_SHOT_FRAMES)).to_int(), 1)
		set_process(true)
	elif has_arg("frames"):
		push_warning("Harness: --frames has no effect without --shot")
	var timeout := arg("timeout", str(DEFAULT_TIMEOUT)).to_float()
	if timeout > 0.0:
		get_tree().create_timer(timeout, true, false, true).timeout.connect(_on_timeout)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < _single_shot_frames:
		return
	set_process(false)
	_capture(_single_shot_path)
	finish(0)


## True when any harness argument is present.
func active() -> bool:
	return not _args.is_empty()


func has_arg(key: String) -> bool:
	return _args.has(key)


## The value of --key=value, "" for a bare --key, or `fallback` when the key is absent.
func arg(key: String, fallback: String = "") -> String:
	return _args.get(key, fallback)


## Saves <shots dir>/<name>.png after the next frame. No effect without --shots.
func shot(name: String) -> void:
	if _shots_dir == "":
		return
	_capture(_shots_dir.path_join(name + ".png"))


## Reports a named event: takes the --shot-on screenshot and honors --quit-at.
func mark(event: String) -> void:
	if not active():
		return
	print("HARNESS MARK ", event)
	if _shot_on.has(event) or _shot_on.has(ALL_EVENTS):
		shot(event)
	if has_arg("quit-at") and arg("quit-at") == event:
		finish(0)


## Quits with `code` once the pending screenshots are saved.
func finish(code: int) -> void:
	if _quit_code >= 0:
		return
	_quit_code = code
	if _pending_shots == 0:
		get_tree().quit(code)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Harness: the headless renderer draws nothing, run the screenshot windowed: %s" % path)
		_quit_code = -1
		finish(1)
		return
	_pending_shots += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := _save_viewport(path)
	print("HARNESS SHOT %s err=%d" % [path, err])
	_pending_shots -= 1
	if err != OK and _quit_code <= 0:
		_quit_code = -1
		finish(1)
	elif _quit_code >= 0 and _pending_shots == 0:
		get_tree().quit(_quit_code)


func _save_viewport(path: String) -> Error:
	var dir_err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_err != OK:
		push_error("Harness: cannot create the folder of the screenshot: %s" % path)
		return dir_err
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Harness: the viewport gave no image for: %s" % path)
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(path)


func _on_timeout() -> void:
	print("HARNESS TIMEOUT")
	get_tree().quit(2)


static func _parse(list: PackedStringArray) -> Dictionary:
	var out := {}
	for item in list:
		if not item.begins_with("--"):
			push_warning("Harness: ignored argument '%s'" % item)
			continue
		var body := item.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = ""
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


## Accepts a Windows path or a WSL /mnt/<drive>/ path, and gives the form that this OS opens.
static func _os_path(path: String) -> String:
	var p := path.replace("\\", "/")
	if OS.has_feature("windows") and p.begins_with("/mnt/") and p.length() > 6 and p[6] == "/":
		p = p[5].to_upper() + ":" + p.substr(6)
	return p
