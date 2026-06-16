extends Node
## Harness de teste (ativado com --autotest).
## Emite uma onda para frente e salva screenshots em varios instantes.
## No final, vira a camera 180 graus para provar que nada aparece atras.
## Saida em res://test_output/.

var _shot_times := [0.12, 1.50, 3.10]  # dreno, recarga parcial e pronto
var _idx := 0
var _t := 0.0
var _emitted := false
var _blocked_checked := false
var _second_emit_checked := false
var _second_drain_captured := false
var _second_t := 0.0
var _did_back := false
var _out_dir := ""

func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("[autotest] saida em: ", _out_dir)

func _process(delta: float) -> void:
	_t += delta

	if not _emitted:
		if _t > 0.5 and WaveManager.player != null:
			var ok := WaveManager.emit_wave(WaveManager.player.get_emit_origin(), WaveManager.player.get_emit_dir())
			_emitted = true
			_t = 0.0
			print("[autotest] onda emitida (para frente): ", ok)
		return

	if not _blocked_checked and _t > 0.18:
		_blocked_checked = true
		var blocked_ok := WaveManager.emit_wave(WaveManager.player.get_emit_origin(), WaveManager.player.get_emit_dir())
		print("[autotest] tentativa durante cooldown bloqueada: ", not blocked_ok)

	if _idx < _shot_times.size():
		if _t >= _shot_times[_idx]:
			await _capture("hud_%d_t%0.2f" % [_idx, _shot_times[_idx]])
			_idx += 1
		return

	if not _second_emit_checked and WaveManager.is_wave_ready():
		_second_emit_checked = true
		var second_ok := WaveManager.emit_wave(WaveManager.player.get_emit_origin(), WaveManager.player.get_emit_dir())
		print("[autotest] segunda onda apos recarga: ", second_ok)
		_second_t = 0.0
		return

	if _second_emit_checked and not _second_drain_captured:
		_second_t += delta
		if _second_t < 0.14:
			return
		_second_drain_captured = true
		await _capture("hud_second_use_drain")
		return

	# Vira 180 graus e captura: a regiao atras da onda deve continuar preta.
	if not _did_back:
		_did_back = true
		WaveManager.player.rotation.y += PI
		await _capture("back_t%0.2f" % _t)
		print("[autotest] concluido")
		get_tree().quit()

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[autotest] screenshot: ", path)
