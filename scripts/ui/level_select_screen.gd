extends "res://scripts/ui/screen.gd"
## Level select: a back button, the star total and 8 cards in two columns.

const LevelsData := preload("res://scripts/core/levels_data.gd")
const LevelCard := preload("res://scripts/ui/level_card.gd")

const COLUMNS := 2

var _cards: Array[Button] = []
var _total_label: Label


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
	var title := UiTheme.label(Strings.t("levels_title"), UiTuning.SIZE_HEADING, UiTuning.WEIGHT_BOLD, Palette.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
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

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	stack.add_child(grid)
	for i in LevelsData.LEVELS.size():
		var card: Button = LevelCard.new().setup_card(LevelsData.LEVELS[i], i)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.chosen.connect(func(index: int) -> void: Game.start_level(index))
		grid.add_child(card)
		_cards.append(card)


func _fill(_data: Dictionary) -> void:
	var stars := 0
	for i in _cards.size():
		var def: Dictionary = LevelsData.LEVELS[i]
		_cards[i].refresh(def)
		stars += int(Save.best(def.id).stars)
	_total_label.text = Strings.t("levels_stars_total", {"n": stars, "max": _cards.size() * 3})


func _play_in() -> void:
	super._play_in()
	var motion := Feel.motion()
	for i in _cards.size():
		var card := _cards[i]
		card.scale = Vector2.ONE * (1.0 - 0.25 * motion)
		card.modulate.a = 0.0
		var tween := card.create_tween().set_parallel()
		tween.tween_property(card, "scale", Vector2.ONE, UiTuning.CARD_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * UiTuning.CARD_STAGGER)
		tween.tween_property(card, "modulate:a", 1.0, UiTuning.CARD_POP_TIME * 0.6).set_delay(i * UiTuning.CARD_STAGGER)
