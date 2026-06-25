extends Node
## Teste do desafio dos tablets (ativado com --tablettest).
## Para alguns tablets: posiciona o player na frente, emite uma onda mirada
## (prova que ele brilha AMARELO) e ativa via o caminho real do jogador
## (prova que fica VERDE e o contador sobe). Salva screenshots em test_output/.

var player_ref

const DEMO_COUNT := 3      # quantos tablets demonstrar (mostra o contador subindo)
const STAND_DIST := 2.6    # distancia do player ao tablet

var _out_dir := ""

func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("[tablettest] saida em: ", _out_dir)
	_run()

func _run() -> void:
	# Espera os tablets serem criados/registrados pelo level.
	await get_tree().process_frame
	await get_tree().process_frame

	var pl = player_ref
	pl.set_physics_process(false) # congela o player para screenshots estaveis

	var total := TabletManager.tablets.size()
	print("[tablettest] tablets encontrados: ", total, " / ", TabletManager.TOTAL)
	if total != TabletManager.TOTAL:
		push_warning("[tablettest] esperado %d tablets, achou %d" % [TabletManager.TOTAL, total])
	_report_spread()

	var n: int = mini(DEMO_COUNT, total)
	for i in n:
		var t = TabletManager.tablets[i]
		_place_in_front(pl, t)
		await get_tree().process_frame

		# Onda mirada diretamente no tablet: garante a revelacao amarela.
		_force_wave_ready()
		var origin: Vector3 = pl.get_emit_origin()
		WaveManager.emit_wave(origin, (t.global_position - origin).normalized())
		await _wait(0.25)
		await _capture("tablet_%d_revelado" % i)

		# Ativacao pelo caminho real (mira da camera do player).
		var ok: bool = TabletManager.try_activate(pl.get_emit_origin(), pl.get_look_dir())
		await get_tree().process_frame
		var ui = get_tree().root.find_child("TabletMinigameUi", true, false)
		var opened: bool = ok and ui != null and ui.visible
		if opened and i == 0 and ui.has_method("set_shape_lock_for_test"):
			await _wait(0.35)
			await _capture("tablet_minigame_stage_0")
			await _capture("tablet_minigame_shortwaves_stage_0")
			await _capture("tablet_minigame_variedwaves_stage_0")
			await _capture("tablet_minigame_highcontrast_stage_0")
			await _capture("tablet_minigame_dynamicwaves_stage_0")
			await _capture("tablet_minigame_radio_stage_0")
			if ui.has_method("set_player_shape_target_for_test"):
				ui.set_player_shape_target_for_test(1.55)
				await get_tree().process_frame
				print("[tablettest] suavizacao inicio -> alvo_player=%.2f player=%.2f" % [
					ui.get_player_shape_target_for_test(), ui.get_player_shape_for_test()])
				await _capture("tablet_minigame_smooth_start")
				await _wait(0.25)
				print("[tablettest] suavizacao depois -> alvo_player=%.2f player=%.2f" % [
					ui.get_player_shape_target_for_test(), ui.get_player_shape_for_test()])
			await _capture("tablet_minigame_smooth_after")
			await _capture("tablet_minigame_dynamicwaves_smooth_after")
			await _capture("tablet_minigame_radio_smooth_after")
			var req0: float = ui.get_hold_required_for_test() if ui.has_method("get_hold_required_for_test") else -1.0
			print("[tablettest] minigame etapa 0 requer %.2fs | alvo=%.2f player=%.2f" % [
				req0, ui.get_target_shape_for_test(), ui.get_player_shape_for_test()])
			ui.set_shape_lock_for_test(true)
			await _wait(req0 + 0.14)
			await _capture("tablet_minigame_stage_1")
			await _capture("tablet_minigame_shortwaves_stage_1")
			await _capture("tablet_minigame_variedwaves_stage_1")
			await _capture("tablet_minigame_highcontrast_stage_1")
			await _capture("tablet_minigame_dynamicwaves_stage_1")
			await _capture("tablet_minigame_radio_stage_1")
			var saved_stage := TabletManager.get_stage(t)
			TabletManager.cancel_minigame()
			await get_tree().process_frame
			TabletManager.try_activate(pl.get_emit_origin(), pl.get_look_dir())
			await get_tree().process_frame
			var resumed_stage: int = ui.get_stage_for_test() if ui.has_method("get_stage_for_test") else -1
			var resumed_hold: float = ui.get_hold_time_for_test() if ui.has_method("get_hold_time_for_test") else -1.0
			print("[tablettest] retomada -> etapa_salva=%d etapa_ui=%d hold=%.2f" % [
				saved_stage, resumed_stage, resumed_hold])
			await _wait(0.2)
			await _capture("tablet_minigame_stage_1_retomada")
			await _capture("tablet_minigame_shortwaves_stage_1_retomada")
			await _capture("tablet_minigame_variedwaves_stage_1_retomada")
			await _capture("tablet_minigame_highcontrast_stage_1_retomada")
			await _capture("tablet_minigame_dynamicwaves_stage_1_retomada")
			await _capture("tablet_minigame_radio_stage_1_retomada")
			var req1: float = ui.get_hold_required_for_test() if ui.has_method("get_hold_required_for_test") else -1.0
			print("[tablettest] minigame etapa 1 requer %.2fs | alvo=%.2f player=%.2f" % [
				req1, ui.get_target_shape_for_test(), ui.get_player_shape_for_test()])
			ui.set_shape_lock_for_test(true)
			await _wait(req1 + 0.14)
			await _capture("tablet_minigame_stage_2")
			await _capture("tablet_minigame_shortwaves_stage_2")
			await _capture("tablet_minigame_variedwaves_stage_2")
			await _capture("tablet_minigame_highcontrast_stage_2")
			await _capture("tablet_minigame_dynamicwaves_stage_2")
			await _capture("tablet_minigame_radio_stage_2")
			var req2: float = ui.get_hold_required_for_test() if ui.has_method("get_hold_required_for_test") else -1.0
			print("[tablettest] minigame etapa 2 requer %.2fs | alvo=%.2f player=%.2f" % [
				req2, ui.get_target_shape_for_test(), ui.get_player_shape_for_test()])
			ui.set_shape_lock_for_test(true)
			await _wait(req2 + 0.14)
		elif opened and ui.has_method("force_complete_for_test"):
			ui.force_complete_for_test()
		print("[tablettest] tablet %d -> minigame=%s ativado=%s | contador=%d/%d" % [
			i, opened, t.is_activated, TabletManager.activated_count, TabletManager.TOTAL])
		await _wait(0.12)
		await _capture("tablet_%d_ativado" % i)

	print("[tablettest] TOTAL ativado: %d/%d" % [TabletManager.activated_count, TabletManager.TOTAL])

	# Sem emitir nova onda: depois que tudo apaga, o ultimo tablet ativado deve
	# continuar aceso (verde) sozinho no escuro. Prova o "fica aceso".
	await _wait(2.0)
	await _capture("final_aceso_no_escuro")

	print("[tablettest] concluido")
	get_tree().quit()

func _report_spread() -> void:
	# Mostra posicoes e a menor distancia entre tablets (valida o espalhamento).
	var ts = TabletManager.tablets
	var min_d := INF
	for i in ts.size():
		var p: Vector3 = ts[i].global_position
		print("[tablettest]   tablet %d em (%.1f, %.1f, %.1f)" % [i, p.x, p.y, p.z])
		for j in range(i + 1, ts.size()):
			var q: Vector3 = ts[j].global_position
			min_d = minf(min_d, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
	print("[tablettest] menor distancia entre tablets: %.1f" % min_d)

func _place_in_front(pl, t) -> void:
	var n: Vector3 = t.face_normal
	if n.dot(Vector3.UP) > 0.9:
		# Tablet no chao: fica de pe a frente e olha para baixo.
		pl.global_position = Vector3(t.global_position.x, 0.0, t.global_position.z + STAND_DIST)
	else:
		var horiz := Vector3(n.x, 0.0, n.z)
		if horiz.length() < 0.01:
			horiz = Vector3.BACK
		horiz = horiz.normalized()
		pl.global_position = Vector3(t.global_position.x, 0.0, t.global_position.z) + horiz * STAND_DIST

	# Mira a camera no tablet (yaw no corpo, pitch na cabeca).
	var cam: Vector3 = pl.head.global_position
	var to: Vector3 = t.global_position - cam
	var flat := sqrt(to.x * to.x + to.z * to.z)
	pl.rotation.y = atan2(-to.x, -to.z)
	var pitch := atan2(to.y, maxf(flat, 0.0001))
	pl._pitch = pitch
	pl.head.rotation.x = pitch

func _force_wave_ready() -> void:
	# Em teste queremos emitir uma onda por tablet ignorando o cooldown.
	WaveManager._is_wave_ready = true
	WaveManager._cooldown_remaining = 0.0

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[tablettest] screenshot: ", path)
