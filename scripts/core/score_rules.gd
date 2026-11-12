extends RefCounted


static func ceil10(n: int) -> int:
	@warning_ignore("integer_division")
	return (n + 9) / 10


static func thresholds(min_moves: int, index: int) -> Dictionary:
	var three_max := maxi(min_moves + 1, ceil10(min_moves * 12))
	var two_max := maxi(three_max + 2, ceil10(min_moves * 16))
	var factor10 := maxi(19, 26 - index)
	var limit := maxi(two_max + 3, ceil10(min_moves * factor10) + 2)
	return {
		"min": min_moves,
		"three_max": three_max,
		"two_max": two_max,
		"limit": limit,
		"tension_moves": maxi(2, ceil10(limit)),
	}


static func stars_for(moves: int, t: Dictionary) -> int:
	if moves <= t.three_max:
		return 3
	if moves <= t.two_max:
		return 2
	if moves <= t.limit:
		return 1
	return 0


# Low and high move counts of a star range. Stars 0 gives the moves above the limit.
static func range_for(stars: int, t: Dictionary) -> Vector2i:
	match stars:
		3:
			return Vector2i(t.min, t.three_max)
		2:
			return Vector2i(t.three_max + 1, t.two_max)
		1:
			return Vector2i(t.two_max + 1, t.limit)
	return Vector2i(t.limit + 1, t.limit + 1)


static func is_tense(moves_used: int, t: Dictionary) -> bool:
	return t.limit - moves_used <= t.tension_moves
