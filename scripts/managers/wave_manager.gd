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
const SHARED_CHARGE_RECHARGE_PER_SECOND := 1.0 / COOLDOWN
const SUPER_HEARING_DRAIN_PER_SECOND := 0.28
const WAVE_SOUND := "res://sounds/wave.ogg"
const WAVE_SOUND_VOLUME_DB := -2.0
const WAVE_SOUND_SILENCE_DB := -60.0
const WAVE_SOUND_DUCK_DB := -14.0
const FOOTSTEPS_BUS := &"Footsteps"
const FOOTSTEPS_NORMAL_DB := 0.0
const FOOTSTEPS_DUCK_DB := -18.0

enum Ability { WAVE, SUPER_HEARING }

signal cooldown_changed(progress: float, ready: bool)
signal wave_used
signal ability_changed(ability: int)
signal super_hearing_changed(active: bool, charge: float)

var _elapsed := []
var _active := []
var _origins := []
var _dirs := []
var _next := 0
var _cutoff := 0.0
var _cooldown_remaining := 0.0  # compat: testes antigos ainda forcam este campo
var _is_wave_ready := true
var _wave_sound: AudioStreamPlayer
var _wave_sound_elapsed := 0.0
var _selected_ability := Ability.WAVE
var _shared_charge := 1.0
var _super_hearing_requested := false
var _super_hearing_active := false

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
	_setup_wave_sound()
	cooldown_changed.emit(1.0, true)
	ability_changed.emit(_selected_ability)
	super_hearing_changed.emit(false, _shared_charge)

func _setup_wave_sound() -> void:
	_wave_sound = AudioStreamPlayer.new()
	_wave_sound.volume_db = WAVE_SOUND_VOLUME_DB
	var stream: AudioStream = load(WAVE_SOUND)
	if stream == null:
		push_warning("Som da onda nao encontrado em %s." % WAVE_SOUND)
	else:
		# A onda deve tocar uma unica vez a cada uso.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_wave_sound.stream = stream
	add_child(_wave_sound)

func is_wave_ready() -> bool:
	return _is_wave_ready

func selected_ability() -> int:
	return _selected_ability

func is_wave_selected() -> bool:
	return _selected_ability == Ability.WAVE

func is_super_hearing_selected() -> bool:
	return _selected_ability == Ability.SUPER_HEARING

func is_super_hearing_active() -> bool:
	return _super_hearing_active

func get_super_hearing_charge() -> float:
	return _shared_charge

func toggle_ability() -> void:
	set_selected_ability(Ability.SUPER_HEARING if _selected_ability == Ability.WAVE else Ability.WAVE)

func set_selected_ability(ability: int) -> void:
	if ability == _selected_ability:
		return
	_selected_ability = ability
	if _selected_ability != Ability.SUPER_HEARING:
		set_super_hearing_requested(false)
	ability_changed.emit(_selected_ability)
	cooldown_changed.emit(get_cooldown_progress(), is_selected_ability_ready())

func is_selected_ability_ready() -> bool:
	if _selected_ability == Ability.SUPER_HEARING:
		return _shared_charge > 0.0
	return is_wave_ready()

func set_super_hearing_requested(requested: bool) -> void:
	_super_hearing_requested = requested and _selected_ability == Ability.SUPER_HEARING

## True se a frente de alguma onda ativa ja alcancou `point` (dentro do alcance
## maximo). Usado por superficies que precisam reagir a passagem da onda no CPU
## (ex.: a porta de saida que mantem a moldura acesa depois de revelada).
func has_reached(point: Vector3) -> bool:
	for i in N:
		if not _active[i]:
			continue
		var d: float = _origins[i].distance_to(point)
		if d <= MAX_DIST and _elapsed[i] * SPEED >= d:
			return true
	return false

## Reseta as ondas e o cooldown ao estado inicial (usado ao reiniciar o jogo).
func reset() -> void:
	for i in N:
		_elapsed[i] = -1000.0
		_active[i] = false
		_origins[i] = Vector3.ZERO
		_dirs[i] = Vector3.FORWARD
		RenderingServer.global_shader_parameter_set("wave_%d" % i, Vector4(0, 0, 0, -1000))
	_next = 0
	_cooldown_remaining = 0.0
	_is_wave_ready = true
	_wave_sound_elapsed = 0.0
	_selected_ability = Ability.WAVE
	_shared_charge = 1.0
	_super_hearing_requested = false
	_set_super_hearing_active(false)
	if _wave_sound != null:
		_wave_sound.stop()
	cooldown_changed.emit(1.0, true)
	ability_changed.emit(_selected_ability)
	super_hearing_changed.emit(false, _shared_charge)

func get_cooldown_progress() -> float:
	return _shared_charge

func emit_wave(origin: Vector3, dir: Vector3 = Vector3.FORWARD) -> bool:
	if _selected_ability != Ability.WAVE:
		return false
	if not is_wave_ready():
		return false

	_origins[_next] = origin
	_dirs[_next] = dir.normalized()
	_elapsed[_next] = 0.0
	_active[_next] = true
	RenderingServer.global_shader_parameter_set(
		"wave_dir_%d" % _next, Vector4(_dirs[_next].x, _dirs[_next].y, _dirs[_next].z, 0.0))
	_next = (_next + 1) % N

	_shared_charge = 0.0
	_cooldown_remaining = COOLDOWN
	_is_wave_ready = false
	_play_wave_sound()
	wave_used.emit()
	cooldown_changed.emit(0.0, false)
	return true

func _process(delta: float) -> void:
	_update_wave_sound(delta)
	_update_shared_charge(delta)

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

func _play_wave_sound() -> void:
	if _wave_sound == null or _wave_sound.stream == null:
		return
	_wave_sound_elapsed = 0.0
	_wave_sound.volume_db = _current_wave_sound_base_db()
	_wave_sound.play()

func _update_wave_sound(delta: float) -> void:
	if _wave_sound == null or not _wave_sound.playing:
		return
	_wave_sound_elapsed += delta
	var distance: float = minf(_wave_sound_elapsed * SPEED, MAX_DIST)
	var distance_ratio: float = distance / MAX_DIST
	# A amplitude cai conforme o raio da onda cresce. A curva cubica deixa o
	# fim do arquivo praticamente inaudivel, sem interromper sua cauda.
	var amplitude: float = pow(1.0 - distance_ratio, 3.0)
	_wave_sound.volume_db = maxf(
		_current_wave_sound_base_db() + linear_to_db(amplitude),
		WAVE_SOUND_SILENCE_DB)

func _update_shared_charge(delta: float) -> void:
	var prev_charge := _shared_charge
	var was_wave_ready := is_wave_ready()
	if _super_hearing_requested and _shared_charge > 0.0:
		_shared_charge = maxf(_shared_charge - SUPER_HEARING_DRAIN_PER_SECOND * delta, 0.0)
	elif not _super_hearing_requested:
		_shared_charge = minf(_shared_charge + SHARED_CHARGE_RECHARGE_PER_SECOND * delta, 1.0)
	_is_wave_ready = _shared_charge >= 1.0
	_cooldown_remaining = (1.0 - _shared_charge) * COOLDOWN
	_set_super_hearing_active(_super_hearing_requested and _shared_charge > 0.0)
	if not is_equal_approx(prev_charge, _shared_charge) or was_wave_ready != is_wave_ready():
		super_hearing_changed.emit(_super_hearing_active, _shared_charge)
		cooldown_changed.emit(_shared_charge, is_selected_ability_ready())

func _set_super_hearing_active(active: bool) -> void:
	if active == _super_hearing_active:
		return
	_super_hearing_active = active
	_apply_super_hearing_mix()
	super_hearing_changed.emit(_super_hearing_active, _shared_charge)

func _apply_super_hearing_mix() -> void:
	var footstep_idx := AudioServer.get_bus_index(FOOTSTEPS_BUS)
	if footstep_idx != -1:
		AudioServer.set_bus_volume_db(footstep_idx, FOOTSTEPS_DUCK_DB if _super_hearing_active else FOOTSTEPS_NORMAL_DB)
	if _wave_sound != null:
		_wave_sound.volume_db = _current_wave_sound_base_db()

func _current_wave_sound_base_db() -> float:
	return WAVE_SOUND_DUCK_DB if _super_hearing_active else WAVE_SOUND_VOLUME_DB
