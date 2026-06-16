extends StaticBody3D
## Porta de saida do desafio: surge numa parede depois que os 5 tablets foram
## ativados. Um pouco maior que o personagem. No escuro fica invisivel; quando a
## onda a atinge, a superficie brilha e a MOLDURA passa a ficar acesa de vez
## (a "amostra" da porta). Apertando E de frente e perto, o MIOLO acende em
## verde neon e a interface de reiniciar aparece.

# x = largura, y = altura, z = espessura. Maior que o player (~0.8 x 1.8).
var door_size: Vector3 = Vector3(1.4, 2.6, 0.2)
var face_normal := Vector3.FORWARD   # direcao da face visivel (para interacao)
var is_open := false

const BORDER := 0.16                 # espessura da moldura (igual ao shader)

var _mat: ShaderMaterial
var _revealed := false

func setup(p_size: Vector3, p_normal: Vector3) -> void:
	door_size = p_size
	face_normal = p_normal.normalized()

func _ready() -> void:
	var shader: Shader = load("res://assets/door.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("half_w", door_size.x * 0.5)
	_mat.set_shader_parameter("half_h", door_size.y * 0.5)
	_mat.set_shader_parameter("border", BORDER)
	_mat.set_shader_parameter("revealed", false)
	_mat.set_shader_parameter("opened", false)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = door_size
	mi.mesh = bm
	mi.material_override = _mat
	add_child(mi)

	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = door_size
	cs.shape = shp
	add_child(cs)

	DoorManager.register(self)

func _process(_delta: float) -> void:
	# Assim que a frente de uma onda alcanca a porta, a moldura fica acesa de vez.
	if not _revealed and WaveManager.has_reached(global_position):
		_revealed = true
		_mat.set_shader_parameter("revealed", true)

func open() -> bool:
	if is_open:
		return false
	is_open = true
	# Garante a moldura acesa mesmo que o jogador abra antes de qualquer onda.
	_revealed = true
	_mat.set_shader_parameter("revealed", true)
	_mat.set_shader_parameter("opened", true)
	return true
