extends RefCounted
# Pure on purpose: it does not read ParData, so tools/levels_tool.gd can load it before the first par write.

const SUFFIX := "_solo"


## The one-block map of `def`: block `keep` becomes block 1, the other block glyphs become floor,
## and each cell of `walls` (index y * cols + x) becomes "X". The id gets SUFFIX, the hint key is "".
static func make_def(def: Dictionary, keep: int, walls: Array) -> Dictionary:
	var source: Array = def.get("rows", [])
	var kept := str(keep)
	var rows: Array[String] = []
	for line in source:
		var text := ""
		for ch in String(line):
			if ch == kept:
				text += "1"
			elif ch >= "1" and ch <= "9":
				text += "."
			else:
				text += ch
		rows.append(text)
	var cols := rows[0].length() if not rows.is_empty() else 0
	for cell in walls if cols > 0 else []:
		@warning_ignore("integer_division")
		var y: int = int(cell) / cols
		var x: int = int(cell) % cols
		rows[y] = rows[y].substr(0, x) + "X" + rows[y].substr(x + 1)
	return {
		"id": String(def.get("id", "")) + SUFFIX,
		"name_key": String(def.get("name_key", "")),
		"hint_key": "",
		"rows": rows,
	}
