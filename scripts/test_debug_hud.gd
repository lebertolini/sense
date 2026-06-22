extends Node
## Teste da interface de debug (ativado com --debughudtest).
## Exercita o atalho real, valida os valores e salva uma captura em test_output/.

var player_ref
var abbath_ref

var _fails := 0
var _out_dir := ""


func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var hud = get_tree().root.find_child("DebugHud", true, false)
	_check("painel de debug foi criado", hud != null)
	if hud == null:
		_finish()
		return

	player_ref.set_physics_process(false)
	abbath_ref.set_process(false)
	_check("painel comeca oculto", not hud.visible)

	# Posicao deterministica, proxima e sem cobertura, para conferir os numeros.
	var look: Vector3 = player_ref.get_emit_dir()
	look.y = 0.0
	look = look.normalized()
	abbath_ref.global_position = Vector3(player_ref.global_position.x, 0.0, player_ref.global_position.z) + look * 6.0
	abbath_ref.face(player_ref.global_position)
	abbath_ref.hunting = false

	await _press_ctrl_d()
	_check("Ctrl+D abre o painel", hud.visible)
	_check("painel fica no canto superior direito", _is_top_right(hud))

	var visible_fraction: float = abbath_ref.visible_fraction()
	var hidden_percent := roundi(clampf(1.0 - visible_fraction, 0.0, 1.0) * 100.0)
	var distance: float = abbath_ref.global_position.distance_to(player_ref.global_position)
	var required_percent := roundi(abbath_ref.hide_cover_required(distance) * 100.0)
	var expected_hidden := "ESCONDIDO: %3d%%" % hidden_percent
	var expected_required := "EXIGIDO:   %3d%%" % required_percent

	_check("mostra a porcentagem escondida real", hud._hidden_label.text == expected_hidden)
	_check("mostra a porcentagem exigida real", hud._required_label.text == expected_required)
	_check("informa que nao esta perseguindo", hud._hunting_label.text == "PERSEGUICAO: NAO")

	# Forca somente o estado para validar a segunda apresentacao do indicador.
	abbath_ref.hunting = true
	hud._update_values()
	_check("informa quando esta perseguindo", hud._hunting_label.text == "PERSEGUICAO: SIM")
	_check("perseguicao usa destaque vermelho", hud._hunting_label.get_theme_color("font_color").r > 0.9)

	if DisplayServer.get_name() != "headless":
		await _capture("debug_hud_perseguicao")
	await _press_ctrl_d()
	_check("Ctrl+D fecha o painel", not hud.visible)
	_finish()


func _press_ctrl_d() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_D
	press.ctrl_pressed = true
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame

	var release := InputEventKey.new()
	release.physical_keycode = KEY_D
	release.ctrl_pressed = true
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _is_top_right(hud: Control) -> bool:
	var rect := hud.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	return rect.position.x > viewport_size.x * 0.5 \
		and rect.position.y >= 0.0 \
		and rect.position.y <= 40.0 \
		and rect.end.x <= viewport_size.x


func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	_check("salva screenshot do painel", error == OK and FileAccess.file_exists(path))
	print("[debughudtest] screenshot: ", path)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[debughudtest]   PASS: ", label)
	else:
		_fails += 1
		print("[debughudtest]   FAIL: ", label)


func _finish() -> void:
	if _fails == 0:
		print("[debughudtest] TODOS OS TESTES PASSARAM")
	else:
		push_warning("[debughudtest] %d checagem(ns) FALHARAM" % _fails)
		print("[debughudtest] %d checagem(ns) FALHARAM" % _fails)
	print("[debughudtest] concluido")
	get_tree().quit(_fails)
