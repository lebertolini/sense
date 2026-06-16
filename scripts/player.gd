extends CharacterBody3D
## Player em primeira pessoa. WASD move, mouse olha, barra de espaco emite a onda.

const SPEED := 6.0
const ACCEL := 12.0
const GRAVITY := 22.0
const MOUSE_SENS := 0.0028

var head: Camera3D
var _pitch := -0.12

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

	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not (args.has("--autotest") or args.has("--tablettest") or args.has("--doortest") or args.has("--abbathtest") or args.has("--abbathmodeltest")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_emit_origin() -> Vector3:
	return head.global_position

func get_emit_dir() -> Vector3:
	# Frente do corpo (horizontal), independente da inclinacao da camera,
	# para a onda cobrir toda a frente do personagem.
	return -global_transform.basis.z

func get_look_dir() -> Vector3:
	# Direcao real da camera (com inclinacao), usada para mirar nos tablets.
	return -head.global_transform.basis.z

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		head.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			WaveManager.emit_wave(get_emit_origin(), get_emit_dir())
		elif event.physical_keycode == KEY_E:
			# E ativa um tablet; sem tablet na mira, tenta abrir a saida.
			if not TabletManager.try_activate(get_emit_origin(), get_look_dir()):
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
