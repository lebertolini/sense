extends Node
## Teste da criatura Abbath (ativado com --abbathtest).
## Valida, de forma deterministica, todas as mecanicas pedidas:
##   1. Marca so a LATERAL/silhueta quando a onda passa (screenshot).
##   2. Visao em cone + linha de visada, com Abbath sempre encarando o jogador.
##   3. Esconder >=60% do corpo tira o alvo e manda Abbath ao spawn aleatorio.
##   4. Intervalo de teleporte diminui proporcional a proximidade.
##   5. Teleporte aleatorio cai dentro do mapa e longe do jogador.
##   6. Chegar perto demais dispara o jumpscare + interface de reiniciar.
## Salva screenshots em test_output/ e imprime PASS/FAIL de cada checagem.

var player_ref
var abbath_ref
var camera_ref
var model_only := false
var keep_model_view_open := false

var _out_dir := ""
var _fails := 0
var _bg_color := Color(0.60, 0.64, 0.66)
var _model_turntable := false

func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if model_only:
		print("[abbathmodeltest] saida em: ", _out_dir)
		_run_model_preview()
		return
	print("[abbathtest] saida em: ", _out_dir)
	print("[abbathtest] locale: ", TranslationServer.get_locale(), " | CAUGHT=", tr("CAUGHT"))
	_run()

func _run_model_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var ab = abbath_ref
	ab.set_process(false)
	ab.global_position = Vector3.ZERO
	ab.rotation = Vector3.ZERO
	ab.set_model_preview(true)
	_setup_model_preview_world()

	_check_model("modelo 3D do .glb carregou com malhas", ab._body_parts.size() >= 1)
	_check_model("modelo tem altura assustadora", ab.MODEL_HEIGHT >= 6.0)
	var fit: AABB = ab._model_local_aabb()
	var fit_scaled: float = fit.size.y * (ab.MODEL_HEIGHT / maxf(fit.size.y, 0.001))
	_check_model("modelo foi escalado para a altura da cena", absf(fit_scaled - ab.MODEL_HEIGHT) < 0.05)

	await _capture_model("abbath_model_front", Vector3(0.0, 3.35, -9.0), Vector3(0.0, 3.35, -0.15), true)
	await _capture_model("abbath_model_side", Vector3(9.0, 3.35, 0.0), Vector3(0.0, 3.35, -0.15), false)
	await _capture_model("abbath_model_three_quarter", Vector3(6.3, 3.55, -7.2), Vector3(0.0, 3.35, -0.15), false)

	if _fails == 0:
		print("[abbathmodeltest] TODOS OS TESTES PASSARAM")
	else:
		push_warning("[abbathmodeltest] %d checagem(ns) FALHARAM" % _fails)
		print("[abbathmodeltest] %d checagem(ns) FALHARAM" % _fails)
	print("[abbathmodeltest] concluido")
	if keep_model_view_open:
		_model_turntable = true
		set_process(true)
		print("[abbathmodelview] janela aberta: modelo isolado em turntable, sem mapa/HUD/gameplay")
	else:
		get_tree().quit()

func _process(delta: float) -> void:
	if model_only and _model_turntable and abbath_ref != null:
		abbath_ref.rotation.y += delta * 0.35

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var pl = player_ref
	var ab = abbath_ref
	pl.set_physics_process(false)   # congela o player
	ab.set_process(false)           # controlamos a criatura manualmente
	AbbathManager.caught = false

	# Direcao horizontal do olhar do player (ele comeca virado para o centro).
	var look: Vector3 = pl.get_emit_dir()
	look.y = 0.0
	look = look.normalized()
	var base := Vector3(pl.global_position.x, 0.0, pl.global_position.z)

	# --- 1. Marca so a lateral quando a onda passa -------------------------
	# Coloca Abbath a frente do player (dentro da area livre do inicio).
	ab.global_position = base + look * 6.0
	ab.face(pl.global_position)
	_aim_camera_at(pl, ab.global_position + Vector3.UP * 3.0)  # enquadra o vulto inteiro
	await get_tree().process_frame
	await _capture("abbath_0_escuro")  # no escuro: invisivel

	_force_wave_ready()
	var origin: Vector3 = pl.get_emit_origin()
	WaveManager.emit_wave(origin, (ab.global_position - origin).normalized())
	await _wait(0.25)
	await _capture("abbath_1_silhueta")  # onda passando: so o contorno acende
	print("[abbathtest] onda emitida sobre Abbath (marca lateral)")

	# --- 2. Visao em cone + alcance + linha de visada ----------------------
	var in_cone: bool = ab.is_player_in_cone()
	var vis: float = ab.visible_fraction()
	var sees: bool = ab.can_see_player()
	print("[abbathtest] em frente: cone=%s visivel=%.2f ve=%s" % [in_cone, vis, sees])
	_check("ve o player quando esta no cone, perto e a vista", in_cone and sees and vis > 0.9)

	# Fora do cone: vira Abbath de costas para o player.
	ab.face(pl.global_position)
	ab.rotation.y += PI
	print("[abbathtest] de costas: cone=%s ve=%s" % [ab.is_player_in_cone(), ab.can_see_player()])
	_check("NAO ve o player fora do cone", not ab.can_see_player())
	ab.hunting = false
	ab._process(0.0)
	_check("mesmo de costas, Abbath vira para encarar o player", ab.is_player_in_cone())
	_check("sem cobertura >=60%, Abbath caca mesmo apos virar de costas", ab.hunting)

	# --- 3. Esconder >=60% do corpo ----------------------------------------
	ab.face(pl.global_position)  # volta a encarar o player
	_check("ve novamente ao reencarar", ab.can_see_player())

	var wall := _spawn_wall(_midpoint(ab.global_position, pl.global_position))
	await get_tree().process_frame
	var vis_hidden: float = ab.visible_fraction()
	print("[abbathtest] escondido atras da parede: visivel=%.2f ve=%s" % [vis_hidden, ab.can_see_player()])
	_check("escondido >=60% deixa de ser visto", vis_hidden <= (1.0 - ab.HIDE_COVER_NEAR) and not ab.can_see_player())

	# Estando cacando e perdendo o alvo (escondido), volta ao spawn aleatorio.
	ab.hunting = true
	ab._process(0.1)
	var dist_after: float = ab.global_position.distance_to(pl.global_position)
	print("[abbathtest] apos esconder: cacando=%s dist=%.1f" % [ab.hunting, dist_after])
	_check("ao se esconder, Abbath para de cacar e vai longe", (not ab.hunting) and dist_after >= ab.SPAWN_MIN_DIST)
	_check("cobertura >=60% mantem intervalo no spawn base", ab._current_interval == ab.TELEPORT_INTERVAL)
	wall.queue_free()
	await get_tree().process_frame

	# --- 4. Intervalo proporcional a proximidade ---------------------------
	var i_far: float = ab.compute_interval(ab.VISION_RANGE)
	var i_near: float = ab.compute_interval(ab.CATCH_RANGE + 1.0)
	print("[abbathtest] intervalo longe=%.2f perto=%.2f (base=%.1f min=%.1f)" % [
		i_far, i_near, ab.TELEPORT_INTERVAL, ab.MIN_TELEPORT_INTERVAL])
	_check("perto teleporta mais rapido que longe", i_near < i_far)
	_check("intervalo respeita os limites",
		i_far <= ab.TELEPORT_INTERVAL + 0.001 and i_near >= ab.MIN_TELEPORT_INTERVAL - 0.001)

	# --- 5. Teleporte aleatorio dentro do mapa e longe do jogador ----------
	var ok_bounds := true
	var ok_far := true
	for i in 20:
		ab.teleport_random()
		var p: Vector3 = ab.global_position
		if absf(p.x) > ab.HALF_X or absf(p.z) > ab.HALF_Z:
			ok_bounds = false
		if p.distance_to(pl.global_position) < ab.SPAWN_MIN_DIST:
			ok_far = false
	_check("teleporte aleatorio fica dentro do mapa", ok_bounds)
	_check("teleporte aleatorio nasce longe do jogador", ok_far)

	# Aproximacao: salta para mais perto sem grudar no jogador.
	ab.pillars = []   # cenarios de pilar sao testados depois, sem level montado
	ab.global_position = base + look * 30.0
	var d_before: float = ab.global_position.distance_to(pl.global_position)
	ab.teleport_closer()
	var d_close: float = ab.global_position.distance_to(pl.global_position)
	print("[abbathtest] aproximacao: antes=%.1f depois=%.1f" % [d_before, d_close])
	_check("teleport_closer aproxima mas nao gruda",
		d_close < d_before and d_close >= ab.MIN_APPROACH_DIST - 0.5)

	# --- 4b. Cobertura exigida varia com a distancia -----------------------
	var cov_near: float = ab.hide_cover_required(ab.CATCH_RANGE + 0.5)
	var cov_far: float = ab.hide_cover_required(ab.VISION_RANGE)
	var cov_mid: float = ab.hide_cover_required((ab.CATCH_RANGE + ab.VISION_RANGE) * 0.5)
	print("[abbathtest] cobertura exigida perto=%.2f meio=%.2f longe=%.2f" % [
		cov_near, cov_mid, cov_far])
	_check("longe exige 100%% escondido", absf(cov_far - 1.0) < 0.01)
	_check("perto exige %d%% escondido" % int(ab.HIDE_COVER_NEAR * 100.0),
		absf(cov_near - ab.HIDE_COVER_NEAR) < 0.05)
	_check("exigencia cresce com a distancia", cov_near < cov_mid and cov_mid < cov_far)
	# A regra de caca usa essa cobertura: longe + qualquer pedacinho visivel = caca;
	# perto + 30% visivel (i.e. 70% escondido) ja nao basta para cacar.
	_check("longe + 40%% visivel ainda dispara a caca",
		ab.would_hunt_at(ab.VISION_RANGE, 0.4))
	_check("longe + 0%% visivel NAO dispara a caca",
		not ab.would_hunt_at(ab.VISION_RANGE, 0.0))
	_check("perto + 30%% visivel NAO dispara a caca",
		not ab.would_hunt_at(ab.CATCH_RANGE + 1.0, 0.3))
	_check("perto + 50%% visivel dispara a caca",
		ab.would_hunt_at(ab.CATCH_RANGE + 1.0, 0.5))

	# --- 4c. Aproximacao por arco frontal/lateral, nao em linha reta -------
	# Sem pilares, varios saltos a partir da MESMA posicao inicial precisam
	# espalhar o ponto final pelo arco em torno do olhar do player, e nao cair
	# sempre na mesma linha reta como a versao antiga.
	var forward: Vector3 = -pl.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var off_axis := 0
	var unique_angles := {}
	var min_cos := 1.0
	for i in 40:
		ab.global_position = base + look * 30.0
		ab.teleport_closer()
		var v: Vector3 = ab.global_position - pl.global_position
		v.y = 0.0
		v = v.normalized()
		var c := v.dot(forward)
		if c < 0.985:
			off_axis += 1
		if c < min_cos:
			min_cos = c
		var bucket := int(round(c * 20.0))
		unique_angles[bucket] = true
	print("[abbathtest] aproximacao arco: off_axis=%d/40 angulos=%d cos_min=%.2f" % [
		off_axis, unique_angles.size(), min_cos])
	_check("teleport_closer espalha os pontos pelo arco", off_axis >= 25)
	_check("teleport_closer alcanca lateralidade real", min_cos < 0.4)
	_check("teleport_closer nao cai atras do player", min_cos > -0.5)

	# --- 4d. Esconderijo atras de pilar (50% por pilar) --------------------
	# Pilar bem no caminho entre Abbath inicial (longe) e o player.
	var pillar_center: Vector3 = pl.global_position + look * 12.0
	pillar_center.y = 0.0
	var pillar_radius := 1.4
	var pillar_body := _spawn_pillar(pillar_center, pillar_radius)
	ab.pillars = [{"center": pillar_center, "radius": pillar_radius, "height": 12.0}]
	var hides := 0
	var lateral_left := 0
	var lateral_right := 0
	var min_to_pillar := 1e9
	for i in 60:
		ab.global_position = base + look * 30.0
		ab.teleport_closer()
		var d_p := Vector2(ab.global_position.x - pillar_center.x,
			ab.global_position.z - pillar_center.z).length()
		if d_p < pillar_radius * 2.2:
			hides += 1
			var to_player: Vector3 = pl.global_position - pillar_center
			to_player.y = 0.0
			to_player = to_player.normalized()
			var lat_axis := Vector3(-to_player.z, 0.0, to_player.x)
			var rel: Vector3 = ab.global_position - pillar_center
			var lat_dot: float = rel.x * lat_axis.x + rel.z * lat_axis.z
			if lat_dot > 0.0:
				lateral_right += 1
			else:
				lateral_left += 1
			if d_p < min_to_pillar:
				min_to_pillar = d_p
	print("[abbathtest] pilares: hides=%d/60 esq=%d dir=%d perto_min=%.2f" % [
		hides, lateral_left, lateral_right, min_to_pillar])
	_check("pilar usado como esconderijo perto de 50% das vezes",
		hides >= 18 and hides <= 42)
	_check("esconderijo se alterna entre os dois lados do pilar",
		lateral_left > 0 and lateral_right > 0)
	_check("escondido fica colado no pilar", min_to_pillar < pillar_radius * 1.8)

	# Dois pilares em sequencia: chance acumulada de esconderijo sobe.
	var second_center: Vector3 = pl.global_position + look * 22.0
	second_center.y = 0.0
	var second_body := _spawn_pillar(second_center, pillar_radius)
	ab.pillars = [
		{"center": pillar_center, "radius": pillar_radius, "height": 12.0},
		{"center": second_center, "radius": pillar_radius, "height": 12.0},
	]
	var any_hide := 0
	for i in 80:
		ab.global_position = base + look * 35.0
		ab.teleport_closer()
		var d_a := Vector2(ab.global_position.x - pillar_center.x,
			ab.global_position.z - pillar_center.z).length()
		var d_b := Vector2(ab.global_position.x - second_center.x,
			ab.global_position.z - second_center.z).length()
		if d_a < pillar_radius * 2.2 or d_b < pillar_radius * 2.2:
			any_hide += 1
	print("[abbathtest] dois pilares: any_hide=%d/80" % any_hide)
	_check("com 2 pilares, esconderijo acontece em mais de 50%",
		any_hide >= 50)
	pillar_body.queue_free()
	second_body.queue_free()
	ab.pillars = []
	await get_tree().process_frame

	# --- 4e. Cobertura de pilar nao auto-cancela a caca --------------------
	# Apos esconder atras de um pilar, o proprio raycast de Abbath ate o player
	# bate no pilar (visible_fraction cai a zero). A regra de perda nao pode
	# disparar dentro do mesmo ciclo: senao Abbath foge no instante seguinte.
	var lock_pillar_center: Vector3 = pl.global_position + look * 10.0
	lock_pillar_center.y = 0.0
	var lock_pillar_radius := 1.4
	var lock_pillar_body := _spawn_pillar(lock_pillar_center, lock_pillar_radius)
	ab.pillars = [{"center": lock_pillar_center, "radius": lock_pillar_radius, "height": 12.0}]

	# Forca varios saltos ate cair atras do pilar; checa que _cover_locked acende.
	var saw_lock := false
	for i in 40:
		ab.global_position = base + look * 30.0
		ab._cover_locked = false
		ab.teleport_closer()
		if ab._cover_locked:
			saw_lock = true
			break
	_check("teleport_closer atras de pilar liga a trava de caca", saw_lock)

	# Posiciona Abbath manualmente atras do pilar e roda _process. visible_fraction
	# vira ~0 (pilar bloqueia), mas com a trava ativa a caca precisa CONTINUAR.
	var behind_dir: Vector3 = (lock_pillar_center - pl.global_position)
	behind_dir.y = 0.0
	behind_dir = behind_dir.normalized()
	ab.global_position = lock_pillar_center + behind_dir * (lock_pillar_radius + 0.6)
	ab.face(pl.global_position)
	ab._cover_locked = true
	ab.hunting = true
	ab._timer = ab.TELEPORT_INTERVAL
	await get_tree().process_frame
	var vis_behind: float = ab.visible_fraction()
	ab._process(0.0)
	print("[abbathtest] atras de pilar: visivel=%.2f hunting=%s locked=%s" % [
		vis_behind, ab.hunting, ab._cover_locked])
	_check("atras de pilar o raycast e bloqueado", vis_behind < 0.4)
	_check("trava mantem a caca mesmo com a visao bloqueada", ab.hunting)

	# Sem a trava (i.e. teleport por arco normal cai em posicao limpa), a regra
	# normal volta a valer: visible_fraction baixa por causa de cobertura faz
	# Abbath perder o alvo.
	ab._cover_locked = false
	ab._process(0.0)
	_check("sem trava a regra normal volta a valer", not ab.hunting)
	lock_pillar_body.queue_free()
	ab.pillars = []
	ab.hunting = false
	ab._timer = ab.TELEPORT_INTERVAL
	await get_tree().process_frame

	# --- 4f. Sequencia de saltos realmente aproxima ------------------------
	# Sem pilares (cenario do arco), N saltos consecutivos precisam reduzir a
	# distancia ate o jogador de forma monotonica em media.
	ab.pillars = []
	ab.global_position = base + look * (ab.VISION_RANGE - 2.0)
	var dists: Array = [ab.global_position.distance_to(pl.global_position)]
	for i in 6:
		ab.teleport_closer()
		dists.append(ab.global_position.distance_to(pl.global_position))
	print("[abbathtest] cadeia de saltos: %s" % [dists])
	_check("6 saltos consecutivos chegam perto do MIN_APPROACH_DIST",
		float(dists[dists.size() - 1]) <= ab.MIN_APPROACH_DIST + 0.5)

	# --- 6. Jumpscare ao chegar perto demais -------------------------------
	ab.set_process(true)
	ab.global_position = base + look * 3.0   # dentro do CATCH_RANGE
	ab.face(pl.global_position)
	ab.hunting = true
	ab._process(0.1)
	var restart_ui = get_tree().root.find_child("RestartUi", true, false)
	var ui_visible: bool = restart_ui != null and restart_ui.visible
	print("[abbathtest] perto demais: caught=%s ui_reiniciar=%s" % [AbbathManager.caught, ui_visible])
	_check("chegar perto dispara o jumpscare", AbbathManager.caught)
	_check("jumpscare mostra a interface de reiniciar", ui_visible)
	await _wait(0.1)
	await _capture("abbath_2_jumpscare")

	# --- Resumo ------------------------------------------------------------
	if _fails == 0:
		print("[abbathtest] TODOS OS TESTES PASSARAM")
	else:
		push_warning("[abbathtest] %d checagem(ns) FALHARAM" % _fails)
		print("[abbathtest] %d checagem(ns) FALHARAM" % _fails)
	print("[abbathtest] concluido")
	get_tree().quit()

# --- Helpers ---------------------------------------------------------------

func _check(label: String, cond: bool) -> void:
	if cond:
		print("[abbathtest]   PASS: ", label)
	else:
		_fails += 1
		print("[abbathtest]   FAIL: ", label)

func _check_model(label: String, cond: bool) -> void:
	if cond:
		print("[abbathmodeltest]   PASS: ", label)
	else:
		_fails += 1
		print("[abbathmodeltest]   FAIL: ", label)

func _midpoint(a: Vector3, b: Vector3) -> Vector3:
	return (a + b) * 0.5

func _setup_model_preview_world() -> void:
	var we = get_tree().root.find_child("WorldEnvironment", true, false)
	if we != null and we is WorldEnvironment:
		var env: Environment = we.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.60, 0.64, 0.66)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.90, 0.92, 0.94)
		env.ambient_light_energy = 1.05
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_strength = 0.55

	# Luz frontal de cima mirando o rosto, para o modelo nao ficar escuro demais
	# no preview (no jogo o corpo usa o shader de silhueta e nao recebe luz).
	var key := DirectionalLight3D.new()
	key.name = "ModelPreviewKeyLight"
	key.light_energy = 1.9
	key.light_color = Color(1.0, 0.98, 0.94)
	get_parent().add_child(key)
	key.position = Vector3(2.0, 8.0, -8.0)
	key.look_at(Vector3(0.0, 5.2, -0.2), Vector3.UP)

	# Sem chao: fundo liso deixa a silhueta do modelo limpa para a checagem de
	# enquadramento (a captura mede pixels que diferem do fundo).
	_bg_color = Color(0.60, 0.64, 0.66)

# Mira a camera do player num ponto (yaw no corpo, pitch na cabeca).
func _aim_camera_at(pl, target: Vector3) -> void:
	var cam: Vector3 = pl.head.global_position
	var to: Vector3 = target - cam
	var flat := sqrt(to.x * to.x + to.z * to.z)
	pl.rotation.y = atan2(-to.x, -to.z)
	var pitch := atan2(to.y, maxf(flat, 0.0001))
	pl._pitch = pitch
	pl.head.rotation.x = pitch

# Pilar (cilindro vertical) usado para testar a cobertura por pilares.
func _spawn_pillar(center: Vector3, radius: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = radius
	shp.height = 12.0
	cs.shape = shp
	sb.add_child(cs)
	sb.position = Vector3(center.x, 6.0, center.z)
	get_parent().add_child(sb)
	return sb

# Parede grande o bastante para cobrir todo o corpo do jogador da visao de Abbath.
func _spawn_wall(center: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(8.0, 6.0, 1.0)
	cs.shape = shp
	sb.add_child(cs)
	sb.position = Vector3(center.x, 3.0, center.z)
	get_parent().add_child(sb)
	return sb

func _force_wave_ready() -> void:
	WaveManager._is_wave_ready = true
	WaveManager._cooldown_remaining = 0.0

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[abbathtest] screenshot: ", path)

func _capture_model(tag: String, eye: Vector3, target: Vector3, analyze_front: bool) -> void:
	var cam: Camera3D = camera_ref
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	if analyze_front:
		_analyze_front_model_capture(img)
	img.save_png(path)
	print("[abbathmodeltest] screenshot: ", path)

func _analyze_front_model_capture(img: Image) -> void:
	# Mede a silhueta do modelo como os pixels que diferem do fundo liso, para
	# confirmar que o .glb aparece, fica centralizado e proporcional a cena.
	var w := img.get_width()
	var h := img.get_height()
	var crop_min_x := int(float(w) * 0.20)
	var crop_max_x := int(float(w) * 0.80)
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	var model_count := 0

	for y in range(0, h, 2):
		for x in range(crop_min_x, crop_max_x, 2):
			if _is_model_pixel(img.get_pixel(x, y)):
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
				model_count += 1

	if model_count == 0:
		_check_model("captura encontra o modelo do Abbath", false)
		return

	var body_h := float(max_y - min_y + 1)
	_check_model("captura encontra o modelo do Abbath", true)
	_check_model("captura enquadra o corpo inteiro", body_h > float(h) * 0.70 and body_h < float(h) * 0.99)
	_check_model("modelo fica centralizado", absf(float(min_x + max_x) * 0.5 - float(w) * 0.5) < float(w) * 0.12)
	_check_model("topo e pes ficam visiveis no quadro", min_y < int(float(h) * 0.20) and max_y > int(float(h) * 0.80))
	_check_model("olhos claros aparecem na parte de cima", _has_two_bright_eyes(img, min_x, max_x, min_y, body_h))

func _is_model_pixel(c: Color) -> bool:
	# Pixel pertence ao modelo se difere o bastante do fundo liso.
	var dr := absf(c.r - _bg_color.r)
	var dg := absf(c.g - _bg_color.g)
	var db := absf(c.b - _bg_color.b)
	return maxf(dr, maxf(dg, db)) > 0.10

func _has_two_bright_eyes(img: Image, min_x: int, max_x: int, min_y: int, body_h: float) -> bool:
	var mid_x := int(float(min_x + max_x) * 0.5)
	var top_y := min_y
	var bottom_y := min_y + int(body_h * 0.30)
	var left_count := 0
	var right_count := 0
	for y in range(top_y, bottom_y):
		for x in range(min_x, max_x + 1):
			var c := img.get_pixel(x, y)
			if c.r > 0.55 and c.g > 0.70 and c.b > 0.75:
				if x < mid_x:
					left_count += 1
				else:
					right_count += 1
	return left_count >= 2 and right_count >= 2
