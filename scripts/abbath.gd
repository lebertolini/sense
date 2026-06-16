extends Node3D
## Abbath: vulto humanoide alto e magro (como na referencia). No escuro e
## invisivel; quando a onda passa, so a LATERAL/silhueta dele acende (ver
## abbath.gdshader). Os olhos tem um brilho fraco constante (mais forte quando
## esta cacando), o unico aviso da sua presenca.
##
## Comportamento:
## - Teleporta para um ponto aleatorio do mapa a cada TELEPORT_INTERVAL segundos.
## - Abbath esta sempre virado para o jogador, mesmo quando nao esta cacando.
## - Se o jogador nao esta escondido pela regra de cobertura (>=60% do corpo
##   tampado), Abbath passa a CACAR: a cada teleporte salta MAIS PERTO do jogador
##   e o intervalo entre teleportes diminui proporcional a proximidade.
## - Se Abbath chega perto demais (CATCH_RANGE) dispara o jumpscare e a tela de
##   reiniciar.
## - Para se livrar dele, o jogador precisa se esconder atras de algo que cubra
##   pelo menos HIDE_COVER (60%) do corpo do campo de visao: ai Abbath perde o
##   alvo e volta para um spawn aleatorio.

# Limites internos do mapa (espelham scripts/level.gd) com margem.
const HALF_X := 60.0
const HALF_Z := 50.0
const EDGE_MARGIN := 4.0

const VISION_RANGE := 45.0                       # alcance maximo da visao
const VISION_COS := 0.819                        # cos(35°): semiangulo do cone
const TELEPORT_INTERVAL := 5.0                   # intervalo base (fora de caca)
const MIN_TELEPORT_INTERVAL := 1.0               # intervalo minimo (bem perto)
const CATCH_RANGE := 3.5                         # distancia que dispara o jumpscare
const APPROACH_FRACTION := 0.45                  # quanto do trajeto cobre por salto
const MIN_APPROACH_DIST := 5.0                   # nao teleporta colado no jogador
const SPAWN_MIN_DIST := 28.0                     # spawn aleatorio longe do jogador
const HIDE_COVER := 0.6                          # 60% do corpo coberto = escondido
const EYE_HEIGHT := 5.35                         # altura dos olhos (origem da visao)

# Amostras verticais do corpo do jogador (a partir dos pes) para a linha de visada.
const BODY_SAMPLES := [0.2, 0.6, 1.0, 1.4, 1.75]

var player                                       # referencia ao jogador
var hunting := false                             # true enquanto o alvo nao esta bem coberto
var _timer := TELEPORT_INTERVAL
var _current_interval := TELEPORT_INTERVAL
var _rng := RandomNumberGenerator.new()

var _body_mat: ShaderMaterial
var _eye_mat: StandardMaterial3D

const EYE_IDLE_ENERGY := 0.7
const EYE_HUNT_ENERGY := 3.5
const MODEL_HEIGHT := 6.25

func _ready() -> void:
	_rng.randomize()

	var shader: Shader = load("res://assets/abbath.gdshader")
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = shader
	_body_mat.set_shader_parameter("preview_reveal", 0.0)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color.BLACK
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.15, 0.12)
	_eye_mat.emission_energy_multiplier = EYE_IDLE_ENERGY

	_build_body()

	AbbathManager.register(self)
	teleport_random()

# --- Construcao do vulto --------------------------------------------------

func _build_body() -> void:
	# Origem nos pes. A silhueta evita simetria perfeita: cabeca baixa, torso
	# inclinado e membros longos demais, para sair do "boneco de capsulas".
	var pelvis := Vector3(0.0, 2.45, 0.08)
	var chest := Vector3(0.0, 4.55, -0.20)
	var neck := Vector3(0.0, 5.18, -0.36)
	var head := Vector3(0.0, 5.73, -0.48)

	_add_bone(Vector3(-0.22, 0.18, 0.02), Vector3(-0.36, 2.55, 0.02), 0.115)
	_add_bone(Vector3(0.24, 0.18, 0.02), Vector3(0.31, 2.48, -0.03), 0.12)
	_add_bone(Vector3(-0.36, 2.55, 0.02), pelvis + Vector3(-0.12, 0.0, 0.02), 0.16)
	_add_bone(Vector3(0.31, 2.48, -0.03), pelvis + Vector3(0.16, 0.0, -0.02), 0.15)
	_add_bone(Vector3(-0.22, 0.12, -0.02), Vector3(-0.56, 0.05, -0.48), 0.08)
	_add_bone(Vector3(0.24, 0.12, -0.02), Vector3(0.65, 0.05, -0.40), 0.08)

	_add_bone(pelvis, chest, 0.20)
	_add_bone(chest, neck, 0.12)
	_add_scaled_sphere(pelvis + Vector3(0.0, 0.10, 0.0), Vector3(0.32, 0.20, 0.20))
	_add_scaled_sphere(chest, Vector3(0.35, 0.54, 0.18))
	_add_scaled_sphere(head, Vector3(0.34, 0.52, 0.24))

	for i in range(5):
		var y := 3.15 + float(i) * 0.28
		var width := 0.50 - float(i) * 0.045
		var z := -0.03 - float(i) * 0.055
		_add_bone(Vector3(-width, y, z), Vector3(width, y + 0.04, z - 0.06), 0.035)

	var shoulder_l := Vector3(-0.48, 4.55, -0.20)
	var shoulder_r := Vector3(0.50, 4.48, -0.22)
	var elbow_l := Vector3(-1.08, 3.05, -0.10)
	var elbow_r := Vector3(1.00, 2.86, -0.02)
	var wrist_l := Vector3(-0.72, 1.10, -0.18)
	var wrist_r := Vector3(0.83, 0.88, -0.18)
	_add_bone(shoulder_l, elbow_l, 0.095)
	_add_bone(elbow_l, wrist_l, 0.075)
	_add_bone(shoulder_r, elbow_r, 0.090)
	_add_bone(elbow_r, wrist_r, 0.070)
	_add_claws(wrist_l, -1.0)
	_add_claws(wrist_r, 1.0)

	_add_back_spikes(chest, neck)
	_add_eye(Vector3(-0.105, 5.80, -0.705), -0.25)
	_add_eye(Vector3(0.105, 5.78, -0.705), 0.25)

func set_preview_reveal(enabled: bool) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("preview_reveal", 0.75 if enabled else 0.0)

func _add_bone(a: Vector3, b: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = a.distance_to(b)
	cap.radial_segments = 10
	cap.rings = 4
	mi.mesh = cap
	mi.material_override = _body_mat
	mi.transform = Transform3D(_basis_from_y_axis(b - a), (a + b) * 0.5)
	add_child(mi)

func _add_scaled_sphere(center: Vector3, scale: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = _body_mat
	mi.position = center
	mi.scale = scale
	add_child(mi)

func _add_claws(wrist: Vector3, side: float) -> void:
	for i in range(4):
		var spread := (float(i) - 1.5) * 0.09
		var root := wrist + Vector3(spread * side, -0.02, -0.02)
		var tip := wrist + Vector3((0.10 + absf(spread) * 0.8) * side, -0.70 - float(i % 2) * 0.08, -0.28)
		_add_taper(root, tip, 0.025, 0.006)

func _add_back_spikes(chest: Vector3, neck: Vector3) -> void:
	var points := [
		Vector3(0.0, 3.75, 0.02),
		Vector3(0.0, 4.18, -0.06),
		Vector3(0.0, 4.62, -0.18),
		Vector3(0.0, 5.02, -0.30),
	]
	for p in points:
		_add_taper(p, p + Vector3(0.0, 0.14, 0.34), 0.035, 0.0)

func _add_taper(a: Vector3, b: Vector3, bottom_radius: float, top_radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_radius
	cm.top_radius = top_radius
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _body_mat
	mi.transform = Transform3D(_basis_from_y_axis(b - a), (a + b) * 0.5)
	add_child(mi)

func _basis_from_y_axis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var helper := Vector3.FORWARD
	if absf(y.dot(helper)) > 0.96:
		helper = Vector3.RIGHT
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _add_capsule(center: Vector3, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	mi.mesh = cap
	mi.material_override = _body_mat
	mi.position = center
	add_child(mi)

func _add_sphere(center: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _body_mat
	mi.position = center
	add_child(mi)

func _add_eye(center: Vector3, slant: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.025
	cap.height = 0.18
	cap.radial_segments = 8
	mi.mesh = cap
	mi.material_override = _eye_mat
	mi.position = center
	mi.rotation.z = slant
	add_child(mi)

# --- Visao -----------------------------------------------------------------

func _eye_origin() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT

# Fracao do corpo do jogador (0..1) com linha de visada limpa a partir dos olhos
# de Abbath. Conta como "coberto" qualquer amostra cuja visada bate em geometria
# antes de chegar ao corpo. O jogador e excluido para nao se auto-bloquear.
func visible_fraction() -> float:
	if player == null:
		return 0.0
	var space := get_world_3d().direct_space_state
	var eye := _eye_origin()
	var clear := 0
	for off in BODY_SAMPLES:
		var pt: Vector3 = player.global_position + Vector3.UP * off
		var q := PhysicsRayQueryParameters3D.create(eye, pt)
		q.exclude = [player.get_rid()]
		if space.intersect_ray(q).is_empty():
			clear += 1
	return float(clear) / float(BODY_SAMPLES.size())

# True se o jogador esta dentro do cone frontal e do alcance da visao.
func is_player_in_cone() -> bool:
	if player == null:
		return false
	var to: Vector3 = player.global_position - global_position
	var dist := to.length()
	if dist > VISION_RANGE or dist < 0.001:
		return false
	var forward := -global_transform.basis.z
	return forward.dot(to / dist) >= VISION_COS

# Abbath "ve" o jogador se ele esta no cone E menos de 60% do corpo esta coberto.
func can_see_player() -> bool:
	if not is_player_in_cone():
		return false
	return visible_fraction() > (1.0 - HIDE_COVER)

# A caca nao depende mais do cone: Abbath sempre olha para o jogador. A unica
# trava da aproximacao agressiva e a cobertura de pelo menos 60% do corpo.
func can_hunt_player() -> bool:
	if player == null:
		return false
	return visible_fraction() > (1.0 - HIDE_COVER)

# --- Teleporte -------------------------------------------------------------

# Intervalo proporcional a proximidade: perto = mais rapido, longe = base.
func compute_interval(dist: float) -> float:
	var t := clampf(dist / VISION_RANGE, 0.0, 1.0)
	return lerpf(MIN_TELEPORT_INTERVAL, TELEPORT_INTERVAL, t)

func teleport_random() -> void:
	var pos := global_position
	for _attempt in 40:
		var px := _rng.randf_range(-HALF_X + EDGE_MARGIN, HALF_X - EDGE_MARGIN)
		var pz := _rng.randf_range(-HALF_Z + EDGE_MARGIN, HALF_Z - EDGE_MARGIN)
		if player != null:
			var d := Vector2(px, pz).distance_to(Vector2(player.global_position.x, player.global_position.z))
			if d < SPAWN_MIN_DIST:
				continue
		pos = Vector3(px, 0.0, pz)
		break
	global_position = pos
	if player != null:
		face(player.global_position)
	else:
		rotation.y = _rng.randf_range(-PI, PI)

# Salta na direcao do jogador, cobrindo parte do trajeto, sem grudar nele.
func teleport_closer() -> void:
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.001:
		return
	var dir := to / dist
	var target_dist := maxf(dist * (1.0 - APPROACH_FRACTION), MIN_APPROACH_DIST)
	var new_pos: Vector3 = player.global_position - dir * target_dist
	new_pos.y = 0.0
	new_pos.x = clampf(new_pos.x, -HALF_X + EDGE_MARGIN, HALF_X - EDGE_MARGIN)
	new_pos.z = clampf(new_pos.z, -HALF_Z + EDGE_MARGIN, HALF_Z - EDGE_MARGIN)
	global_position = new_pos
	face(player.global_position)

# Gira (so yaw) para encarar um ponto. -Z e a frente do vulto.
func face(target: Vector3) -> void:
	var dx := target.x - global_position.x
	var dz := target.z - global_position.z
	if absf(dx) < 0.0001 and absf(dz) < 0.0001:
		return
	rotation.y = atan2(-dx, -dz)

# --- Loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null or AbbathManager.caught:
		return

	face(player.global_position)

	if can_hunt_player():
		hunting = true
		var dist := global_position.distance_to(player.global_position)
		if dist <= CATCH_RANGE:
			_catch()
			return
		_current_interval = compute_interval(dist)
	elif hunting:
		# Jogador ficou >=60% coberto: perde a caca e volta para um spawn aleatorio.
		hunting = false
		teleport_random()
		_timer = TELEPORT_INTERVAL
		_current_interval = TELEPORT_INTERVAL
		_update_eyes()
		return
	else:
		_current_interval = TELEPORT_INTERVAL

	_update_eyes()

	_timer -= delta
	if _timer <= 0.0:
		if hunting:
			teleport_closer()
			var d := global_position.distance_to(player.global_position)
			_timer = compute_interval(d)
		else:
			teleport_random()
			_timer = TELEPORT_INTERVAL

func _update_eyes() -> void:
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = EYE_HUNT_ENERGY if hunting else EYE_IDLE_ENERGY

func _catch() -> void:
	AbbathManager.trigger_jumpscare()
	set_process(false)
