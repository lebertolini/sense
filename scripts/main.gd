extends Node3D
## Monta a cena: ambiente escuro com glow, a sala e o player.

func _ready() -> void:
	_setup_display()

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	# Glow para os neons "brilharem" no escuro.
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.6
	we.environment = env
	add_child(we)

	var level := Node3D.new()
	level.set_script(load("res://scripts/level.gd"))
	add_child(level)

	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(-50.0, 1.5, -42.0)
	add_child(player)
	# Vira o player para o centro da sala (apenas yaw).
	player.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	player.rotation = Vector3(0, player.rotation.y, 0)

	if OS.get_cmdline_args().has("--autotest") or OS.get_cmdline_user_args().has("--autotest"):
		var t := Node.new()
		t.set_script(load("res://scripts/test_capture.gd"))
		add_child(t)

func _setup_display() -> void:
	## Renderiza no tamanho real da tela conectada (resolucao nativa do monitor).
	if OS.get_cmdline_args().has("--autotest") or OS.get_cmdline_user_args().has("--autotest"):
		# Em teste: janela fixa para screenshots deterministicas.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = Vector2i(1280, 720)
		return
	# Acompanha o monitor onde a janela esta e usa o tamanho dele.
	var screen := DisplayServer.window_get_current_screen()
	get_window().size = DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
