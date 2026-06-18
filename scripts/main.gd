extends Node3D
## Monta a cena: ambiente escuro com glow, a sala e o player.

func _ready() -> void:
	_setup_display()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
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

	if args.has("--abbathmodeltest") or args.has("--abbathmodelview"):
		_setup_abbath_model_test(args.has("--abbathmodelview"))
		return

	var level := Node3D.new()
	level.name = "Level"
	level.set_script(load("res://scripts/level.gd"))
	add_child(level)

	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(-50.0, 1.5, -42.0)
	add_child(player)
	# Vira o player para o centro da sala (apenas yaw).
	player.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	player.rotation = Vector3(0, player.rotation.y, 0)

	var abbath := Node3D.new()
	abbath.name = "Abbath"
	abbath.set_script(load("res://scripts/abbath.gd"))
	abbath.set("player", player)
	abbath.set("pillars", level.pillars)
	add_child(abbath)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	var wave_hud := Control.new()
	wave_hud.name = "WaveCooldownHud"
	wave_hud.set_script(load("res://scripts/wave_cooldown_hud.gd"))
	hud_layer.add_child(wave_hud)

	var tablet_hud := Label.new()
	tablet_hud.name = "TabletCounterHud"
	tablet_hud.set_script(load("res://scripts/tablet_counter_hud.gd"))
	hud_layer.add_child(tablet_hud)

	var restart_ui := Control.new()
	restart_ui.name = "RestartUi"
	restart_ui.set_script(load("res://scripts/restart_ui.gd"))
	hud_layer.add_child(restart_ui)

	if args.has("--autotest"):
		var t := Node.new()
		t.set_script(load("res://scripts/test_capture.gd"))
		add_child(t)

	if args.has("--tablettest"):
		var tt := Node.new()
		tt.set_script(load("res://scripts/test_tablets.gd"))
		tt.set("player_ref", player)
		add_child(tt)

	if args.has("--doortest"):
		var dt := Node.new()
		dt.set_script(load("res://scripts/test_doors.gd"))
		dt.set("player_ref", player)
		add_child(dt)

	if args.has("--abbathtest"):
		var at := Node.new()
		at.set_script(load("res://scripts/test_abbath.gd"))
		at.set("player_ref", player)
		at.set("abbath_ref", abbath)
		add_child(at)

func _setup_abbath_model_test(keep_open: bool = false) -> void:
	var abbath := Node3D.new()
	abbath.name = "AbbathModelPreview"
	abbath.set_script(load("res://scripts/abbath.gd"))
	add_child(abbath)

	var cam := Camera3D.new()
	cam.name = "AbbathModelCamera"
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.35
	cam.fov = 42.0
	cam.near = 0.05
	cam.far = 50.0
	add_child(cam)

	var t := Node.new()
	t.set_script(load("res://scripts/test_abbath.gd"))
	t.set("model_only", true)
	t.set("keep_model_view_open", keep_open)
	t.set("abbath_ref", abbath)
	t.set("camera_ref", cam)
	add_child(t)

func _setup_display() -> void:
	## Renderiza no tamanho real da tela conectada (resolucao nativa do monitor).
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("--autotest") or args.has("--tablettest") or args.has("--doortest") or args.has("--abbathtest") or args.has("--abbathmodeltest") or args.has("--abbathmodelview"):
		# Em teste: janela fixa para screenshots deterministicas.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = Vector2i(1280, 720)
		return
	# Acompanha o monitor onde a janela esta e usa o tamanho dele.
	var screen := DisplayServer.window_get_current_screen()
	get_window().size = DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
