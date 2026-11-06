@tool
class_name HouseElementIndustrial
extends RefCounted

## Metal hall and optional annex for hangars and warehouses.

static func span_roof(ctx: HouseBuildContext) -> bool:
	return ctx.props.roof_profile == HouseProperties.RoofProfile.SPAN


## A windowless metal hall. The optional entry unit occupies the front-right corner of the same footprint.


static func add_industrial(ctx: HouseBuildContext) -> void:
	var annex_w := 0.0
	var annex_d := 0.0
	if ctx.props.annex:
		annex_w = clampf(minf(4.2, ctx.width * 0.28), 3.6, ctx.width - 10.0)
		annex_d = clampf(minf(5.0, ctx.depth * 0.42), 3.8, ctx.depth - 5.0)
	var hall_x0 := -ctx.hx
	var hall_x1 := ctx.hx - annex_w
	var hall_w := hall_x1 - hall_x0
	var y0 := ctx.found_h
	var wall_h := ctx._below_roof(ctx.front_h)
	var annex_h := minf(3.15, wall_h - 0.55)
	if ctx.lod < 2:
		HouseElementIndustrial.add_pad(ctx, hall_x0, hall_x1, -ctx.hz, ctx.hz, true, annex_w <= 0.0, true, true)
		if annex_w > 0.0:
			HouseElementIndustrial.add_pad(ctx, hall_x1, ctx.hx, -ctx.hz, -ctx.hz + annex_d, false, true, true, true)
		HouseElementIndustrial.add_hall_near(ctx, hall_x0, hall_x1, hall_w, y0, wall_h)
		if annex_w > 0.0:
			HouseElementIndustrial.add_annex_near(ctx, hall_x1, ctx.hx, -ctx.hz, -ctx.hz + annex_d, y0, annex_h)
	else:
		HouseElementIndustrial.add_hall_far(ctx, hall_x0, hall_x1, hall_w, y0, wall_h)
		if annex_w > 0.0:
			HouseElementIndustrial.add_annex_far(ctx, hall_x1, ctx.hx, -ctx.hz, -ctx.hz + annex_d, y0, annex_h)
	if HouseElementIndustrial.span_roof(ctx):
		HouseElementIndustrial.add_span_roof(ctx, hall_x0, hall_x1, -ctx.hz, ctx.hz, ctx.found_h + ctx.front_h, ctx.peak_y)
	if annex_w > 0.0:
		var annex_y := ctx.found_h + annex_h
		var oh := 0.22
		ctx._panel(ctx.shell_roof, [
			Vector3(hall_x1, annex_y, -ctx.hz - oh),
			Vector3(ctx.hx + oh, annex_y, -ctx.hz - oh),
			Vector3(ctx.hx + oh, annex_y, -ctx.hz + annex_d + oh),
			Vector3(hall_x1, annex_y, -ctx.hz + annex_d + oh),
		], 0.08)


static func add_pad(ctx: HouseBuildContext, x0: float, x1: float, z0: float, z1: float, pad_left: bool, pad_right: bool, pad_front: bool, pad_back: bool) -> void:
	var bottom := ctx._base_y()
	var top := ctx.found_h
	if top - bottom <= 0.001 or x1 - x0 < 0.2 or z1 - z0 < 0.2:
		return
	var pad := HouseMeshBuilder.FOUNDATION_PAD
	var min_x := x0 - (pad if pad_left else 0.0)
	var max_x := x1 + (pad if pad_right else 0.0)
	var min_z := z0 - (pad if pad_front else 0.0)
	var max_z := z1 + (pad if pad_back else 0.0)
	ctx._box(HouseBuildContext.FOUNDATION, Vector3((min_x + max_x) * 0.5, (top + bottom) * 0.5, (min_z + max_z) * 0.5), Vector3(max_x - min_x, top - bottom, max_z - min_z))


static func add_hall_near(ctx: HouseBuildContext, x0: float, x1: float, hall_w: float, y0: float, wall_h: float) -> void:
	var openings: Array = [HouseOpeningLayout.hall_door(ctx, hall_w)] if ctx.lod == 0 else []
	ctx._add_rect_wall(Vector3(x0, y0, -ctx.hz), Vector3.RIGHT, hall_w, wall_h, Vector3.FORWARD, openings, true)
	ctx._add_rect_wall(Vector3(x1, y0, ctx.hz), Vector3.LEFT, hall_w, wall_h, Vector3.BACK, [], true)
	ctx._add_side_wall(Vector3(x0, y0, ctx.hz), Vector3(0, 0, -1), ctx.depth, wall_h, wall_h, Vector3.LEFT, [])
	ctx._add_side_wall(Vector3(x1, y0, -ctx.hz), Vector3(0, 0, 1), ctx.depth, wall_h, wall_h, Vector3.RIGHT, [])


static func add_hall_far(ctx: HouseBuildContext, x0: float, x1: float, hall_w: float, y0: float, wall_h: float) -> void:
	var base := ctx._base_y()
	var top := y0 + wall_h - base
	ctx._add_shell_wall(Vector3(x0, base, -ctx.hz), Vector3.RIGHT, hall_w, top, Vector3.FORWARD)
	ctx._add_shell_wall(Vector3(x1, base, ctx.hz), Vector3.LEFT, hall_w, top, Vector3.BACK)
	ctx._add_far_side(Vector3(x0, base, ctx.hz), Vector3(0, 0, -1), ctx.depth, top, top, Vector3.LEFT)
	ctx._add_far_side(Vector3(x1, base, -ctx.hz), Vector3(0, 0, 1), ctx.depth, top, top, Vector3.RIGHT)


static func add_annex_near(ctx: HouseBuildContext, x0: float, x1: float, z0: float, z1: float, y0: float, annex_h: float) -> void:
	var openings: Array = HouseOpeningLayout.annex_front(ctx, x1 - x0, annex_h) if ctx.lod == 0 else []
	ctx._add_rect_wall(Vector3(x0, y0, z0), Vector3.RIGHT, x1 - x0, annex_h, Vector3.FORWARD, openings, true)
	ctx._add_rect_wall(Vector3(x1, y0, z0), Vector3(0, 0, 1), z1 - z0, annex_h, Vector3.RIGHT, [], true)
	ctx._add_rect_wall(Vector3(x1, y0, z1), Vector3.LEFT, x1 - x0, annex_h, Vector3.BACK, [], true)


static func add_annex_far(ctx: HouseBuildContext, x0: float, x1: float, z0: float, z1: float, y0: float, annex_h: float) -> void:
	var base := ctx._base_y()
	var top := y0 + annex_h - base
	ctx._add_shell_wall(Vector3(x0, base, z0), Vector3.RIGHT, x1 - x0, top, Vector3.FORWARD)
	ctx._add_shell_wall(Vector3(x1, base, z0), Vector3(0, 0, 1), z1 - z0, top, Vector3.RIGHT)
	ctx._add_shell_wall(Vector3(x1, base, z1), Vector3.LEFT, x1 - x0, top, Vector3.BACK)


static func add_span_roof(ctx: HouseBuildContext, x0: float, x1: float, z0: float, z1: float, y_wall: float, ridge_y: float) -> void:
	var y_outer := y_wall - ctx.overhang * ctx.pitch
	var mid_z := (z0 + z1) * 0.5
	var ox0 := x0 - ctx.overhang
	var ox1 := x1 + ctx.overhang
	ctx._panel(ctx.shell_roof, [
		Vector3(ox0, y_outer, z0 - ctx.overhang),
		Vector3(ox1, y_outer, z0 - ctx.overhang),
		Vector3(ox1, ridge_y, mid_z),
		Vector3(ox0, ridge_y, mid_z),
	], 0.12)
	ctx._panel(ctx.shell_roof, [
		Vector3(ox1, y_outer, z1 + ctx.overhang),
		Vector3(ox0, y_outer, z1 + ctx.overhang),
		Vector3(ox0, ridge_y, mid_z),
		Vector3(ox1, ridge_y, mid_z),
	], 0.12)



