extends Control
## HUD da onda: usa as texturas desenhadas a mao (corpo + barras) e mantem em
## codigo apenas os efeitos dinamicos -- o preenchimento das barras e o brilho
## dos olhos. O corpo troca para a pose super_hearing ao apertar TAB.

const NEON_GREEN := Color(0.25, 1.0, 0.75)
const POWER_BLUE := Color(0.42, 0.95, 1.0)
const POWER_CORE := Color(0.86, 1.0, 1.0)
const HUD_WIDTH := 360
const HUD_HEIGHT := 225
const HUD_SIZE := Vector2(HUD_WIDTH, HUD_HEIGHT)
const DRAIN_DURATION := 0.42

# Espaco da arte original exportada no ibis Paint.
const ART_CANVAS := Vector2(1920.0, 1080.0)
# Mapeia a arte (1920x1080) sobre a mesma area que o HUD ocupava antes: a bbox
# de conteudo da nova arte cai exatamente sobre a bbox de conteudo de hoje.
# Resultado em pixels do box de referencia (360x225):
const DEST_MIN := Vector2(-42.05, -15.0)
const DEST_SIZE := Vector2(448.13, 240.0)

# Retangulos internos (vazio dentro do contorno) das 16 barras largas, em
# coordenadas da arte. A barra enche de baixo para cima por fracao propria.
const BAR_INNER: Array[Rect2] = [
	Rect2(230, 395, 21, 47),
	Rect2(280, 301, 20, 141),
	Rect2(372, 262, 20, 178),
	Rect2(420, 142, 20, 298),
	Rect2(464, 243, 24, 199),
	Rect2(556, 128, 27, 367),
	Rect2(614, 79, 30, 351),
	Rect2(673, 259, 26, 91),
	Rect2(1208, 259, 25, 91),
	Rect2(1263, 79, 30, 351),
	Rect2(1323, 128, 27, 367),
	Rect2(1418, 243, 25, 199),
	Rect2(1467, 142, 20, 298),
	Rect2(1515, 262, 20, 178),
	Rect2(1606, 301, 21, 141),
	Rect2(1655, 395, 21, 47),
]
# Centros dos olhos desenhados na arte (a aura/brilho em codigo cai aqui).
const EYE_L := Vector2(851.0, 459.0)
const EYE_R := Vector2(1055.0, 459.0)

# As barras sobem este tanto (px da arte) nas duas poses, para abrir espaco para
# as maos do super_hearing sem causar deslocamento ao apertar TAB.
const BAR_RAISE := 120.0

var _body_tex: Texture2D
var _alt_tex: Texture2D
var _bar_tex: Texture2D

var _cooldown_progress := 1.0
var _display_progress := 1.0
var _wave_ready := true
var _draining := false
var _drain_t := 0.0
var _drain_from := 1.0
var _alt_pose := false

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 36.0
	offset_top = -257.0
	offset_right = 396.0
	offset_bottom = -32.0
	custom_minimum_size = HUD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mipmaps deixam o downscale de 1920px liso (sem serrilhado).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_body_tex = load("res://assets/wave_power.png")
	_alt_tex = load("res://assets/super_hearing.png")
	_bar_tex = load("res://assets/power_bar.png")
	set_process_unhandled_input(true)

	WaveManager.cooldown_changed.connect(_on_cooldown_changed)
	WaveManager.wave_used.connect(_on_wave_used)
	_on_cooldown_changed(WaveManager.get_cooldown_progress(), WaveManager.is_wave_ready())

func _process(delta: float) -> void:
	if _draining:
		_drain_t += delta
		var t := clampf(_drain_t / DRAIN_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		_display_progress = lerpf(_drain_from, 0.0, eased)
		if t >= 1.0:
			_draining = false
			_display_progress = _cooldown_progress
	else:
		_display_progress = _cooldown_progress
	queue_redraw()

func _on_cooldown_changed(progress: float, ready: bool) -> void:
	_cooldown_progress = clampf(progress, 0.0, 1.0)
	_wave_ready = ready
	if not _draining:
		_display_progress = _cooldown_progress

func _on_wave_used() -> void:
	_wave_ready = false
	_draining = true
	_drain_t = 0.0
	_drain_from = 1.0

func _draw() -> void:
	var s := size / HUD_SIZE
	var dest := Rect2(_box(Vector2.ZERO), DEST_SIZE * s)
	# Barras sobem nas duas poses (mesma altura sempre, sem pulo no TAB).
	var bar_dy := -BAR_RAISE / ART_CANVAS.y * DEST_SIZE.y * s.y
	var bar_dest := Rect2(dest.position + Vector2(0.0, bar_dy), dest.size)
	# A textura das barras define o contorno; o verde fica por baixo, dentro do
	# vazio de cada barra, e o contorno branco passa por cima (fica nitido).
	_draw_bar_fills(bar_dy)
	draw_texture_rect(_bar_tex, bar_dest, false)
	# Corpo (troca de pose no TAB) por cima das barras.
	var body := _alt_tex if _alt_pose else _body_tex
	draw_texture_rect(body, dest, false)
	# Olhos brilhantes por ultimo.
	_draw_power_eyes()

func _draw_bar_fills(bar_dy: float) -> void:
	var fill := clampf(_display_progress, 0.0, 1.0)
	if fill <= 0.0:
		return
	for source_rect in BAR_INNER:
		var rect := _box_rect(source_rect)
		rect.position.y += bar_dy
		var fill_height := rect.size.y * fill
		var fill_rect := Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y - fill_height),
			Vector2(rect.size.x, fill_height)
		)
		draw_rect(fill_rect, Color(NEON_GREEN, 0.94), true)

func _draw_power_eyes() -> void:
	if not (_wave_ready and _display_progress >= 0.995):
		return
	var left := _box(EYE_L)
	var right := _box(EYE_R)
	for center in [left, right]:
		_draw_filled_ellipse(center, Vector2(18.0, 9.0), Color(POWER_BLUE, 0.10))
		_draw_filled_ellipse(center, Vector2(13.0, 6.0), Color(POWER_BLUE, 0.20))
		_draw_filled_ellipse(center, Vector2(8.2, 3.7), Color(POWER_CORE, 0.62))
	for center in [left, right]:
		_draw_filled_ellipse(center, Vector2(7.0, 3.2), Color(POWER_CORE, 0.88))
		draw_circle(center, 2.4, Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_alt_pose = not _alt_pose
			queue_redraw()
			get_viewport().set_input_as_handled()

func _draw_filled_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var t := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(t) * radius.x, sin(t) * radius.y))
	draw_colored_polygon(points, color)

## Converte um ponto da arte (1920x1080) para a coordenada local do HUD.
func _box(art_pt: Vector2) -> Vector2:
	var s := size / HUD_SIZE
	return (DEST_MIN + art_pt / ART_CANVAS * DEST_SIZE) * s

## Converte um retangulo da arte para o local do HUD.
func _box_rect(art_rect: Rect2) -> Rect2:
	var s := size / HUD_SIZE
	return Rect2(_box(art_rect.position), art_rect.size / ART_CANVAS * DEST_SIZE * s)
