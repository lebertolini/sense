extends Node
## Captura screenshots do HUD nas duas poses (padrao e alt via TAB).

var _t := 0.0
var _stage := 0
var _out_dir := ""

func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://test_output/")
	DirAccess.make_dir_recursive_absolute(_out_dir)

func _process(delta: float) -> void:
	_t += delta
	match _stage:
		0:
			if _t > 0.6:
				await _capture("hud_pose_default")
				_stage = 1
				_t = 0.0
		1:
			if _t > 0.2:
				var ev := InputEventKey.new()
				ev.physical_keycode = KEY_TAB
				ev.pressed = true
				Input.parse_input_event(ev)
				_stage = 2
				_t = 0.0
		2:
			if _t > 0.5:
				await _capture("hud_pose_alt")
				_stage = 3
				_t = 0.0
		3:
			if _t > 0.2:
				get_tree().quit()

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%sshot_%s.png" % [_out_dir, tag]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[hud_pose] screenshot: ", path)
