extends Node3D
## Monta a cena: a sala e o player. O ambiente escuro com glow (WorldEnvironment)
## e o HUD vem de cenas (main.tscn / hud.tscn).

# Harnesses de teste: cada flag de linha de comando mapeia para o script a montar.
# O codigo de producao (player, minigame) nao conhece nenhuma flag; tudo mora aqui.
const TEST_HARNESSES := {
	"--autotest": "res://scripts/test/test_capture.gd",
	"--hudposetest": "res://scripts/test/test_hud_pose.gd",
	"--debughudtest": "res://scripts/test/test_debug_hud.gd",
	"--tablettest": "res://scripts/test/test_tablets.gd",
	"--doortest": "res://scripts/test/test_doors.gd",
	"--abbathtest": "res://scripts/test/test_abbath.gd",
	"--abbathsoundtest": "res://scripts/test/test_abbath_sound.gd",
}
# Modelagem isolada do Abbath (tratada a parte, com retorno antecipado).
const MODEL_TEST_FLAGS := ["--abbathmodeltest", "--abbathmodelview"]

func _ready() -> void:
	_setup_display()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()

	if args.has("--abbathmodeltest") or args.has("--abbathmodelview"):
		_setup_abbath_model_test(args.has("--abbathmodelview"))
		return

	var level := Node3D.new()
	level.name = "Level"
	level.set_script(load("res://scripts/gameplay/level.gd"))
	add_child(level)

	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(-50.0, 1.5, -42.0)
	# Em execucao de teste nao capturamos o mouse (o player nao le mais as flags).
	if _is_headless_test(args):
		player.set("capture_mouse", false)
	add_child(player)
	# Vira o player para o centro da sala (apenas yaw).
	player.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	player.rotation = Vector3(0, player.rotation.y, 0)

	var abbath := Node3D.new()
	abbath.name = "Abbath"
	abbath.set_script(load("res://scripts/gameplay/abbath.gd"))
	abbath.set("player", player)
	abbath.set("pillars", level.pillars)
	add_child(abbath)

	# HUD montado como cena (scenes/hud.tscn). O abbath_ref e injetado antes de
	# entrar na arvore, para o _ready do painel de debug ja ter a referencia.
	var hud_layer := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	hud_layer.get_node("DebugHud").set("abbath_ref", abbath)
	add_child(hud_layer)

	# Monta o harness pedido pela flag. set() ignora refs que o script nao declara,
	# entao passamos player/abbath para todos sem precisar saber quem usa o que.
	for flag in TEST_HARNESSES:
		if not args.has(flag):
			continue
		var harness := Node.new()
		harness.set_script(load(TEST_HARNESSES[flag]))
		harness.set("player_ref", player)
		harness.set("abbath_ref", abbath)
		add_child(harness)

func _setup_abbath_model_test(keep_open: bool = false) -> void:
	var abbath := Node3D.new()
	abbath.name = "AbbathModelPreview"
	abbath.set_script(load("res://scripts/gameplay/abbath.gd"))
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
	t.set_script(load("res://scripts/test/test_abbath.gd"))
	t.set("model_only", true)
	t.set("keep_model_view_open", keep_open)
	t.set("abbath_ref", abbath)
	t.set("camera_ref", cam)
	add_child(t)

## True se alguma flag de teste/modelagem foi passada na linha de comando.
func _is_headless_test(args) -> bool:
	for flag in TEST_HARNESSES:
		if args.has(flag):
			return true
	for flag in MODEL_TEST_FLAGS:
		if args.has(flag):
			return true
	return false

func _setup_display() -> void:
	## Renderiza no tamanho real da tela conectada (resolucao nativa do monitor).
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if _is_headless_test(args):
		# Em teste: janela fixa para screenshots deterministicas.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = Vector2i(1280, 720)
		return
	# Acompanha o monitor onde a janela esta e usa o tamanho dele.
	var screen := DisplayServer.window_get_current_screen()
	get_window().size = DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
