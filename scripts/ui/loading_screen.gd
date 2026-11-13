extends "res://scripts/ui/screen.gd"
## The screen of a random level that takes time: a bobbing jelly, the text, the seed and a cancel button.
## open() makes it block input at once but shows nothing; reveal() fades it in when the level is not ready soon.

signal cancel_requested

const JELLY_SIZE := 120.0

var _card: PanelContainer
var _jelly: Control
var _seed_label: Label
var _seed := 0
var _revealed := false
var _bob_tween: Tween


func _init() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(Palette.SCRIM, Tuning.DIALOG_SCRIM_ALPHA)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var column := Column.new()
	add_child(column)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	_card = UiTheme.panel(UiTheme.pad(UiTheme.card_box(), UiTuning.CARD_PADDING, UiTuning.CARD_PADDING))
	_card.custom_minimum_size.x = minf(UiTuning.CARD_WIDTH - 40.0, Tuning.COLUMN_WIDTH - UiTuning.GUTTER * 2.0)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	center.add_child(_card)
	var stack := UiTheme.vbox(18)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(stack)

	# The jelly sits in a plain Control, so the bob moves it with no fight from the container layout.
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(holder)
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(JELLY_SIZE, JELLY_SIZE)
	holder.add_child(slot)
	_jelly = Icon.new().setup(&"jelly_happy", JELLY_SIZE, Palette.INK, Palette.BODY[2])
	slot.add_child(_jelly)

	var text := UiTheme.paragraph("", UiTuning.SIZE_BODY + 6, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(text, "random_loading")
	stack.add_child(text)
	_seed_label = UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BODY, Palette.INK_SOFT)
	stack.add_child(_seed_label)

	var cancel := _button(JuicyButton.Kind.SECONDARY, "random_cancel", &"back")
	cancel.pressed.connect(func() -> void:
		if is_open:
			cancel_requested.emit())
	stack.add_child(cancel)


func _ready() -> void:
	Bus.locale_changed.connect(func(_locale: StringName) -> void: _set_seed_text())


func _fill(data: Dictionary) -> void:
	_seed = int(data.get("seed", 0))
	_set_seed_text()


## Open but invisible: input is blocked and nothing shows until reveal().
func _play_in() -> void:
	_revealed = false
	_stop_bob()
	modulate.a = 0.0
	position = Vector2.ZERO


## True when the open screen shows (after reveal()).
func is_revealed() -> bool:
	return _revealed


## Fades the open screen in, springs the card and starts the bob, then emits `opened`.
func reveal() -> void:
	if not is_open or _revealed:
		return
	_revealed = true
	_kill_screen_tween()
	var motion := Feel.motion()
	_card.scale = Vector2.ONE * lerpf(1.0, UiTuning.CARD_START_SCALE + 0.15, motion)
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.tween_property(_card, "scale", Vector2.ONE, UiTuning.CARD_SPRING_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screen_tween.chain().tween_callback(opened.emit)
	_start_bob(UiTuning.LOADING_BOB * motion)


func _on_closed() -> void:
	_stop_bob()
	super._on_closed()


func _set_seed_text() -> void:
	_seed_label.text = Strings.t("random_seed", {"seed": _seed})


func _start_bob(amount: float) -> void:
	_stop_bob()
	if amount <= 0.0:
		return
	_bob_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(_jelly, "position:y", -amount, UiTuning.LOADING_BOB_TIME).from(0.0)
	_bob_tween.tween_property(_jelly, "position:y", 0.0, UiTuning.LOADING_BOB_TIME)


func _stop_bob() -> void:
	if _bob_tween:
		_bob_tween.kill()
		_bob_tween = null
	_jelly.position = Vector2.ZERO
