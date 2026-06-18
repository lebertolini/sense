extends Node3D
## Abbath: vulto humanoide alto e magro (como na referencia). No escuro e
## invisivel; quando a onda passa, so a LATERAL/silhueta dele acende (ver
## abbath.gdshader). Os olhos tem um brilho fraco constante (mais forte quando
## esta cacando), o unico aviso da sua presenca.
##
## Comportamento:
## - Teleporta para um ponto aleatorio do mapa a cada TELEPORT_INTERVAL segundos.
## - Abbath esta sempre virado para o jogador, mesmo quando nao esta cacando.
## - Se o jogador nao esta suficientemente escondido, Abbath passa a CACAR: a
##   cada teleporte salta MAIS PERTO do jogador e o intervalo entre teleportes
##   diminui proporcional a proximidade.
## - A exigencia de "estar escondido" cresce com a distancia: bem longe exige
##   100% do corpo coberto (qualquer parte visivel ja dispara a caca); bem perto
##   exige apenas HIDE_COVER_NEAR (60%). Entre esses extremos a regra interpola
##   linearmente.
## - A aproximacao nao e em linha reta: o salto cai em algum ponto ao redor do
##   campo de visao do jogador (frontal ou lateral) e, se houver pilares no
##   trajeto, cada pilar tem 50% de chance de virar esconderijo (Abbath aparece
##   atras dele com cerca de 30% do corpo ainda visivel).
## - Se Abbath chega perto demais (CATCH_RANGE) dispara o jumpscare e a tela de
##   reiniciar.

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
const HIDE_COVER_NEAR := 0.6                     # bem perto: 60% coberto ja conta como escondido
const HIDE_COVER_FAR := 1.0                      # bem longe: precisa estar 100% coberto
const HIDE_COVER := HIDE_COVER_NEAR               # compat: regra "minima" usada na visao a curta distancia
const EYE_HEIGHT := 6.10                         # altura dos olhos (origem da visao)

# Aproximacao: arco ao redor da direcao do olhar do player onde o teleporte
# pode aterrissar (em radianos). PI*0.61 ~ 110 graus de cada lado: frente +
# laterais, evitando que Abbath caia diretamente atras do jogador.
const APPROACH_ARC := PI * 0.61
# Chance, por pilar candidato, de Abbath usar o pilar como esconderijo no
# proximo teleporte. Rolada de forma independente para cada pilar entre Abbath
# e o jogador, do mais proximo ao mais longe do jogador.
const PILLAR_COVER_CHANCE := 0.5
# Quanto Abbath desliza para o lado quando se esconde atras de um pilar
# (fracao do raio do pilar). Calibrado para deixar ~30% do corpo visivel.
const PILLAR_LATERAL_FACTOR := 0.85
# Folga atras do pilar (em unidades) entre o raio e o corpo de Abbath.
const PILLAR_BEHIND_MARGIN := 0.6

# Amostras verticais do corpo do jogador (a partir dos pes) para a linha de visada.
const BODY_SAMPLES := [0.2, 0.6, 1.0, 1.4, 1.75]

var player                                       # referencia ao jogador
var pillars: Array = []                          # cilindros do mapa: {center, radius, height}
var hunting := false                             # true enquanto o alvo nao esta bem coberto
var _timer := TELEPORT_INTERVAL
var _current_interval := TELEPORT_INTERVAL
var _rng := RandomNumberGenerator.new()
# True quando o ultimo salto foi atras de um pilar. Nesse caso o pilar bloqueia
# o raycast da visao DO PROPRIO Abbath (ele tambem perderia o player), mas a
# intencao do salto e justamente espreitar pelo lado. Mantemos a caca ate o
# proximo teleporte, que reavalia normalmente.
var _cover_locked := false

var _body_mat: ShaderMaterial
var _eye_mat: StandardMaterial3D
var _model: Node3D                                # raiz do .glb instanciado
var _body_parts := []                             # MeshInstance3D do corpo (recebem o shader)
var _model_preview := false                       # mostra os materiais reais do .glb

const EYE_IDLE_ENERGY := 0.7
const EYE_HUNT_ENERGY := 3.5
const MODEL_HEIGHT := 6.65                         # altura final do vulto na cena

# Modelo 3D da criatura (substitui o vulto procedural antigo).
const MODEL_PATH := "res://assets/abbath.glb"
# Se o .glb nao encarar -Z (a frente do Abbath), gire-o aqui (em radianos).
# Este modelo foi autorado encarando +Z, entao gira meia-volta.
const MODEL_YAW := PI
# Olhos brilhantes (unico aviso da presenca no escuro). Posicao derivada da
# caixa do modelo; ajuste estas fracoes se nao casarem com o rosto do .glb.
const EYE_HEIGHT_FRACTION := 0.905                 # altura dos olhos (fracao da altura)
const EYE_SPREAD_FRACTION := 0.075                 # separacao (fracao da largura)
const EYE_FRONT_FRACTION := 0.92                   # avanco a frente (fracao da meia-profundidade)
const EYE_RADIUS := 0.06

func _ready() -> void:
	_rng.randomize()

	var shader: Shader = load("res://assets/abbath.gdshader")
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = shader
	_body_mat.set_shader_parameter("preview_reveal", 0.0)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color.BLACK
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.86, 0.91, 1.0)
	_eye_mat.emission_energy_multiplier = EYE_IDLE_ENERGY

	_build_body()

	AbbathManager.register(self)
	teleport_random()

# --- Construcao do vulto a partir do modelo 3D ----------------------------

func _build_body() -> void:
	# Instancia o .glb, normaliza a escala para MODEL_HEIGHT e centra com os pes
	# na origem. Origem nos pes mantem o resto do codigo (visao, teleporte) igual.
	var packed: PackedScene = load(MODEL_PATH)
	_model = packed.instantiate()
	add_child(_model)

	_collect_body_parts(_model)
	_fit_model_to_scene()
	_apply_body_material()
	_add_eyes()

# Reune todos os MeshInstance3D do modelo (recebem o shader da silhueta).
func _collect_body_parts(node: Node) -> void:
	if node is MeshInstance3D:
		_body_parts.append(node)
	for child in node.get_children():
		_collect_body_parts(child)

# Caixa envolvente do modelo no espaco local da raiz do Abbath.
func _model_local_aabb() -> AABB:
	var result := AABB()
	var first := true
	var inv := global_transform.affine_inverse()
	for mi in _body_parts:
		if mi.mesh == null:
			continue
		var rel: Transform3D = inv * mi.global_transform
		var box: AABB = rel * mi.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

# Escala uniforme + recentro: altura = MODEL_HEIGHT, pes em y=0, centrado em x/z.
# Aplica escala e rotacao primeiro e so entao recentra, para o resultado ficar
# correto com qualquer MODEL_YAW (a rotacao desloca o centro em x/z).
func _fit_model_to_scene() -> void:
	var raw := _model_local_aabb()
	var s := MODEL_HEIGHT / maxf(raw.size.y, 0.001)
	_model.scale = Vector3(s, s, s)
	_model.rotation.y = MODEL_YAW
	var aabb := _model_local_aabb()
	var cx := aabb.position.x + aabb.size.x * 0.5
	var cz := aabb.position.z + aabb.size.z * 0.5
	_model.position = -Vector3(cx, aabb.position.y, cz)

func _apply_body_material() -> void:
	for mi in _body_parts:
		mi.material_override = null if _model_preview else _body_mat

# Dois olhos emissivos perto do topo e a frente do modelo ja dimensionado.
func _add_eyes() -> void:
	var aabb := _model_local_aabb()
	var s := MODEL_HEIGHT / maxf(aabb.size.y, 0.001)
	var width := aabb.size.x * s
	var depth := aabb.size.z * s
	var eye_y := MODEL_HEIGHT * EYE_HEIGHT_FRACTION
	var eye_x := width * EYE_SPREAD_FRACTION * 0.5
	var eye_z := -(depth * 0.5) * EYE_FRONT_FRACTION
	_add_eye(Vector3(-eye_x, eye_y, eye_z))
	_add_eye(Vector3(eye_x, eye_y, eye_z))

func set_preview_reveal(enabled: bool) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("preview_reveal", 0.75 if enabled else 0.0)

# Liga/desliga a visualizacao do modelo: mostra os materiais reais do .glb
# (em vez do shader de silhueta) para inspecionar o que foi importado.
func set_model_preview(enabled: bool) -> void:
	_model_preview = enabled
	set_preview_reveal(false)
	_apply_body_material()

func _add_eye(center: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = EYE_RADIUS
	sm.height = EYE_RADIUS * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _eye_mat
	mi.position = center
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

# Fracao MINIMA do corpo que precisa estar coberta para o player ser considerado
# escondido NESSA distancia. Longe: 100% (qualquer pedaco visivel dispara a caca).
# Perto: HIDE_COVER_NEAR (60%). Interpola linear entre CATCH_RANGE e VISION_RANGE.
func hide_cover_required(dist: float) -> float:
	var span := maxf(VISION_RANGE - CATCH_RANGE, 0.001)
	var t := clampf((dist - CATCH_RANGE) / span, 0.0, 1.0)
	return lerpf(HIDE_COVER_NEAR, HIDE_COVER_FAR, t)

# Versao testavel da regra: dado uma distancia e uma fracao visivel do corpo,
# diz se Abbath cacaria. Usada pelo loop e pelos testes determinisicos.
func would_hunt_at(dist: float, visible: float) -> bool:
	return visible > (1.0 - hide_cover_required(dist))

# Abbath "ve" o jogador se ele esta no cone E o corpo nao esta coberto o
# bastante para a distancia atual.
func can_see_player() -> bool:
	if not is_player_in_cone():
		return false
	var dist := global_position.distance_to(player.global_position)
	return would_hunt_at(dist, visible_fraction())

# A caca nao depende mais do cone: Abbath sempre olha para o jogador. A trava
# da aproximacao agressiva e a cobertura exigida na distancia atual.
func can_hunt_player() -> bool:
	if player == null:
		return false
	var dist := global_position.distance_to(player.global_position)
	return would_hunt_at(dist, visible_fraction())

# --- Teleporte -------------------------------------------------------------

# Intervalo proporcional a proximidade: perto = mais rapido, longe = base.
func compute_interval(dist: float) -> float:
	var t := clampf(dist / VISION_RANGE, 0.0, 1.0)
	return lerpf(MIN_TELEPORT_INTERVAL, TELEPORT_INTERVAL, t)

func teleport_random() -> void:
	_cover_locked = false
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

# Salta para mais perto do jogador. A direcao nao e a linha reta: cai num
# angulo aleatorio em torno do olhar do player (frente ou lateral). Se houver
# pilares no trajeto, cada um tem PILLAR_COVER_CHANCE de virar esconderijo
# (Abbath aparece atras dele, com ~30% do corpo ainda a vista).
func teleport_closer() -> void:
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.001:
		return
	var target_dist := maxf(dist * (1.0 - APPROACH_FRACTION), MIN_APPROACH_DIST)
	var new_pos := _pick_pillar_cover_pos(dist)
	var used_cover := new_pos != Vector3.INF
	if not used_cover:
		new_pos = _lateral_approach_pos(target_dist)
	new_pos.y = 0.0
	new_pos.x = clampf(new_pos.x, -HALF_X + EDGE_MARGIN, HALF_X - EDGE_MARGIN)
	new_pos.z = clampf(new_pos.z, -HALF_Z + EDGE_MARGIN, HALF_Z - EDGE_MARGIN)
	global_position = new_pos
	_cover_locked = used_cover
	face(player.global_position)

# Direcao horizontal que o jogador esta olhando (so yaw). Cai em FORWARD se o
# vetor for degenerado.
func _player_forward() -> Vector3:
	var f: Vector3 = -player.global_transform.basis.z
	f.y = 0.0
	var l := f.length()
	if l < 0.001:
		return Vector3.FORWARD
	return f / l

# Posicao final para uma aproximacao lateral/frontal: random no arco em torno
# do olhar do player, a `target_dist` dele. Angulo 0 = na cara do player;
# +-APPROACH_ARC ja entra na zona lateral. Nunca passa para tras (essa zona so
# e acessada por trips de pilar).
func _lateral_approach_pos(target_dist: float) -> Vector3:
	var angle := _rng.randf_range(-APPROACH_ARC, APPROACH_ARC)
	var dir := _player_forward().rotated(Vector3.UP, angle)
	return Vector3(
		player.global_position.x + dir.x * target_dist,
		0.0,
		player.global_position.z + dir.z * target_dist
	)

# Procura um pilar entre Abbath e o player para usar como cobertura. Roda
# PILLAR_COVER_CHANCE por candidato (do mais perto ao player ao mais longe);
# o primeiro sorteado vence. Retorna Vector3.INF quando nenhum aceita.
func _pick_pillar_cover_pos(current_dist: float) -> Vector3:
	if player == null or pillars.is_empty():
		return Vector3.INF
	var pp: Vector3 = player.global_position
	var candidates: Array = []
	for p in pillars:
		var pc: Vector3 = p["center"]
		var pr: float = p["radius"]
		var d2p := Vector2(pc.x - pp.x, pc.z - pp.z).length()
		# Precisa estar entre Abbath e o player, longe o suficiente para nao
		# nascer dentro do CATCH_RANGE.
		if d2p >= current_dist:
			continue
		if d2p <= CATCH_RANGE + pr + 0.5:
			continue
		candidates.append({"center": pc, "radius": pr, "d2p": d2p})
	candidates.sort_custom(func(a, b): return a["d2p"] < b["d2p"])
	for c in candidates:
		if _rng.randf() < PILLAR_COVER_CHANCE:
			return _position_behind_pillar(c["center"], c["radius"])
	return Vector3.INF

# Coloca Abbath atras do pilar (lado oposto ao player) com um deslize lateral
# para o corpo "espreitar" pela borda. Lado esquerdo/direito sai aleatorio.
func _position_behind_pillar(pc: Vector3, pr: float) -> Vector3:
	var to: Vector3 = pc - player.global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.001:
		return Vector3.INF
	var dir := to / d
	var lat := Vector3(-dir.z, 0.0, dir.x)
	var lateral := pr * PILLAR_LATERAL_FACTOR
	if _rng.randf() < 0.5:
		lateral = -lateral
	var behind := pr + PILLAR_BEHIND_MARGIN
	return Vector3(
		pc.x + dir.x * behind + lat.x * lateral,
		0.0,
		pc.z + dir.z * behind + lat.z * lateral
	)

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

	if _cover_locked or can_hunt_player():
		hunting = true
		var dist := global_position.distance_to(player.global_position)
		if dist <= CATCH_RANGE:
			_catch()
			return
		_current_interval = compute_interval(dist)
	elif hunting:
		# Jogador ficou coberto o bastante para a distancia: perde a caca e
		# volta para um spawn aleatorio.
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
