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
# Pecas registradas para depois grudar os tablets.
# caixa: {center: Vector3, size: Vector3, yaw: float}
var _box_list: Array = []
# pilar: {center: Vector3, radius: float, height: float}
var _pillar_list: Array = []

func _ready() -> void:
	var shader: Shader = load("res://assets/sonar.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rng.seed = 20260616

	_build_shell()
	_build_pillars()
	_build_boxes()
	_build_tablets()

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
					_pillar_list.append({"center": Vector3(px, HEIGHT * 0.5, pz), "radius": r, "height": HEIGHT})
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
		_box_list.append({"center": Vector3(px, sy * 0.5, pz), "size": Vector3(sx, sy, sz), "yaw": yaw})
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

# --- Tablets do desafio ---------------------------------------------------

func _build_tablets() -> void:
	# 5 tablets: 2 grudados em caixas, 2 em pilares, 1 no chao.
	# Tamanhos variados para ficar natural.
	var sizes := [
		Vector3(1.2, 0.72, 0.08),
		Vector3(0.85, 0.55, 0.07),
		Vector3(1.0, 0.62, 0.08),
		Vector3(0.9, 0.6, 0.07),
		Vector3(1.3, 0.7, 0.09),
	]
	var plan := ["box", "box", "pillar", "pillar", "floor"]
	for i in plan.size():
		var ok := false
		match plan[i]:
			"box":
				ok = _place_tablet_on_box(sizes[i])
			"pillar":
				ok = _place_tablet_on_pillar(sizes[i])
			_:
				ok = _place_tablet_on_floor(sizes[i])
		if not ok:
			_place_tablet_on_floor(sizes[i]) # fallback garante os 5

func _place_tablet_on_box(size: Vector3) -> bool:
	if _box_list.is_empty():
		return false
	for _attempt in 16:
		var b: Dictionary = _box_list[_rng.randi() % _box_list.size()]
		var bsize: Vector3 = b["size"]
		var center: Vector3 = b["center"]
		var yaw: float = b["yaw"]
		var top := center.y + bsize.y * 0.5
		if top < 0.8 or bsize.y < size.y + 0.2:
			continue
		# Escolhe uma face lateral (nunca o topo).
		var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
		var axis: Vector3 = axes[_rng.randi() % 4]
		var on_x := absf(axis.x) > 0.5
		var half := (bsize.x * 0.5) if on_x else (bsize.z * 0.5)
		var face_w := bsize.z if on_x else bsize.x
		if face_w < size.x + 0.15:
			continue
		var bx := Basis(Vector3.UP, yaw)
		var normal := (bx * axis).normalized()
		# Altura visivel: ate a altura do personagem (ou pouco acima).
		var hi := minf(top - size.y * 0.5 - 0.05, 2.1)
		var lo := size.y * 0.5 + 0.2
		if hi < lo:
			continue
		var ty := _rng.randf_range(lo, hi)
		var pos := Vector3(center.x, ty, center.z) + normal * (half + size.z * 0.5 + 0.02)
		_spawn_tablet(pos, _basis_from_normal(normal), normal, size)
		return true
	return false

func _place_tablet_on_pillar(size: Vector3) -> bool:
	if _pillar_list.is_empty():
		return false
	for _attempt in 16:
		var p: Dictionary = _pillar_list[_rng.randi() % _pillar_list.size()]
		var radius: float = p["radius"]
		var center: Vector3 = p["center"]
		var ang := _rng.randf_range(-PI, PI)
		var normal := Vector3(cos(ang), 0.0, sin(ang))
		# Nao muito alto: ate a altura do personagem ou pouco acima.
		var ty := _rng.randf_range(1.0, 2.3)
		var pos := Vector3(center.x, ty, center.z) + normal * (radius + size.z * 0.5 + 0.02)
		_spawn_tablet(pos, _basis_from_normal(normal), normal, size)
		return true
	return false

func _place_tablet_on_floor(size: Vector3) -> bool:
	var clear := maxf(size.x, size.y) * 0.6 + 0.6
	for _attempt in 80:
		var px := _rng.randf_range(-HALF_X + 4.0, HALF_X - 4.0)
		var pz := _rng.randf_range(-HALF_Z + 4.0, HALF_Z - 4.0)
		if not _is_free(px, pz, clear):
			continue
		var yaw := _rng.randf_range(-PI, PI)
		var pos := Vector3(px, size.z * 0.5 + 0.02, pz)
		var basis := Basis(Vector3.UP, yaw) * _basis_from_normal(Vector3.UP)
		_spawn_tablet(pos, basis, Vector3.UP, size)
		return true
	# Ultimo recurso: numa area garantidamente livre perto do player.
	var fpos := Vector3(PLAYER_XZ.x + 9.0, size.z * 0.5 + 0.02, PLAYER_XZ.y)
	_spawn_tablet(fpos, _basis_from_normal(Vector3.UP), Vector3.UP, size)
	return true

func _spawn_tablet(center: Vector3, basis: Basis, normal: Vector3, size: Vector3) -> void:
	var t := StaticBody3D.new()
	t.set_script(load("res://scripts/tablet.gd"))
	t.setup(size, normal)
	t.transform = Transform3D(basis.orthonormalized(), center)
	add_child(t)

# Base ortonormal cuja coluna Z aponta para `n` (face visivel do tablet).
func _basis_from_normal(n: Vector3) -> Basis:
	n = n.normalized()
	var up := Vector3.UP
	if absf(n.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x := up.cross(n).normalized()
	var y := n.cross(x).normalized()
	return Basis(x, y, n)
