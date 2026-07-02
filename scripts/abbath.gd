extends Node3D
## Abbath: vulto humanoide alto e magro (como na referencia). No escuro e
## invisivel; quando a onda passa, so a LATERAL/silhueta dele acende (ver
## abbath.gdshader). Os olhos tem um brilho fraco constante (mais forte quando
## esta cacando), o unico aviso da sua presenca.
##
## Comportamento:
## - Teleporta para um ponto aleatorio do mapa a cada TELEPORT_INTERVAL segundos.
## - Quando ve o jogador, memoriza sua posicao e salta metade da distancia.
## - Enquanto ele estiver visivel, atualiza essa memoria e carrega o abate.
##   Cinco segundos visiveis acumulados disparam o jumpscare.
## - Se o jogador some, olha para o ultimo ponto por 10 segundos. Reencontra-lo
##   provoca um salto exato de 5 m e renova essa janela sem zerar a carga.
## - A exigencia de "estar escondido" cresce com a distancia: bem longe exige
##   100% do corpo coberto (qualquer parte visivel ja dispara a caca); bem perto
##   exige apenas HIDE_COVER_NEAR (60%). Entre esses extremos a regra interpola
##   linearmente.
## - Em qualquer salto, um pilar a frente e a ate 5 m tem 50% de chance de ser
##   usado. Abbath fica atras dele, 50% exposto para a ultima posicao vista.

# Limites internos do mapa (espelham scripts/level.gd) com margem.
const HALF_X := 60.0
const HALF_Z := 50.0
const EDGE_MARGIN := 4.0

const VISION_RANGE := 45.0                       # alcance maximo da visao
const VISION_COS := 0.819                        # cos(35°): semiangulo do cone
const TELEPORT_INTERVAL := 5.0                   # intervalo base (fora de caca)
const CATCH_RANGE := 3.5                         # referencia da curva de cobertura
const SPAWN_MIN_DIST := 28.0                     # spawn aleatorio longe do jogador
const HIDE_COVER_NEAR := 0.6                     # bem perto: 60% coberto ja conta como escondido
const HIDE_COVER_FAR := 1.0                      # bem longe: precisa estar 100% coberto
const HIDE_COVER := HIDE_COVER_NEAR               # compat: regra "minima" usada na visao a curta distancia
const EYE_HEIGHT := 6.10                         # altura dos olhos (origem da visao)

const PREPARE_DURATION := 10.0                   # janela para reencontrar o jogador
const JUMPSCARE_VISIBLE_DURATION := 5.0           # visao acumulada necessaria para matar
const REACQUIRE_STEP_DISTANCE := 5.0             # salto apos reencontrar o jogador
const PILLAR_SEARCH_DISTANCE := 5.0               # alcance da busca por pilares em cada salto

# Chance unica de usar o pilar valido mais proximo em cada salto de caca.
const PILLAR_COVER_CHANCE := 0.5
# Quanto Abbath desliza para o lado quando se esconde atras de um pilar
# (fracao do raio do pilar). Calibrado para deixar ~50% do corpo visivel.
const PILLAR_LATERAL_FACTOR := 1.15
# Folga atras do pilar (em unidades) entre o raio e o corpo de Abbath.
const PILLAR_BEHIND_MARGIN := 0.6

# Amostras verticais do corpo do jogador (a partir dos pes) para a linha de visada.
const BODY_SAMPLES := [0.2, 0.6, 1.0, 1.4, 1.75]

var player                                       # referencia ao jogador
var pillars: Array = []                          # cilindros do mapa: {center, radius, height}
var hunting := false                             # true durante o preparo para abate
var last_seen_position := Vector3.ZERO            # ultimo ponto onde o jogador esteve visivel
var has_last_seen_position := false
var preparation_remaining := 0.0                  # tempo restante da janela atual
var visible_kill_charge := 0.0                    # segundos visiveis acumulados na caca
var _timer := TELEPORT_INTERVAL
var _rng := RandomNumberGenerator.new()
var _was_player_visible := false

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
const ABBATH_SOUND := "res://sounds/abbath.ogg"
const ABBATH_SOUND_MAX_DISTANCE := 30.0
const ABBATH_SOUND_FULL_VOLUME_DISTANCE := 5.0
const ABBATH_SOUND_CLOSE_BOOST := 1.4
const ABBATH_SOUND_GLOBAL_GAIN := 0.5
const ABBATH_SOUND_OCCLUDED_GAIN := 0.01
const ABBATH_SOUND_BASE_DB := 18.0
const ABBATH_SOUND_SUPER_HEARING_DB := 24.0
const ABBATH_SOUND_SILENCE_DB := -60.0
const PLAYER_VISIBLE_SOUND_COS := 0.5
const ENEMY_FOCUS_BUS := &"EnemyFocus"

var _sound: AudioStreamPlayer3D

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
	_setup_sound()

	AbbathManager.register(self)
	teleport_random()

func _setup_sound() -> void:
	_ensure_enemy_focus_bus()
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = ENEMY_FOCUS_BUS
	_sound.volume_db = ABBATH_SOUND_SILENCE_DB
	_sound.max_db = ABBATH_SOUND_SUPER_HEARING_DB
	_sound.unit_size = 1.0
	_sound.max_distance = ABBATH_SOUND_MAX_DISTANCE
	_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	var stream: AudioStream = load(ABBATH_SOUND)
	if stream == null:
		push_warning("Som do Abbath nao encontrado em %s." % ABBATH_SOUND)
	else:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_sound.stream = stream
	add_child(_sound)
	if _sound.stream != null:
		_sound.play()

func _ensure_enemy_focus_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(ENEMY_FOCUS_BUS)
	if bus_idx != -1:
		return
	bus_idx = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, ENEMY_FOCUS_BUS)
	AudioServer.set_bus_send(bus_idx, &"Master")

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
	var dist := _sound_distance_to_player()
	return would_hunt_at(dist, visible_fraction())

# Compatibilidade para chamadas externas: na nova caca, perseguir exige que o
# jogador esteja realmente dentro da visao, e nao apenas descoberto no mapa.
func can_hunt_player() -> bool:
	return can_see_player()

# --- Teleporte -------------------------------------------------------------

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

# Inicia a caca usando a posicao realmente vista neste instante. O primeiro
# salto vai para a metade da distancia, salvo quando um pilar proximo e usado.
func _start_hunt() -> void:
	hunting = true
	last_seen_position = player.global_position
	last_seen_position.y = 0.0
	has_last_seen_position = true
	preparation_remaining = PREPARE_DURATION
	visible_kill_charge = 0.0
	_was_player_visible = true
	var current := global_position
	var midpoint := current.lerp(last_seen_position, 0.5)
	midpoint.y = 0.0
	_teleport_for_hunt(midpoint)
	face(player.global_position)
	_update_eyes()

# Processamento isolado para a regra poder ser testada deterministicamente.
func _process_hunt(delta: float, player_visible: bool) -> void:
	if player_visible:
		last_seen_position = player.global_position
		last_seen_position.y = 0.0
		has_last_seen_position = true
		face(player.global_position)

		# So avanca ao REENCONTRAR. Permanecer visivel apenas carrega o abate.
		if not _was_player_visible:
			_teleport_reacquire_step()
			preparation_remaining = PREPARE_DURATION
			face(player.global_position)

		visible_kill_charge += delta
		if visible_kill_charge >= JUMPSCARE_VISIBLE_DURATION:
			_catch()
			return
	elif has_last_seen_position:
		face(last_seen_position)

	preparation_remaining -= delta
	_was_player_visible = player_visible
	if preparation_remaining <= 0.0:
		_end_hunt()

# Ao reencontrar, salta exatamente 5 m. Se o ponto estiver mais perto que o
# passo, fica parado como especificado.
func _teleport_reacquire_step() -> bool:
	var to_target := last_seen_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < REACQUIRE_STEP_DISTANCE:
		return false
	var destination := global_position + to_target / distance * REACQUIRE_STEP_DISTANCE
	_teleport_for_hunt(destination)
	return true

# Todo salto de caca passa pela mesma chance de pilar. O alvo usado tanto para
# escolher a frente quanto para calcular "atras" e sempre a ultima posicao vista.
func _teleport_for_hunt(direct_destination: Vector3) -> bool:
	var pillar_position := _pick_nearby_pillar_cover_pos()
	var used_pillar := pillar_position != Vector3.INF
	var destination := pillar_position if used_pillar else direct_destination
	destination.y = 0.0
	destination.x = clampf(destination.x, -HALF_X + EDGE_MARGIN, HALF_X - EDGE_MARGIN)
	destination.z = clampf(destination.z, -HALF_Z + EDGE_MARGIN, HALF_Z - EDGE_MARGIN)
	global_position = destination
	if has_last_seen_position:
		face(last_seen_position)
	return used_pillar

# Considera pilares a frente e a no maximo 5 m. Havendo candidatos, faz uma
# unica rolagem de 50% e usa o mais proximo.
func _pick_nearby_pillar_cover_pos() -> Vector3:
	if not has_last_seen_position or pillars.is_empty():
		return Vector3.INF
	var toward_target := last_seen_position - global_position
	toward_target.y = 0.0
	if toward_target.length() < 0.001:
		return Vector3.INF
	toward_target = toward_target.normalized()
	var candidates: Array = []
	for pillar in pillars:
		var center: Vector3 = pillar["center"]
		var from_abbath := center - global_position
		from_abbath.y = 0.0
		var distance := from_abbath.length()
		if distance > PILLAR_SEARCH_DISTANCE or distance < 0.001:
			continue
		if toward_target.dot(from_abbath / distance) <= 0.0:
			continue
		candidates.append({"center": center, "radius": float(pillar["radius"]), "distance": distance})
	if candidates.is_empty() or _rng.randf() >= PILLAR_COVER_CHANCE:
		return Vector3.INF
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var chosen = candidates[0]
	return _position_behind_pillar(chosen["center"], chosen["radius"])

# "Atras" e calculado a partir da ultima posicao vista, nao da posicao atual
# real do jogador. O deslocamento lateral deixa cerca de metade do corpo a vista.
func _position_behind_pillar(center: Vector3, radius: float) -> Vector3:
	var away_from_last_seen := center - last_seen_position
	away_from_last_seen.y = 0.0
	if away_from_last_seen.length() < 0.001:
		return Vector3.INF
	var direction := away_from_last_seen.normalized()
	var lateral_axis := Vector3(-direction.z, 0.0, direction.x)
	var lateral := radius * PILLAR_LATERAL_FACTOR
	if _rng.randf() < 0.5:
		lateral = -lateral
	return center + direction * (radius + PILLAR_BEHIND_MARGIN) + lateral_axis * lateral

func _end_hunt() -> void:
	hunting = false
	has_last_seen_position = false
	preparation_remaining = 0.0
	visible_kill_charge = 0.0
	_was_player_visible = false
	teleport_random()
	_timer = TELEPORT_INTERVAL
	_update_eyes()

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
		_update_sound()
		return

	_update_sound()
	var player_visible := can_see_player()
	if hunting:
		_process_hunt(delta, player_visible)
		return
	if player_visible:
		_start_hunt()
		return

	_timer -= delta
	if _timer <= 0.0:
		teleport_random()
		_timer = TELEPORT_INTERVAL

func _update_eyes() -> void:
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = EYE_HUNT_ENERGY if hunting else EYE_IDLE_ENERGY

func _catch() -> void:
	AbbathManager.trigger_jumpscare()
	if _sound != null:
		_sound.volume_db = ABBATH_SOUND_SILENCE_DB
	set_process(false)

func _update_sound() -> void:
	if _sound == null or _sound.stream == null:
		return
	if not _sound.playing:
		_sound.play()
	_sound.volume_db = _abbath_sound_volume_db()

func _abbath_sound_volume_db() -> float:
	if player == null:
		return ABBATH_SOUND_SILENCE_DB
	var dist := _sound_distance_to_player()
	if dist > ABBATH_SOUND_MAX_DISTANCE:
		return ABBATH_SOUND_SILENCE_DB
	var super_hearing := WaveManager.is_super_hearing_active()
	var amplitude := _abbath_sound_amplitude(dist) * ABBATH_SOUND_GLOBAL_GAIN
	if not super_hearing:
		if not _is_in_player_sound_cone(dist):
			return ABBATH_SOUND_SILENCE_DB
		if not _has_clear_sound_line():
			amplitude *= ABBATH_SOUND_OCCLUDED_GAIN
	var base_db := ABBATH_SOUND_SUPER_HEARING_DB if super_hearing else ABBATH_SOUND_BASE_DB
	return maxf(base_db + linear_to_db(maxf(amplitude, 0.001)), ABBATH_SOUND_SILENCE_DB)

func _abbath_sound_amplitude(dist: float) -> float:
	var span := maxf(ABBATH_SOUND_MAX_DISTANCE - ABBATH_SOUND_FULL_VOLUME_DISTANCE, 0.001)
	var t := clampf((ABBATH_SOUND_MAX_DISTANCE - dist) / span, 0.0, 1.0)
	return lerpf(1.0, ABBATH_SOUND_CLOSE_BOOST, t)

func _is_in_player_sound_cone(dist: float) -> bool:
	if player == null:
		return false
	var origin: Vector3 = player.get_emit_origin() if player.has_method("get_emit_origin") else player.global_position + Vector3.UP * 1.6
	var to_target := _eye_origin() - origin
	if dist < 0.001 or dist > ABBATH_SOUND_MAX_DISTANCE:
		return false
	var look_dir: Vector3 = player.get_look_dir() if player.has_method("get_look_dir") else -player.global_transform.basis.z
	return look_dir.normalized().dot(to_target.normalized()) >= PLAYER_VISIBLE_SOUND_COS

func _has_clear_sound_line() -> bool:
	if player == null:
		return false
	var origin: Vector3 = player.get_emit_origin() if player.has_method("get_emit_origin") else player.global_position + Vector3.UP * 1.6
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, _eye_origin())
	q.exclude = [player.get_rid()]
	return space.intersect_ray(q).is_empty()

func _sound_distance_to_player() -> float:
	if player == null:
		return INF
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
