extends Node
## Pooled CPUParticles2D emitters of one board, made one time in `attach`. A burst restarts a pooled emitter.
## Glitter has two layers: confetti in normal blend (shows on cream) and an additive glow over the board and the scrim.
## The static switches turn particles or the glow off for every pool (performance panel).

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const Palette := preload("res://scripts/core/palette.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")

const MAX_BLOCKS := 4
const POOL_SIZES := {
	&"splash": 6, &"ring": 6, &"spark": 4, &"glitter": 10, &"glow": 10,
	&"confetti": 2, &"sparkle": 2, &"burst_glow": 2,
}

static var particles_enabled := true
static var glow_enabled := true
static var _pools: Array = []

var _pool := {}
var _next := {}
var _streaks: Array[CPUParticles2D] = []
var _glow_layer: Node2D
var _board_scale := 1.0
var _attached := false


## Turns every particle effect of every pool on or off.
static func set_particles_enabled(on: bool) -> void:
	particles_enabled = on
	for pool in _pools:
		if not on:
			pool.clear()


## Turns the additive glow layer of every pool on or off.
static func set_glow_enabled(on: bool) -> void:
	glow_enabled = on
	for pool in _pools:
		pool.apply_glow()


func _enter_tree() -> void:
	_pools.append(self)


func _exit_tree() -> void:
	_pools.erase(self)


func is_attached() -> bool:
	return _attached


## Makes all emitters. `under` is behind the blocks, `over` is above them, `glow` is the additive layer.
func attach(under: Node2D, over: Node2D, glow: Node2D) -> void:
	if _attached:
		return
	_attached = true
	_glow_layer = glow
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in MAX_BLOCKS:
		_streaks.append(_make_streak(under))
	for kind: StringName in POOL_SIZES:
		var list: Array[CPUParticles2D] = []
		for i in POOL_SIZES[kind]:
			var parent := glow if kind == &"glow" or kind == &"burst_glow" else over
			var e := _make(kind, parent)
			if parent == glow:
				e.material = add_material
			list.append(e)
		_pool[kind] = list
		_next[kind] = 0
	apply_glow()


## The streak particles live in global space, so their size follows the board scale by hand.
func set_board_scale(s: float) -> void:
	_board_scale = s
	for e in _streaks:
		e.scale_amount_min = 0.85 * s
		e.scale_amount_max = 1.0 * s


func set_streak_color(block: int, color: Color) -> void:
	if block < _streaks.size():
		_streaks[block].color = color


func streak(block: int) -> CPUParticles2D:
	return _streaks[block]


func streak_on(block: int, on: bool) -> void:
	if block >= _streaks.size():
		return
	var e := _streaks[block]
	if on and particles_enabled:
		e.visible = true
		e.emitting = true
	else:
		e.emitting = false


## Droplets that fly back from the contact point of a stop.
func splash(pos: Vector2, dir: int, color: Color, tiles: int) -> void:
	var count := _count(mini(BoardTuning.SPLASH_BASE + BoardTuning.SPLASH_PER_TILE * tiles, BoardTuning.SPLASH_MAX))
	var e := _take(&"splash", count)
	if e == null:
		return
	e.position = pos
	e.direction = -_dir_vector(dir)
	e.color = color
	e.restart()


## A ring that grows at the contact point of a stop.
func impact_ring(pos: Vector2, color: Color, power: float) -> void:
	var e := _take(&"ring", 1)
	if e == null:
		return
	e.position = pos
	e.color = Color(color, 0.85)
	e.scale_amount_min = lerpf(0.7, 1.2, power)
	e.scale_amount_max = e.scale_amount_min
	e.restart()


## Sparks where a block turns on a rail.
func rail_spark(pos: Vector2) -> void:
	var e := _take(&"spark", _count(BoardTuning.RAIL_SPARKS))
	if e == null:
		return
	e.position = pos
	e.restart()


## Glitter from every tile of one win ring, in the color of one block. Returns the confetti count.
func ring_glitter(points: PackedVector2Array, hue: int) -> int:
	if points.is_empty():
		return 0
	var count := _count(mini(points.size() * BoardTuning.WIN_GLITTER_PER_TILE, BoardTuning.WIN_GLITTER_RING_MAX))
	var e := _take(&"glitter", count)
	if e == null:
		return 0
	e.texture = TextureBank.glitter(hue)
	e.emission_points = points
	e.restart()
	if glow_enabled:
		var g := _take(&"glow", points.size())
		if g != null:
			g.emission_points = points
			g.restart()
	return count


## The final win burst from `center`, in the colors of the blocks.
func burst(center: Vector2, hues: PackedInt32Array) -> void:
	var colors := PackedColorArray()
	var sparkles := PackedColorArray()
	for h in hues:
		colors.append(Palette.BODY[h])
		sparkles.append(Palette.PAINT[h].lightened(0.35))
	colors.append(Palette.STAR)
	sparkles.append(Color.WHITE)
	var confetti := _take(&"confetti", _count(BoardTuning.WIN_BURST))
	if confetti != null:
		confetti.position = center
		confetti.color_initial_ramp = _stepped(colors)
		confetti.restart()
	var sparkle := _take(&"sparkle", _count(BoardTuning.WIN_BURST_SPARKLES))
	if sparkle != null:
		sparkle.position = center
		sparkle.color_initial_ramp = _stepped(sparkles)
		sparkle.restart()
	if glow_enabled:
		var g := _take(&"burst_glow", _count(10))
		if g != null:
			g.position = center
			g.restart()


## Stops and hides every emitter.
func clear() -> void:
	for e in _streaks:
		e.emitting = false
		e.visible = false
	for kind in _pool:
		for e: CPUParticles2D in _pool[kind]:
			e.emitting = false
			e.visible = false


func apply_glow() -> void:
	if _glow_layer != null:
		_glow_layer.visible = glow_enabled


func _count(base: int) -> int:
	return maxi(1, roundi(base * Feel.motion()))


func _take(kind: StringName, amount: int) -> CPUParticles2D:
	if not particles_enabled or not _attached:
		return null
	var list: Array[CPUParticles2D] = _pool[kind]
	var i: int = _next[kind]
	_next[kind] = (i + 1) % list.size()
	var e := list[i]
	if e.amount != amount:
		e.amount = amount
	e.visible = true
	return e


static func _dir_vector(dir: int) -> Vector2:
	return [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][dir]


static func _stepped(colors: PackedColorArray) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / colors.size())
	g.offsets = offsets
	g.colors = colors
	return g


static func _fade(start_alpha: float, hold: float = 0.0) -> Gradient:
	var g := Gradient.new()
	if hold > 0.0:
		g.offsets = PackedFloat32Array([0.0, hold, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, start_alpha), Color(1, 1, 1, start_alpha), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, start_alpha), Color(1, 1, 1, 0)])
	return g


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	return c


func _base(parent: Node2D, texture: Texture2D, amount: int, lifetime: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.emitting = false
	e.one_shot = true
	e.explosiveness = 1.0
	e.amount = amount
	e.lifetime = lifetime
	e.texture = texture
	e.local_coords = true
	e.visible = false
	e.finished.connect(e.hide)
	parent.add_child(e)
	return e


func _make_streak(parent: Node2D) -> CPUParticles2D:
	var e := _base(parent, TextureBank.particle(&"dot"), BoardTuning.STREAK_AMOUNT, BoardTuning.STREAK_LIFETIME)
	e.one_shot = false
	e.explosiveness = 0.0
	e.local_coords = false
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 6.0
	e.spread = 180.0
	e.initial_velocity_min = 0.0
	e.initial_velocity_max = 18.0
	e.gravity = Vector2.ZERO
	e.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.1)])
	e.color_ramp = _fade(0.6)
	return e


func _make(kind: StringName, parent: Node2D) -> CPUParticles2D:
	var e: CPUParticles2D
	match kind:
		&"splash":
			e = _base(parent, TextureBank.particle(&"droplet"), 8, 0.5)
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			e.emission_sphere_radius = 14.0
			e.spread = 80.0
			e.gravity = Vector2.ZERO
			e.initial_velocity_min = 320.0
			e.initial_velocity_max = 680.0
			e.damping_min = 700.0
			e.damping_max = 1100.0
			e.scale_amount_min = 0.8
			e.scale_amount_max = 1.45
			e.scale_amount_curve = _curve([Vector2(0, 1), Vector2(0.6, 0.8), Vector2(1, 0)])
			e.color_ramp = _fade(1.0, 0.5)
		&"ring":
			e = _base(parent, TextureBank.particle(&"ring"), 1, 0.36)
			e.gravity = Vector2.ZERO
			e.initial_velocity_min = 0.0
			e.initial_velocity_max = 0.0
			e.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.4, 0.85), Vector2(1, 1.2)])
			e.color_ramp = _fade(1.0)
		&"spark":
			e = _base(parent, TextureBank.particle(&"sparkle"), 7, 0.42)
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			e.emission_sphere_radius = 18.0
			e.spread = 180.0
			e.gravity = Vector2.ZERO
			e.initial_velocity_min = 150.0
			e.initial_velocity_max = 340.0
			e.damping_min = 400.0
			e.damping_max = 700.0
			e.angular_velocity_min = -240.0
			e.angular_velocity_max = 240.0
			e.scale_amount_min = 0.35
			e.scale_amount_max = 0.7
			e.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0)])
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 1.0])
			g.colors = PackedColorArray([Palette.CORAL, Color(Palette.CREAM_LIGHT, 0.0)])
			e.color_ramp = g
		&"glitter":
			e = _base(parent, TextureBank.glitter(0), 8, 0.9)
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
			e.direction = Vector2.UP
			e.spread = 75.0
			e.gravity = Vector2(0, 900)
			e.initial_velocity_min = 220.0
			e.initial_velocity_max = 480.0
			e.damping_min = 20.0
			e.damping_max = 60.0
			e.angle_min = 0.0
			e.angle_max = 360.0
			e.angular_velocity_min = -360.0
			e.angular_velocity_max = 360.0
			e.scale_amount_min = 0.85
			e.scale_amount_max = 1.45
			e.scale_amount_curve = _curve([Vector2(0, 0), Vector2(0.12, 1), Vector2(0.7, 0.85), Vector2(1, 0)])
			e.lifetime_randomness = 0.25
		&"glow":
			e = _base(parent, TextureBank.soft(), 4, 0.45)
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
			e.gravity = Vector2.ZERO
			e.initial_velocity_min = 0.0
			e.initial_velocity_max = 0.0
			e.scale_amount_min = 2.2
			e.scale_amount_max = 2.8
			e.scale_amount_curve = _curve([Vector2(0, 0.4), Vector2(0.25, 1), Vector2(1, 0)])
			e.color_ramp = _fade(0.5)
		&"confetti":
			e = _base(parent, TextureBank.particle(&"confetti"), BoardTuning.WIN_BURST, 1.6)
			_burst_motion(e, 380.0, 900.0)
			e.scale_amount_min = 1.6
			e.scale_amount_max = 2.5
			e.color_ramp = _fade(1.0, 0.75)
		&"sparkle":
			e = _base(parent, TextureBank.particle(&"sparkle"), BoardTuning.WIN_BURST_SPARKLES, 1.2)
			_burst_motion(e, 300.0, 750.0)
			e.scale_amount_min = 0.7
			e.scale_amount_max = 1.3
			e.scale_amount_curve = _curve([Vector2(0, 0.2), Vector2(0.15, 1), Vector2(1, 0)])
		&"burst_glow":
			e = _base(parent, TextureBank.soft(), 10, 0.7)
			e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			e.emission_sphere_radius = 220.0
			e.gravity = Vector2.ZERO
			e.initial_velocity_min = 0.0
			e.initial_velocity_max = 60.0
			e.scale_amount_min = 3.5
			e.scale_amount_max = 5.5
			e.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.3, 1), Vector2(1, 0)])
			e.color_ramp = _fade(0.45)
	return e


func _burst_motion(e: CPUParticles2D, v_min: float, v_max: float) -> void:
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 40.0
	e.direction = Vector2.UP
	e.spread = 180.0
	e.gravity = Vector2(0, 900)
	e.initial_velocity_min = v_min
	e.initial_velocity_max = v_max
	e.damping_min = 60.0
	e.damping_max = 140.0
	e.angle_min = 0.0
	e.angle_max = 360.0
	e.angular_velocity_min = -540.0
	e.angular_velocity_max = 540.0
	e.lifetime_randomness = 0.3
