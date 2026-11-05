@tool
class_name HouseElementChurch
extends RefCounted

## Tower, chancel, aisle, and campanile masses.

static func add_church_masses(ctx: HouseBuildContext) -> void:
	if ctx.props.church_plan == 2:
		HouseElementChurch.add_campanile(ctx)
		return
	HouseElementChurch.add_west_tower(ctx)
	HouseElementChurch.add_chancel(ctx)
	if ctx.props.church_plan == 1 and (ctx.policy == null or ctx.policy.church_aisle()):
		HouseElementChurch.add_side_aisle(ctx)


static func add_west_tower(ctx: HouseBuildContext) -> void:
	var side := clampf(ctx.depth * 0.46, 2.8, 3.4)
	var cx := -ctx.hx - side * 0.5 + 0.28
	var base := ctx._base_y()
	var shaft_top := ctx.peak_y + 2.05
	var peak := shaft_top + lerpf(0.85, 2.75, ctx._unit(91))
	HouseElementChurch.add_prism(ctx, HouseBuildContext.WALL, cx - side * 0.5, cx + side * 0.5, -side * 0.5, side * 0.5, base, shaft_top)
	HouseElementChurch.add_pyramid(ctx, HouseBuildContext.ROOF, cx, 0.0, shaft_top - 0.04, peak, side * 0.52, side * 0.52)
	HouseElementChurch.add_tower_cross(ctx, cx, 0.0, peak, 1.0)


static func add_tower_cross(ctx: HouseBuildContext, cx: float, cz: float, y_peak: float, scale: float) -> void:
	var stem := 1.15 * scale
	var arm := 0.46 * scale
	var thick := 0.07 * scale
	var y0 := y_peak - 0.05
	var y1 := y_peak + stem
	var arm_y := y_peak + stem * 0.62
	if ctx.policy == null or ctx.policy.church_cross_boxes():
		ctx._box(HouseBuildContext.WALL, Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(thick * 2.0, y1 - y0, thick * 2.0))
		ctx._box(HouseBuildContext.WALL, Vector3(cx, arm_y, cz), Vector3(thick * 2.0, thick * 2.0, arm * 2.0))
		return
	# The far mesh keeps the open sides. A closed cross would push the chapel past its vertex budget.
	HouseElementChurch.add_prism(ctx, HouseBuildContext.WALL, cx - thick, cx + thick, cz - thick, cz + thick, y0, y1)
	HouseElementChurch.add_prism(ctx, HouseBuildContext.WALL, cx - thick, cx + thick, cz - arm, cz + arm, arm_y - thick, arm_y + thick)


static func add_chancel(ctx: HouseBuildContext) -> void:
	var span_z := ctx.depth * 0.64
	var span_x := 2.55
	var x0 := ctx.hx - 0.22
	var x1 := x0 + span_x
	var z0 := -span_z * 0.5
	var z1 := span_z * 0.5
	var eave := ctx.found_h + ctx.front_h * 0.52
	var cap := eave + span_z * 0.28
	HouseElementChurch.add_prism(ctx, HouseBuildContext.WALL, x0, x1, z0, z1, ctx._base_y(), eave, -1)
	ctx._face3(HouseBuildContext.WALL, Vector3(x1, eave, z0), Vector3(x1, eave, z1), Vector3(x1, cap, 0.0), Vector3.RIGHT)
	ctx._panel(ctx.shell_roof, [Vector3(x0, eave, z0), Vector3(x1, eave, z0), Vector3(x1, cap, 0.0), Vector3(x0, cap, 0.0)], 0.08)
	ctx._panel(ctx.shell_roof, [Vector3(x1, eave, z1), Vector3(x0, eave, z1), Vector3(x0, cap, 0.0), Vector3(x1, cap, 0.0)], 0.08)


static func add_side_aisle(ctx: HouseBuildContext) -> void:
	var x0 := -ctx.hx + 0.35
	var x1 := ctx.hx - 0.35
	var z_inner := ctx.hz - 0.04
	var z_outer := ctx.hz + 1.65
	var y_inner := ctx.found_h + ctx.front_h * 0.46
	var y_outer := y_inner - 0.7
	var y0 := ctx._base_y()
	ctx._face4(HouseBuildContext.WALL, Vector3(x0, y0, z_outer), Vector3(x1, y0, z_outer), Vector3(x1, y_outer, z_outer), Vector3(x0, y_outer, z_outer), Vector3.BACK)
	ctx._face4(HouseBuildContext.WALL, Vector3(x0, y0, z_outer), Vector3(x0, y0, z_inner), Vector3(x0, y_inner, z_inner), Vector3(x0, y_outer, z_outer), Vector3.LEFT)
	ctx._face4(HouseBuildContext.WALL, Vector3(x1, y0, z_inner), Vector3(x1, y0, z_outer), Vector3(x1, y_outer, z_outer), Vector3(x1, y_inner, z_inner), Vector3.RIGHT)
	ctx._panel(ctx.shell_roof, [
		Vector3(x0, y_inner, z_inner),
		Vector3(x1, y_inner, z_inner),
		Vector3(x1, y_outer, z_outer),
		Vector3(x0, y_outer, z_outer),
	], 0.08)


static func add_campanile(ctx: HouseBuildContext) -> void:
	var side := 1.7
	var cx := ctx.hx + side * 0.22
	var cz := ctx.hz + side * 0.22
	var top := ctx.found_h + ctx.back_h + 3.1
	var base := ctx._base_y()
	var lip := 0.14
	var x0 := cx - side * 0.5 - lip
	var x1 := cx + side * 0.5 + lip
	var z0 := cz - side * 0.5 - lip
	var z1 := cz + side * 0.5 + lip
	var cap := top + 0.2
	HouseElementChurch.add_prism(ctx, HouseBuildContext.WALL, cx - side * 0.5, cx + side * 0.5, cz - side * 0.5, cz + side * 0.5, base, top)
	HouseElementChurch.add_prism(ctx, HouseBuildContext.ROOF, x0, x1, z0, z1, top, cap)
	ctx._face4(HouseBuildContext.ROOF, Vector3(x0, cap, z0), Vector3(x1, cap, z0), Vector3(x1, cap, z1), Vector3(x0, cap, z1), Vector3.UP)
	ctx._face4(HouseBuildContext.ROOF, Vector3(x0, top, z1), Vector3(x1, top, z1), Vector3(x1, top, z0), Vector3(x0, top, z0), Vector3.DOWN)
	HouseElementChurch.add_tower_cross(ctx, cx, cz, cap, lerpf(1.7, 2.6, ctx._unit(94)))


static func add_prism(ctx: HouseBuildContext, surface: int, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, omit_x: int = 0) -> void:
	if x1 - x0 < 0.05 or z1 - z0 < 0.05 or y1 - y0 < 0.05:
		return
	ctx._face4(surface, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD)
	ctx._face4(surface, Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3.BACK)
	if omit_x != 1:
		ctx._face4(surface, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT)
	if omit_x != -1:
		ctx._face4(surface, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3.LEFT)


static func add_pyramid(ctx: HouseBuildContext, surface: int, cx: float, cz: float, y0: float, y1: float, half_x: float, half_z: float) -> void:
	var peak := Vector3(cx, y1, cz)
	var a := Vector3(cx - half_x, y0, cz - half_z)
	var b := Vector3(cx + half_x, y0, cz - half_z)
	var c := Vector3(cx + half_x, y0, cz + half_z)
	var d := Vector3(cx - half_x, y0, cz + half_z)
	ctx._face3(surface, a, b, peak, Vector3(0, 0.45, -1))
	ctx._face3(surface, b, c, peak, Vector3(1, 0.45, 0))
	ctx._face3(surface, c, d, peak, Vector3(0, 0.45, 1))
	ctx._face3(surface, d, a, peak, Vector3(-1, 0.45, 0))


