extends PanelContainer
## Painel de diagnostico do Abbath. Ctrl+D alterna sua visibilidade.

var abbath_ref

var _hidden_label: Label
var _required_label: Label
var _hunting_label: Label


func _ready() -> void:
	name = "DebugHud"
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -350.0
	offset_top = 20.0
	offset_right = -20.0
	offset_bottom = 166.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 0.92)
	panel_style.border_color = Color(0.25, 1.0, 0.75, 0.75)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", panel_style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	add_child(rows)

	_hidden_label = _make_label(rows)
	_required_label = _make_label(rows)
	_hunting_label = _make_label(rows)
	_update_values()


func _process(_delta: float) -> void:
	if visible:
		_update_values()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.physical_keycode == KEY_D:
			visible = not visible
			if visible:
				_update_values()
			get_viewport().set_input_as_handled()


func _make_label(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.94))
	parent.add_child(label)
	return label


func _update_values() -> void:
	if not is_instance_valid(abbath_ref) or abbath_ref.player == null:
		_hidden_label.text = "ESCONDIDO: --%"
		_required_label.text = "EXIGIDO:   --%"
		_hunting_label.text = "PERSEGUICAO: INDISPONIVEL"
		_hunting_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
		return

	var visible_fraction: float = abbath_ref.visible_fraction()
	var hidden_percent := roundi(clampf(1.0 - visible_fraction, 0.0, 1.0) * 100.0)
	var distance: float = abbath_ref.global_position.distance_to(abbath_ref.player.global_position)
	var required_percent := roundi(abbath_ref.hide_cover_required(distance) * 100.0)
	var is_hunting: bool = abbath_ref.hunting

	_hidden_label.text = "ESCONDIDO: %3d%%" % hidden_percent
	_required_label.text = "EXIGIDO:   %3d%%" % required_percent
	_hunting_label.text = "PERSEGUICAO: %s" % ("SIM" if is_hunting else "NAO")
	_hunting_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.28, 0.22) if is_hunting else Color(0.25, 1.0, 0.75)
	)
