@tool
class_name HouseElementAlpine
extends RefCounted

## Cross-gable roof, valley walls, and balcony.
##
## The long roof runs left–right across the full width. The front/back cross
## gable is narrower, so the wide facade shows a center gable that does not
## span the whole wall.

## Keep wall tops under the thick roof panels (LOD0 thickness is 0.1).
const _ROOF_TUCK := 0.14


## Half-width of the front/back cross gable on the wall (not including overhang).
static func cross_half_x(ctx: HouseBuildContext) -> float:
	return clampf(ctx.hx * 0.5, 2.2, ctx.hx * 0.62)


## Roof-plan half-width of the cross, scaled so the wall shoulders meet the valley at plate height.
static func cross_x_out(ctx: HouseBuildContext) -> float:
	var half := cross_half_x(ctx)
	return half * (ctx.hz + ctx.overhang) / maxf(ctx.hz, 0.01)


static func cross_roof(ctx: HouseBuildContext) -> bool:
	return ctx.props.style == HouseProperties.Style.ALPINE


static func add_roof_cross(ctx: HouseBuildContext) -> void:
	var y_eave := ctx.found_h + ctx.front_h - ctx.overhang * ctx.pitch
	var x_out := ctx.hx + ctx.overhang
	var z_out := ctx.hz + ctx.overhang
	var cx_out := cross_x_out(ctx)
	var center := Vector3(0, ctx.peak_y, 0)
	var front_peak := Vector3(0, ctx.peak_y, -z_out)
	var back_peak := Vector3(0, ctx.peak_y, z_out)
	var left_peak := Vector3(-x_out, ctx.peak_y, 0)
	var right_peak := Vector3(x_out, ctx.peak_y, 0)
	var lcr := Vector3(-cx_out, ctx.peak_y, 0)
	var rcr := Vector3(cx_out, ctx.peak_y, 0)
	var fl := Vector3(-x_out, y_eave, -z_out)
	var fr := Vector3(x_out, y_eave, -z_out)
	var bl := Vector3(-x_out, y_eave, z_out)
	var br := Vector3(x_out, y_eave, z_out)
	var cfl := Vector3(-cx_out, y_eave, -z_out)
	var cfr := Vector3(cx_out, y_eave, -z_out)
	var cbl := Vector3(-cx_out, y_eave, z_out)
	var cbr := Vector3(cx_out, y_eave, z_out)
	var thick := 0.1
	# Narrow cross gable facing front and back.
	ctx._panel(ctx.shell_roof, [center, front_peak, cfr], thick)
	ctx._panel(ctx.shell_roof, [center, cfl, front_peak], thick)
	ctx._panel(ctx.shell_roof, [center, back_peak, cbl], thick)
	ctx._panel(ctx.shell_roof, [center, cbr, back_peak], thick)
	# Long roof within the cross width (main slopes down to the cross shoulders).
	ctx._panel(ctx.shell_roof, [center, cfr, rcr], thick)
	ctx._panel(ctx.shell_roof, [center, lcr, cfl], thick)
	ctx._panel(ctx.shell_roof, [center, rcr, cbr], thick)
	ctx._panel(ctx.shell_roof, [center, cbl, lcr], thick)
	# Long roof outside the cross: full-width eaves at the corners.
	ctx._panel(ctx.shell_roof, [lcr, left_peak, fl, cfl], thick)
	ctx._panel(ctx.shell_roof, [rcr, cfr, fr, right_peak], thick)
	ctx._panel(ctx.shell_roof, [lcr, cbl, bl, left_peak], thick)
	ctx._panel(ctx.shell_roof, [rcr, right_peak, br, cbr], thick)


static func cross_roof_y(ctx: HouseBuildContext, x: float, z: float) -> float:
	var z_out := ctx.hz + ctx.overhang
	var cx_out := cross_x_out(ctx)
	var y_eave := ctx.found_h + ctx.front_h - ctx.overhang * ctx.pitch
	var along_z := absf(z) / maxf(z_out, 0.01)
	if absf(x) > cx_out:
		return ctx.peak_y - (ctx.peak_y - y_eave) * along_z
	var along_x := absf(x) / maxf(cx_out, 0.01)
	return ctx.peak_y - (ctx.peak_y - y_eave) * minf(along_x, along_z)


static func add_cross_walls(ctx: HouseBuildContext, far: bool) -> void:
	var y0 := ctx._base_y() if far else ctx.found_h
	var wall_h := ctx.found_h + ctx.front_h - _ROOF_TUCK - y0
	var front_open: Array = [] if far or ctx.lod != 0 else HouseOpeningLayout.layout_wall(ctx, ctx.width, ctx.front_h, 0, true)
	var right_open: Array = [] if far or ctx.lod != 0 else HouseOpeningLayout.layout_wall(ctx, ctx.depth, ctx.front_h, 1, false)
	var back_open: Array = [] if far or ctx.lod != 0 else HouseOpeningLayout.layout_wall(ctx, ctx.width, ctx.back_h, 2, false)
	var left_open: Array = [] if far or ctx.lod != 0 else HouseOpeningLayout.layout_wall(ctx, ctx.depth, ctx.front_h, 3, false)
	HouseElementAlpine.add_cross_side(ctx, Vector3(-ctx.hx, y0, -ctx.hz), Vector3.RIGHT, ctx.width, wall_h, Vector3.FORWARD, front_open, far)
	HouseElementAlpine.add_cross_side(ctx, Vector3(ctx.hx, y0, -ctx.hz), Vector3(0, 0, 1), ctx.depth, wall_h, Vector3.RIGHT, right_open, far)
	HouseElementAlpine.add_cross_side(ctx, Vector3(ctx.hx, y0, ctx.hz), Vector3.LEFT, ctx.width, wall_h, Vector3.BACK, back_open, far)
	HouseElementAlpine.add_cross_side(ctx, Vector3(-ctx.hx, y0, ctx.hz), Vector3(0, 0, -1), ctx.depth, wall_h, Vector3.LEFT, left_open, far)


static func add_cross_side(ctx: HouseBuildContext, origin: Vector3, axis_u: Vector3, length: float, wall_h: float, outward: Vector3, openings: Array, far: bool) -> void:
	if far:
		ctx._add_shell_wall(origin, axis_u, length, wall_h, outward)
	else:
		ctx._add_rect_wall(origin, axis_u, length, wall_h, outward, openings, false)
	var y_base := ctx.found_h + ctx.front_h - _ROOF_TUCK
	var front_back := absf(outward.z) > 0.5
	var left_u := 0.0
	var right_u := length
	if front_back:
		var half := cross_half_x(ctx)
		left_u = length * 0.5 - half
		right_u = length * 0.5 + half
	var peak := HouseElementAlpine.cross_wall_point(ctx, origin, axis_u, length * 0.5, y_base)
	var left := origin + axis_u * left_u
	var right := origin + axis_u * right_u
	# Shoulders sit on the plate so the rectangle never rises into the roof valley.
	left.y = y_base
	right.y = y_base
	if not front_back:
		left = HouseElementAlpine.cross_wall_point(ctx, origin, axis_u, left_u, y_base)
		right = HouseElementAlpine.cross_wall_point(ctx, origin, axis_u, right_u, y_base)
	ctx._add_wall_polygon([left, peak, right], outward)
	if front_back:
		if left_u > 0.05:
			HouseElementAlpine.cap_wall_span(ctx, origin, axis_u, 0.0, left_u, y_base, outward)
		if right_u < length - 0.05:
			HouseElementAlpine.cap_wall_span(ctx, origin, axis_u, right_u, length, y_base, outward)


static func cross_wall_point(ctx: HouseBuildContext, origin: Vector3, axis_u: Vector3, u: float, y_base: float) -> Vector3:
	var point := origin + axis_u * u
	point.y = minf(HouseElementAlpine.cross_roof_y(ctx, point.x, point.z) - _ROOF_TUCK, ctx.peak_y - _ROOF_TUCK)
	point.y = maxf(point.y, y_base)
	return point


static func cap_wall_span(ctx: HouseBuildContext, origin: Vector3, axis_u: Vector3, u0: float, u1: float, y: float, outward: Vector3) -> void:
	var top_a := origin + axis_u * u0
	var top_b := origin + axis_u * u1
	top_a.y = y
	top_b.y = y
	ctx._face4(ctx.shell_wall, top_a, top_b, top_b - outward * ctx.thickness, top_a - outward * ctx.thickness, Vector3.UP)


static func add_alpine_balcony(ctx: HouseBuildContext) -> void:
	if ctx.props.style != HouseProperties.Style.ALPINE or ctx.floors < 2:
		return
	var reach := minf(1.2, maxf(0.85, ctx.overhang - 0.25))
	var x0 := -ctx.hx + 0.35
	var x1 := ctx.hx - 0.35
	if x1 - x0 < 2.0:
		return
	var deck_y := ctx.found_h + ctx.floor_h
	var z_inner := -ctx.hz + 0.02
	var z_outer := -ctx.hz - reach
	ctx._box(HouseBuildContext.TRIM, Vector3((x0 + x1) * 0.5, deck_y - 0.06, (z_inner + z_outer) * 0.5), Vector3(x1 - x0, 0.12, z_inner - z_outer))
	if ctx.policy == null or not ctx.policy.alpine_balcony_rails():
		return
	var rail_h := 0.9
	ctx._box(HouseBuildContext.TRIM, Vector3((x0 + x1) * 0.5, deck_y + rail_h - 0.04, z_outer + 0.05), Vector3(x1 - x0, 0.06, 0.06))
	ctx._box(HouseBuildContext.TRIM, Vector3((x0 + x1) * 0.5, deck_y + rail_h * 0.48, z_outer + 0.05), Vector3(x1 - x0, 0.05, 0.05))
	for x in [x0 + 0.05, (x0 + x1) * 0.5, x1 - 0.05]:
		ctx._box(HouseBuildContext.TRIM, Vector3(x, deck_y + rail_h * 0.5, z_outer + 0.05), Vector3(0.08, rail_h, 0.08))
