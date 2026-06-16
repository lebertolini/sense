extends Node3D
## Constroi proceduralmente a sala fechada (grande): chao, teto, paredes,
## pilares e caixas distribuidos de forma natural. Cada peca ganha colisao.

# Meia-extensao interna da sala (~10x a area original).
const HALF_X := 60.0
const HALF_Z := 50.0
const HEIGHT := 14.0
const WALL := 1.0

# Onde o player comeca (mantemos uma area livre ao redor).
const PLAYER_XZ := Vector2(-50.0, -42.0)
const PLAYER_CLEAR := 14.0

var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
# Cada item ocupado: Vector3(x, z, raio) para evitar sobreposicoes.
var _occupied: Array[Vector3] = []

func _ready() -> void:
	var shader: Shader = load("res://assets/sonar.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rng.seed = 20260616

	_build_shell()
	_build_pillars()
	_build_boxes()

func _build_shell() -> void:
	var sx := HALF_X * 2.0 + WALL * 2.0
	var sz := HALF_Z * 2.0 + WALL * 2.0
	# Chao e teto.
	_add_box(Vector3(0, -0.5, 0), Vector3(sx, WALL, sz))
	_add_box(Vector3(0, HEIGHT + 0.5, 0), Vector3(sx, WALL, sz))
	# Paredes.
	_add_box(Vector3(0, HEIGHT * 0.5, -HALF_Z - WALL * 0.5), Vector3(sx, HEIGHT, WALL))
	_add_box(Vector3(0, HEIGHT * 0.5, HALF_Z + WALL * 0.5), Vector3(sx, HEIGHT, WALL))
	_add_box(Vector3(-HALF_X - WALL * 0.5, HEIGHT * 0.5, 0), Vector3(WALL, HEIGHT, HALF_Z * 2.0))
	_add_box(Vector3(HALF_X + WALL * 0.5, HEIGHT * 0.5, 0), Vector3(WALL, HEIGHT, HALF_Z * 2.0))

func _build_pillars() -> void:
	# Grade irregular de pilares do chao ao teto.
	var spacing := 15.0
	var margin := 8.0
	var x := -HALF_X + margin
	while x <= HALF_X - margin:
		var z := -HALF_Z + margin
		while z <= HALF_Z - margin:
			if _rng.randf() < 0.82:
				var px := x + _rng.randf_range(-4.0, 4.0)
				var pz := z + _rng.randf_range(-4.0, 4.0)
				var r := _rng.randf_range(0.8, 1.7)
				if _is_free(px, pz, r + 1.0):
					_add_cylinder(Vector3(px, HEIGHT * 0.5, pz), r, HEIGHT)
					_occupied.append(Vector3(px, pz, r))
			z += spacing
		x += spacing

func _build_boxes() -> void:
	# Espalha caixas de tamanhos variados, algumas empilhadas.
	var target := 150
	var placed := 0
	var attempts := 0
	while placed < target and attempts < target * 10:
		attempts += 1
		var px := _rng.randf_range(-HALF_X + 3.0, HALF_X - 3.0)
		var pz := _rng.randf_range(-HALF_Z + 3.0, HALF_Z - 3.0)
		var base := _rng.randf_range(1.0, 4.2)
		var sx := base * _rng.randf_range(0.7, 1.3)
		var sy := base * _rng.randf_range(0.7, 1.5)
		var sz := base * _rng.randf_range(0.7, 1.3)
		var radius := maxf(sx, sz) * 0.5
		if not _is_free(px, pz, radius + 1.0):
			continue
		var yaw := _rng.randf_range(-PI, PI)
		_add_box(Vector3(px, sy * 0.5, pz), Vector3(sx, sy, sz), yaw)
		_occupied.append(Vector3(px, pz, radius))
		placed += 1
		# As vezes empilha uma caixa menor em cima.
		if _rng.randf() < 0.28:
			var s2 := minf(sx, sz) * _rng.randf_range(0.45, 0.75)
			_add_box(Vector3(px, sy + s2 * 0.5, pz), Vector3(s2, s2, s2), _rng.randf_range(-PI, PI))

func _is_free(x: float, z: float, radius: float) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(PLAYER_XZ) < PLAYER_CLEAR + radius:
		return false
	for o in _occupied:
		if p.distance_to(Vector2(o.x, o.y)) < radius + o.z + 0.5:
			return false
	return true

func _add_box(center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat
	mi.position = center
	mi.rotation.y = yaw
	add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	cs.shape = shp
	sb.add_child(cs)
	sb.position = center
	sb.rotation.y = yaw
	add_child(sb)

func _add_cylinder(center: Vector3, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 18
	mi.mesh = cm
	mi.material_override = _mat
	mi.position = center
	add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = radius
	shp.height = height
	cs.shape = shp
	sb.add_child(cs)
	sb.position = center
	add_child(sb)
