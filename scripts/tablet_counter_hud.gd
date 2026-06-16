extends Label
## Contador "0 / 5" dos tablets ativados, no topo da tela.

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -160.0
	offset_right = 160.0
	offset_top = 22.0
	offset_bottom = 92.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 46)
	add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("outline_size", 9)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	TabletManager.count_changed.connect(_on_count_changed)
	_on_count_changed(TabletManager.activated_count, TabletManager.TOTAL)

func _on_count_changed(activated: int, total: int) -> void:
	text = "%d / %d" % [activated, total]
	# Tudo verde quando completa o desafio.
	if activated >= total:
		add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
