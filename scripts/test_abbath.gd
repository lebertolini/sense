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

var _out_dir := ""
var _fails := 0

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
	ab.set_preview_reveal(true)

	_check_model("modelo tem bastante detalhe", ab.get_child_count() >= 24)
	_check_model("modelo tem altura assustadora", ab.MODEL_HEIGHT >= 6.0)

	await _capture_model("abbath_model_front", Vector3(0.0, 3.25, -9.0), Vector3(0.0, 3.15, -0.15))
	await _capture_model("abbath_model_side", Vector3(9.0, 3.25, 0.0), Vector3(0.0, 3.15, -0.15))
	await _capture_model("abbath_model_three_quarter", Vector3(6.3, 3.55, -7.2), Vector3(0.0, 3.25, -0.15))

	if _fails == 0:
		print("[abbathmodeltest] TODOS OS TESTES PASSARAM")
	else:
		push_warning("[abbathmodeltest] %d checagem(ns) FALHARAM" % _fails)
		print("[abbathmodeltest] %d checagem(ns) FALHARAM" % _fails)
	print("[abbathmodeltest] concluido")
	get_tree().quit()

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
	_check("escondido >=60% deixa de ser visto", vis_hidden <= (1.0 - ab.HIDE_COVER) and not ab.can_see_player())

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
	ab.global_position = base + look * 30.0
	var d_before: float = ab.global_position.distance_to(pl.global_position)
	ab.teleport_closer()
	var d_close: float = ab.global_position.distance_to(pl.global_position)
	print("[abbathtest] aproximacao: antes=%.1f depois=%.1f" % [d_before, d_close])
	_check("teleport_closer aproxima mas nao gruda",
		d_close < d_before and d_close >= ab.MIN_APPROACH_DIST - 0.5)

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

# Mira a camera do player num ponto (yaw no corpo, pitch na cabeca).
func _aim_camera_at(pl, target: Vector3) -> void:
	var cam: Vector3 = pl.head.global_position
	var to: Vector3 = target - cam
	var flat := sqrt(to.x * to.x + to.z * to.z)
	pl.rotation.y = atan2(-to.x, -to.z)
	var pitch := atan2(to.y, maxf(flat, 0.0001))
	pl._pitch = pitch
	pl.head.rotation.x = pitch

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

func _capture_model(tag: String, eye: Vector3, target: Vector3) -> void:
	var cam: Camera3D = camera_ref
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[abbathmodeltest] screenshot: ", path)
