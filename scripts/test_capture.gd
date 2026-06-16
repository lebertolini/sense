extends Node
## Harness de teste (ativado com --autotest).
## Emite uma onda para frente e salva screenshots em varios instantes.
## No final, vira a camera 180 graus para provar que nada aparece atras.
## Saida em res://test_output/.

var _shot_times := [0.30, 0.80, 1.60, 2.60]  # segundos apos a emissao (vista frontal)
var _idx := 0
var _t := 0.0
var _emitted := false
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
			WaveManager.emit_wave(WaveManager.player.get_emit_origin(), WaveManager.player.get_emit_dir())
			_emitted = true
			_t = 0.0
			print("[autotest] onda emitida (para frente)")
		return

	if _idx < _shot_times.size():
		if _t >= _shot_times[_idx]:
			await _capture("front_%d_t%0.2f" % [_idx, _shot_times[_idx]])
			_idx += 1
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
