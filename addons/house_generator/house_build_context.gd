@tool
class_name HouseBuildContext
extends HouseMeshWriter

## Shared metrics, LOD policy, and mesh primitives for one house build.

enum WallMode { DETAILED, SOLID, SHELL }

enum Composition { RESIDENTIAL, ALPINE, CHURCH, INDUSTRIAL }

const OpeningLayout := preload("res://addons/house_generator/house_opening_layout.gd")
const ElementIndustrial := preload("res://addons/house_generator/elements/house_element_industrial.gd")
const ElementChurch := preload("res://addons/house_generator/elements/house_element_church.gd")
const ElementAlpine := preload("res://addons/house_generator/elements/house_element_alpine.gd")

var policy: HouseLodPolicy
var composition: Composition = Composition.RESIDENTIAL


var width: float
var depth: float
var floors: int
var floor_h: float
var thickness: float
var pitch: float
var overhang: float
var peak_y: float
var break_z: float
var y_break: float
var door_center_x: float
var post_bottoms: PackedFloat32Array = PackedFloat32Array()
## House shells use wall and roof. Hangars and warehouses switch these to the metal tiles.
var shell_wall: int = WALL
var shell_roof: int = ROOF
## Alpine ground floor, measured up the wall from the foundation. Zero keeps the wall one material.
var stone_band: float = 0.0
## Walls stop this far below the roof surface so the two faces do not sit on the same plane.
const _ROOF_TUCK := 0.05
## Solid wall kept between a door and the nearest ground-floor window.
const _DOOR_PIER := 0.46

func run(properties: HouseProperties, level: int) -> ArrayMesh:
	props = properties
	lod = clampi(level, 0, 2)
	policy = HouseLodPolicy.for_build(lod, props)
	composition = HouseRecipes.composition_for(props.style)
	paint = _paint_colors()
	begin_surfaces()
	_compute_dimensions()
	match composition:
		Composition.INDUSTRIAL:
			shell_wall = METAL
			shell_roof = METAL_ROOF
			ElementIndustrial.add_industrial(self)
		Composition.ALPINE:
			_add_residential_shell()
			if policy.alpine_balcony():
				ElementAlpine.add_alpine_balcony(self)
		Composition.CHURCH:
			_add_residential_shell()
			ElementChurch.add_church_masses(self)
		_:
			_add_residential_shell()
	return _commit()


func _add_residential_shell() -> void:
	if policy.foundation():
		_add_foundation()
	_add_walls()
	_add_roof()
	if policy.porch():
		_add_porch()
	if policy.step():
		_add_step()
	if policy.chimney():
		_add_chimney()


func _compute_dimensions() -> void:
	width = maxf(props.width, 2.0)
	depth = maxf(props.depth, 2.0)
	floors = clampi(props.floors, 1, 5)
	floor_h = clampf(props.floor_height, 2.2, 6.5)
	found_h = clampf(props.foundation_height, 0.0, 1.5)
	thickness = clampf(props.wall_thickness, 0.08, 0.35)
	hx = width * 0.5
	hz = depth * 0.5
	front_h = floors * floor_h
	stone_band = floor_h if composition == Composition.ALPINE else 0.0
	# The steep eave drops in front of a one-story chalet and crosses the door.
	if props.style == HouseProperties.Style.CHALET and floors == 1:
		front_h += 0.5
	back_h = front_h
	if props.roof_type == HouseProperties.RoofType.SHED:
		back_h = front_h + depth * maxf(props.roof_pitch, 0.05)
	pitch = 0.0 if props.roof_type == HouseProperties.RoofType.FLAT else maxf(props.roof_pitch, 0.05)
	overhang = maxf(props.roof_overhang, 0.0)
	_compute_roof_metrics()

func _compute_roof_metrics() -> void:
	var y_wall := found_h + front_h
	match props.roof_type:
		HouseProperties.RoofType.FLAT:
			peak_y = y_wall
		HouseProperties.RoofType.SHED:
			peak_y = found_h + back_h
		HouseProperties.RoofType.HIP:
			peak_y = y_wall + minf(hx, hz) * pitch
		HouseProperties.RoofType.GAMBREL:
			break_z = hz * 0.42
			var lower_run := hz - break_z
			y_break = y_wall + lower_run * pitch * 1.35
			peak_y = y_break + break_z * pitch * 0.42
		_:
			# The alpine roof is a cross gable: one ridge height, set by the short span.
			if composition == Composition.ALPINE:
				peak_y = y_wall + minf(hx, hz) * pitch
			else:
				peak_y = y_wall + hz * pitch

func _base_y() -> float:
	return -HouseMeshBuilder.CATALOG_SKIRT if catalog else 0.0

func _add_foundation() -> void:
	var bottom := _base_y()
	var top := found_h
	if top - bottom <= 0.001:
		return
	var pad := HouseMeshBuilder.FOUNDATION_PAD
	_box(FOUNDATION, Vector3(0, (top + bottom) * 0.5, 0), Vector3(width + pad, top - bottom, depth + pad))

func _add_walls() -> void:
	var mode := policy.wall_mode()
	if mode == WallMode.SHELL:
		_add_far_walls()
		return
	if ElementAlpine.cross_roof(self):
		ElementAlpine.add_cross_walls(self, false)
		return
	var y0 := found_h
	var front_wall := _below_roof(front_h)
	var back_wall := _below_roof(back_h)
	var front_open: Array = OpeningLayout.layout(self, width, front_h, 0, true) if policy.openings() else []
	_add_rect_wall(Vector3(-hx, y0, -hz), Vector3.RIGHT, width, front_wall, Vector3.FORWARD, front_open, true)
	var right_open: Array = OpeningLayout.layout(self, depth, minf(front_h, back_h), 1, false) if policy.openings() else []
	_add_side_wall(Vector3(hx, y0, -hz), Vector3(0, 0, 1), depth, front_wall, back_wall, Vector3.RIGHT, right_open)
	var back_open: Array = OpeningLayout.layout(self, width, back_h, 2, false) if policy.openings() else []
	_add_rect_wall(Vector3(hx, y0, hz), Vector3.LEFT, width, back_wall, Vector3.BACK, back_open, true)
	var left_open: Array = OpeningLayout.layout(self, depth, minf(front_h, back_h), 3, false) if policy.openings() else []
	_add_side_wall(Vector3(-hx, y0, hz), Vector3(0, 0, -1), depth, back_wall, front_wall, Vector3.LEFT, left_open)

func _add_far_walls() -> void:
	if ElementAlpine.cross_roof(self):
		ElementAlpine.add_cross_walls(self, true)
		return
	var base := _base_y()
	var front_top := found_h + _below_roof(front_h) - base
	var back_top := found_h + _below_roof(back_h) - base
	_add_shell_wall(Vector3(-hx, base, -hz), Vector3.RIGHT, width, front_top, Vector3.FORWARD)
	_add_far_side(Vector3(hx, base, -hz), Vector3(0, 0, 1), depth, front_top, back_top, Vector3.RIGHT)
	_add_shell_wall(Vector3(hx, base, hz), Vector3.LEFT, width, back_top, Vector3.BACK)
	_add_far_side(Vector3(-hx, base, hz), Vector3(0, 0, -1), depth, back_top, front_top, Vector3.LEFT)

func _add_far_side(origin: Vector3, axis_u: Vector3, length: float, h_start: float, h_end: float, outward: Vector3) -> void:
	var h_rect := minf(h_start, h_end)
	_add_shell_wall(origin, axis_u, length, h_rect, outward)
	if props.roof_type == HouseProperties.RoofType.GABLE or props.roof_type == HouseProperties.RoofType.GAMBREL:
		_add_end_profile(origin, axis_u, length, outward)
	elif absf(h_start - h_end) > 0.02:
		_add_slope_cap(origin, axis_u, length, h_start, h_end, outward)

func _add_shell_wall(origin: Vector3, axis_u: Vector3, length: float, height: float, outward: Vector3) -> void:
	if height < 0.05 or length < 0.05:
		return
	var p00 := origin
	var p10 := origin + axis_u * length
	var p11 := p10 + Vector3.UP * height
	var p01 := origin + Vector3.UP * height
	_face4(shell_wall, p00, p10, p11, p01, outward)

func _below_roof(height: float) -> float:
	return maxf(0.2, height - _ROOF_TUCK)

func _add_side_wall(origin: Vector3, axis_u: Vector3, length: float, h_start: float, h_end: float, outward: Vector3, openings: Array) -> void:
	var h_rect := minf(h_start, h_end)
	var profile := (
		props.roof_type == HouseProperties.RoofType.GABLE
		or props.roof_type == HouseProperties.RoofType.GAMBREL
		or absf(h_start - h_end) > 0.02
	)
	_add_rect_wall(origin, axis_u, length, h_rect, outward, openings, not profile)
	if props.roof_type == HouseProperties.RoofType.GABLE or props.roof_type == HouseProperties.RoofType.GAMBREL:
		_add_end_profile(origin, axis_u, length, outward)
	elif absf(h_start - h_end) > 0.02:
		_add_slope_cap(origin, axis_u, length, h_start, h_end, outward)

func _add_roof() -> void:
	if ElementAlpine.cross_roof(self):
		ElementAlpine.add_roof_cross(self)
		return
	match props.roof_type:
		HouseProperties.RoofType.HIP:
			_add_roof_hip()
		HouseProperties.RoofType.FLAT:
			_add_roof_flat()
		HouseProperties.RoofType.SHED:
			_add_roof_shed()
		HouseProperties.RoofType.GAMBREL:
			_add_roof_gambrel()
		_:
			_add_roof_gable()

func _add_roof_gable() -> void:
	var y_wall := found_h + front_h
	var y_outer := y_wall - overhang * pitch
	var x0 := -hx - overhang
	var x1 := hx + overhang
	_panel(shell_roof, [
		Vector3(x0, y_outer, -hz - overhang),
		Vector3(x1, y_outer, -hz - overhang),
		Vector3(x1, peak_y, 0),
		Vector3(x0, peak_y, 0),
	], 0.12)
	_panel(shell_roof, [
		Vector3(x1, y_outer, hz + overhang),
		Vector3(x0, y_outer, hz + overhang),
		Vector3(x0, peak_y, 0),
		Vector3(x1, peak_y, 0),
	], 0.12)

func _add_roof_hip() -> void:
	var y_wall := found_h + front_h
	var y_outer := y_wall - overhang * pitch
	var x0 := -hx - overhang
	var x1 := hx + overhang
	var z0 := -hz - overhang
	var z1 := hz + overhang
	var thick := 0.12
	if hx + 0.001 >= hz:
		var rx := maxf(0.0, hx - hz)
		var r0 := Vector3(-rx, peak_y, 0.0)
		var r1 := Vector3(rx, peak_y, 0.0)
		_panel(shell_roof, [Vector3(x0, y_outer, z0), Vector3(x1, y_outer, z0), r1, r0], thick)
		_panel(shell_roof, [Vector3(x1, y_outer, z1), Vector3(x0, y_outer, z1), r0, r1], thick)
		_panel(shell_roof, [Vector3(x0, y_outer, z1), Vector3(x0, y_outer, z0), r0], thick)
		_panel(shell_roof, [Vector3(x1, y_outer, z0), Vector3(x1, y_outer, z1), r1], thick)
	else:
		var rz := maxf(0.0, hz - hx)
		var r0 := Vector3(0.0, peak_y, -rz)
		var r1 := Vector3(0.0, peak_y, rz)
		_panel(shell_roof, [Vector3(x0, y_outer, z0), Vector3(x1, y_outer, z0), r0], thick)
		_panel(shell_roof, [Vector3(x1, y_outer, z1), Vector3(x0, y_outer, z1), r1], thick)
		_panel(shell_roof, [Vector3(x0, y_outer, z1), Vector3(x0, y_outer, z0), r0, r1], thick)
		_panel(shell_roof, [Vector3(x1, y_outer, z0), Vector3(x1, y_outer, z1), r1, r0], thick)

func _add_roof_flat() -> void:
	var y := found_h + front_h
	var oh := minf(overhang, 0.25)
	_panel(shell_roof, [
		Vector3(-hx - oh, y, -hz - oh),
		Vector3(hx + oh, y, -hz - oh),
		Vector3(hx + oh, y, hz + oh),
		Vector3(-hx - oh, y, hz + oh),
	], 0.1)
	if not policy.flat_roof_trim():
		return
	var ph := 0.24
	var t := 0.1
	var y_center := y + ph * 0.5 - 0.03
	_box(TRIM, Vector3(0, y_center, -hz + t * 0.35), Vector3(width, ph, t))
	_box(TRIM, Vector3(0, y_center, hz - t * 0.35), Vector3(width, ph, t))
	_box(TRIM, Vector3(-hx + t * 0.35, y_center, 0), Vector3(t, ph, depth))
	_box(TRIM, Vector3(hx - t * 0.35, y_center, 0), Vector3(t, ph, depth))

func _add_roof_shed() -> void:
	var yf := found_h + front_h
	var yb := found_h + back_h
	var slope := (yb - yf) / depth
	var y_front_edge := yf - overhang * slope
	var y_back_edge := yb + overhang * slope
	var x0 := -hx - overhang
	var x1 := hx + overhang
	_panel(shell_roof, [
		Vector3(x0, y_front_edge, -hz - overhang),
		Vector3(x1, y_front_edge, -hz - overhang),
		Vector3(x1, y_back_edge, hz + overhang),
		Vector3(x0, y_back_edge, hz + overhang),
	], 0.1)

func _add_roof_gambrel() -> void:
	var y_wall := found_h + front_h
	var lower_run := maxf(0.2, hz - break_z)
	var lower_slope := (y_break - y_wall) / lower_run
	var y_outer := y_wall - overhang * lower_slope
	var x0 := -hx - overhang
	var x1 := hx + overhang
	var thick := 0.1
	_panel(shell_roof, [
		Vector3(x0, y_outer, -hz - overhang),
		Vector3(x1, y_outer, -hz - overhang),
		Vector3(x1, y_break, -break_z),
		Vector3(x0, y_break, -break_z),
	], thick)
	_panel(shell_roof, [
		Vector3(x0, y_break, -break_z),
		Vector3(x1, y_break, -break_z),
		Vector3(x1, peak_y, 0),
		Vector3(x0, peak_y, 0),
	], thick)
	_panel(shell_roof, [
		Vector3(x1, y_outer, hz + overhang),
		Vector3(x0, y_outer, hz + overhang),
		Vector3(x0, y_break, break_z),
		Vector3(x1, y_break, break_z),
	], thick)
	_panel(shell_roof, [
		Vector3(x1, y_break, break_z),
		Vector3(x0, y_break, break_z),
		Vector3(x0, peak_y, 0),
		Vector3(x1, peak_y, 0),
	], thick)

func _add_porch() -> void:
	var metrics := _porch_metrics()
	if metrics.is_empty():
		return
	var x0: float = metrics.x0
	var x1: float = metrics.x1
	var z_outer: float = metrics.z_outer
	var pd: float = metrics.pd
	var deck_top: float = metrics.deck_top
	var y_outer: float = metrics.y_outer
	var y_wall: float = metrics.y_wall
	var deck_span := x1 - x0
	if policy.porch_posts_and_deck() and props.style != HouseProperties.Style.STATION:
		_box(TRIM, Vector3(0, deck_top - 0.05, (-hz + z_outer) * 0.5), Vector3(deck_span, 0.1, pd))
	var z_wall: float = metrics.z_attach if metrics.has("z_attach") else -hz - 0.02
	_panel(shell_roof, [
		Vector3(x0, y_outer, z_outer),
		Vector3(x1, y_outer, z_outer),
		Vector3(x1, y_wall, z_wall),
		Vector3(x0, y_wall, z_wall),
	], 0.07)
	if not policy.porch_posts_and_deck():
		return
	var posts := _porch_post_points()
	for i in posts.size():
		var post := posts[i]
		var bottom := _base_y()
		if i < post_bottoms.size():
			bottom = post_bottoms[i]
		if catalog:
			bottom = maxf(bottom, _base_y())
		bottom = minf(bottom, post.y - 0.5)
		var height := post.y - bottom
		if height < 0.4:
			continue
		_box(TRIM, Vector3(post.x, bottom + height * 0.5, post.z), Vector3(0.13, height, 0.13))

func _porch_metrics() -> Dictionary:
	if not props.porch:
		return {}
	if props.style == HouseProperties.Style.STATION:
		var canopy := clampf(props.porch_depth, 1.8, 3.2)
		var plate := found_h + front_h
		var y_eave := plate - overhang * pitch
		return {
			"x0": -hx - minf(overhang, 0.4),
			"x1": hx + minf(overhang, 0.4),
			"z_outer": -hz - canopy,
			"z_attach": -hz - maxf(0.0, overhang - 0.08),
			"pd": canopy,
			"deck_top": found_h,
			"y_wall": y_eave - 0.18,
			"y_outer": y_eave - 0.34,
		}
	var pd := clampf(props.porch_depth, 0.6, 3.5)
	var x0 := -hx + 0.2
	var x1 := hx - 0.2
	if x1 - x0 < 1.2:
		return {}
	var head := OpeningLayout.ground_floor_window_top(self)
	var attach := minf(maxf(props.door_height + 0.4, head + 0.36), front_h - _ROOF_TUCK - 0.08)
	var y_wall := found_h + attach
	return {
		"x0": x0,
		"x1": x1,
		"z_outer": -hz - pd,
		"pd": pd,
		"deck_top": found_h,
		"y_wall": y_wall,
		"y_outer": y_wall - 0.14,
	}

func _porch_post_points() -> PackedVector3Array:
	var metrics := _porch_metrics()
	var points := PackedVector3Array()
	if metrics.is_empty():
		return points
	var x0: float = metrics.x0
	var x1: float = metrics.x1
	var inset := 0.16
	var x_start := x0 + inset
	var x_end := x1 - inset
	if x_end - x_start < 0.4:
		return points
	var gaps := maxi(1, int(ceil((x_end - x_start) / HouseMeshBuilder.PORCH_POST_SPAN)))
	var z := float(metrics.z_outer) + 0.16
	var top := float(metrics.y_outer)
	for i in gaps + 1:
		var x := lerpf(x_start, x_end, float(i) / float(gaps))
		points.append(Vector3(x, top, z))
	return points

func _add_step() -> void:
	if lod != 0 or props.porch or found_h < 0.08:
		return
	var dw := minf(props.door_width + 0.3, width - 0.3)
	var z_inner := -hz - 0.08
	var z_outer := -hz - 0.55
	_box(
		FOUNDATION,
		Vector3(door_center_x, found_h * 0.45, (z_inner + z_outer) * 0.5),
		Vector3(dw, found_h * 0.9, absf(z_outer - z_inner))
	)

func _add_chimney() -> void:
	if lod >= 2 or not props.chimney:
		return
	var sign := 0.0
	match props.chimney_side:
		HouseProperties.HouseSide.LEFT:
			sign = -1.0
		HouseProperties.HouseSide.RIGHT:
			sign = 1.0
	var cw := 0.46
	var top := peak_y + 0.7
	var bottom := found_h + minf(front_h, back_h) * 0.5
	var height := maxf(0.8, top - bottom)
	var cx := hx * 0.28 * sign
	var cz := hz * 0.25 if props.roof_type == HouseProperties.RoofType.SHED else hz * 0.16
	if ElementAlpine.cross_roof(self):
		if absf(sign) < 0.5:
			sign = 1.0
		cx = hx * 0.38 * sign
		cz = 0.0
	_box(CHIMNEY, Vector3(cx, bottom + height * 0.5, cz), Vector3(cw, height, cw))
	if policy.chimney_cap():
		_box(CHIMNEY, Vector3(cx, bottom + height + 0.05, cz), Vector3(cw + 0.14, 0.1, cw + 0.14))

func _add_rect_wall(origin: Vector3, axis_u: Vector3, length: float, height: float, outward: Vector3, openings: Array, cap_top: bool) -> void:
	if height < 0.05 or length < 0.05:
		return
	var xs: Array = [0.0, length]
	var ys: Array = [0.0, height]
	if stone_band > 0.05 and stone_band < height - 0.05:
		ys.append(stone_band)
	if policy.openings():
		for op in openings:
			var r: Rect2 = op.rect
			xs.append(r.position.x)
			xs.append(r.end.x)
			ys.append(r.position.y)
			ys.append(r.end.y)
	var xu := _unique_sorted(xs)
	var yu := _unique_sorted(ys)
	for i in xu.size() - 1:
		for j in yu.size() - 1:
			var x0: float = xu[i]
			var x1: float = xu[i + 1]
			var y0: float = yu[j]
			var y1: float = yu[j + 1]
			if x1 - x0 < 0.002 or y1 - y0 < 0.002:
				continue
			if policy.openings() and _cell_open((x0 + x1) * 0.5, (y0 + y1) * 0.5, openings):
				continue
			var p00 := origin + axis_u * x0 + Vector3.UP * y0
			var p10 := origin + axis_u * x1 + Vector3.UP * y0
			var p11 := origin + axis_u * x1 + Vector3.UP * y1
			var p01 := origin + axis_u * x0 + Vector3.UP * y1
			var surface := FOUNDATION if stone_band > 0.05 and (y0 + y1) * 0.5 < stone_band else shell_wall
			_face4(surface, p00, p10, p11, p01, outward)
			var shift := -outward * thickness
			_face4(surface, p00 + shift, p01 + shift, p11 + shift, p10 + shift, -outward)
	if cap_top:
		var top_a := origin + Vector3.UP * height
		var top_b := origin + axis_u * length + Vector3.UP * height
		_face4(shell_wall, top_a, top_b, top_b - outward * thickness, top_a - outward * thickness, Vector3.UP)
	if policy.openings():
		for op in openings:
			_add_opening(origin, axis_u, outward, op)

func _cell_open(u: float, v: float, openings: Array) -> bool:
	for op in openings:
		var r: Rect2 = op.rect
		if u > r.position.x + 0.0001 and u < r.end.x - 0.0001 and v > r.position.y + 0.0001 and v < r.end.y - 0.0001:
			return true
	return false

func _add_opening(origin: Vector3, axis_u: Vector3, outward: Vector3, op: Dictionary) -> void:
	var r: Rect2 = op.rect
	var u0 := r.position.x
	var v0 := r.position.y
	var u1 := r.end.x
	var v1 := r.end.y
	var ob0 := origin + axis_u * u0 + Vector3.UP * v0
	var ob1 := origin + axis_u * u1 + Vector3.UP * v0
	var ot1 := origin + axis_u * u1 + Vector3.UP * v1
	var ot0 := origin + axis_u * u0 + Vector3.UP * v1
	var ib0 := ob0 - outward * thickness
	var ib1 := ob1 - outward * thickness
	var it1 := ot1 - outward * thickness
	var it0 := ot0 - outward * thickness
	_face4(TRIM, ob0, ot0, it0, ib0, axis_u)
	_face4(TRIM, ob1, ib1, it1, ot1, -axis_u)
	_face4(TRIM, ob0, ob1, ib1, ib0, Vector3.UP)
	_face4(TRIM, ot0, it0, it1, ot1, Vector3.DOWN)
	if op.door:
		var center := origin + axis_u * ((u0 + u1) * 0.5) + Vector3.UP * ((v1 - 0.03) * 0.5) - outward * thickness * 0.32
		var size := axis_u.abs() * (u1 - u0 - 0.08) + Vector3.UP * (v1 - 0.04) + outward.abs() * 0.05
		_box(DOOR, center, size)
	else:
		var mid := -outward * thickness * 0.45
		var g0 := origin + axis_u * u0 + Vector3.UP * v0 + mid
		var g1 := origin + axis_u * u1 + Vector3.UP * v0 + mid
		var g2 := origin + axis_u * u1 + Vector3.UP * v1 + mid
		var g3 := origin + axis_u * u0 + Vector3.UP * v1 + mid
		_face4(GLASS, g0, g1, g2, g3, outward)
		if not catalog:
			_add_frame(origin, axis_u, outward, u0, v0, u1, v1, false)
	if not op.door:
		return
	_add_frame(origin, axis_u, outward, u0, v0, u1, v1, true)

func _add_frame(origin: Vector3, axis_u: Vector3, outward: Vector3, u0: float, v0: float, u1: float, v1: float, is_door: bool) -> void:
	var fw := 0.055
	var fd := 0.035
	var along := (u1 - u0) + fw * 2.0
	var lift := outward * (fd * 0.5)
	var mid_u := (u0 + u1) * 0.5
	_box(TRIM, origin + axis_u * mid_u + Vector3.UP * v1 + lift, axis_u.abs() * along + Vector3.UP * fw + outward.abs() * fd)
	if not is_door:
		_box(TRIM, origin + axis_u * mid_u + Vector3.UP * v0 + lift, axis_u.abs() * along + Vector3.UP * fw + outward.abs() * fd)
	var side_h := maxf(0.05, (v1 - v0) - fw - 0.008)
	var side_v := (v0 + v1) * 0.5
	if is_door:
		side_h = maxf(0.05, v1 - v0 - fw * 0.5 - 0.008)
		side_v = v0 + side_h * 0.5
	var side_size := axis_u.abs() * fw + Vector3.UP * side_h + outward.abs() * fd
	_box(TRIM, origin + axis_u * u0 + Vector3.UP * side_v + lift, side_size)
	_box(TRIM, origin + axis_u * u1 + Vector3.UP * side_v + lift, side_size)

func _add_opening_decal(origin: Vector3, axis_u: Vector3, outward: Vector3, op: Dictionary) -> void:
	var r: Rect2 = op.rect
	var lift := outward * 0.012
	var p0 := origin + axis_u * r.position.x + Vector3.UP * r.position.y + lift
	var p1 := origin + axis_u * r.end.x + Vector3.UP * r.position.y + lift
	var p2 := origin + axis_u * r.end.x + Vector3.UP * r.end.y + lift
	var p3 := origin + axis_u * r.position.x + Vector3.UP * r.end.y + lift
	_face4(DOOR if op.door else GLASS, p0, p1, p2, p3, outward)

func _add_slope_cap(origin: Vector3, axis_u: Vector3, length: float, h_start: float, h_end: float, outward: Vector3) -> void:
	var h_min := minf(h_start, h_end)
	var pts: Array = [
		origin + Vector3.UP * h_min,
		origin + axis_u * length + Vector3.UP * h_min,
		origin + axis_u * length + Vector3.UP * h_end,
		origin + Vector3.UP * h_start,
	]
	_add_wall_polygon(pts, outward)

func _add_end_profile(origin: Vector3, axis_u: Vector3, length: float, outward: Vector3) -> void:
	var y_wall := found_h + _below_roof(minf(front_h, back_h))
	var a := origin
	a.y = y_wall
	var b := origin + axis_u * length
	b.y = y_wall
	var mids: Array[Vector3] = []
	if props.roof_type == HouseProperties.RoofType.GAMBREL:
		mids.append(_wall_point(origin, axis_u, _u_at_z(origin, axis_u, -break_z), y_break - _ROOF_TUCK))
		mids.append(_wall_point(origin, axis_u, _u_at_z(origin, axis_u, 0.0), peak_y - _ROOF_TUCK))
		mids.append(_wall_point(origin, axis_u, _u_at_z(origin, axis_u, break_z), y_break - _ROOF_TUCK))
	else:
		mids.append(_wall_point(origin, axis_u, length * 0.5, peak_y - _ROOF_TUCK))
	mids.sort_custom(func(p: Vector3, q: Vector3) -> bool:
		return (p - origin).dot(axis_u) < (q - origin).dot(axis_u)
	)
	var pts: Array = [a]
	for mid in mids:
		pts.append(mid)
	pts.append(b)
	_add_wall_polygon(pts, outward)

func _wall_point(origin: Vector3, axis_u: Vector3, u: float, y: float) -> Vector3:
	var p := origin + axis_u * u
	p.y = y
	return p

func _u_at_z(origin: Vector3, axis_u: Vector3, z: float) -> float:
	if absf(axis_u.z) < 0.001:
		return 0.0
	return (z - origin.z) / axis_u.z

func _add_wall_polygon(points: Array, outward: Vector3) -> void:
	var clean: Array[Vector3] = _dedupe_points(points)
	if clean.size() < 3:
		return
	var inner: Array[Vector3] = []
	for p in clean:
		inner.append(p - outward * thickness)
	for i in range(1, clean.size() - 1):
		_face3(shell_wall, clean[0], clean[i], clean[i + 1], outward)
	if policy == null or not policy.wall_inner_faces():
		return
	for i in range(1, inner.size() - 1):
		_face3(shell_wall, inner[0], inner[i + 1], inner[i], -outward)
	for i in clean.size():
		var j := (i + 1) % clean.size()
		var hint := (clean[j] - clean[i]).cross(outward)
		_face4(shell_wall, clean[i], clean[j], inner[j], inner[i], hint)

