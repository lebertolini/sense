extends CharacterBody3D
## Player em primeira pessoa. WASD move, mouse olha, barra de espaco emite a onda.

const SPEED := 6.0
const ACCEL := 12.0
const GRAVITY := 22.0
const MOUSE_SENS := 0.0028

# Passos: comecam a tocar quando a velocidade horizontal passa esse limiar.
const WALK_MIN_SPEED := 0.6
# Bus dedicado para aplicar o reverb da sala so nos passos.
const FOOTSTEPS_BUS := &"Footsteps"
const WALKING_SOUND := "res://sounds/walking.ogg"

var head: Camera3D
var _pitch := -0.12
var _footsteps: AudioStreamPlayer
var _tablet_minigame_active := false

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8
	cap.radius = 0.4
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	head = Camera3D.new()
	head.position = Vector3(0, 1.6, 0)
	head.fov = 75.0
	head.far = 200.0
	head.current = true
	add_child(head)
	head.rotation.x = _pitch

	WaveManager.player = self

	_setup_footsteps()

	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not (args.has("--autotest") or args.has("--tablettest") or args.has("--doortest") or args.has("--abbathtest") or args.has("--abbathmodeltest")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Cria um bus dedicado com reverb calibrado para a sala (~120x100x14m,
# paredes/pilares/chao duros) e prende um AudioStreamPlayer em loop nele.
func _setup_footsteps() -> void:
	var bus_idx := AudioServer.get_bus_index(FOOTSTEPS_BUS)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, FOOTSTEPS_BUS)
		AudioServer.set_bus_send(bus_idx, &"Master")
		# Reverb suave de sala grande. Sem feedback no predelay (evita
		# ressonancia metalica) e damping alto pra absorver os agudos.
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.85
		reverb.damping = 0.6
		reverb.spread = 0.75
		reverb.predelay_msec = 80.0
		reverb.predelay_feedback = 0.0
		reverb.wet = 0.35
		reverb.dry = 0.95
		reverb.hipass = 0.1
		AudioServer.add_bus_effect(bus_idx, reverb)

	_footsteps = AudioStreamPlayer.new()
	_footsteps.bus = FOOTSTEPS_BUS
	_footsteps.volume_db = -4.0
	var stream: AudioStream = load(WALKING_SOUND)
	if stream != null:
		# Loop continuo enquanto o personagem anda.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_footsteps.stream = stream
	else:
		push_warning("Som de passos nao encontrado em %s (Godot nao importa .m4a; converta para .ogg ou .mp3)." % WALKING_SOUND)
	add_child(_footsteps)

func get_emit_origin() -> Vector3:
	return head.global_position

func get_emit_dir() -> Vector3:
	# Frente do corpo (horizontal), independente da inclinacao da camera,
	# para a onda cobrir toda a frente do personagem.
	return -global_transform.basis.z

func get_look_dir() -> Vector3:
	# Direcao real da camera (com inclinacao), usada para mirar nos tablets.
	return -head.global_transform.basis.z

func set_tablet_minigame_active(active: bool) -> void:
	_tablet_minigame_active = active

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _tablet_minigame_active:
		rotation.y -= event.relative.x * MOUSE_SENS
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		head.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if _tablet_minigame_active:
			if event.physical_keycode == KEY_E:
				TabletManager.cancel_minigame()
			return
		if event.physical_keycode == KEY_SPACE:
			WaveManager.emit_wave(get_emit_origin(), get_emit_dir())
		elif event.physical_keycode == KEY_E:
			# E ativa um tablet; sem tablet na mira, tenta abrir a saida.
			if not TabletManager.try_activate(get_emit_origin(), get_look_dir(), self):
				DoorManager.try_open(get_emit_origin(), get_look_dir())
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0

	var dir := (transform.basis * input_dir)
	dir.y = 0.0
	dir = dir.normalized()

	var target := dir * SPEED
	var k := clampf(ACCEL * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target.x, k)
	velocity.z = lerpf(velocity.z, target.z, k)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()
	_update_footsteps()

func _update_footsteps() -> void:
	if _footsteps == null or _footsteps.stream == null:
		return
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var should_play := is_on_floor() and horiz_speed > WALK_MIN_SPEED
	if should_play:
		# Pitch acompanha a velocidade pra cadencia parecer natural.
		_footsteps.pitch_scale = clampf(0.85 + (horiz_speed / SPEED) * 0.3, 0.85, 1.15)
		if not _footsteps.playing:
			_footsteps.play()
	elif _footsteps.playing:
		_footsteps.stop()
