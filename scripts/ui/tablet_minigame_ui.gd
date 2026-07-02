extends Control
## Desafio visual dos tablets: ajustar por scroll a intensidade da malha ondulada.

const NEON_GREEN := Color(0.25, 1.0, 0.75)
const TARGET_WHITE := Color(1.0, 1.0, 1.0, 0.5)
const AURA_WHITE := Color(1.0, 1.0, 1.0, 0.75)
const RING_COUNT := 3
const POINTS := 192
const LINE_WIDTH := 3.0
const SCROLL_STEP := 0.08
const MATCH_TOLERANCE := 0.22
const PLAYER_SHAPE_MAX := 1.75
const PLAYER_SHAPE_SMOOTH_SPEED := 4.5
const WAVE_BINS := 24
const WAVE_RESHAPE_INTERVAL := 0.7

var _tablet = null
var _player = null
var _stage := 0
var _hold_time := 0.0
var _target_phase := 0.0
var _player_shape := 0.0
var _player_shape_target := 0.0
var _shape_time := 0.0
var _wave_reshape_time := 0.0
var _wave_values: Array[float] = []
var _wave_next_values: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _active := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	TabletManager.tablet_minigame_requested.connect(_on_requested)
	TabletManager.tablet_minigame_cancelled.connect(_on_cancelled)

func _on_requested(tablet, player) -> void:
	_tablet = tablet
	_player = player
	_stage = TabletManager.get_stage(tablet)
	_hold_time = 0.0
	_target_phase = 0.0
	_player_shape = 0.0
	_player_shape_target = 0.0
	_shape_time = 0.0
	_wave_reshape_time = 0.0
	_rng.randomize()
	_wave_values = _make_random_wave_values()
	_wave_next_values = _make_random_wave_values()
	_active = true
	visible = true
	if _player != null and is_instance_valid(_player) and _player.has_method("set_tablet_minigame_active"):
		_player.set_tablet_minigame_active(true)
	queue_redraw()

func _on_cancelled() -> void:
	_hide_ui()

func _hide_ui() -> void:
	_active = false
	visible = false
	_tablet = null
	_player = null
	_hold_time = 0.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_player_shape_target = clampf(_player_shape_target + SCROLL_STEP, 0.0, PLAYER_SHAPE_MAX)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_player_shape_target = clampf(_player_shape_target - SCROLL_STEP, 0.0, PLAYER_SHAPE_MAX)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		TabletManager.cancel_minigame()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _active:
		return
	if _should_cancel_for_distance():
		TabletManager.cancel_minigame()
		return

	_shape_time += delta
	_update_wave_map(delta)
	var k := 1.0 - exp(-PLAYER_SHAPE_SMOOTH_SPEED * delta)
	_player_shape = lerpf(_player_shape, _player_shape_target, k)
	if _is_aligned():
		_hold_time += delta
		if _hold_time >= _hold_required():
			_complete_stage()
	else:
		# Ao perder o encaixe, o tempo fica pausado como pedido.
		_hold_time = _hold_time
	queue_redraw()

func _should_cancel_for_distance() -> bool:
	if _tablet == null or not is_instance_valid(_tablet):
		return true
	if _player == null or not is_instance_valid(_player):
		return false
	var origin: Vector3 = _player.get_emit_origin()
	var look_dir: Vector3 = _player.get_look_dir()
	return TabletManager.find_target(origin, look_dir) != _tablet

func _is_aligned() -> bool:
	return absf(_player_shape - _target_shape()) <= MATCH_TOLERANCE

func _complete_stage() -> void:
	_stage += 1
	_hold_time = 0.0
	if _stage >= RING_COUNT:
		var t = _tablet
		_hide_ui()
		TabletManager.complete_minigame(t)
		return
	TabletManager.save_stage(_tablet, _stage)
	_player_shape = 0.0
	_player_shape_target = 0.0

func _draw() -> void:
	if not _active:
		return
	var center := size * 0.5
	var base_radius := minf(size.x, size.y) * 0.15
	var spacing := minf(size.x, size.y) * 0.085
	for i in _stage:
		_draw_completed_ring(center, base_radius + spacing * i)
	var radius := base_radius + spacing * _stage
	_draw_target_ring(center, radius)
	_draw_player_ring(center, radius)
	_draw_progress_arc(center, radius + 24.0)

func _draw_target_ring(center: Vector2, radius: float) -> void:
	var pts := _make_wave_points(center, radius, _target_phase, _target_shape())
	draw_polyline(pts, TARGET_WHITE, LINE_WIDTH, true)

func _draw_player_ring(center: Vector2, radius: float) -> void:
	var pts := _make_wave_points(center, radius, _target_phase, _player_shape)
	draw_polyline(pts, AURA_WHITE, LINE_WIDTH + 5.0, true)
	draw_polyline(pts, NEON_GREEN, LINE_WIDTH, true)

func _draw_completed_ring(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, POINTS, AURA_WHITE, LINE_WIDTH + 5.0, true)
	draw_arc(center, radius, 0.0, TAU, POINTS, NEON_GREEN, LINE_WIDTH, true)

func _draw_progress_arc(center: Vector2, radius: float) -> void:
	var progress := clampf(_hold_time / _hold_required(), 0.0, 1.0)
	if progress <= 0.0:
		return
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, NEON_GREEN, 2.0, true)

func _make_wave_points(center: Vector2, radius: float, phase: float, shape_amount: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var amp := radius * (0.14 + 0.026 * sin(_shape_time * 1.6 + float(_stage)))
	for i in range(POINTS + 1):
		var a := TAU * float(i) / float(POINTS)
		var wave := _wave_profile(a - phase)
		var r := radius + amp * shape_amount * wave
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

func _target_shape() -> float:
	var pulse := (sin(_shape_time * 5.8 + float(_stage) * 0.9) + 1.0) * 0.5
	var snap := pow(pulse, 0.42)
	var ripple := 0.12 * sin(_shape_time * 11.4 + float(_stage) * 1.7)
	return clampf(lerpf(0.18, 1.42, snap) + ripple, 0.1, 1.58)

func _hold_required() -> float:
	return float(_stage + 1)

func _update_wave_map(delta: float) -> void:
	if _wave_values.is_empty() or _wave_next_values.is_empty():
		_wave_values = _make_random_wave_values()
		_wave_next_values = _make_random_wave_values()
	_wave_reshape_time += delta
	while _wave_reshape_time >= WAVE_RESHAPE_INTERVAL:
		_wave_reshape_time -= WAVE_RESHAPE_INTERVAL
		_wave_values = _wave_next_values
		_wave_next_values = _make_random_wave_values()

func _make_random_wave_values() -> Array[float]:
	var values: Array[float] = []
	for i in WAVE_BINS:
		var low := sin(float(i) * 0.65 + _rng.randf_range(-0.35, 0.35)) * 0.28
		var mid := sin(float(i) * 1.15 + _rng.randf_range(-0.55, 0.55)) * 0.18
		var height := 0.9 + low + mid
		if _rng.randf() < 0.12:
			height += _rng.randf_range(0.35, 0.75)
		elif _rng.randf() < 0.18:
			height -= _rng.randf_range(0.22, 0.45)
		height = clampf(height, 0.42, 1.65)
		values.append(height)
	return values

func _random_wave_scale(a: float) -> float:
	if _wave_values.is_empty() or _wave_next_values.is_empty():
		return 1.0
	var x := wrapf(a / TAU, 0.0, 1.0) * float(WAVE_BINS)
	var i0 := int(floor(x)) % WAVE_BINS
	var i1 := (i0 + 1) % WAVE_BINS
	var f := smoothstep(0.0, 1.0, x - floor(x))
	var now := lerpf(_wave_values[i0], _wave_values[i1], f)
	var next := lerpf(_wave_next_values[i0], _wave_next_values[i1], f)
	var blend := smoothstep(0.0, 1.0, _wave_reshape_time / WAVE_RESHAPE_INTERVAL)
	return lerpf(now, next, blend)

func _wave_profile(a: float) -> float:
	var t := _shape_time
	var morph := (sin(t * 5.6 + float(_stage) * 0.8) + 1.0) * 0.5
	var carrier: float = (
		sin(a * 7.0 + 0.35) * 0.46
		+ sin(a * 11.0 + 1.2) * 0.28
		+ sin(a * 17.0 + 2.1) * 0.16
		+ sin(a * 23.0 + 0.4) * 0.10
	)
	var envelope := _random_wave_scale(a)
	var rounded: float = carrier * envelope
	var tuned: float = sign(rounded) * pow(absf(rounded), 0.82) * 1.08
	var breath: float = sin(a * 3.0 + float(_stage) * 0.7) * 0.045 * envelope
	var radio_wave := lerpf(rounded, tuned, morph)
	return clampf(radio_wave + breath, -1.0, 1.0)
