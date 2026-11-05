@tool
class_name HouseMeshWriter
extends RefCounted

## Low-level surface emission and mesh commit for house builds.

const WALL := HouseMeshBuilder.WALL
const ROOF := HouseMeshBuilder.ROOF
const TRIM := HouseMeshBuilder.TRIM
const FOUNDATION := HouseMeshBuilder.FOUNDATION
const DOOR := HouseMeshBuilder.DOOR
const GLASS := HouseMeshBuilder.GLASS
const CHIMNEY := HouseMeshBuilder.CHIMNEY
const METAL := HouseMeshBuilder.METAL
const METAL_ROOF := HouseMeshBuilder.METAL_ROOF

const _Surface := preload("res://addons/house_generator/house_surface.gd")
const _SURFACE_NAMES: PackedStringArray = [
	"wall", "roof", "trim", "foundation", "door", "glass", "chimney", "wall", "roof",
]

var props: HouseProperties
var lod: int = 0
var sts: Array = []
var counts: Array[int] = []
var catalog: bool = false
var paint: Array[Color] = []
var hx: float
var hz: float
var found_h: float
var front_h: float
var back_h: float

func begin_surfaces() -> void:
	sts.clear()
	counts.clear()
	for i in _SURFACE_NAMES.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
		counts.append(0)

func _panel(surface: int, points: Array, panel_thickness: float) -> void:
	var pts: Array[Vector3] = _dedupe_points(points)
	if pts.size() < 3:
		return
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.y < 0.0:
		n = -n
		pts.reverse()
	if lod >= 2:
		if pts.size() == 3:
			_face3(surface, pts[0], pts[1], pts[2], n)
		else:
			_face4(surface, pts[0], pts[1], pts[2], pts[3], n)
		return
	var lower: Array[Vector3] = []
	for p in pts:
		lower.append(p - n * panel_thickness)
	if pts.size() == 3:
		_face3(surface, pts[0], pts[1], pts[2], Vector3.UP)
		_face3(TRIM, lower[0], lower[1], lower[2], Vector3.DOWN)
	else:
		_face4(surface, pts[0], pts[1], pts[2], pts[3], Vector3.UP)
		_face4(TRIM, lower[0], lower[1], lower[2], lower[3], Vector3.DOWN)
		# Extra bends on gambrel/hip quads stay planar; ignore accidental 5+ points.
	var centroid := Vector3.ZERO
	for p in pts:
		centroid += p
	centroid /= float(pts.size())
	for i in pts.size():
		var j := (i + 1) % pts.size()
		var hint := (pts[i] + pts[j]) * 0.5 - centroid
		hint.y = 0.0
		if hint.length_squared() < 1e-8:
			hint = (pts[j] - pts[i]).cross(Vector3.UP)
		_face4(TRIM, pts[i], lower[i], lower[j], pts[j], hint)


func _box(surface: int, center: Vector3, size: Vector3) -> void:
	if size.x < 0.002 or size.y < 0.002 or size.z < 0.002:
		return
	var he := size * 0.5
	var x := Vector3(he.x, 0, 0)
	var y := Vector3(0, he.y, 0)
	var z := Vector3(0, 0, he.z)
	_face4(surface, center - x + y - z, center + x + y - z, center + x + y + z, center - x + y + z, Vector3.UP)
	_face4(surface, center - x - y - z, center - x - y + z, center + x - y + z, center + x - y - z, Vector3.DOWN)
	_face4(surface, center - x - y - z, center + x - y - z, center + x + y - z, center - x + y - z, Vector3.FORWARD)
	_face4(surface, center + x - y + z, center - x - y + z, center - x + y + z, center + x + y + z, Vector3.BACK)
	_face4(surface, center + x - y - z, center + x - y + z, center + x + y + z, center + x + y - z, Vector3.RIGHT)
	_face4(surface, center - x - y + z, center - x - y - z, center - x + y - z, center - x + y + z, Vector3.LEFT)


func _face4(surface: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) < 0.0:
		var swap := b
		b = d
		d = swap
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Godot front faces are clockwise when viewed from outside. The cross product
	# above points outward, so the emitted order is the reverse of that loop.
	_vert(surface, a, n)
	_vert(surface, c, n)
	_vert(surface, b, n)
	_vert(surface, a, n)
	_vert(surface, d, n)
	_vert(surface, c, n)


func _face3(surface: int, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	_vert(surface, a, n)
	_vert(surface, c, n)
	_vert(surface, b, n)


func _vert(surface: int, p: Vector3, n: Vector3) -> void:
	var st: SurfaceTool = sts[surface]
	st.set_normal(n)
	st.set_uv(_face_uv(p, n))
	st.set_uv2(Vector2(float(surface), 0.0))
	var shade := _occlusion(surface, p, n)
	if catalog:
		var tint := paint[surface]
		st.set_color(Color(tint.r * shade, tint.g * shade, tint.b * shade))
	else:
		st.set_color(Color(shade, shade, shade))
	st.add_vertex(p)
	counts[surface] = counts[surface] + 1

## One tile is 4 m. Horizontal faces keep plan coordinates so roof courses run across the slope.

func _face_uv(p: Vector3, n: Vector3) -> Vector2:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	var uv := Vector2(p.x, p.y)
	if ay >= ax and ay >= az:
		uv = Vector2(p.x, p.z)
	elif ax >= az:
		uv = Vector2(p.z, p.y)
	return uv * 0.25


func _occlusion(surface: int, p: Vector3, n: Vector3) -> float:
	if surface == GLASS:
		return 1.0
	var shade := 1.0
	if absf(n.y) < 0.55:
		var above := clampf(maxf(p.y, 0.0) / 0.9, 0.0, 1.0)
		shade *= lerpf(0.76, 1.0, above)
		if absf(p.x) <= hx + 0.35 and absf(p.z) <= hz + 0.35:
			var edge_x := clampf((hx - absf(p.x)) / 0.4, 0.0, 1.0)
			var edge_z := clampf((hz - absf(p.z)) / 0.4, 0.0, 1.0)
			shade *= lerpf(0.84, 1.0, minf(edge_x, edge_z))
			# The gable follows the slope, so measure from the plate. Using the
			# roof height would darken the whole triangle above the rectangle.
			var plate := found_h + minf(front_h, back_h)
			var below_plate := plate - p.y
			if below_plate >= -0.02 and below_plate < 0.45:
				shade *= lerpf(0.82, 1.0, clampf(below_plate / 0.45, 0.0, 1.0))
		var from_center := Vector3(p.x, 0.0, p.z)
		if from_center.length_squared() > 0.04 and n.dot(from_center.normalized()) < -0.65:
			shade *= 0.9
	elif n.y < -0.65:
		shade *= 0.78
	return clampf(shade, 0.62, 1.0)


func _paint_colors() -> Array[Color]:
	return [
		_varied_wall(props.wall_color, props.seed),
		props.roof_color,
		props.trim_color,
		props.foundation_color,
		props.door_color,
		props.glass_color,
		props.chimney_color,
		_varied_wall(props.wall_color, props.seed),
		props.roof_color,
	]


func _commit() -> ArrayMesh:
	if catalog:
		return _commit_catalog()
	var mesh := ArrayMesh.new()
	var colors := paint
	var out_index := 0
	for i in sts.size():
		if counts[i] == 0:
			continue
		sts[i].set_material(_Surface.editor_material(i, colors[i], i == GLASS))
		sts[i].commit(mesh)
		mesh.surface_set_name(out_index, _SURFACE_NAMES[i])
		out_index += 1
	return mesh


func _commit_catalog() -> ArrayMesh:
	var merged := SurfaceTool.new()
	merged.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in sts.size():
		if counts[i] == 0:
			continue
		var temp := ArrayMesh.new()
		sts[i].commit(temp)
		merged.append_from(temp, 0, Transform3D.IDENTITY)
		any = true
	var mesh := ArrayMesh.new()
	if not any:
		return mesh
	merged.set_material(_Surface.catalog_material())
	merged.commit(mesh)
	mesh.surface_set_name(0, "house")
	return mesh


func _varied_wall(color: Color, seed_value: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value) * 13 + 5
	var varied := color
	varied.h = fposmod(varied.h + rng.randf_range(-0.015, 0.015), 1.0)
	varied.s = clampf(varied.s * rng.randf_range(0.94, 1.06), 0.0, 1.0)
	varied.v = clampf(varied.v * rng.randf_range(0.93, 1.07), 0.0, 1.0)
	return varied


func _unit(salt: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(props.seed) + salt * 7919
	return rng.randf()


func _unique_sorted(values: Array) -> Array:
	values.sort()
	var out: Array = []
	for v in values:
		if out.is_empty() or absf(float(v) - float(out[out.size() - 1])) > 0.0008:
			out.append(float(v))
	return out


func _dedupe_points(points: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in points:
		var point := p as Vector3
		if out.is_empty() or out[out.size() - 1].distance_squared_to(point) > 0.000004:
			out.append(point)
	if out.size() >= 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.000004:
		out.remove_at(out.size() - 1)
	return out
