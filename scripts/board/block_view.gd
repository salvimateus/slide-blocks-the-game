extends Node2D
## One jelly block: shadow, body and two eyes. All motion is native tweens, and only a blink timer runs at rest.
## Node chain: self (cell position) > bob (hops and pushes) > jelly (pivot and squash) > content > body, flash, face.

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")

const DIRS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
const EYE_OFFSET := Vector2(21, -5)
const DOWN := 1

var hue := 0
var mood: StringName = &"open"

var _shadow: Sprite2D
var _bob: Node2D
var _jelly: Node2D
var _content: Node2D
var _body: Sprite2D
var _flash: Sprite2D
var _face: Node2D
var _eyes: Array[Sprite2D] = []
var _blink: Timer
var _rng := RandomNumberGenerator.new()

var _scale_tw: Tween
var _bob_tw: Tween
var _face_tw: Tween
var _eye_tw: Tween
var _flash_tw: Tween
var _shadow_tw: Tween
var _tint_tw: Tween
var _move_tw: Tween


func _init() -> void:
	_shadow = Sprite2D.new()
	_shadow.position = Vector2(0, BoardTuning.BLOCK_SHADOW_Y)
	add_child(_shadow)
	_bob = Node2D.new()
	add_child(_bob)
	_jelly = Node2D.new()
	_bob.add_child(_jelly)
	_content = Node2D.new()
	_jelly.add_child(_content)
	_body = Sprite2D.new()
	_content.add_child(_body)
	_flash = Sprite2D.new()
	_flash.visible = false
	_content.add_child(_flash)
	_face = Node2D.new()
	_content.add_child(_face)
	for side in [-1.0, 1.0]:
		var eye := Sprite2D.new()
		eye.position = Vector2(EYE_OFFSET.x * side, EYE_OFFSET.y)
		_face.add_child(eye)
		_eyes.append(eye)
	_blink = Timer.new()
	_blink.one_shot = true
	_blink.timeout.connect(_on_blink)
	add_child(_blink)


func _ready() -> void:
	_schedule_blink()


func setup(p_hue: int, seed_value: int) -> void:
	_rng.seed = seed_value
	_shadow.texture = TextureBank.tex(&"block_shadow")
	_flash.texture = TextureBank.tex(&"block_mask")
	set_hue(p_hue)
	reset_pose()


func set_hue(p_hue: int) -> void:
	hue = p_hue
	_body.texture = TextureBank.block(hue)


## Kills every tween and puts the block at rest, with open eyes.
func reset_pose() -> void:
	for tw in [_scale_tw, _bob_tw, _face_tw, _eye_tw, _flash_tw, _shadow_tw, _tint_tw, _move_tw]:
		if tw != null:
			tw.kill()
	_bob.position = Vector2.ZERO
	_set_pivot(Vector2.ZERO)
	_jelly.scale = Vector2.ONE
	_face.position = Vector2.ZERO
	_shadow.scale = Vector2.ONE
	_flash.visible = false
	modulate = Color.WHITE
	_body.modulate = Color.WHITE
	set_mood(&"open")


## Ends the motion juice of a ceremony at once, and keeps the mood.
func settle() -> void:
	var keep := mood
	reset_pose()
	set_mood(keep)


func set_mood(p_mood: StringName) -> void:
	mood = p_mood
	if _eye_tw != null:
		_eye_tw.kill()
	_apply_mood()


## Turns the face toward `dir`, or back to the center for -1.
func look(dir: int) -> void:
	var target := Vector2.ZERO if dir < 0 else DIRS[dir] * BoardTuning.EYE_LOOK * BoardTuning.PITCH
	_face_tw = _renew(_face_tw)
	_face_tw.tween_property(_face, "position", target, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Stretch along the motion.
func start_motion(dir: int) -> void:
	_set_pivot(Vector2.ZERO)
	look(dir)
	var s := BoardTuning.STRETCH * Feel.motion()
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", _axis_scale(dir, s, -s * 0.55), BoardTuning.STRETCH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Swaps the stretch axis along a rail arc of `time` seconds.
func turn_motion(new_dir: int, time: float) -> void:
	var s := BoardTuning.STRETCH * Feel.motion()
	look(new_dir)
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", Vector2.ONE, time * 0.5).set_trans(Tween.TRANS_SINE)
	_scale_tw.tween_property(_jelly, "scale", _axis_scale(new_dir, s, -s * 0.55), time * 0.5).set_trans(Tween.TRANS_SINE)


## Jelly squash with the contact edge fixed on the wall, then an elastic return. `amount` is the squash share.
func squash(dir: int, amount: float) -> void:
	var half := BoardTuning.BLOCK_SIZE * 0.5
	_set_pivot(DIRS[dir] * (half.y if dir <= DOWN else half.x))
	_jelly.scale = _axis_scale(dir, -amount, amount * BoardTuning.SQUASH_SPREAD)
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", Vector2.ONE, BoardTuning.SQUASH_RETURN_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	squint()


## The wobble of a block that another block hits from the side opposite to `dir`.
func jiggle(dir: int, power: float) -> void:
	var motion := Feel.motion()
	if _scale_tw == null or not _scale_tw.is_running():
		var j := BoardTuning.BUMP_JIGGLE * (0.5 + 0.5 * power) * motion
		_set_pivot(Vector2.ZERO)
		_jelly.scale = _axis_scale(dir, -j, j)
		_scale_tw = _renew(_scale_tw)
		_scale_tw.tween_property(_jelly, "scale", Vector2.ONE, BoardTuning.BUMP_JIGGLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_push(DIRS[dir] * BoardTuning.PITCH * BoardTuning.BUMP_PUSH * (0.5 + 0.5 * power) * motion, BoardTuning.BUMP_JIGGLE_TIME)
	squint()


## The no-move nudge: a short lean toward `dir` and a spring back.
func nudge(dir: int) -> void:
	look(dir)
	var motion := Feel.motion()
	_set_pivot(Vector2.ZERO)
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", _axis_scale(dir, -0.06 * motion, 0.05 * motion), BoardTuning.NUDGE_TIME * 0.3)
	_scale_tw.tween_property(_jelly, "scale", Vector2.ONE, BoardTuning.NUDGE_TIME * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bob_tw = _renew(_bob_tw)
	_bob_tw.tween_property(_bob, "position", DIRS[dir] * BoardTuning.PITCH * BoardTuning.NUDGE_DISTANCE * motion, BoardTuning.NUDGE_TIME * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bob_tw.tween_property(_bob, "position", Vector2.ZERO, BoardTuning.NUDGE_TIME * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func squint() -> void:
	if mood != &"open":
		return
	_set_eyes(&"eye_squint", true)
	_eye_tw = _renew(_eye_tw)
	_eye_tw.tween_interval(BoardTuning.EYE_SQUINT_TIME)
	_eye_tw.tween_callback(_apply_mood)


## A jump in place, with a land squash. Heights are in board units.
func hop(height: float, time: float, delay: float = 0.0) -> void:
	var h := height * Feel.motion()
	_bob_tw = _renew(_bob_tw)
	if delay > 0.0:
		_bob_tw.tween_interval(delay)
	_bob_tw.tween_callback(_takeoff)
	_bob_tw.tween_property(_bob, "position:y", -h, time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bob_tw.tween_property(_bob, "position:y", 0.0, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bob_tw.tween_callback(squash.bind(DOWN, 0.16 * Feel.motion()))
	_shadow_tw = _renew(_shadow_tw)
	if delay > 0.0:
		_shadow_tw.tween_interval(delay)
	_shadow_tw.tween_property(_shadow, "scale", Vector2.ONE * 0.7, time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shadow_tw.tween_property(_shadow, "scale", Vector2.ONE, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The level intro: the block falls from `height` and lands with a squash. `on_land` runs at the landing.
func drop_in(height: float, time: float, delay: float, on_land: Callable) -> void:
	reset_pose()
	_bob.position.y = -height
	modulate.a = 0.0
	_shadow.scale = Vector2.ONE * 0.3
	_bob_tw = _renew(_bob_tw)
	_bob_tw.tween_interval(delay)
	_bob_tw.tween_callback(_takeoff)
	_bob_tw.tween_property(_bob, "position:y", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bob_tw.tween_callback(squash.bind(DOWN, 0.28 * Feel.motion()))
	_bob_tw.tween_callback(on_land)
	_tint_tw = _renew(_tint_tw)
	_tint_tw.tween_interval(delay)
	_tint_tw.tween_property(self, "modulate:a", 1.0, minf(0.12, time))
	_shadow_tw = _renew(_shadow_tw)
	_shadow_tw.tween_interval(delay)
	_shadow_tw.tween_property(_shadow, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The restart: a hop from the current place to `target`. The color changes at the top of the hop.
func hop_to(target: Vector2, time: float, delay: float, new_hue: int, on_land: Callable) -> void:
	reset_pose()
	var h := BoardTuning.RESTART_HOP * BoardTuning.PITCH * Feel.motion()
	_move_tw = _renew(_move_tw)
	_move_tw.tween_interval(delay)
	_move_tw.tween_property(self, "position", target, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tw = _renew(_bob_tw)
	_bob_tw.tween_interval(delay)
	_bob_tw.tween_callback(_takeoff)
	_bob_tw.tween_property(_bob, "position:y", -h, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bob_tw.tween_callback(set_hue.bind(new_hue))
	_bob_tw.tween_callback(flash_white)
	_bob_tw.tween_property(_bob, "position:y", 0.0, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bob_tw.tween_callback(squash.bind(DOWN, 0.2 * Feel.motion()))
	_bob_tw.tween_callback(on_land)


## Defeat: the block sags on its bottom edge, grays a little and looks sad.
func deflate() -> void:
	set_mood(&"sad")
	_set_pivot(Vector2(0, BoardTuning.BLOCK_SIZE.y * 0.5))
	var target := _deflated_scale()
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", target, BoardTuning.DEFEAT_DEFLATE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_face_tw = _renew(_face_tw)
	_face_tw.tween_property(_face, "position", Vector2(0, 7), BoardTuning.DEFEAT_DEFLATE_TIME).set_trans(Tween.TRANS_SINE)
	_tint_tw = _renew(_tint_tw)
	_tint_tw.tween_property(_body, "modulate", Color(0.88, 0.88, 0.9), BoardTuning.DEFEAT_DEFLATE_TIME)


## The end pose of `deflate`, at once.
func deflate_now() -> void:
	reset_pose()
	set_mood(&"sad")
	_set_pivot(Vector2(0, BoardTuning.BLOCK_SIZE.y * 0.5))
	_jelly.scale = _deflated_scale()
	_face.position = Vector2(0, 7)
	_body.modulate = Color(0.88, 0.88, 0.9)


func flash_white() -> void:
	_flash.visible = true
	_flash.modulate = Color(1, 1, 1, 0.85)
	_flash_tw = _renew(_flash_tw)
	_flash_tw.tween_property(_flash, "modulate:a", 0.0, 0.25)
	_flash_tw.tween_callback(_flash.hide)


func _deflated_scale() -> Vector2:
	var d := lerpf(1.0, BoardTuning.DEFEAT_DEFLATE, Feel.motion())
	return Vector2(1.0 + (1.0 - d) * 0.55, d)


func _takeoff() -> void:
	_set_pivot(Vector2(0, BoardTuning.BLOCK_SIZE.y * 0.5))
	_jelly.scale = Vector2(0.9, 1.12)
	_scale_tw = _renew(_scale_tw)
	_scale_tw.tween_property(_jelly, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _push(offset: Vector2, time: float) -> void:
	_bob_tw = _renew(_bob_tw)
	_bob.position = offset
	_bob_tw.tween_property(_bob, "position", Vector2.ZERO, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The pivot is the point of the jelly that a scale keeps in place.
func _set_pivot(p: Vector2) -> void:
	_jelly.position = p
	_content.position = -p


func _axis_scale(dir: int, along: float, across: float) -> Vector2:
	if dir <= DOWN:
		return Vector2(1.0 + across, 1.0 + along)
	return Vector2(1.0 + along, 1.0 + across)


func _apply_mood() -> void:
	match mood:
		&"happy":
			_set_eyes(&"eye_happy", false)
		&"sad":
			_set_eyes(&"eye_sad", true)
		_:
			_set_eyes(&"eye_open", false)


func _set_eyes(key: StringName, mirror: bool) -> void:
	var t := TextureBank.tex(key)
	for i in _eyes.size():
		_eyes[i].texture = t
		_eyes[i].flip_h = mirror and i == 1
		_eyes[i].scale = Vector2.ONE


func _schedule_blink() -> void:
	_blink.start(_rng.randf_range(BoardTuning.BLINK_INTERVAL_MIN, BoardTuning.BLINK_INTERVAL_MAX))


func _on_blink() -> void:
	if mood == &"open" and (_eye_tw == null or not _eye_tw.is_running()):
		var half := BoardTuning.BLINK_TIME * 0.5
		_eye_tw = _renew(_eye_tw).set_parallel(true)
		var count := 2 if _rng.randf() < BoardTuning.BLINK_DOUBLE_CHANCE else 1
		for n in count:
			for eye in _eyes:
				_eye_tw.tween_property(eye, "scale:y", 0.12, half)
			_eye_tw.chain()
			for eye in _eyes:
				_eye_tw.tween_property(eye, "scale:y", 1.0, half)
			_eye_tw.chain()
	_schedule_blink()


func _renew(tw: Tween) -> Tween:
	if tw != null:
		tw.kill()
	return create_tween()
