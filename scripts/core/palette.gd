extends RefCounted
## All colors of the game. Four reference colors; every other color derives from them.
## The theme colors are static vars that `apply(theme)` sets from LIGHT or DARK. Code reads them when it builds a node,
## so a theme change builds the nodes again (Game.apply_theme). The block family and SHADE are the same in both themes.

const THEMES: Array[StringName] = [&"light", &"dark"]

const LIGHT := {
	# References.
	&"CREAM": Color("#FFF3E3"),
	&"MINT": Color("#D5E8E6"),
	&"PERIWINKLE": Color("#9FA0FF"),
	&"CORAL": Color("#FF7171"),
	# Derived.
	&"INK": Color("#282559"),
	&"INK_SOFT": Color("#494A7A"),
	&"SCRIM": Color("#1B193F"),
	&"TRAY_WELL": Color("#7471D6"),
	&"TRAY_SHADOW": Color("#5E59BB"),
	&"TRAY_HIGHLIGHT": Color("#CDD0FE"),
	&"FLOOR_SHADOW": Color("#A5C5C3"),
	&"FLOOR_DIMPLE": Color("#B9D4D2"),
	&"MINT_LIGHT": Color("#EBF6F5"),
	&"CREAM_LIGHT": Color("#FFF9F1"),
	&"CREAM_SHADOW": Color("#E6D1B4"),
	&"CORAL_DEEP": Color("#D33944"),
	&"CORAL_SOFT": Color("#FEC8C5"),
	&"STAR": Color("#F0B135"),
	&"STAR_DEEP": Color("#B87501"),
	&"GRAY_TILE": Color("#B6B7BE"),
	&"METER_GOLD": Color("#F8D89C"),   # star mixed with cream_light
	&"KNOB": Color("#FFF9F1"),         # the knob of a switch
	&"JELLY_FACE": Color("#EBF6F5"),   # the body of a jelly icon in a settings row
	# Obstacle: a raised wall block, darker than every paint color and block body.
	&"OBSTACLE_TOP": Color("#6C68D0"),
	&"OBSTACLE_SIDE": Color("#47429A"),
	&"OBSTACLE_EDGE": Color("#8E8BEA"),
}

## Night candy: the cream surfaces turn to deep indigo from SCRIM, the ink turns to cream.
const DARK := {
	&"CREAM": Color("#1F1D4A"),
	&"MINT": Color("#2E4E5E"),
	&"PERIWINKLE": Color("#5B58D6"),
	&"CORAL": Color("#FF7171"),
	&"INK": Color("#FFF4E6"),
	&"INK_SOFT": Color("#D2CEF4"),
	&"SCRIM": Color("#0B0A20"),
	&"TRAY_WELL": Color("#34318A"),
	&"TRAY_SHADOW": Color("#24216B"),
	&"TRAY_HIGHLIGHT": Color("#8583F0"),
	&"FLOOR_SHADOW": Color("#17293A"),
	&"FLOOR_DIMPLE": Color("#284656"),
	&"MINT_LIGHT": Color("#24405A"),
	&"CREAM_LIGHT": Color("#2D2A66"),
	&"CREAM_SHADOW": Color("#18163F"),
	&"CORAL_DEEP": Color("#FF9B9B"),
	&"CORAL_SOFT": Color("#7A2E48"),
	&"STAR": Color("#F0B135"),
	&"STAR_DEEP": Color("#B87501"),
	&"GRAY_TILE": Color("#8E8FA8"),
	&"METER_GOLD": Color("#6E521A"),
	&"KNOB": Color("#F3EEFF"),
	&"JELLY_FACE": Color("#CDE8E4"),
	&"OBSTACLE_TOP": Color("#27246E"),
	&"OBSTACLE_SIDE": Color("#15134A"),
	&"OBSTACLE_EDGE": Color("#4A47B0"),
}

## The ink of block eyes and drop shadows, the same in both themes.
const SHADE := Color("#282559")

static var theme: StringName = &"light"

static var CREAM: Color = LIGHT.CREAM
static var MINT: Color = LIGHT.MINT
static var PERIWINKLE: Color = LIGHT.PERIWINKLE
static var CORAL: Color = LIGHT.CORAL
static var INK: Color = LIGHT.INK
static var INK_SOFT: Color = LIGHT.INK_SOFT
static var SCRIM: Color = LIGHT.SCRIM
static var TRAY_WELL: Color = LIGHT.TRAY_WELL
static var TRAY_SHADOW: Color = LIGHT.TRAY_SHADOW
static var TRAY_HIGHLIGHT: Color = LIGHT.TRAY_HIGHLIGHT
static var FLOOR_SHADOW: Color = LIGHT.FLOOR_SHADOW
static var FLOOR_DIMPLE: Color = LIGHT.FLOOR_DIMPLE
static var MINT_LIGHT: Color = LIGHT.MINT_LIGHT
static var CREAM_LIGHT: Color = LIGHT.CREAM_LIGHT
static var CREAM_SHADOW: Color = LIGHT.CREAM_SHADOW
static var CORAL_DEEP: Color = LIGHT.CORAL_DEEP
static var CORAL_SOFT: Color = LIGHT.CORAL_SOFT
static var STAR: Color = LIGHT.STAR
static var STAR_DEEP: Color = LIGHT.STAR_DEEP
static var GRAY_TILE: Color = LIGHT.GRAY_TILE
static var METER_GOLD: Color = LIGHT.METER_GOLD
static var KNOB: Color = LIGHT.KNOB
static var JELLY_FACE: Color = LIGHT.JELLY_FACE
static var OBSTACLE_TOP: Color = LIGHT.OBSTACLE_TOP
static var OBSTACLE_SIDE: Color = LIGHT.OBSTACLE_SIDE
static var OBSTACLE_EDGE: Color = LIGHT.OBSTACLE_EDGE

# Block and paint family, by palette index.
const HUES: Array[int] = [22, 55, 88, 150, 195, 240, 282, 330]
const PAINT: Array[Color] = [
	Color("#F59693"), Color("#EDA06A"), Color("#D3B057"), Color("#7CC98D"),
	Color("#42CBCB"), Color("#6ABEF6"), Color("#A8ABFC"), Color("#DE99D7"),
]
const BODY: Array[Color] = [
	Color("#DF6768"), Color("#D67523"), Color("#B48C05"), Color("#3EAB5E"),
	Color("#05A7A7"), Color("#069CE4"), Color("#8584EB"), Color("#C46DBD"),
]
const OUTLINE: Array[Color] = [
	Color("#A03F40"), Color("#974C00"), Color("#7B5F01"), Color("#137738"),
	Color("#067272"), Color("#026A9D"), Color("#5957AA"), Color("#8B4486"),
]
const FAMILY_SIZE := 8


## Sets the theme colors from `name` (&"light" or &"dark"; any other value gives light).
static func apply(name: StringName) -> void:
	theme = &"dark" if name == &"dark" else &"light"
	var t: Dictionary = DARK if theme == &"dark" else LIGHT
	CREAM = t.CREAM
	MINT = t.MINT
	PERIWINKLE = t.PERIWINKLE
	CORAL = t.CORAL
	INK = t.INK
	INK_SOFT = t.INK_SOFT
	SCRIM = t.SCRIM
	TRAY_WELL = t.TRAY_WELL
	TRAY_SHADOW = t.TRAY_SHADOW
	TRAY_HIGHLIGHT = t.TRAY_HIGHLIGHT
	FLOOR_SHADOW = t.FLOOR_SHADOW
	FLOOR_DIMPLE = t.FLOOR_DIMPLE
	MINT_LIGHT = t.MINT_LIGHT
	CREAM_LIGHT = t.CREAM_LIGHT
	CREAM_SHADOW = t.CREAM_SHADOW
	CORAL_DEEP = t.CORAL_DEEP
	CORAL_SOFT = t.CORAL_SOFT
	STAR = t.STAR
	STAR_DEEP = t.STAR_DEEP
	GRAY_TILE = t.GRAY_TILE
	METER_GOLD = t.METER_GOLD
	KNOB = t.KNOB
	JELLY_FACE = t.JELLY_FACE
	OBSTACLE_TOP = t.OBSTACLE_TOP
	OBSTACLE_SIDE = t.OBSTACLE_SIDE
	OBSTACLE_EDGE = t.OBSTACLE_EDGE


## Palette indices for `count` blocks: a random start k, then k, k+2, k+4, k+6 in a shuffled order.
## Past four blocks, the odd offsets follow, also shuffled.
static func pick_block_hues(count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var k := rng.randi_range(0, FAMILY_SIZE - 1)
	var even := PackedInt32Array()
	var odd := PackedInt32Array()
	for offset in range(0, FAMILY_SIZE, 2):
		even.append((k + offset) % FAMILY_SIZE)
		odd.append((k + offset + 1) % FAMILY_SIZE)
	_shuffle(even, rng)
	_shuffle(odd, rng)
	var all := even + odd
	return all.slice(0, clampi(count, 0, FAMILY_SIZE))


static func _shuffle(list: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held := list[i]
		list[i] = list[j]
		list[j] = held
