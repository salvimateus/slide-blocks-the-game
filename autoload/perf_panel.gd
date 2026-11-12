extends CanvasLayer
## Performance panel over all screens: FPS, frame, script, draw and render times, draw calls, primitives, device and
## GPU names, and toggles for particles, glow and background, saved in user://perf.cfg.
## Closed by default; the toggle_perf action (F3) or toggle() opens it.
## It also gives the run sums of Harness --perf-summary and --frame-log.
## Times are measured only while the panel is open or a run is on:
## script = each _process and _physics_process callback, draw = the work between the last _process and the render
## (deferred calls and the canvas item flush), render = the RenderingServer frame.

const Strings := preload("res://scripts/ui/strings.gd")

signal option_changed(key: StringName, value: bool)

const SETTINGS_PATH := "user://perf.cfg"
const SETTINGS_SECTION := "options"
const OPTIONS: Array[StringName] = [&"particles", &"glow", &"background"]
const OPTION_LABELS := {&"particles": "perf_particles", &"glow": "perf_glow", &"background": "perf_background"}
const CANVAS_LAYER := 100
const MARGIN := 16.0
const PANEL_WIDTH := 460.0
const REFRESH_MS := 250
## Runs before and after each other node, so the two stamps bracket all script callbacks of a frame.
const FIRST_PRIORITY := -1000000
const LAST_PRIORITY := 1000000


## Stamps the start of the process and physics callbacks of each frame.
class FirstStamp extends Node:
	var process_start := 0
	var physics_start := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = FIRST_PRIORITY
		process_physics_priority = FIRST_PRIORITY

	func _process(_delta: float) -> void:
		process_start = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		physics_start = Time.get_ticks_usec()


var _options := {}
var _open := false
var _root: Control
var _panel: PanelContainer
var _stats: Label
var _checks := {}
var _first: FirstStamp
var _headless := false
var _measuring := false
var _physics_usec := 0
var _process_end := 0
var _pre_draw := 0
var _last_end := 0
var _next_refresh := 0
## Sums over a refresh window: frames, frame, script, draw, render (usec).
var _win := PackedInt64Array([0, 0, 0, 0, 0])
## Sums over a run: frames, frame, script, draw, render (usec), worst frame, draw calls, worst draw calls,
## primitives, slow frames.
var _run := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var _run_on := false
var _log_over_usec := 0


func _ready() -> void:
	layer = CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = LAST_PRIORITY
	process_physics_priority = LAST_PRIORITY
	_headless = DisplayServer.get_name() == "headless"
	_load_options()
	_first = FirstStamp.new()
	_first.name = "FirstStamp"
	add_child(_first)
	_build()
	_set_measuring(false)


func toggle() -> void:
	_set_open(not _open)


func is_open() -> bool:
	return _open


## The value of a toggle: &"particles", &"glow" or &"background". True means the system is on.
func option(key: StringName) -> bool:
	return _options.get(key, true)


func set_option(key: StringName, value: bool) -> void:
	if not OPTIONS.has(key) or option(key) == value:
		return
	_options[key] = value
	if _checks.has(key):
		(_checks[key] as CheckButton).set_pressed_no_signal(value)
	_save_options()
	option_changed.emit(key, value)


## Starts the run sums. With `log_over_ms` above 0, prints each frame that takes longer.
func begin_run(log_over_ms: float = 0.0) -> void:
	_run.fill(0)
	_log_over_usec = roundi(log_over_ms * 1000.0)
	_run_on = true
	_last_end = 0
	_set_measuring(true)


## Averages of the run, in ms, plus draw calls and primitives.
func run_summary() -> Dictionary:
	var n := maxf(float(_run[0]), 1.0)
	var frame_avg := _run[1] / n / 1000.0
	return {
		"frames": _run[0],
		"fps_avg": _round(1000.0 / frame_avg) if frame_avg > 0.0 else 0.0,
		"frame_avg_ms": _round(frame_avg),
		"frame_max_ms": _round(_run[5] / 1000.0),
		"script_avg_ms": _round(_run[2] / n / 1000.0),
		"draw_avg_ms": _round(_run[3] / n / 1000.0),
		"render_avg_ms": _round(_run[4] / n / 1000.0),
		"draw_calls_avg": _round(_run[6] / n),
		"draw_calls_max": _run[7],
		"primitives_avg": _round(_run[8] / n),
		"slow_frames": _run[9],
	}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_perf") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	_physics_usec += Time.get_ticks_usec() - _first.physics_start


func _process(_delta: float) -> void:
	_process_end = Time.get_ticks_usec()
	if _headless:
		# The headless renderer emits no frame signals: the frame ends here, with no draw and no render time.
		_pre_draw = _process_end
		_end_frame(_process_end)
	if _open and Time.get_ticks_msec() >= _next_refresh:
		_next_refresh = Time.get_ticks_msec() + REFRESH_MS
		_refresh_text()


func _on_pre_draw() -> void:
	_pre_draw = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_end_frame(Time.get_ticks_usec())


func _end_frame(now: int) -> void:
	var frame := now - _last_end if _last_end > 0 else 0
	_last_end = now
	var script := maxi(_process_end - _first.process_start, 0) + _physics_usec
	_physics_usec = 0
	var draw := maxi(_pre_draw - _process_end, 0)
	var render := maxi(now - _pre_draw, 0)
	if frame <= 0:
		return
	_add(_win, frame, script, draw, render)
	if not _run_on:
		return
	_add(_run, frame, script, draw, render)
	_run[5] = maxi(_run[5], frame)
	var calls := _draw_calls()
	_run[6] += calls
	_run[7] = maxi(_run[7], calls)
	_run[8] += _primitives()
	if _log_over_usec > 0 and frame > _log_over_usec:
		_run[9] += 1
		print("FRAME_SLOW n=%d ms=%.2f script=%.2f draw=%.2f render=%.2f" % [_run[0], frame / 1000.0, script / 1000.0, draw / 1000.0, render / 1000.0])


static func _add(sums: PackedInt64Array, frame: int, script: int, draw: int, render: int) -> void:
	sums[0] += 1
	sums[1] += frame
	sums[2] += script
	sums[3] += draw
	sums[4] += render


func _set_open(open: bool) -> void:
	_open = open
	_root.visible = open
	if open:
		_root.theme = get_tree().root.theme
		_place_panel()
		_win.fill(0)
		_next_refresh = 0
		_refresh_text()
	_set_measuring(open or _run_on)


func _set_measuring(on: bool) -> void:
	if on == _measuring and is_processing() == on:
		return
	_measuring = on
	set_process(on)
	set_physics_process(on)
	_first.set_process(on)
	_first.set_physics_process(on)
	_last_end = 0
	_physics_usec = 0
	if _headless:
		return
	var connected := RenderingServer.frame_post_draw.is_connected(_on_post_draw)
	if on and not connected:
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	elif not on and connected:
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)


func _refresh_text() -> void:
	var n := maxf(float(_win[0]), 1.0)
	var ms := func(index: int) -> String: return "%.2f ms" % (_win[index] / n / 1000.0)
	var lines := PackedStringArray([
		"%s: %d" % [Strings.t("perf_fps"), Engine.get_frames_per_second()],
		"%s: %s" % [Strings.t("perf_frame"), ms.call(1)],
		"%s: %s" % [Strings.t("perf_script"), ms.call(2)],
		"%s: %s" % [Strings.t("perf_draw"), ms.call(3)],
		"%s: %s" % [Strings.t("perf_render"), ms.call(4)],
		"%s: %d" % [Strings.t("perf_draw_calls"), _draw_calls()],
		"%s: %d" % [Strings.t("perf_primitives"), _primitives()],
		"%s: %s" % [Strings.t("perf_device"), OS.get_model_name()],
		"%s: %s" % [Strings.t("perf_gpu"), _gpu_name()],
	])
	_stats.text = "\n".join(lines)
	_win.fill(0)


func _build() -> void:
	_root = Control.new()
	_root.name = "PerfRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var title := Label.new()
	title.text = Strings.t("perf_title")
	column.add_child(title)
	_stats = Label.new()
	column.add_child(_stats)
	for key in OPTIONS:
		var check := CheckButton.new()
		check.text = Strings.t(OPTION_LABELS[key])
		check.focus_mode = Control.FOCUS_NONE
		check.set_pressed_no_signal(option(key))
		check.toggled.connect(func(on: bool) -> void: set_option(key, on))
		column.add_child(check)
		_checks[key] = check
	var close := Button.new()
	close.text = Strings.t("perf_close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	column.add_child(close)


## Puts the panel at the top left corner, inside the safe area on a phone.
func _place_panel() -> void:
	var top_left := Vector2(MARGIN, MARGIN)
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var to_view := get_viewport().get_final_transform().affine_inverse()
		top_left += (to_view * Vector2(safe.position)).max(Vector2.ZERO)
	_panel.position = top_left


func _load_options() -> void:
	for key in OPTIONS:
		_options[key] = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in OPTIONS:
		_options[key] = bool(config.get_value(SETTINGS_SECTION, String(key), true))


func _save_options() -> void:
	var config := ConfigFile.new()
	for key in OPTIONS:
		config.set_value(SETTINGS_SECTION, String(key), _options[key])
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("PerfPanel: cannot save %s (error %d)" % [SETTINGS_PATH, err])


static func _draw_calls() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


static func _primitives() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)


static func _gpu_name() -> String:
	var adapter := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	if vendor == "" or adapter.contains(vendor):
		return adapter
	return "%s (%s)" % [adapter, vendor]


static func _round(value: float) -> float:
	return snappedf(value, 0.001)
