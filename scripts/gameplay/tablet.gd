extends StaticBody3D
## Um tablet do desafio: retangulo achatado pequeno revelado pela onda (amarelo).
## Ao ser ativado pelo jogador (apertar de frente), fica aceso em verde para
## sempre. A orientacao/posicao e definida por quem o instancia (level.gd).

var slab_size: Vector3 = Vector3(1.0, 0.6, 0.08) # x=largura, y=altura, z=espessura
var face_normal := Vector3.FORWARD              # direcao da face visivel (para interacao)
var is_activated := false

var _mat: ShaderMaterial

func setup(p_size: Vector3, p_normal: Vector3) -> void:
	slab_size = p_size
	face_normal = p_normal.normalized()

func _ready() -> void:
	var shader: Shader = load("res://assets/shaders/tablet.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("activated", false)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = slab_size
	mi.mesh = bm
	mi.material_override = _mat
	add_child(mi)

	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = slab_size
	cs.shape = shp
	add_child(cs)

	TabletManager.register(self)

func activate() -> bool:
	if is_activated:
		return false
	is_activated = true
	_mat.set_shader_parameter("activated", true)
	TabletManager.notify_activated(self)
	return true
