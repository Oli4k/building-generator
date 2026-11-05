@tool
class_name HouseOpeningLayout
extends RefCounted

## Door and window placement for facade walls.
##
## Recipes set [member HouseProperties.facade_profile], [member HouseProperties.slit_walls],
## and garage fields. This class only places rects; mesh cutting stays on [HouseBuildContext].

## Smallest structural corner pier. Real spacing uses [method grid_gap] so edge and
## inter-window piers stay in the same rhythm.
const GRID_EDGE_MIN := 0.36


## Place openings for one house wall. Prefer this over style-specific callers.
static func layout_wall(ctx: HouseBuildContext, length: float, wall_height: float, wall_id: int, with_door: bool) -> Array:
	return layout(ctx, length, wall_height, wall_id, with_door)


static func layout(ctx: HouseBuildContext, length: float, wall_height: float, wall_id: int, with_door: bool) -> Array:
	var windows := HouseOpeningLayout.windows_on(ctx, wall_id)
	var profile := ctx.props.facade_profile
	if with_door and profile == HouseProperties.FacadeProfile.SHOP_FRONT:
		return HouseOpeningLayout.shop_front(ctx, length, wall_height)
	if windows and HouseOpeningLayout.slits_on(ctx, wall_id):
		return HouseOpeningLayout.slit_row(ctx, length, wall_height)
	var openings: Array = []
	var door := Rect2()
	var has_door := false
	if with_door:
		var door_w := minf(ctx.props.door_width, maxf(0.6, length - 0.7))
		var door_h := minf(ctx.props.door_height, maxf(1.2, wall_height - 0.12))
		var u := HouseOpeningLayout.door_u(ctx, length, door_w)
		door = Rect2(u, 0.0, door_w, door_h)
		has_door = true
		openings.append({"rect": door, "door": true})
		ctx.door_center_x = -ctx.hx + door.position.x + door.size.x * 0.5
	if not windows or profile == HouseProperties.FacadeProfile.NONE:
		return openings
	var ww := clampf(ctx.props.window_width, 0.35, 1.8)
	var columns := HouseOpeningLayout.grid_columns(ctx, length, ww)
	if columns <= 0:
		return openings
	var xs := HouseOpeningLayout.grid_column_xs(length, columns, ww)
	HouseOpeningLayout.spread_around_door(ctx, xs, ww, door, has_door, length)
	var placed: Array[Rect2] = []
	if has_door:
		placed.append(door)
	var window_count := 0
	for f in ctx.floors:
		var tallest := HouseOpeningLayout.tallest_window(ctx, f, columns, wall_id).y
		var sill := HouseOpeningLayout.window_sill(ctx, f, tallest)
		if sill + 0.4 > wall_height - 0.16:
			continue
		var head := sill + tallest
		if head > wall_height - 0.16:
			head = wall_height - 0.16
		if head - sill < 0.4:
			continue
		var above_door := has_door and sill >= door.end.y - 0.02
		for c in columns:
			var size := HouseOpeningLayout.window_size(ctx, f, c, columns, wall_id)
			var pane_h := minf(size.y, head - sill)
			if pane_h < 0.4:
				continue
			var center := float(xs[c]) + ww * 0.5
			var rect := Rect2(center - size.x * 0.5, head - pane_h, size.x, pane_h)
			rect = HouseOpeningLayout.fit_beside_door(ctx, rect, door, has_door and not above_door, length, placed)
			if rect.size.x <= 0.0:
				continue
			if ctx._unit(1000 + wall_id * 100 + f * 10 + c) < ctx.props.window_omit:
				continue
			openings.append({"rect": rect, "door": false})
			placed.append(rect)
			window_count += 1
		if above_door:
			var mid := HouseOpeningLayout.window_size(ctx, f, columns / 2, columns, wall_id)
			var over_h := minf(mid.y, head - sill)
			var over := HouseOpeningLayout.window_over_door(ctx, door, Vector2(mid.x, over_h), head - over_h, length, placed)
			if over.size.x > 0.0 and ctx._unit(1200 + wall_id * 10 + f) >= ctx.props.window_omit:
				openings.append({"rect": over, "door": false})
				placed.append(over)
				window_count += 1
	if window_count == 0:
		var fallback := HouseOpeningLayout.fallback_window(ctx, length, wall_height, door, has_door)
		if fallback.size.x > 0.0:
			openings.append({"rect": fallback, "door": false})
	return openings


static func shop_front(ctx: HouseBuildContext, length: float, wall_height: float) -> Array:
	var openings: Array = []
	var margin := 0.4
	var door_w := minf(ctx.props.door_width, maxf(0.8, length - 1.4))
	var door_h := minf(ctx.props.door_height, maxf(1.8, wall_height - 0.3))
	var door_x := margin
	match ctx.props.door_side:
		HouseProperties.HouseSide.RIGHT:
			door_x = length - margin - door_w
		HouseProperties.HouseSide.CENTER:
			door_x = (length - door_w) * 0.5
	var door := Rect2(door_x, 0.0, door_w, door_h)
	openings.append({"rect": door, "door": true})
	ctx.door_center_x = -ctx.hx + door.position.x + door.size.x * 0.5
	var door_gap := 0.42
	var sill := 0.32
	var head := minf(door_h + 0.08, wall_height - 0.35)
	if ctx.props.door_side == HouseProperties.HouseSide.CENTER:
		HouseOpeningLayout.shop_glass(ctx, openings, margin, door.position.x - door_gap, sill, head)
		HouseOpeningLayout.shop_glass(ctx, openings, door.end.x + door_gap, length - margin, sill, head)
	elif ctx.props.door_side == HouseProperties.HouseSide.LEFT:
		HouseOpeningLayout.shop_glass(ctx, openings, door.end.x + door_gap, length - margin, sill, head)
	else:
		HouseOpeningLayout.shop_glass(ctx, openings, margin, door.position.x - door_gap, sill, head)
	if ctx.floors > 1:
		HouseOpeningLayout.append_window_row(ctx, openings, length, wall_height, 1, ctx.floors - 1, door, true, 0)
	return openings


static func shop_glass(ctx: HouseBuildContext, openings: Array, x0: float, x1: float, sill: float, head: float) -> void:
	if head - sill <= 0.8 or x1 - x0 <= 0.8:
		return
	var mullion := 0.2
	if x1 - x0 > 4.2:
		var mid := (x0 + x1) * 0.5
		openings.append({"rect": Rect2(x0, sill, mid - mullion * 0.5 - x0, head - sill), "door": false})
		openings.append({"rect": Rect2(mid + mullion * 0.5, sill, x1 - mid - mullion * 0.5, head - sill), "door": false})
	else:
		openings.append({"rect": Rect2(x0, sill, x1 - x0, head - sill), "door": false})


static func append_window_row(ctx: HouseBuildContext, openings: Array, length: float, wall_height: float, first_floor: int, floor_count: int, door: Rect2, has_door: bool, wall_id: int) -> void:
	var ww := clampf(ctx.props.window_width, 0.35, 1.8)
	var columns := HouseOpeningLayout.grid_columns(ctx, length, ww)
	if columns <= 0:
		return
	var xs := HouseOpeningLayout.grid_column_xs(length, columns, ww)
	var placed: Array[Rect2] = []
	if has_door:
		placed.append(door)
	for f in floor_count:
		var floor_index := first_floor + f
		var tallest := HouseOpeningLayout.tallest_window(ctx, floor_index, columns, wall_id).y
		var sill := HouseOpeningLayout.window_sill(ctx, floor_index, tallest)
		var head := sill + tallest
		if head > wall_height - 0.16:
			head = wall_height - 0.16
		if head - sill < 0.4:
			continue
		var above_door := has_door and sill >= door.end.y - 0.02
		for c in columns:
			var size := HouseOpeningLayout.window_size(ctx, floor_index, c, columns, wall_id)
			var pane_h := minf(size.y, head - sill)
			if pane_h < 0.4:
				continue
			var center := float(xs[c]) + ww * 0.5
			var rect := Rect2(center - size.x * 0.5, head - pane_h, size.x, pane_h)
			rect = HouseOpeningLayout.fit_beside_door(ctx, rect, door, has_door and not above_door, length, placed)
			if rect.size.x <= 0.0:
				continue
			openings.append({"rect": rect, "door": false})
			placed.append(rect)


## Pier between windows — scales with pane width so denser glass keeps tighter rhythm.
static func grid_gap(ww: float) -> float:
	return maxf(0.5, ww * 0.62)


## How many grid columns fit this wall after recipe / catalog caps.
## [member HouseProperties.window_columns] `0` fills the wall at a fixed bay pitch;
## a positive count is a hard cap (sparse styles such as chapel or shed).
static func grid_columns(ctx: HouseBuildContext, length: float, ww: float) -> int:
	var gap := HouseOpeningLayout.grid_gap(ww)
	var margin := maxf(HouseOpeningLayout.GRID_EDGE_MIN, gap)
	var usable := length - margin * 2.0
	if usable < ww * 0.75:
		return 0
	var max_fit := maxi(1, int(floor((usable + gap) / (ww + gap))))
	var columns := max_fit if ctx.props.window_columns <= 0 else mini(ctx.props.window_columns, max_fit)
	if ctx.catalog:
		columns = mini(columns, ctx.props.catalog_column_cap)
	return columns


## Left edges of each column at a fixed bay pitch, centered on the wall.
static func grid_column_xs(length: float, columns: int, ww: float) -> Array:
	var xs: Array = []
	if columns <= 0:
		return xs
	var gap := HouseOpeningLayout.grid_gap(ww)
	if columns == 1:
		xs.append(clampf((length - ww) * 0.5, HouseOpeningLayout.GRID_EDGE_MIN, maxf(HouseOpeningLayout.GRID_EDGE_MIN, length - HouseOpeningLayout.GRID_EDGE_MIN - ww)))
		return xs
	var row_w := float(columns) * ww + float(columns - 1) * gap
	var start := maxf(HouseOpeningLayout.GRID_EDGE_MIN, (length - row_w) * 0.5)
	for c in columns:
		xs.append(start + float(c) * (ww + gap))
	return xs


## Tall narrow lights with a pier between each (modern church hall back wall).
static func slit_row(ctx: HouseBuildContext, length: float, wall_height: float) -> Array:
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


static func church_glass_wall(ctx: HouseBuildContext, length: float, wall_height: float) -> Array:
	return slit_row(ctx, length, wall_height)


## Hangar/warehouse hall door from recipe garage fields.
static func hall_door(ctx: HouseBuildContext, length: float) -> Dictionary:
	var fraction := clampf(ctx.props.garage_width_fraction, 0.2, 0.9)
	var door_w := clampf(length * fraction, 3.2, maxf(3.2, length - 1.1))
	var clearance := clampf(ctx.props.garage_top_clearance, 0.3, 1.5)
	var door_h := minf(ctx.props.garage_max_height, ctx.front_h - clearance)
	door_h = minf(door_h, ctx._below_roof(ctx.front_h) - 0.12)
	var door_x := (length - door_w) * 0.5
	return {"rect": Rect2(door_x, 0.0, door_w, door_h), "door": true}


## Annex front: person door plus one window.
static func annex_front(ctx: HouseBuildContext, length: float, wall_h: float) -> Array:
	var door_w := 0.96
	var door_h := minf(2.15, wall_h - 0.2)
	var margin := 0.32
	var door := Rect2(margin, 0.0, door_w, door_h)
	var win_w := 1.15
	var win_h := 1.0
	var sill := 1.2
	if sill + win_h > wall_h - 0.25:
		win_h = wall_h - 0.25 - sill
	var win_x := door.end.x + 0.5
	var openings: Array = [{"rect": door, "door": true}]
	if win_h >= 0.6 and win_x + win_w <= length - margin:
		openings.append({"rect": Rect2(win_x, sill, win_w, win_h), "door": false})
	return openings


static func fallback_window(ctx: HouseBuildContext, length: float, wall_height: float, door: Rect2, has_door: bool) -> Rect2:
	var base := HouseOpeningLayout.window_size(ctx, 0, 0, 1, 0)
	var ww := minf(base.x, length * 0.42)
	var wh := minf(base.y, wall_height * 0.42)
	var sill := maxf(0.48, minf(ctx.floor_h * 0.34, wall_height - wh - 0.36))
	if has_door and sill < door.size.y + 0.08:
		sill = door.size.y + 0.16
	if sill + wh > wall_height - 0.12:
		return Rect2()
	var rect := Rect2((length - ww) * 0.5, sill, ww, wh)
	if has_door and HouseOpeningLayout.overlaps(ctx, rect, door, 0.46):
		var left := door.position.x - 0.46 - ww
		var right := door.end.x + 0.46
		if left >= 0.28:
			rect.position.x = left
		elif right + ww <= length - 0.28:
			rect.position.x = right
		else:
			return Rect2()
	return rect


static func overlaps(ctx: HouseBuildContext, a: Rect2, b: Rect2, margin: float) -> bool:
	return a.grow(margin).intersects(b)


static func windows_on(ctx: HouseBuildContext, wall_id: int) -> bool:
	return (ctx.props.window_walls & (1 << wall_id)) != 0


static func slits_on(ctx: HouseBuildContext, wall_id: int) -> bool:
	return (ctx.props.slit_walls & (1 << wall_id)) != 0


static func door_u(ctx: HouseBuildContext, length: float, door_w: float) -> float:
	var margin := 0.36
	match ctx.props.door_side:
		HouseProperties.HouseSide.LEFT:
			return margin
		HouseProperties.HouseSide.RIGHT:
			return maxf(margin, length - door_w - margin)
		_:
			return clampf((length - door_w) * 0.5, margin, maxf(margin, length - door_w - margin))


## Largest pane on a floor, used so every window on that floor shares one head line.


static func tallest_window(ctx: HouseBuildContext, floor_index: int, column_count: int, wall_id: int) -> Vector2:
	var tallest := HouseOpeningLayout.window_size(ctx, floor_index, 0, column_count, wall_id)
	for c in range(1, column_count):
		var size := HouseOpeningLayout.window_size(ctx, floor_index, c, column_count, wall_id)
		if size.y > tallest.y:
			tallest = size
	return tallest


## Base size is the largest pane. The pattern only steps away from it, and a row keeps one head line.


static func window_size(ctx: HouseBuildContext, floor_index: int, column: int, column_count: int, wall_id: int) -> Vector2:
	var w := clampf(ctx.props.window_width, 0.35, 1.8)
	var h := clampf(ctx.props.window_height, 0.4, 2.2)
	var amount := clampf(ctx.props.window_variation, 0.0, 1.0)
	if amount <= 0.001 or ctx.props.window_pattern == HouseProperties.WindowPattern.UNIFORM:
		return Vector2(w, h)
	var count := maxi(column_count, 1)
	var bay := clampi(column, 0, count - 1)
	match ctx.props.window_pattern:
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
			if HouseOpeningLayout.alternating_narrow(ctx, bay, count):
				w *= lerpf(1.0, 0.7, amount)
		HouseProperties.WindowPattern.IRREGULAR:
			var groups := (count + 1) / 2
			if groups > 1:
				var mirror := mini(bay, count - 1 - bay)
				var lowest := 1.0
				var highest := 0.0
				var units: Array[float] = []
				for group in groups:
					var unit := ctx._unit(3000 + wall_id * 50 + floor_index * 7 + group)
					units.append(unit)
					lowest = minf(lowest, unit)
					highest = maxf(highest, unit)
				var rank := 1.0
				if highest - lowest > 0.001:
					rank = (units[mirror] - lowest) / (highest - lowest)
				w *= lerpf(1.0 - 0.26 * amount, 1.0, rank)
				h *= lerpf(1.0 - 0.12 * amount, 1.0, rank)
	return Vector2(maxf(w, 0.35), maxf(h, 0.4))


static func alternating_narrow(ctx: HouseBuildContext, column: int, column_count: int) -> bool:
	if column_count <= 2:
		return column % 2 == 1
	var steps := int(round(absf(float(column) - float(column_count - 1) * 0.5)))
	return steps % 2 == 1


static func spread_around_door(ctx: HouseBuildContext, xs: Array, span: float, door: Rect2, has_door: bool, length: float) -> void:
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
			if not overlaps and (gap_left >= 0.46 or gap_right >= 0.46):
				continue
			if not overlaps and gap_left >= 0.0:
				xs[i] = door.position.x - 0.46 - span
			elif not overlaps and gap_right >= 0.0:
				xs[i] = door.end.x + 0.46
			else:
				var to_left := door.position.x - 0.46 - span
				var to_right := door.end.x + 0.46
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


static func fit_beside_door(ctx: HouseBuildContext, rect: Rect2, door: Rect2, has_door: bool, length: float, placed: Array[Rect2]) -> Rect2:
	if rect.position.x < 0.28 or rect.end.x > length - 0.28:
		return Rect2()
	if has_door and HouseOpeningLayout.overlaps(ctx, rect, door, 0.46):
		return Rect2()
	if HouseOpeningLayout.hits_opening(ctx, rect, placed):
		return Rect2()
	return rect


static func window_over_door(ctx: HouseBuildContext, door: Rect2, size: Vector2, sill: float, length: float, placed: Array[Rect2]) -> Rect2:
	var x := door.position.x + door.size.x * 0.5 - size.x * 0.5
	var rect := Rect2(x, sill, size.x, size.y)
	return HouseOpeningLayout.fit_beside_door(ctx, rect, door, false, length, placed)


static func hits_opening(ctx: HouseBuildContext, rect: Rect2, placed: Array[Rect2]) -> bool:
	for other in placed:
		if rect.grow(0.12).intersects(other):
			return true
	return false


static func window_sill(ctx: HouseBuildContext, floor_index: int, window_height: float) -> float:
	return floor_index * ctx.floor_h + maxf(0.54, ctx.floor_h - window_height - 0.56)


static func ground_floor_window_top(ctx: HouseBuildContext) -> float:
	var wh := clampf(ctx.props.window_height, 0.45, 2.2)
	var sill := HouseOpeningLayout.window_sill(ctx, 0, wh)
	if sill + wh > ctx.front_h - 0.16:
		wh = maxf(0.4, ctx.front_h - 0.16 - sill)
	return sill + wh


