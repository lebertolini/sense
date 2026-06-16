extends Control
## Interface de reiniciar. Fica escondida ate o jogador abrir a porta de saida
## (DoorManager.door_opened). Mostra um botao "REINICIAR" (i18n) que recarrega o
## jogo do zero, resetando os autoloads de estado.

const NEON_GREEN := Color(0.3, 1.0, 0.55)
const INK_SHADOW := Color(0.0, 0.0, 0.0, 0.85)
const BLOOD_RED := Color(0.85, 0.08, 0.12)

var _button: Button
var _overlay: ColorRect    # fundo vermelho do jumpscare (so quando pego pelo Abbath)
var _title: Label          # texto "ABBATH TE PEGOU" no jumpscare

func _ready() -> void:
	# Cobre a tela inteira; comeca invisivel e sem capturar cliques.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Fundo vermelho do jumpscare: escondido ate o Abbath pegar o jogador.
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(BLOOD_RED.r, BLOOD_RED.g, BLOOD_RED.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	# Titulo do jumpscare (so aparece quando pego pelo Abbath).
	_title = Label.new()
	_title.text = tr("CAUGHT")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	_title.add_theme_color_override("font_outline_color", INK_SHADOW)
	_title.add_theme_constant_override("outline_size", 12)
	_title.visible = false
	box.add_child(_title)

	_button = Button.new()
	_button.text = tr("RESTART")
	_button.custom_minimum_size = Vector2(360, 96)
	_button.add_theme_font_size_override("font_size", 46)
	_button.add_theme_color_override("font_color", NEON_GREEN)
	_button.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.8))
	_button.add_theme_color_override("font_focus_color", NEON_GREEN)
	_button.add_theme_color_override("font_outline_color", INK_SHADOW)
	_button.add_theme_constant_override("outline_size", 9)
	# Fundo discreto com borda verde neon, no tom do jogo.
	_button.add_theme_stylebox_override("normal", _make_style(0.18))
	_button.add_theme_stylebox_override("hover", _make_style(0.32))
	_button.add_theme_stylebox_override("pressed", _make_style(0.45))
	_button.add_theme_stylebox_override("focus", _make_style(0.32))
	_button.pressed.connect(_on_restart_pressed)
	box.add_child(_button)

	DoorManager.door_opened.connect(_on_door_opened)
	AbbathManager.jumpscare.connect(_on_jumpscare)

func _make_style(fill_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.12, 0.08, fill_alpha)
	sb.border_color = NEON_GREEN
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	return sb

func _on_door_opened() -> void:
	_reveal()

# Jumpscare do Abbath: tela vermelha + "ABBATH TE PEGOU" e a mesma UI de reiniciar.
func _on_jumpscare() -> void:
	_overlay.color = Color(BLOOD_RED.r, BLOOD_RED.g, BLOOD_RED.b, 0.55)
	_overlay.visible = true
	_title.visible = true
	_reveal()

func _reveal() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Libera o mouse para o jogador clicar no botao.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_button.grab_focus()

func _on_restart_pressed() -> void:
	# Reseta o estado dos autoloads (eles sobrevivem ao reload da cena).
	WaveManager.reset()
	TabletManager.reset()
	DoorManager.reset()
	AbbathManager.reset()
	get_tree().reload_current_scene()
