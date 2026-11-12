extends RefCounted

const NONE := 0
const NW := 1
const NE := 2
const SW := 3
const SE := 4

var id: String
var index: int
var name_key: String
var hint_key: String
var cols: int
var rows: int
var cells: int
var floor_cells: PackedByteArray
var obstacle: PackedByteArray
var deflector: PackedByteArray
var floor_bit: PackedInt32Array
var starts: PackedInt32Array
var floor_count: int
var step: PackedInt32Array
var errors: PackedStringArray


func is_valid() -> bool:
	return errors.is_empty()


func col_of(cell: int) -> int:
	return cell % cols


func row_of(cell: int) -> int:
	@warning_ignore("integer_division")
	return cell / cols
