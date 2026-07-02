extends Node
## Teste da porta de saida (ativado com --doortest).
## Ativa os 5 tablets (o contador vira "ENCONTRE A SAÍDA" e a porta surge numa
## parede), posiciona o player na frente da porta, emite uma onda (revela a
## superficie), espera a onda passar (sobra so a MOLDURA acesa), abre a porta
## com E (o MIOLO fica verde neon) e confirma a interface de reiniciar.
## Salva screenshots em test_output/.

var player_ref

const STAND_DIST := 3.0    # distancia do player ate a porta

var _out_dir := ""

func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("[doortest] saida em: ", _out_dir)
	print("[doortest] locale: ", TranslationServer.get_locale(),
		" | FIND_THE_EXIT=", tr("FIND_THE_EXIT"), " | RESTART=", tr("RESTART"))
	_run()

func _run() -> void:
	# Espera os tablets serem criados/registrados pelo level.
	await get_tree().process_frame
	await get_tree().process_frame

	var pl = player_ref
	pl.set_physics_process(false) # congela o player para screenshots estaveis

	var total := TabletManager.tablets.size()
	print("[doortest] tablets encontrados: ", total, " / ", TabletManager.TOTAL)

	# Ativa todos os tablets: dispara challenge_complete e faz a porta surgir.
	for t in TabletManager.tablets.duplicate():
		t.activate()
	await get_tree().process_frame
	print("[doortest] tablets ativados: %d/%d" % [TabletManager.activated_count, TabletManager.TOTAL])

	var hud := get_tree().root.find_child("TabletCounterHud", true, false)
	if hud != null:
		print("[doortest] contador agora mostra: \"%s\"" % hud.text)

	var door = DoorManager.door
	if door == null:
		push_warning("[doortest] porta NAO foi criada!")
		get_tree().quit()
		return
	print("[doortest] porta criada em (%.1f, %.1f, %.1f), normal (%.2f, %.2f, %.2f)" % [
		door.global_position.x, door.global_position.y, door.global_position.z,
		door.face_normal.x, door.face_normal.y, door.face_normal.z])

	_place_in_front(pl, door)
	await get_tree().process_frame
	await _capture("door_0_dark") # antes da onda: porta invisivel no escuro

	# Onda mirada na porta: revela a superficie inteira.
	_force_wave_ready()
	var origin: Vector3 = pl.get_emit_origin()
	WaveManager.emit_wave(origin, (door.global_position - origin).normalized())
	await _wait(0.2)
	await _capture("door_1_revelada") # onda passando: superficie acesa

	# Espera a onda passar: deve sobrar SO a moldura acesa (a "amostra").
	await _wait(2.0)
	await _capture("door_2_so_moldura")
	print("[doortest] moldura revelada (persistente): ", door._revealed)

	# Abre a porta pelo caminho real (mira da camera). Miolo fica verde neon.
	var ok: bool = DoorManager.try_open(pl.get_emit_origin(), pl.get_look_dir())
	print("[doortest] porta aberta via E: ", ok)
	await _wait(0.15)
	await _capture("door_3_aberta_verde")

	# Interface de reiniciar deve estar visivel.
	var restart_ui = get_tree().root.find_child("RestartUi", true, false)
	var ui_visible: bool = restart_ui != null and restart_ui.visible
	print("[doortest] interface de reiniciar visivel: ", ui_visible)
	if restart_ui != null and restart_ui._button != null:
		print("[doortest] botao diz: \"%s\"" % restart_ui._button.text)
	await get_tree().process_frame
	await _capture("door_4_reiniciar_ui")

	print("[doortest] concluido")
	get_tree().quit()

func _place_in_front(pl, door) -> void:
	var n: Vector3 = door.face_normal
	var horiz := Vector3(n.x, 0.0, n.z)
	if horiz.length() < 0.01:
		horiz = Vector3.BACK
	horiz = horiz.normalized()
	pl.global_position = Vector3(door.global_position.x, 0.0, door.global_position.z) + horiz * STAND_DIST

	# Mira a camera na porta (yaw no corpo, pitch na cabeca).
	var cam: Vector3 = pl.head.global_position
	var to: Vector3 = door.global_position - cam
	var flat := sqrt(to.x * to.x + to.z * to.z)
	pl.rotation.y = atan2(-to.x, -to.z)
	var pitch := atan2(to.y, maxf(flat, 0.0001))
	pl._pitch = pitch
	pl.head.rotation.x = pitch

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
	print("[doortest] screenshot: ", path)
