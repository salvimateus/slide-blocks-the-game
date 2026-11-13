extends "res://scripts/ui/screen.gd"
## Level select: a back button, the one-jelly toggle, the star total, the level cards in pages of two columns, and a page footer.
## The toggle switches the cards and the total between the normal records and the one-jelly records.
## All pages stay laid out side by side in a clipped strip, so each thumbnail has a size at boot and bakes in the warm-up.
## open() takes an optional {"page": n}; with no page it opens the page of the highest open level.

const LevelsData := preload("res://scripts/core/levels_data.gd")
const LevelModes := preload("res://scripts/core/level_modes.gd")
const LevelCard := preload("res://scripts/ui/level_card.gd")
const ToggleRow := preload("res://scripts/ui/toggle_row.gd")

const COLUMNS := 2
const CARD_GAP := 22
## The clip box passes the page area by this much on each side, so a card that pops or shakes is not cut at the edge.
const CLIP_BLEED := 16.0
const DOT_ALPHA_OFF := 0.35
const BUTTON_ALPHA_OFF := 0.35

var _cards: Array[Button] = []
var _total_label: Label
var _solo_toggle: Button
var _pager: Control
var _strip: Control
var _pages: Array[Control] = []
var _footer: HBoxContainer
var _prev_button: Button
var _next_button: Button
var _dots: Array[StyleBoxFlat] = []
var _page := 0
var _strip_tween: Tween


func _init() -> void:
	super()
	var column := Column.new()
	column.pad_top = 20.0
	column.pad_bottom = 28.0
	add_child(column)
	var stack := UiTheme.vbox(24)
	column.add_child(stack)

	var header := UiTheme.hbox(16)
	stack.add_child(header)
	var back := _round_button(&"back")
	back.pressed.connect(func() -> void: Game.open_home())
	header.add_child(back)
	var title := UiTheme.label("", UiTuning.SIZE_HEADING, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(title, "levels_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_solo_toggle = ToggleRow.new().setup_toggle(&"solo", "", &"jelly_happy", true)
	Strings.bind(_solo_toggle.label, "solo_short")
	header.add_child(_solo_toggle)
	var total := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, 44, Palette.FLOOR_SHADOW, 3, 4), 14, 6))
	total.custom_minimum_size = Vector2(UiTuning.ICON_BUTTON_SIZE, UiTuning.ICON_BUTTON_SIZE)
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var total_row := UiTheme.hbox(4)
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_child(Icon.new().setup(&"star", 34, Palette.INK_SOFT, Palette.STAR))
	_total_label = UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK)
	total_row.add_child(_total_label)
	total.add_child(total_row)
	header.add_child(total)

	_build_pager(stack)
	_build_footer(stack)
	Bus.locale_changed.connect(_on_locale_changed)
	Bus.setting_changed.connect(_on_setting_changed)


func _build_pager(stack: Control) -> void:
	@warning_ignore("integer_division")
	var rows := UiTuning.LEVELS_PAGE_SIZE / COLUMNS
	_pager = Control.new()
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pager.custom_minimum_size.y = rows * LevelCard.HEIGHT + (rows - 1) * CARD_GAP
	_pager.resized.connect(_place_pages)
	stack.add_child(_pager)
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = -CLIP_BLEED
	clip.offset_top = -CLIP_BLEED
	clip.offset_right = CLIP_BLEED
	clip.offset_bottom = CLIP_BLEED
	_pager.add_child(clip)
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_strip)

	for p in _page_count():
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_theme_constant_override("h_separation", CARD_GAP)
		grid.add_theme_constant_override("v_separation", CARD_GAP)
		_strip.add_child(grid)
		_pages.append(grid)
		for slot in UiTuning.LEVELS_PAGE_SIZE:
			var i := p * UiTuning.LEVELS_PAGE_SIZE + slot
			var cell: Control
			if i < LevelsData.LEVELS.size():
				var card: Button = LevelCard.new().setup_card(LevelsData.LEVELS[i], i)
				card.chosen.connect(func(index: int) -> void: Game.start_level(index))
				_cards.append(card)
				cell = card
			else:
				# An empty cell keeps the cards of the last page at the size of a full page.
				cell = Control.new()
				cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)


func _build_footer(stack: Control) -> void:
	_footer = UiTheme.hbox(20)
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.visible = _page_count() > 1
	stack.add_child(_footer)
	_prev_button = _round_button(&"back")
	_prev_button.pressed.connect(func() -> void: _go_to(_page - 1, true))
	_footer.add_child(_prev_button)
	for p in _page_count():
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(UiTuning.PAGE_DOT_SIZE, UiTuning.PAGE_DOT_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := UiTheme.box(Palette.INK, int(UiTuning.PAGE_DOT_SIZE / 2.0))
		dot.add_theme_stylebox_override("panel", sb)
		_footer.add_child(dot)
		_dots.append(sb)
	_next_button = _round_button(&"back")
	_next_button.icon_node.mirrored = true
	_next_button.pressed.connect(func() -> void: _go_to(_page + 1, true))
	_footer.add_child(_next_button)


func _page_count() -> int:
	return maxi(ceili(LevelsData.LEVELS.size() / float(UiTuning.LEVELS_PAGE_SIZE)), 1)


func _page_step() -> float:
	return _pager.size.x + UiTuning.LEVELS_PAGE_GAP


func _place_pages() -> void:
	for p in _pages.size():
		_pages[p].position = Vector2(CLIP_BLEED + p * _page_step(), CLIP_BLEED)
		_pages[p].size = _pager.size
	_move_strip(false)


func _go_to(page: int, animate: bool) -> void:
	_page = clampi(page, 0, _page_count() - 1)
	for p in _dots.size():
		_dots[p].bg_color = Palette.INK if p == _page else Color(Palette.INK_SOFT, DOT_ALPHA_OFF)
	_set_page_button(_prev_button, _page > 0)
	_set_page_button(_next_button, _page < _page_count() - 1)
	_move_strip(animate)


func _set_page_button(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate.a = 1.0 if enabled else BUTTON_ALPHA_OFF


func _move_strip(animate: bool) -> void:
	if _strip_tween:
		_strip_tween.kill()
		_strip_tween = null
	var target := -_page * _page_step()
	if animate and Feel.motion() >= 1.0:
		_strip_tween = _strip.create_tween()
		_strip_tween.tween_property(_strip, "position:x", target, UiTuning.LEVELS_PAGE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_strip.position.x = target


func _fill(data: Dictionary) -> void:
	_solo_toggle.refresh()
	_refresh_cards()
	@warning_ignore("integer_division")
	var page: int = data.get("page", Save.highest_unlocked() / UiTuning.LEVELS_PAGE_SIZE)
	_go_to(page, false)


func _refresh_cards() -> void:
	var solo: bool = Save.setting(&"solo")
	var stars := 0
	for i in _cards.size():
		_cards[i].refresh(LevelsData.LEVELS[i], solo)
		stars += int(Save.best(LevelModes.record_id(i, solo)).stars)
	_total_label.text = Strings.t("levels_stars_total", {"n": stars, "max": _cards.size() * 3})


func _on_locale_changed(_locale: StringName) -> void:
	if is_open:
		_refresh_cards()


func _on_setting_changed(key: StringName, _value: bool) -> void:
	if key == &"solo" and is_open:
		_refresh_cards()


func _play_in() -> void:
	super._play_in()
	var motion := Feel.motion()
	var first := _page * UiTuning.LEVELS_PAGE_SIZE
	for i in _cards.size():
		var card := _cards[i]
		var slot := i - first
		if slot < 0 or slot >= UiTuning.LEVELS_PAGE_SIZE:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
			continue
		card.scale = Vector2.ONE * (1.0 - 0.25 * motion)
		card.modulate.a = 0.0
		var tween := card.create_tween().set_parallel()
		tween.tween_property(card, "scale", Vector2.ONE, UiTuning.CARD_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(slot * UiTuning.CARD_STAGGER)
		tween.tween_property(card, "modulate:a", 1.0, UiTuning.CARD_POP_TIME * 0.6).set_delay(slot * UiTuning.CARD_STAGGER)
