extends RefCounted
## All colors of the game. Four reference colors; every other color derives from them.

# References.
const CREAM := Color("#FFF3E3")
const MINT := Color("#D5E8E6")
const PERIWINKLE := Color("#9FA0FF")
const CORAL := Color("#FF7171")

# Derived.
const INK := Color("#282559")
const INK_SOFT := Color("#494A7A")
const SCRIM := Color("#1B193F")
const TRAY_WELL := Color("#7471D6")
const TRAY_SHADOW := Color("#5E59BB")
const TRAY_HIGHLIGHT := Color("#CDD0FE")
const FLOOR_SHADOW := Color("#A5C5C3")
const FLOOR_DIMPLE := Color("#B9D4D2")
const MINT_LIGHT := Color("#EBF6F5")
const CREAM_LIGHT := Color("#FFF9F1")
const CREAM_SHADOW := Color("#E6D1B4")
const CORAL_DEEP := Color("#D33944")
const CORAL_SOFT := Color("#FEC8C5")
const STAR := Color("#F0B135")
const STAR_DEEP := Color("#B87501")
const GRAY_TILE := Color("#B6B7BE")

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
