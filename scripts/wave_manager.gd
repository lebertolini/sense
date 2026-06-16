extends Node
## Autoload. Registra os parametros globais do shader de sonar e gerencia
## ate N ondas simultaneas num ring buffer, avancando o tempo de cada uma.

const N := 6
const SPEED := 50.0
const LIFETIME := 0.8
const DIST_LIFETIME := 0.015
const MAX_DIST := 220.0
const CONE := 0.0  # 0 = hemisferio frontal completo (toda a frente do personagem)
const COOLDOWN := 3.0

signal cooldown_changed(progress: float, ready: bool)
signal wave_used

var _elapsed := []
var _active := []
var _origins := []
var _dirs := []
var _next := 0
var _cutoff := 0.0
var _cooldown_remaining := 0.0
var _is_wave_ready := true

var player  # referencia opcional ao player (definida pelo player no _ready)

func _ready() -> void:
	for i in N:
		_elapsed.append(-1000.0)
		_active.append(false)
		_origins.append(Vector3.ZERO)
		_dirs.append(Vector3.FORWARD)

	# Os globals do shader sao declarados em [shader_globals] no project.godot.
	# Aqui apenas garantimos os valores escalares e zeramos as ondas.
	RenderingServer.global_shader_parameter_set("wave_speed", SPEED)
	RenderingServer.global_shader_parameter_set("wave_lifetime", LIFETIME)
	RenderingServer.global_shader_parameter_set("wave_dist_lifetime", DIST_LIFETIME)
	RenderingServer.global_shader_parameter_set("wave_max_dist", MAX_DIST)
	RenderingServer.global_shader_parameter_set("wave_cone", CONE)
	for i in N:
		RenderingServer.global_shader_parameter_set("wave_%d" % i, Vector4(0, 0, 0, -1000))

	# Tempo total ate uma onda sumir por completo em qualquer canto da sala.
	_cutoff = MAX_DIST / SPEED + LIFETIME + MAX_DIST * DIST_LIFETIME + 0.5
	cooldown_changed.emit(1.0, true)

func is_wave_ready() -> bool:
	return _is_wave_ready

func get_cooldown_progress() -> float:
	if _is_wave_ready:
		return 1.0
	return clampf(1.0 - _cooldown_remaining / COOLDOWN, 0.0, 1.0)

func emit_wave(origin: Vector3, dir: Vector3 = Vector3.FORWARD) -> bool:
	if not _is_wave_ready:
		return false

	_origins[_next] = origin
	_dirs[_next] = dir.normalized()
	_elapsed[_next] = 0.0
	_active[_next] = true
	RenderingServer.global_shader_parameter_set(
		"wave_dir_%d" % _next, Vector4(_dirs[_next].x, _dirs[_next].y, _dirs[_next].z, 0.0))
	_next = (_next + 1) % N

	_is_wave_ready = false
	_cooldown_remaining = COOLDOWN
	wave_used.emit()
	cooldown_changed.emit(0.0, false)
	return true

func _process(delta: float) -> void:
	if not _is_wave_ready:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
		if _cooldown_remaining <= 0.0:
			_is_wave_ready = true
		cooldown_changed.emit(get_cooldown_progress(), _is_wave_ready)

	for i in N:
		if not _active[i]:
			continue
		_elapsed[i] += delta
		if _elapsed[i] > _cutoff:
			_active[i] = false
			RenderingServer.global_shader_parameter_set(
				"wave_%d" % i, Vector4(0, 0, 0, -1000.0))
		else:
			var o: Vector3 = _origins[i]
			RenderingServer.global_shader_parameter_set(
				"wave_%d" % i, Vector4(o.x, o.y, o.z, _elapsed[i]))
