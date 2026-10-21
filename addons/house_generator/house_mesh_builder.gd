@tool
class_name HouseMeshBuilder
extends RefCounted

## Builds one [ArrayMesh] from [HouseProperties].
##
## The mesh is centered on XZ with its base on Y = 0. Several surfaces share that
## mesh (walls, roof, trim, foundation, door, glass, chimney) so Terrain3D can
## instance it as a single MultiMesh.

const WALL := 0
const ROOF := 1
const TRIM := 2
const FOUNDATION := 3
const DOOR := 4
const GLASS := 5
const CHIMNEY := 6
## Extra width of the foundation past the walls, on each axis.
const FOUNDATION_PAD := 0.08
## Longest gap between porch posts. Wider houses get more posts so the roof span stays short.
const PORCH_POST_SPAN := 2.4
## How far a catalog mesh continues below the origin. Steeper sites are rejected instead of buried.
const CATALOG_SKIRT := 1.5

const _Surface := preload("res://addons/house_generator/house_surface.gd")
const _SURFACE_NAMES: PackedStringArray = [
	"wall", "roof", "trim", "foundation", "door", "glass", "chimney",
]


static func build(properties: HouseProperties, lod: int = 0, post_bottoms: PackedFloat32Array = PackedFloat32Array(), catalog: bool = false) -> ArrayMesh:
	var builder := Builder.new()
	builder.post_bottoms = post_bottoms
	builder.catalog = catalog
	return builder.run(properties, lod)


## Local post positions. X and Z are the post center; Y is the top, where it meets the porch roof.
static func porch_post_layout(properties: HouseProperties) -> PackedVector3Array:
	if properties == null or not properties.porch:
		return PackedVector3Array()
	var builder := Builder.new()
	builder.props = properties
	builder._compute_dimensions()
	return builder._porch_post_points()


class Builder:
	var props: HouseProperties
	## 0 is the near mesh, 1 the solid mid mesh, 2 the far silhouette.
	var lod: int = 0
	var sts: Array = []
	var counts: Array[int] = []

	var width: float
	var depth: float
	var floors: int
	var floor_h: float
	var found_h: float
	var thickness: float
	var hx: float
	var hz: float
	var front_h: float
	var back_h: float
	var pitch: float
	var overhang: float
	var peak_y: float
	var break_z: float
	var y_break: float
	var door_center_x: float
	var post_bottoms: PackedFloat32Array = PackedFloat32Array()
	## Catalog meshes share one vertex-colored material and extend a skirt below the origin.
	var catalog: bool = false
	var paint: Array[Color] = []
	## Walls stop this far below the roof surface so the two faces do not sit on the same plane.
	const _ROOF_TUCK := 0.05
	## Solid wall kept between a door and the nearest ground-floor window.
	const _DOOR_PIER := 0.46

	func run(properties: HouseProperties, level: int) -> ArrayMesh:
		props = properties
		lod = clampi(level, 0, 2)
		paint = _paint_colors()
		sts.clear()
		counts.clear()
		for i in 7:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts.append(st)
			counts.append(0)
		_compute_dimensions()
		if lod < 2:
			_add_foundation()
		_add_walls()
		_add_roof()
		if lod < 2:
			_add_porch()
		if lod == 0:
			_add_step()
		if lod < 2:
			_add_chimney()
		if props.style == HouseProperties.Style.CHURCH:
			_add_church_masses()
		return _commit()

	func _compute_dimensions() -> void:
		width = maxf(props.width, 2.0)
		depth = maxf(props.depth, 2.0)
		floors = clampi(props.floors, 1, 5)
		floor_h = clampf(props.floor_height, 2.2, 4.0)
		found_h = clampf(props.foundation_height, 0.0, 1.5)
		thickness = clampf(props.wall_thickness, 0.08, 0.35)
		hx = width * 0.5
		hz = depth * 0.5
		front_h = floors * floor_h
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
		if lod >= 2:
			_add_far_walls()
			return
		var y0 := found_h
		var front_wall := _below_roof(front_h)
		var back_wall := _below_roof(back_h)
		var front_open: Array = _layout(width, front_h, 0, true) if lod == 0 else []
		_add_rect_wall(Vector3(-hx, y0, -hz), Vector3.RIGHT, width, front_wall, Vector3.FORWARD, front_open, true)
		var right_open: Array = _layout(depth, minf(front_h, back_h), 1, false) if lod == 0 else []
		_add_side_wall(Vector3(hx, y0, -hz), Vector3(0, 0, 1), depth, front_wall, back_wall, Vector3.RIGHT, right_open)
		var back_open: Array = _layout(width, back_h, 2, false) if lod == 0 else []
		_add_rect_wall(Vector3(hx, y0, hz), Vector3.LEFT, width, back_wall, Vector3.BACK, back_open, true)
		var left_open: Array = _layout(depth, minf(front_h, back_h), 3, false) if lod == 0 else []
		_add_side_wall(Vector3(-hx, y0, hz), Vector3(0, 0, -1), depth, back_wall, front_wall, Vector3.LEFT, left_open)

	func _add_far_walls() -> void:
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
		_face4(WALL, p00, p10, p11, p01, outward)

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
		_panel(ROOF, [
			Vector3(x0, y_outer, -hz - overhang),
			Vector3(x1, y_outer, -hz - overhang),
			Vector3(x1, peak_y, 0),
			Vector3(x0, peak_y, 0),
		], 0.12)
		_panel(ROOF, [
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
			_panel(ROOF, [Vector3(x0, y_outer, z0), Vector3(x1, y_outer, z0), r1, r0], thick)
			_panel(ROOF, [Vector3(x1, y_outer, z1), Vector3(x0, y_outer, z1), r0, r1], thick)
			_panel(ROOF, [Vector3(x0, y_outer, z1), Vector3(x0, y_outer, z0), r0], thick)
			_panel(ROOF, [Vector3(x1, y_outer, z0), Vector3(x1, y_outer, z1), r1], thick)
		else:
			var rz := maxf(0.0, hz - hx)
			var r0 := Vector3(0.0, peak_y, -rz)
			var r1 := Vector3(0.0, peak_y, rz)
			_panel(ROOF, [Vector3(x0, y_outer, z0), Vector3(x1, y_outer, z0), r0], thick)
			_panel(ROOF, [Vector3(x1, y_outer, z1), Vector3(x0, y_outer, z1), r1], thick)
			_panel(ROOF, [Vector3(x0, y_outer, z1), Vector3(x0, y_outer, z0), r0, r1], thick)
			_panel(ROOF, [Vector3(x1, y_outer, z0), Vector3(x1, y_outer, z1), r1, r0], thick)

	func _add_roof_flat() -> void:
		var y := found_h + front_h
		var oh := minf(overhang, 0.25)
		_panel(ROOF, [
			Vector3(-hx - oh, y, -hz - oh),
			Vector3(hx + oh, y, -hz - oh),
			Vector3(hx + oh, y, hz + oh),
			Vector3(-hx - oh, y, hz + oh),
		], 0.1)
		if lod != 0:
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
		_panel(ROOF, [
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
		_panel(ROOF, [
			Vector3(x0, y_outer, -hz - overhang),
			Vector3(x1, y_outer, -hz - overhang),
			Vector3(x1, y_break, -break_z),
			Vector3(x0, y_break, -break_z),
		], thick)
		_panel(ROOF, [
			Vector3(x0, y_break, -break_z),
			Vector3(x1, y_break, -break_z),
			Vector3(x1, peak_y, 0),
			Vector3(x0, peak_y, 0),
		], thick)
		_panel(ROOF, [
			Vector3(x1, y_outer, hz + overhang),
			Vector3(x0, y_outer, hz + overhang),
			Vector3(x0, y_break, break_z),
			Vector3(x1, y_break, break_z),
		], thick)
		_panel(ROOF, [
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
		if lod == 0:
			_box(TRIM, Vector3(0, deck_top - 0.05, (-hz + z_outer) * 0.5), Vector3(deck_span, 0.1, pd))
		var z_wall := -hz - 0.02
		_panel(ROOF, [
			Vector3(x0, y_outer, z_outer),
			Vector3(x1, y_outer, z_outer),
			Vector3(x1, y_wall, z_wall),
			Vector3(x0, y_wall, z_wall),
		], 0.07)
		if lod != 0:
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
		var pd := clampf(props.porch_depth, 0.6, 3.5)
		var x0 := -hx + 0.2
		var x1 := hx - 0.2
		if x1 - x0 < 1.2:
			return {}
		var head := _ground_floor_window_top()
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
		_box(CHIMNEY, Vector3(cx, bottom + height * 0.5, cz), Vector3(cw, height, cw))
		if lod == 0:
			_box(CHIMNEY, Vector3(cx, bottom + height + 0.05, cz), Vector3(cw + 0.14, 0.1, cw + 0.14))

	func _layout(length: float, wall_height: float, wall_id: int, with_door: bool) -> Array:
		var windows := _windows_on(wall_id)
		if windows and props.style == HouseProperties.Style.SHOP and with_door:
			return _shop_front(length, wall_height)
		if windows and props.style == HouseProperties.Style.CHURCH and _church_plan() == 2 and wall_id == 2:
			return _church_glass_wall(length, wall_height)
		var openings: Array = []
		var door := Rect2()
		var has_door := false
		if with_door:
			var door_w := minf(props.door_width, maxf(0.6, length - 0.7))
			var door_h := minf(props.door_height, maxf(1.2, wall_height - 0.12))
			var u := _door_u(length, door_w)
			door = Rect2(u, 0.0, door_w, door_h)
			has_door = true
			openings.append({"rect": door, "door": true})
			door_center_x = -hx + door.position.x + door.size.x * 0.5
		if not windows:
			return openings
		var ww := clampf(props.window_width, 0.35, 1.8)
		var gap := maxf(0.5, ww * 0.62)
		var margin := 0.42
		var usable := length - margin * 2.0
		if usable < ww * 0.75:
			return openings
		var max_fit := maxi(1, int(floor((usable + gap) / (ww + gap))))
		var columns := max_fit if props.window_columns <= 0 else mini(props.window_columns, max_fit)
		if catalog and props.style != HouseProperties.Style.OFFICE:
			columns = mini(columns, 2)
		var row_w := columns * ww + (columns - 1) * gap
		var start := (length - row_w) * 0.5
		var xs: Array = []
		for c in columns:
			xs.append(start + c * (ww + gap))
		_spread_around_door(xs, ww, door, has_door, length)
		var placed: Array[Rect2] = []
		if has_door:
			placed.append(door)
		var window_count := 0
		for f in floors:
			var tallest := _tallest_window(f, columns, wall_id).y
			var sill := _window_sill(f, tallest)
			if sill + 0.4 > wall_height - 0.16:
				continue
			var head := sill + tallest
			if head > wall_height - 0.16:
				head = wall_height - 0.16
			if head - sill < 0.4:
				continue
			var above_door := has_door and sill >= door.end.y - 0.02
			for c in columns:
				var size := _window_size(f, c, columns, wall_id)
				var pane_h := minf(size.y, head - sill)
				if pane_h < 0.4:
					continue
				var center := float(xs[c]) + ww * 0.5
				var rect := Rect2(center - size.x * 0.5, head - pane_h, size.x, pane_h)
				rect = _fit_beside_door(rect, door, has_door and not above_door, length, placed)
				if rect.size.x <= 0.0:
					continue
				if _unit(1000 + wall_id * 100 + f * 10 + c) < props.window_omit:
					continue
				openings.append({"rect": rect, "door": false})
				placed.append(rect)
				window_count += 1
			if above_door:
				var mid := _window_size(f, columns / 2, columns, wall_id)
				var over_h := minf(mid.y, head - sill)
				var over := _window_over_door(door, Vector2(mid.x, over_h), head - over_h, length, placed)
				if over.size.x > 0.0 and _unit(1200 + wall_id * 10 + f) >= props.window_omit:
					openings.append({"rect": over, "door": false})
					placed.append(over)
					window_count += 1
		if window_count == 0:
			var fallback := _fallback_window(length, wall_height, door, has_door)
			if fallback.size.x > 0.0:
				openings.append({"rect": fallback, "door": false})
		return openings

	func _shop_front(length: float, wall_height: float) -> Array:
		var openings: Array = []
		var margin := 0.4
		var door_w := minf(props.door_width, maxf(0.8, length - 1.4))
		var door_h := minf(props.door_height, maxf(1.8, wall_height - 0.3))
		var door_x := margin
		match props.door_side:
			HouseProperties.HouseSide.RIGHT:
				door_x = length - margin - door_w
			HouseProperties.HouseSide.CENTER:
				door_x = (length - door_w) * 0.5
		var door := Rect2(door_x, 0.0, door_w, door_h)
		openings.append({"rect": door, "door": true})
		door_center_x = -hx + door.position.x + door.size.x * 0.5
		var door_gap := 0.42
		var sill := 0.32
		var head := minf(door_h + 0.08, wall_height - 0.35)
		if props.door_side == HouseProperties.HouseSide.CENTER:
			_shop_glass(openings, margin, door.position.x - door_gap, sill, head)
			_shop_glass(openings, door.end.x + door_gap, length - margin, sill, head)
		elif props.door_side == HouseProperties.HouseSide.LEFT:
			_shop_glass(openings, door.end.x + door_gap, length - margin, sill, head)
		else:
			_shop_glass(openings, margin, door.position.x - door_gap, sill, head)
		if floors > 1:
			_append_window_row(openings, length, wall_height, 1, floors - 1, door, true, 0)
		return openings

	func _shop_glass(openings: Array, x0: float, x1: float, sill: float, head: float) -> void:
		if head - sill <= 0.8 or x1 - x0 <= 0.8:
			return
		var mullion := 0.2
		if x1 - x0 > 4.2:
			var mid := (x0 + x1) * 0.5
			openings.append({"rect": Rect2(x0, sill, mid - mullion * 0.5 - x0, head - sill), "door": false})
			openings.append({"rect": Rect2(mid + mullion * 0.5, sill, x1 - mid - mullion * 0.5, head - sill), "door": false})
		else:
			openings.append({"rect": Rect2(x0, sill, x1 - x0, head - sill), "door": false})


	func _append_window_row(openings: Array, length: float, wall_height: float, first_floor: int, floor_count: int, door: Rect2, has_door: bool, wall_id: int) -> void:
		var ww := clampf(props.window_width, 0.35, 1.8)
		var gap := maxf(0.5, ww * 0.62)
		var margin := 0.42
		var usable := length - margin * 2.0
		if usable < ww * 0.75:
			return
		var max_fit := maxi(1, int(floor((usable + gap) / (ww + gap))))
		var columns := max_fit if props.window_columns <= 0 else mini(props.window_columns, max_fit)
		if catalog and props.style != HouseProperties.Style.OFFICE:
			columns = mini(columns, 2)
		var row_w := columns * ww + (columns - 1) * gap
		var start := (length - row_w) * 0.5
		var placed: Array[Rect2] = []
		if has_door:
			placed.append(door)
		for f in floor_count:
			var floor_index := first_floor + f
			var tallest := _tallest_window(floor_index, columns, wall_id).y
			var sill := _window_sill(floor_index, tallest)
			var head := sill + tallest
			if head > wall_height - 0.16:
				head = wall_height - 0.16
			if head - sill < 0.4:
				continue
			var above_door := has_door and sill >= door.end.y - 0.02
			for c in columns:
				var size := _window_size(floor_index, c, columns, wall_id)
				var pane_h := minf(size.y, head - sill)
				if pane_h < 0.4:
					continue
				var center := start + c * (ww + gap) + ww * 0.5
				var rect := Rect2(center - size.x * 0.5, head - pane_h, size.x, pane_h)
				rect = _fit_beside_door(rect, door, has_door and not above_door, length, placed)
				if rect.size.x <= 0.0:
					continue
				openings.append({"rect": rect, "door": false})
				placed.append(rect)

	func _church_plan() -> int:
		return posmod(int(props.seed), 3)

	## Tall narrow lights in the high wall, with a concrete pier between each.
	func _church_glass_wall(length: float, wall_height: float) -> Array:
		var margin := 1.25
		var sill := 1.4
		var head := wall_height - 0.7
		var slit_w := 0.4
		var count := clampi(int(round(length / 3.3)), 4, 5)
		if head - sill < 2.4 or length < margin * 2.0 + slit_w * float(count):
			return []
		var gap := (length - margin * 2.0 - slit_w * float(count)) / float(count - 1)
		if gap < 0.9:
			return []
		var openings: Array = []
		for i in count:
			var x := margin + float(i) * (slit_w + gap)
			openings.append({"rect": Rect2(x, sill, slit_w, head - sill), "door": false})
		return openings

	## 0 is a west-tower chapel with a narrower chancel, 1 adds a side aisle, 2 is a tilted 1960s hall.
	func _add_church_masses() -> void:
		if _church_plan() == 2:
			_add_campanile()
			return
		_add_west_tower()
		_add_chancel()
		if _church_plan() == 1 and lod < 2:
			_add_side_aisle()

	func _add_west_tower() -> void:
		var side := clampf(depth * 0.46, 2.8, 3.4)
		var cx := -hx - side * 0.5 + 0.28
		var base := _base_y()
		var shaft_top := peak_y + 2.05
		var peak := shaft_top + lerpf(0.85, 2.75, _unit(91))
		_add_prism(WALL, cx - side * 0.5, cx + side * 0.5, -side * 0.5, side * 0.5, base, shaft_top)
		_add_pyramid(ROOF, cx, 0.0, shaft_top - 0.04, peak, side * 0.52, side * 0.52)
		_add_tower_cross(cx, 0.0, peak, 1.0)

	func _add_tower_cross(cx: float, cz: float, y_peak: float, scale: float) -> void:
		var stem := 1.15 * scale
		var arm := 0.46 * scale
		var thick := 0.07 * scale
		var y0 := y_peak - 0.05
		var y1 := y_peak + stem
		var arm_y := y_peak + stem * 0.62
		if lod < 2:
			_box(WALL, Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(thick * 2.0, y1 - y0, thick * 2.0))
			_box(WALL, Vector3(cx, arm_y, cz), Vector3(thick * 2.0, thick * 2.0, arm * 2.0))
			return
		# The far mesh keeps the open sides. A closed cross would push the chapel past its vertex budget.
		_add_prism(WALL, cx - thick, cx + thick, cz - thick, cz + thick, y0, y1)
		_add_prism(WALL, cx - thick, cx + thick, cz - arm, cz + arm, arm_y - thick, arm_y + thick)

	func _add_chancel() -> void:
		var span_z := depth * 0.64
		var span_x := 2.55
		var x0 := hx - 0.22
		var x1 := x0 + span_x
		var z0 := -span_z * 0.5
		var z1 := span_z * 0.5
		var eave := found_h + front_h * 0.52
		var cap := eave + span_z * 0.28
		_add_prism(WALL, x0, x1, z0, z1, _base_y(), eave, -1)
		_face3(WALL, Vector3(x1, eave, z0), Vector3(x1, eave, z1), Vector3(x1, cap, 0.0), Vector3.RIGHT)
		_panel(ROOF, [Vector3(x0, eave, z0), Vector3(x1, eave, z0), Vector3(x1, cap, 0.0), Vector3(x0, cap, 0.0)], 0.08)
		_panel(ROOF, [Vector3(x1, eave, z1), Vector3(x0, eave, z1), Vector3(x0, cap, 0.0), Vector3(x1, cap, 0.0)], 0.08)

	func _add_side_aisle() -> void:
		var x0 := -hx + 0.35
		var x1 := hx - 0.35
		var z_inner := hz - 0.04
		var z_outer := hz + 1.65
		var y_inner := found_h + front_h * 0.46
		var y_outer := y_inner - 0.7
		var y0 := _base_y()
		_face4(WALL, Vector3(x0, y0, z_outer), Vector3(x1, y0, z_outer), Vector3(x1, y_outer, z_outer), Vector3(x0, y_outer, z_outer), Vector3.BACK)
		_face4(WALL, Vector3(x0, y0, z_outer), Vector3(x0, y0, z_inner), Vector3(x0, y_inner, z_inner), Vector3(x0, y_outer, z_outer), Vector3.LEFT)
		_face4(WALL, Vector3(x1, y0, z_inner), Vector3(x1, y0, z_outer), Vector3(x1, y_outer, z_outer), Vector3(x1, y_inner, z_inner), Vector3.RIGHT)
		_panel(ROOF, [
			Vector3(x0, y_inner, z_inner),
			Vector3(x1, y_inner, z_inner),
			Vector3(x1, y_outer, z_outer),
			Vector3(x0, y_outer, z_outer),
		], 0.08)

	func _add_campanile() -> void:
		var side := 1.7
		var cx := hx + side * 0.22
		var cz := hz + side * 0.22
		var top := found_h + back_h + 3.1
		var base := _base_y()
		var lip := 0.14
		var x0 := cx - side * 0.5 - lip
		var x1 := cx + side * 0.5 + lip
		var z0 := cz - side * 0.5 - lip
		var z1 := cz + side * 0.5 + lip
		var cap := top + 0.2
		_add_prism(WALL, cx - side * 0.5, cx + side * 0.5, cz - side * 0.5, cz + side * 0.5, base, top)
		_add_prism(ROOF, x0, x1, z0, z1, top, cap)
		_face4(ROOF, Vector3(x0, cap, z0), Vector3(x1, cap, z0), Vector3(x1, cap, z1), Vector3(x0, cap, z1), Vector3.UP)
		_face4(ROOF, Vector3(x0, top, z1), Vector3(x1, top, z1), Vector3(x1, top, z0), Vector3(x0, top, z0), Vector3.DOWN)
		_add_tower_cross(cx, cz, cap, lerpf(1.7, 2.6, _unit(94)))

	func _add_prism(surface: int, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, omit_x: int = 0) -> void:
		if x1 - x0 < 0.05 or z1 - z0 < 0.05 or y1 - y0 < 0.05:
			return
		_face4(surface, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD)
		_face4(surface, Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3.BACK)
		if omit_x != 1:
			_face4(surface, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT)
		if omit_x != -1:
			_face4(surface, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3.LEFT)

	func _add_pyramid(surface: int, cx: float, cz: float, y0: float, y1: float, half_x: float, half_z: float) -> void:
		var peak := Vector3(cx, y1, cz)
		var a := Vector3(cx - half_x, y0, cz - half_z)
		var b := Vector3(cx + half_x, y0, cz - half_z)
		var c := Vector3(cx + half_x, y0, cz + half_z)
		var d := Vector3(cx - half_x, y0, cz + half_z)
		_face3(surface, a, b, peak, Vector3(0, 0.45, -1))
		_face3(surface, b, c, peak, Vector3(1, 0.45, 0))
		_face3(surface, c, d, peak, Vector3(0, 0.45, 1))
		_face3(surface, d, a, peak, Vector3(-1, 0.45, 0))

	func _fallback_window(length: float, wall_height: float, door: Rect2, has_door: bool) -> Rect2:
		var base := _window_size(0, 0, 1, 0)
		var ww := minf(base.x, length * 0.42)
		var wh := minf(base.y, wall_height * 0.42)
		var sill := maxf(0.48, minf(floor_h * 0.34, wall_height - wh - 0.36))
		if has_door and sill < door.size.y + 0.08:
			sill = door.size.y + 0.16
		if sill + wh > wall_height - 0.12:
			return Rect2()
		var rect := Rect2((length - ww) * 0.5, sill, ww, wh)
		if has_door and _overlaps(rect, door, _DOOR_PIER):
			var left := door.position.x - _DOOR_PIER - ww
			var right := door.end.x + _DOOR_PIER
			if left >= 0.28:
				rect.position.x = left
			elif right + ww <= length - 0.28:
				rect.position.x = right
			else:
				return Rect2()
		return rect

	func _overlaps(a: Rect2, b: Rect2, margin: float) -> bool:
		return a.grow(margin).intersects(b)

	func _add_rect_wall(origin: Vector3, axis_u: Vector3, length: float, height: float, outward: Vector3, openings: Array, cap_top: bool) -> void:
		if height < 0.05 or length < 0.05:
			return
		var xs: Array = [0.0, length]
		var ys: Array = [0.0, height]
		if lod == 0:
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
				if lod == 0 and _cell_open((x0 + x1) * 0.5, (y0 + y1) * 0.5, openings):
					continue
				var p00 := origin + axis_u * x0 + Vector3.UP * y0
				var p10 := origin + axis_u * x1 + Vector3.UP * y0
				var p11 := origin + axis_u * x1 + Vector3.UP * y1
				var p01 := origin + axis_u * x0 + Vector3.UP * y1
				_face4(WALL, p00, p10, p11, p01, outward)
				var shift := -outward * thickness
				_face4(WALL, p00 + shift, p01 + shift, p11 + shift, p10 + shift, -outward)
		if cap_top:
			var top_a := origin + Vector3.UP * height
			var top_b := origin + axis_u * length + Vector3.UP * height
			_face4(WALL, top_a, top_b, top_b - outward * thickness, top_a - outward * thickness, Vector3.UP)
		if lod == 0:
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

	func _windows_on(wall_id: int) -> bool:
		return (props.window_walls & (1 << wall_id)) != 0


	func _door_u(length: float, door_w: float) -> float:
		var margin := 0.36
		match props.door_side:
			HouseProperties.HouseSide.LEFT:
				return margin
			HouseProperties.HouseSide.RIGHT:
				return maxf(margin, length - door_w - margin)
			_:
				return clampf((length - door_w) * 0.5, margin, maxf(margin, length - door_w - margin))


	## Largest pane on a floor, used so every window on that floor shares one head line.
	func _tallest_window(floor_index: int, column_count: int, wall_id: int) -> Vector2:
		var tallest := _window_size(floor_index, 0, column_count, wall_id)
		for c in range(1, column_count):
			var size := _window_size(floor_index, c, column_count, wall_id)
			if size.y > tallest.y:
				tallest = size
		return tallest


	## Base size is the largest pane. The pattern only steps away from it, and a row keeps one head line.
	func _window_size(floor_index: int, column: int, column_count: int, wall_id: int) -> Vector2:
		var w := clampf(props.window_width, 0.35, 1.8)
		var h := clampf(props.window_height, 0.4, 2.2)
		var amount := clampf(props.window_variation, 0.0, 1.0)
		if amount <= 0.001 or props.window_pattern == HouseProperties.WindowPattern.UNIFORM:
			return Vector2(w, h)
		var count := maxi(column_count, 1)
		var bay := clampi(column, 0, count - 1)
		match props.window_pattern:
			HouseProperties.WindowPattern.SMALLER_ABOVE:
				if floor_index > 0:
					w *= lerpf(1.0, 0.82, amount)
					h *= lerpf(1.0, 0.72, amount)
			HouseProperties.WindowPattern.WIDER_ABOVE:
				if floor_index > 0:
					w = minf(w * lerpf(1.0, 1.16, amount), 1.8)
					h *= lerpf(1.0, 0.88, amount)
			HouseProperties.WindowPattern.WIDE_CENTER:
				var reach := float(count - 1) * 0.5
				if reach > 0.51:
					var dist := absf(float(bay) - reach)
					var from_center := clampf((dist - 0.5) / (reach - 0.5), 0.0, 1.0)
					w *= 1.0 - 0.32 * amount * from_center
			HouseProperties.WindowPattern.ALTERNATING:
				if _alternating_narrow(bay, count):
					w *= lerpf(1.0, 0.7, amount)
			HouseProperties.WindowPattern.IRREGULAR:
				var groups := (count + 1) / 2
				if groups > 1:
					var mirror := mini(bay, count - 1 - bay)
					var lowest := 1.0
					var highest := 0.0
					var units: Array[float] = []
					for group in groups:
						var unit := _unit(3000 + wall_id * 50 + floor_index * 7 + group)
						units.append(unit)
						lowest = minf(lowest, unit)
						highest = maxf(highest, unit)
					var rank := 1.0
					if highest - lowest > 0.001:
						rank = (units[mirror] - lowest) / (highest - lowest)
					w *= lerpf(1.0 - 0.26 * amount, 1.0, rank)
					h *= lerpf(1.0 - 0.12 * amount, 1.0, rank)
		return Vector2(maxf(w, 0.35), maxf(h, 0.4))


	func _alternating_narrow(column: int, column_count: int) -> bool:
		if column_count <= 2:
			return column % 2 == 1
		var steps := int(round(absf(float(column) - float(column_count - 1) * 0.5)))
		return steps % 2 == 1


	func _spread_around_door(xs: Array, span: float, door: Rect2, has_door: bool, length: float) -> void:
		if not has_door or xs.is_empty():
			return
		var changed := true
		var guard := 0
		while changed and guard < 8:
			changed = false
			guard += 1
			for i in xs.size():
				var x0 := float(xs[i])
				var x1 := x0 + span
				var overlaps := x1 > door.position.x and x0 < door.end.x
				var gap_left := door.position.x - x1
				var gap_right := x0 - door.end.x
				if not overlaps and (gap_left >= _DOOR_PIER or gap_right >= _DOOR_PIER):
					continue
				if not overlaps and gap_left >= 0.0:
					xs[i] = door.position.x - _DOOR_PIER - span
				elif not overlaps and gap_right >= 0.0:
					xs[i] = door.end.x + _DOOR_PIER
				else:
					var to_left := door.position.x - _DOOR_PIER - span
					var to_right := door.end.x + _DOOR_PIER
					var left_fits := to_left >= 0.28
					var right_fits := to_right + span <= length - 0.28
					if left_fits and not right_fits:
						xs[i] = to_left
					elif right_fits and not left_fits:
						xs[i] = to_right
					elif absf(x0 - to_left) <= absf(x0 - to_right):
						xs[i] = to_left
					else:
						xs[i] = to_right
				changed = true
		xs.sort()
		for i in range(1, xs.size()):
			var min_x := float(xs[i - 1]) + span + 0.32
			if float(xs[i]) < min_x:
				xs[i] = min_x
		for i in xs.size():
			xs[i] = clampf(float(xs[i]), 0.28, maxf(0.28, length - 0.28 - span))


	func _fit_beside_door(rect: Rect2, door: Rect2, has_door: bool, length: float, placed: Array[Rect2]) -> Rect2:
		if rect.position.x < 0.28 or rect.end.x > length - 0.28:
			return Rect2()
		if has_door and _overlaps(rect, door, _DOOR_PIER):
			return Rect2()
		if _hits_opening(rect, placed):
			return Rect2()
		return rect


	func _window_over_door(door: Rect2, size: Vector2, sill: float, length: float, placed: Array[Rect2]) -> Rect2:
		var x := door.position.x + door.size.x * 0.5 - size.x * 0.5
		var rect := Rect2(x, sill, size.x, size.y)
		return _fit_beside_door(rect, door, false, length, placed)


	func _hits_opening(rect: Rect2, placed: Array[Rect2]) -> bool:
		for other in placed:
			if rect.grow(0.12).intersects(other):
				return true
		return false


	func _window_sill(floor_index: int, window_height: float) -> float:
		return floor_index * floor_h + maxf(0.54, floor_h - window_height - 0.56)

	func _ground_floor_window_top() -> float:
		var wh := clampf(props.window_height, 0.45, 2.2)
		var sill := _window_sill(0, wh)
		if sill + wh > front_h - 0.16:
			wh = maxf(0.4, front_h - 0.16 - sill)
		return sill + wh

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
			_face3(WALL, clean[0], clean[i], clean[i + 1], outward)
		if lod >= 2:
			return
		for i in range(1, inner.size() - 1):
			_face3(WALL, inner[0], inner[i + 1], inner[i], -outward)
		for i in clean.size():
			var j := (i + 1) % clean.size()
			var hint := (clean[j] - clean[i]).cross(outward)
			_face4(WALL, clean[i], clean[j], inner[j], inner[i], hint)

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
