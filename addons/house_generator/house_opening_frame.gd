@tool
class_name HouseOpeningFrame
extends RefCounted

## Exterior trim boxes around an opening rect.
##
## Recipes set [member HouseProperties.frame_profile] and frame sizes. Layout stays
## in [HouseOpeningLayout]; this class only emits TRIM mesh on [HouseBuildContext].


## Add kozijn / door trim for one opening. Catalog meshes skip window frames.
static func add(
	ctx: HouseBuildContext,
	origin: Vector3,
	axis_u: Vector3,
	outward: Vector3,
	u0: float,
	v0: float,
	u1: float,
	v1: float,
	is_door: bool,
) -> void:
	var profile := ctx.props.frame_profile
	if profile == HouseProperties.FrameProfile.NONE:
		return
	if ctx.catalog and not is_door:
		return
	match profile:
		HouseProperties.FrameProfile.SILL:
			_simple(ctx, origin, axis_u, outward, u0, v0, u1, v1, is_door)
			_sill(ctx, origin, axis_u, outward, u0, v0, u1)
		HouseProperties.FrameProfile.DIVIDED:
			_simple(ctx, origin, axis_u, outward, u0, v0, u1, v1, is_door)
			_divided(ctx, origin, axis_u, outward, u0, v0, u1, v1, is_door)
		_:
			# SIMPLE and any unknown value — keep drawing a basic kozijn.
			_simple(ctx, origin, axis_u, outward, u0, v0, u1, v1, is_door)


static func _simple(
	ctx: HouseBuildContext,
	origin: Vector3,
	axis_u: Vector3,
	outward: Vector3,
	u0: float,
	v0: float,
	u1: float,
	v1: float,
	is_door: bool,
) -> void:
	var fw := maxf(ctx.props.frame_width, 0.03)
	var fd := maxf(ctx.props.frame_depth, 0.02)
	var along := (u1 - u0) + fw * 2.0
	# Sit fully outside the wall face so the kozijn reads in exterior views.
	var lift := outward * (fd * 0.5 + 0.004)
	var mid_u := (u0 + u1) * 0.5
	var trim := HouseMeshBuilder.TRIM
	# Head (and sill on windows) — rails sit just outside the opening.
	ctx._box(
		trim,
		origin + axis_u * mid_u + Vector3.UP * (v1 + fw * 0.5) + lift,
		axis_u.abs() * along + Vector3.UP * fw + outward.abs() * fd,
	)
	if not is_door:
		ctx._box(
			trim,
			origin + axis_u * mid_u + Vector3.UP * (v0 - fw * 0.5) + lift,
			axis_u.abs() * along + Vector3.UP * fw + outward.abs() * fd,
		)
	# Side stiles fully on the wall, not half into the glass void.
	var side_h := maxf(0.05, (v1 - v0) + fw)
	var side_v := (v0 + v1) * 0.5
	if is_door:
		side_h = maxf(0.05, v1 - v0 + fw * 0.5)
		side_v = v0 + side_h * 0.5 - fw * 0.25
	var side_size := axis_u.abs() * fw + Vector3.UP * side_h + outward.abs() * fd
	ctx._box(trim, origin + axis_u * (u0 - fw * 0.5) + Vector3.UP * side_v + lift, side_size)
	ctx._box(trim, origin + axis_u * (u1 + fw * 0.5) + Vector3.UP * side_v + lift, side_size)


static func _sill(
	ctx: HouseBuildContext,
	origin: Vector3,
	axis_u: Vector3,
	outward: Vector3,
	u0: float,
	v0: float,
	u1: float,
) -> void:
	var fw := maxf(ctx.props.frame_width, 0.03)
	var fd := maxf(ctx.props.frame_depth, 0.02)
	var sill_d := maxf(fd + 0.02, ctx.props.sill_depth)
	var along := (u1 - u0) + fw * 2.0
	var lift := outward * (sill_d * 0.5 + 0.004)
	var mid_u := (u0 + u1) * 0.5
	ctx._box(
		HouseMeshBuilder.TRIM,
		origin + axis_u * mid_u + Vector3.UP * (v0 - fw * 0.65) + lift,
		axis_u.abs() * along + Vector3.UP * (fw * 1.25) + outward.abs() * sill_d,
	)


static func _divided(
	ctx: HouseBuildContext,
	origin: Vector3,
	axis_u: Vector3,
	outward: Vector3,
	u0: float,
	v0: float,
	u1: float,
	v1: float,
	is_door: bool,
) -> void:
	var fw := maxf(ctx.props.frame_width, 0.03)
	var fd := maxf(ctx.props.frame_depth, 0.02)
	var bar := maxf(fw * 0.45, 0.025)
	var lift := outward * (fd * 0.35 + 0.004)
	var mid_u := (u0 + u1) * 0.5
	var trim := HouseMeshBuilder.TRIM
	if is_door:
		var rail_v := v1 - fw - maxf(0.12, (v1 - v0) * 0.22)
		var along := maxf(0.05, (u1 - u0) - fw * 0.5)
		ctx._box(
			trim,
			origin + axis_u * mid_u + Vector3.UP * rail_v + lift,
			axis_u.abs() * along + Vector3.UP * bar + outward.abs() * (fd * 0.7),
		)
		return
	var inner_h := maxf(0.05, (v1 - v0) - fw * 0.5)
	ctx._box(
		trim,
		origin + axis_u * mid_u + Vector3.UP * ((v0 + v1) * 0.5) + lift,
		axis_u.abs() * bar + Vector3.UP * inner_h + outward.abs() * (fd * 0.7),
	)
	var along := maxf(0.05, (u1 - u0) - fw * 0.5)
	ctx._box(
		trim,
		origin + axis_u * mid_u + Vector3.UP * ((v0 + v1) * 0.5) + lift,
		axis_u.abs() * along + Vector3.UP * bar + outward.abs() * (fd * 0.7),
	)
