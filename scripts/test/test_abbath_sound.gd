extends Node
## Teste do audio 3D do Abbath (ativado com --abbathsoundtest).

var player_ref
var abbath_ref

var _fails := 0
var _blocker: StaticBody3D

func _ready() -> void:
	print("[abbathsoundtest] iniciando")
	if player_ref == null or abbath_ref == null:
		_check("referencias do player e Abbath foram recebidas", false)
		_finish()
		return

	player_ref.set_physics_process(false)
	abbath_ref.set_process(false)
	_set_player_pose(Vector3.ZERO, 0.0)
	WaveManager.reset()
	await get_tree().physics_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	_check("player 3D de som existe", abbath_ref._sound != null)
	if abbath_ref._sound == null:
		_finish()
		return

	_check("som do Abbath carregou stream", abbath_ref._sound.stream != null)
	_check("som do Abbath fica em loop tocando", abbath_ref._sound.playing)
	_check("som do Abbath usa bus de foco de inimigo", AudioServer.get_bus_index(abbath_ref.ENEMY_FOCUS_BUS) != -1)

	_set_super_hearing(false)
	_set_abbath_pos(Vector3(0.0, 0.0, -5.0))
	var near_visible := _volume()
	_set_abbath_pos(Vector3(0.0, 0.0, -10.0))
	var mid_close_visible := _volume()
	_set_abbath_pos(Vector3(0.0, 0.0, -20.0))
	var mid_far_visible := _volume()
	_set_abbath_pos(Vector3(0.0, 0.0, -30.0))
	var edge_visible := _volume()
	_check("sem super audicao, Abbath visivel na frente fica audivel", _is_audible(near_visible))
	_check("em 30 metros o Abbath ja fica audivel", _is_audible(edge_visible))
	_check("volume ja comeca a subir de 30m para 20m", mid_far_visible > edge_visible)
	_check("volume continua subindo de 20m para 10m", mid_close_visible > mid_far_visible)
	_check("volume aumenta ate 5m", near_visible > mid_close_visible)
	_check("a rampa pura de 30m a 5m distribui exatamente 40%%", is_equal_approx(abbath_ref._abbath_sound_amplitude(5.0), abbath_ref._abbath_sound_amplitude(30.0) * abbath_ref.ABBATH_SOUND_CLOSE_BOOST))

	_set_abbath_pos(Vector3(0.0, 0.0, -31.0))
	_check("acima de 30 metros o volume fica zerado", not _is_audible(_volume()))

	_set_abbath_pos(Vector3(0.0, 0.0, 6.0))
	_check("sem super audicao, Abbath atras do player fica silencioso", not _is_audible(_volume()))
	_set_super_hearing(true)
	_check("com super audicao, Abbath atras do player fica audivel em 3D", _is_audible(_volume()))

	_set_super_hearing(false)
	_set_abbath_pos(Vector3(0.0, 0.0, -8.0))
	var clear_at_8m := _volume()
	_add_blocker()
	var blocked_at_8m := _volume()
	_check("sem super audicao, obstaculo nao cancela o som do Abbath", _is_audible(blocked_at_8m))
	_check("sem super audicao, obstaculo deixa o som em 1%%", absf(blocked_at_8m - (clear_at_8m + linear_to_db(abbath_ref.ABBATH_SOUND_OCCLUDED_GAIN))) <= 0.05)
	_set_super_hearing(true)
	_check("com super audicao, som atravessa obstaculo", _is_audible(_volume()))
	_remove_blocker()

	_set_super_hearing(false)
	WaveManager.set_selected_ability(WaveManager.Ability.SUPER_HEARING)
	var before := WaveManager.get_cooldown_progress()
	WaveManager.set_super_hearing_requested(true)
	WaveManager._update_shared_charge(1.0)
	var after := WaveManager.get_cooldown_progress()
	_check("super audicao consome a mesma barra compartilhada", after < before)
	WaveManager.set_super_hearing_requested(false)

	WaveManager.reset()
	WaveManager.set_selected_ability(WaveManager.Ability.WAVE)
	var emitted: bool = WaveManager.emit_wave(player_ref.get_emit_origin(), player_ref.get_emit_dir())
	_check("onda usa a barra compartilhada cheia", emitted)
	_check("onda zera a barra compartilhada", WaveManager.get_cooldown_progress() <= 0.01)
	WaveManager.set_selected_ability(WaveManager.Ability.SUPER_HEARING)
	_check("super audicao enxerga a mesma barra vazia apos onda", WaveManager.get_cooldown_progress() <= 0.01)
	WaveManager._update_shared_charge(1.0)
	var shared_after_recharge := WaveManager.get_cooldown_progress()
	WaveManager.set_selected_ability(WaveManager.Ability.WAVE)
	_check("recarga da barra e compartilhada entre as duas skills", is_equal_approx(WaveManager.get_cooldown_progress(), shared_after_recharge))

	_finish()

func _set_player_pose(pos: Vector3, yaw: float) -> void:
	player_ref.global_position = pos
	player_ref.rotation = Vector3(0.0, yaw, 0.0)
	if player_ref.head != null:
		player_ref.head.rotation = Vector3.ZERO

func _set_abbath_pos(pos: Vector3) -> void:
	abbath_ref.global_position = pos
	abbath_ref.face(player_ref.global_position)

func _set_super_hearing(active: bool) -> void:
	WaveManager.set_selected_ability(WaveManager.Ability.SUPER_HEARING if active else WaveManager.Ability.WAVE)
	WaveManager.set_super_hearing_requested(active)
	WaveManager._update_shared_charge(0.05)

func _volume() -> float:
	abbath_ref._update_sound()
	return abbath_ref._sound.volume_db

func _is_audible(volume_db: float) -> bool:
	return volume_db > abbath_ref.ABBATH_SOUND_SILENCE_DB + 1.0

func _add_blocker() -> void:
	_remove_blocker()
	_blocker = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 8.0, 0.5)
	cs.shape = shape
	_blocker.add_child(cs)
	add_child(_blocker)
	_blocker.global_position = Vector3(0.0, 3.8, -4.0)
	_blocker.force_update_transform()

func _remove_blocker() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		_blocker.queue_free()
	_blocker = null

func _check(label: String, ok: bool) -> void:
	if ok:
		print("[abbathsoundtest]   PASS: ", label)
	else:
		_fails += 1
		push_warning("[abbathsoundtest]   FAIL: %s" % label)
		print("[abbathsoundtest]   FAIL: ", label)

func _finish() -> void:
	_remove_blocker()
	if _fails == 0:
		print("[abbathsoundtest] TODOS OS TESTES PASSARAM")
	else:
		push_warning("[abbathsoundtest] %d checagem(ns) FALHARAM" % _fails)
		print("[abbathsoundtest] %d checagem(ns) FALHARAM" % _fails)
	print("[abbathsoundtest] concluido")
	get_tree().quit(_fails)
