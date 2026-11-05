extends SceneTree

## Headless check for every house style, plus a demo scene.


func _init() -> void:
	var failed := false
	for style in HouseProperties.Style.values():
		for lod_seed in [1, 7, 21]:
			var props := HouseProperties.make(style, lod_seed)
			var mesh0 := HouseGenerator.build_mesh(props, 0)
			var mesh1 := HouseGenerator.build_mesh(props, 1)
			var mesh2 := HouseGenerator.build_mesh(props, 2)
			var problem := _check_mesh(mesh0, props, 0)
			if problem == "":
				problem = _check_mesh(mesh1, props, 1)
			if problem == "":
				problem = _check_mesh(mesh2, props, 2)
			if problem == "":
				problem = _check_lod(mesh0, mesh1, mesh2)
			if problem == "":
				problem = _check_silhouette(props)
			if problem == "":
				problem = _check_window_proportions(props)
			if problem == "":
				problem = _check_window_gap(mesh0, props)
			if problem == "":
				problem = _check_chalet_eave(mesh0, props)
			if problem == "":
				problem = _check_normals(mesh0)
			if problem == "":
				problem = _check_winding(mesh0)
			if problem == "":
				problem = _check_winding(mesh2)
			if problem != "":
				failed = true
				push_error("%s seed %d: %s" % [HouseProperties.Style.keys()[style], lod_seed, problem])
			else:
				print("%s seed %d  lod0=%d lod1=%d lod2=%d  aabb=%s" % [
					HouseProperties.Style.keys()[style], lod_seed,
					_vertex_count(mesh0), _vertex_count(mesh1), _vertex_count(mesh2), mesh0.get_aabb(),
				])
	var facade := _check_facade_controls()
	if facade != "":
		failed = true
		push_error(facade)
	var pattern := _check_window_pattern()
	if pattern != "":
		failed = true
		push_error(pattern)
	var span := _check_window_span()
	if span != "":
		failed = true
		push_error(span)
	var industrial := _check_industrial()
	if industrial != "":
		failed = true
		push_error(industrial)
	var profiles := _check_facade_profiles()
	if profiles != "":
		failed = true
		push_error(profiles)
	var added := _check_alpine_and_station()
	if added != "":
		failed = true
		push_error(added)
	var demo_error := _save_demo()
	if demo_error != OK:
		failed = true
		push_error("Demo save failed: %s" % error_string(demo_error))
	else:
		print("Wrote res://demo/village.tscn")
	quit(1 if failed else 0)


func _check_mesh(mesh: ArrayMesh, props: HouseProperties, lod: int) -> String:
	var aabb := mesh.get_aabb()
	if lod < 2 and mesh.get_surface_count() < 3:
		return "lod %d has %d surfaces" % [lod, mesh.get_surface_count()]
	if aabb.position.y < -0.02:
		return "lod %d dips below ground (%s)" % [lod, aabb]
	if aabb.size.y < 2.0:
		return "lod %d is too short" % lod
	if absf(aabb.get_center().x) > 2.0:
		return "lod %d is off-center in X" % lod
	var names: PackedStringArray = []
	for i in mesh.get_surface_count():
		names.append(mesh.surface_get_name(i))
		var arrays: Array = mesh.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			return "lod %d surface %s is empty" % [lod, mesh.surface_get_name(i)]
		for vertex in vertices:
			if is_nan(vertex.x) or is_nan(vertex.y) or is_nan(vertex.z):
				return "lod %d has a NaN vertex" % lod
	if not names.has("wall") or not names.has("roof"):
		return "lod %d missing surfaces %s" % [lod, names]
	if lod == 0 and not names.has("door"):
		return "lod 0 missing a door"
	if lod >= 1 and (names.has("door") or names.has("glass")):
		return "lod %d still has openings %s" % [lod, names]
	if lod == 2 and (names.size() != 2 or names.has("trim") or names.has("foundation") or names.has("chimney")):
		return "lod 2 is not a wall-and-roof shell %s" % names
	if _vertex_count(mesh) > 160 and lod == 2:
		return "lod 2 has %d vertices" % _vertex_count(mesh)
	if aabb.position.z > -props.depth * 0.45:
		return "lod %d front is not on -Z" % lod
	return ""


func _check_lod(mesh0: ArrayMesh, mesh1: ArrayMesh, mesh2: ArrayMesh) -> String:
	var verts0 := _vertex_count(mesh0)
	var verts1 := _vertex_count(mesh1)
	var verts2 := _vertex_count(mesh2)
	if verts1 >= verts0:
		return "lod1 is not simpler than lod0"
	if verts2 >= verts1:
		return "lod2 is not simpler than lod1"
	return ""


func _check_silhouette(props: HouseProperties) -> String:
	var quiet := props.duplicate() as HouseProperties
	quiet.chimney = false
	var near := HouseGenerator.build_mesh(quiet, 0)
	var far := HouseGenerator.build_mesh(quiet, 2)
	var top_near := near.get_aabb().position.y + near.get_aabb().size.y
	var top_far := far.get_aabb().position.y + far.get_aabb().size.y
	var allowance := 0.3 if quiet.roof_type == HouseProperties.RoofType.FLAT else 0.08
	if absf(top_near - top_far) > allowance:
		return "lod2 height %s differs from lod0 %s" % [top_far, top_near]
	return ""


func _check_window_proportions(props: HouseProperties) -> String:
	var w := props.window_width
	var h := props.window_height
	match props.style:
		HouseProperties.Style.CABIN:
			if w > 0.6 or h > 0.75:
				return "cabin windows are not small"
		HouseProperties.Style.COTTAGE:
			if h < w * 1.6:
				return "cottage windows are not upright casements"
		HouseProperties.Style.TOWNHOUSE:
			if h < w * 2.5:
				return "townhouse windows are not tall sashes"
		HouseProperties.Style.FARMHOUSE:
			if w <= h:
				return "farmhouse windows are not wide"
		HouseProperties.Style.VILLA:
			if w < 1.1 or h < 1.7:
				return "villa windows are not large"
		HouseProperties.Style.SHED:
			if w > 0.55 or h > 0.6:
				return "shed window is not a small square"
		HouseProperties.Style.CHALET:
			if w < h * 1.4:
				return "chalet windows are not horizontal"
		HouseProperties.Style.CHURCH:
			if posmod(props.seed, 3) == 2:
				if w < h * 1.8:
					return "modern church windows are not horizontal slots"
			elif h < w * 4.0:
				return "chapel windows are not lancets"
		HouseProperties.Style.OFFICE:
			if w < 1.2 or h < 1.45:
				return "office windows are not large panes"
		HouseProperties.Style.HANGAR, HouseProperties.Style.WAREHOUSE:
			if props.window_walls != 0:
				return "industrial hall has windows"
		HouseProperties.Style.ALPINE:
			if w < h * 1.25:
				return "alpine windows are not horizontal"
		HouseProperties.Style.STATION:
			if h < w * 1.7:
				return "station windows are not tall"
	return ""


func _check_facade_controls() -> String:
	var props := HouseProperties.make(HouseProperties.Style.COTTAGE, 4)
	props.door_side = HouseProperties.HouseSide.LEFT
	props.chimney = true
	props.chimney_side = HouseProperties.HouseSide.LEFT
	props.window_walls = HouseProperties.WINDOW_FRONT
	var mesh := HouseGenerator.build_mesh(props, 0)
	var door := _front_component(mesh, "door", props)
	if door.size.x <= 0.0 or door.get_center().x >= -0.4:
		return "door is not on the left"
	var chimney := mesh.surface_find_by_name("chimney")
	if chimney < 0:
		return "chimney is missing"
	for vertex in mesh.surface_get_arrays(chimney)[Mesh.ARRAY_VERTEX]:
		if vertex.x >= -0.05:
			return "chimney is not on the left"
	var glass := mesh.surface_find_by_name("glass")
	if glass < 0:
		return "front windows are missing"
	var normals: PackedVector3Array = mesh.surface_get_arrays(glass)[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if absf(normal.x) > 0.7 or normal.z > 0.5:
			return "windows leaked onto another wall"
	props.door_side = HouseProperties.HouseSide.RIGHT
	props.chimney_side = HouseProperties.HouseSide.RIGHT
	mesh = HouseGenerator.build_mesh(props, 0)
	door = _front_component(mesh, "door", props)
	if door.get_center().x <= 0.4:
		return "door is not on the right"
	return ""


func _check_window_pattern() -> String:
	var props := HouseProperties.make(HouseProperties.Style.COTTAGE, 4)
	props.floors = 2
	props.floor_height = 2.7
	props.width = 10.0
	props.window_omit = 0.0
	props.window_columns = 3
	props.window_walls = HouseProperties.WINDOW_FRONT
	props.porch = false
	props.door_side = HouseProperties.HouseSide.LEFT
	props.window_pattern = HouseProperties.WindowPattern.SMALLER_ABOVE
	props.window_variation = 1.0
	var mesh := HouseGenerator.build_mesh(props, 0)
	var low: Array[AABB] = []
	var high: Array[AABB] = []
	var split := props.foundation_height + props.floor_height
	for pane in _front_components(mesh, "glass", props):
		var box: AABB = pane
		if box.get_center().y < split:
			low.append(box)
		else:
			high.append(box)
	if low.is_empty() or high.is_empty():
		return "upstairs pattern is missing a floor"
	var low_h := low[0].size.y
	for box in low:
		low_h = minf(low_h, box.size.y)
	var high_h := 0.0
	for box in high:
		high_h = maxf(high_h, box.size.y)
	if high_h > low_h * 0.9:
		return "upstairs windows are not smaller (%.2f vs %.2f)" % [high_h, low_h]
	props.floors = 1
	props.window_columns = 4
	props.window_pattern = HouseProperties.WindowPattern.WIDE_CENTER
	mesh = HouseGenerator.build_mesh(props, 0)
	var panes := _front_components(mesh, "glass", props)
	if panes.size() < 3:
		return "center pattern has too few windows"
	var narrow := INF
	var wide := 0.0
	var head := -1.0
	for pane in panes:
		var box: AABB = pane
		narrow = minf(narrow, box.size.x)
		wide = maxf(wide, box.size.x)
		var top := box.position.y + box.size.y
		if head < 0.0:
			head = top
		elif absf(top - head) > 0.03:
			return "window heads are not aligned"
	if wide - narrow < 0.18:
		return "center windows are not wider (%.2f vs %.2f)" % [wide, narrow]
	props.window_variation = 0.0
	mesh = HouseGenerator.build_mesh(props, 0)
	var first := -1.0
	for pane in _front_components(mesh, "glass", props):
		var box: AABB = pane
		if first < 0.0:
			first = box.size.x
		elif absf(box.size.x - first) > 0.02:
			return "zero variation still changes window width"
	props.window_pattern = HouseProperties.WindowPattern.IRREGULAR
	props.window_variation = 1.0
	mesh = HouseGenerator.build_mesh(props, 0)
	head = -1.0
	narrow = INF
	wide = 0.0
	for pane in _front_components(mesh, "glass", props):
		var box: AABB = pane
		narrow = minf(narrow, box.size.x)
		wide = maxf(wide, box.size.x)
		var top := box.position.y + box.size.y
		if head < 0.0:
			head = top
		elif absf(top - head) > 0.03:
			return "irregular window heads are not aligned"
	if wide - narrow < 0.08:
		return "irregular windows do not vary"
	return ""


func _check_window_span() -> String:
	# Fill mode keeps a fixed bay pitch: modest corner piers, no huge mid-wall void.
	var props := HouseProperties.make(HouseProperties.Style.TOWNHOUSE, 4)
	props.width = 11.0
	props.depth = 6.0
	props.floors = 2
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_walls = HouseProperties.WINDOW_FRONT
	props.window_pattern = HouseProperties.WindowPattern.UNIFORM
	props.porch = false
	props.door_side = HouseProperties.HouseSide.CENTER
	var mesh := HouseGenerator.build_mesh(props, 0)
	var split := props.foundation_height + props.floor_height
	var xs: Array[float] = []
	var left := INF
	var right := -INF
	for pane in _front_components(mesh, "glass", props):
		var box: AABB = pane
		# Upstairs avoids the door gap so bay rhythm is measurable.
		if box.get_center().y < split:
			continue
		xs.append(box.get_center().x)
		left = minf(left, box.position.x)
		right = maxf(right, box.position.x + box.size.x)
	if xs.size() < 4:
		return "wide facade kept too few windows (%d)" % xs.size()
	xs.sort()
	var half := props.width * 0.5
	var edge_left := left - (-half)
	var edge_right := half - right
	if edge_left > 1.2 or edge_right > 1.2:
		return "wide facade leaves %.2f/%.2f m at the corners" % [edge_left, edge_right]
	if edge_left < 0.25 or edge_right < 0.25:
		return "windows sit on the corners (%.2f/%.2f m)" % [edge_left, edge_right]
	var max_gap := 0.0
	for i in range(1, xs.size()):
		max_gap = maxf(max_gap, xs[i] - xs[i - 1])
	if max_gap > 1.6:
		return "window bays are uneven / too open (%.2f m)" % max_gap
	return ""


func _check_facade_profiles() -> String:
	var shop := HouseProperties.make(HouseProperties.Style.SHOP, 6)
	if shop.facade_profile != HouseProperties.FacadeProfile.SHOP_FRONT:
		return "shop recipe did not set SHOP_FRONT"
	var modern := HouseProperties.make(HouseProperties.Style.CHURCH, 14)
	if (modern.slit_walls & HouseProperties.WINDOW_BACK) == 0:
		return "modern church recipe did not set slit_walls on the back"
	var hangar := HouseProperties.make(HouseProperties.Style.HANGAR, 2)
	if hangar.facade_profile != HouseProperties.FacadeProfile.NONE:
		return "hangar recipe did not set NONE facade"
	if absf(hangar.garage_width_fraction - 0.66) > 0.001:
		return "hangar garage fraction is %.2f" % hangar.garage_width_fraction
	var warehouse := HouseProperties.make(HouseProperties.Style.WAREHOUSE, 4)
	if absf(warehouse.garage_width_fraction - 0.40) > 0.001:
		return "warehouse garage fraction is %.2f" % warehouse.garage_width_fraction
	var office := HouseProperties.make(HouseProperties.Style.OFFICE, 17)
	if office.catalog_column_cap < 8:
		return "office catalog column cap stayed low"
	var cottage := HouseProperties.make(HouseProperties.Style.COTTAGE, 4)
	if cottage.facade_profile != HouseProperties.FacadeProfile.GRID or cottage.slit_walls != 0:
		return "cottage facade profile drifted"
	return ""


func _check_industrial() -> String:
	var hangar_on := 0
	var warehouse_on := 0
	for seed_value in 24:
		if HouseProperties.make(HouseProperties.Style.HANGAR, seed_value + 1).annex:
			hangar_on += 1
		if HouseProperties.make(HouseProperties.Style.WAREHOUSE, seed_value + 1).annex:
			warehouse_on += 1
	if hangar_on < 4 or hangar_on > 16:
		return "hangar annex is not occasional (%d of 24)" % hangar_on
	if warehouse_on < 12 or warehouse_on > 22:
		return "warehouse annex is not usual (%d of 24)" % warehouse_on
	for style in [HouseProperties.Style.HANGAR, HouseProperties.Style.WAREHOUSE]:
		var bare := HouseProperties.make(style, 3)
		bare.annex = false
		var bare_mesh := HouseGenerator.build_mesh(bare, 0)
		if bare_mesh.surface_find_by_name("glass") >= 0:
			return "industrial hall has glass without an annex"
		var wide := _widest_front(bare_mesh, "door", bare)
		if wide < 4.0:
			return "garage door is only %.2f m" % wide
		var with_annex := HouseProperties.make(style, 3)
		with_annex.annex = true
		var mesh := HouseGenerator.build_mesh(with_annex, 0)
		var doors := _front_components(mesh, "door", with_annex)
		var narrow := INF
		var garage := 0.0
		for door in doors:
			narrow = minf(narrow, door.size.x)
			garage = maxf(garage, door.size.x)
		if garage < 4.0 or narrow > 1.6:
			return "annex is missing a person door or the garage door (%.2f / %.2f)" % [garage, narrow]
		var glass := _front_components(mesh, "glass", with_annex)
		if glass.is_empty():
			return "annex is missing its window"
		var annex_x := with_annex.width * 0.5 - 4.6
		for pane in glass:
			if pane.get_center().x < annex_x:
				return "a window sits on the hall"
	return ""


func _check_alpine_and_station() -> String:
	for seed_value in 24:
		var alpine := HouseProperties.make(HouseProperties.Style.ALPINE, seed_value + 1)
		if alpine.floors < 2 or alpine.roof_pitch > 0.45 or alpine.roof_overhang < 1.1 or alpine.roof_overhang > 1.55 or alpine.porch:
			return "alpine seed %d is not a shallow wide-eaved chalet" % (seed_value + 1)
		var mesh := HouseGenerator.build_mesh(alpine, 0)
		var roof_id := mesh.surface_find_by_name("roof")
		if roof_id < 0:
			return "alpine is missing its roof"
		var front_peak := 0.0
		var side_peak := 0.0
		var corner_y := INF
		var eaves_past := alpine.roof_overhang * 0.85
		for vertex in mesh.surface_get_arrays(roof_id)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.x) < 0.15 and vertex.z < -alpine.depth * 0.5 - eaves_past:
				front_peak = maxf(front_peak, vertex.y)
			if absf(vertex.z) < 0.15 and vertex.x > alpine.width * 0.5 + eaves_past:
				side_peak = maxf(side_peak, vertex.y)
			if absf(vertex.x) > alpine.width * 0.5 and absf(vertex.z) > alpine.depth * 0.5:
				corner_y = minf(corner_y, vertex.y)
		var plate := alpine.foundation_height + alpine.floors * alpine.floor_height
		if front_peak < plate + 0.5 or side_peak < plate + 0.5:
			return "alpine roof is not a cross gable (front %.2f, side %.2f)" % [front_peak, side_peak]
		if corner_y > plate - 0.2:
			return "alpine overhang does not drop at the corners (%.2f)" % corner_y
		var front_shoulder := INF
		for vertex in mesh.surface_get_arrays(roof_id)[Mesh.ARRAY_VERTEX]:
			if vertex.z < -alpine.depth * 0.5 - eaves_past and absf(vertex.x) > alpine.width * 0.32:
				front_shoulder = minf(front_shoulder, vertex.y)
		if front_shoulder > plate + 0.35:
			return "alpine front cross gable still spans the full width (%.2f)" % front_shoulder
		var foundation := mesh.surface_find_by_name("foundation")
		if foundation < 0:
			return "alpine is missing its stone floor"
		var stone := 0.0
		for vertex in mesh.surface_get_arrays(foundation)[Mesh.ARRAY_VERTEX]:
			stone = maxf(stone, vertex.y)
		if stone < alpine.foundation_height + alpine.floor_height * 0.8:
			return "alpine stone floor stops at %.2f" % stone
		var balcony := false
		var trim := mesh.surface_find_by_name("trim")
		if trim >= 0:
			for vertex in mesh.surface_get_arrays(trim)[Mesh.ARRAY_VERTEX]:
				if vertex.y > alpine.foundation_height + alpine.floor_height - 0.4 and vertex.z < -alpine.depth * 0.5:
					balcony = true
		if not balcony:
			return "alpine seed %d has no balcony" % (seed_value + 1)
		var far := HouseGenerator.build_mesh(alpine, 2)
		if far.surface_find_by_name("trim") >= 0 or far.surface_find_by_name("foundation") >= 0:
			return "alpine far mesh keeps the balcony or stone floor"
	for seed_value in [8, 19]:
		var station := HouseProperties.make(HouseProperties.Style.STATION, seed_value)
		if station.floors != 1 or not station.porch or station.porch_depth < 2.0:
			return "station is not a single-story platform building"
		for lod in [0, 2]:
			var canopy := HouseGenerator.build_mesh(station, lod)
			var roof := canopy.surface_find_by_name("roof")
			if roof < 0:
				return "station is missing its roof"
			var reached := false
			for vertex in canopy.surface_get_arrays(roof)[Mesh.ARRAY_VERTEX]:
				if vertex.z < -station.depth * 0.5 - 1.4:
					reached = true
			if not reached:
				return "station canopy is missing on lod %d" % lod
	return ""


func _widest_front(mesh: ArrayMesh, surface_name: String, props: HouseProperties) -> float:
	var widest := 0.0
	for box in _front_components(mesh, surface_name, props):
		widest = maxf(widest, box.size.x)
	return widest


func _check_chalet_eave(mesh: ArrayMesh, props: HouseProperties) -> String:
	if props.style != HouseProperties.Style.CHALET or props.floors != 1:
		return ""
	var door_top := _front_component(mesh, "door", props)
	var roof := mesh.surface_find_by_name("roof")
	if door_top.size.y <= 0.0 or roof < 0:
		return "one-story chalet is missing a door or roof"
	var eave_y := INF
	var vertices: PackedVector3Array = mesh.surface_get_arrays(roof)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		if vertex.z < -props.depth * 0.45:
			eave_y = minf(eave_y, vertex.y)
	var door_y := door_top.position.y + door_top.size.y
	if eave_y < door_y + 0.05:
		return "chalet eave %.2f cuts the door at %.2f" % [eave_y, door_y]
	return ""


func _check_window_gap(mesh: ArrayMesh, props: HouseProperties) -> String:
	var door_box := _front_component(mesh, "door", props)
	if door_box.size.x <= 0.0:
		return ""
	for pane in _front_components(mesh, "glass", props):
		var box: AABB = pane
		if box.position.y >= door_box.position.y + door_box.size.y - 0.05:
			continue
		if box.position.y + box.size.y <= door_box.position.y:
			continue
		var gap := 0.0
		if box.position.x >= door_box.end.x:
			gap = box.position.x - door_box.end.x
		elif box.end.x <= door_box.position.x:
			gap = door_box.position.x - box.end.x
		else:
			return "a window overlaps the door"
		if gap < 0.38:
			return "a window is %.2f m from the door" % gap
	return ""


func _front_component(mesh: ArrayMesh, surface_name: String, props: HouseProperties) -> AABB:
	var boxes := _front_components(mesh, surface_name, props)
	if boxes.is_empty():
		return AABB()
	return boxes[0]


func _front_components(mesh: ArrayMesh, surface_name: String, props: HouseProperties) -> Array[AABB]:
	var surface := mesh.surface_find_by_name(surface_name)
	if surface < 0:
		return []
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	if index_data != null:
		indices = index_data
	var tris: Array = []
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for t in range(0, count, 3):
		var ids: Array[int] = []
		if indices.is_empty():
			ids = [t, t + 1, t + 2]
		else:
			ids = [indices[t], indices[t + 1], indices[t + 2]]
		var center := (vertices[ids[0]] + vertices[ids[1]] + vertices[ids[2]]) / 3.0
		var normal := normals[ids[0]] + normals[ids[1]] + normals[ids[2]]
		if normal.z > -2.2 or center.z > -props.depth * 0.3:
			continue
		tris.append(ids)
	var parent: Array[int] = []
	parent.resize(tris.size())
	for i in tris.size():
		parent[i] = i
	for a in tris.size():
		for b in range(a + 1, tris.size()):
			if _shares_vertex(tris[a], tris[b]):
				_join(parent, a, b)
	var boxes: Array[AABB] = []
	var seen: Dictionary = {}
	for i in tris.size():
		var root := _find(parent, i)
		if not seen.has(root):
			var first: Vector3 = vertices[tris[i][0]]
			seen[root] = AABB(first, Vector3.ZERO)
			boxes.append(seen[root])
		var box: AABB = seen[root]
		for id in tris[i]:
			box = box.expand(vertices[id])
		seen[root] = box
	boxes.clear()
	for root in seen:
		boxes.append(seen[root])
	return boxes


func _shares_vertex(a: Array, b: Array) -> bool:
	for id in a:
		if id in b:
			return true
	return false


func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _join(parent: Array[int], a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[rb] = ra


func _check_normals(mesh: ArrayMesh) -> String:
	var axes: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var found: Array[bool] = []
	found.resize(axes.size())
	found.fill(false)
	for surface in mesh.get_surface_count():
		var normals: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
		for normal in normals:
			for i in axes.size():
				if normal.dot(axes[i]) > 0.95:
					found[i] = true
	if found.has(false):
		return "missing an axis normal %s" % [found]
	return ""


func _check_winding(mesh: ArrayMesh) -> String:
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if index_data is PackedInt32Array:
			indices = index_data
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle in triangle_count:
			var a: int
			var b: int
			var c: int
			if indices.is_empty():
				a = triangle * 3
				b = a + 1
				c = a + 2
			else:
				a = indices[triangle * 3]
				b = indices[triangle * 3 + 1]
				c = indices[triangle * 3 + 2]
			var geometric: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if geometric.length_squared() < 1e-10:
				continue
			if geometric.dot(normals[a]) > 0.0:
				return "lod winding is counter-clockwise on %s" % mesh.surface_get_name(surface)
	return ""


func _vertex_count(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		count += vertices.size()
	return count


func _place_village(root: Node3D, rows: Array) -> Rect2:
	var gap_x := 6.0
	var gap_z := 10.0
	var z_cursor := 0.0
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for row in rows:
		var x_cursor := 0.0
		var row_depth := 0.0
		var houses: Array = []
		for spec in row:
			var props := HouseProperties.make(int(spec.style), int(spec.seed))
			if spec.has("annex"):
				props.annex = bool(spec.annex)
			var box := HouseGenerator.build_mesh(props, 0).get_aabb()
			var house := GeneratedHouse.new()
			house.properties = props
			house.name = props.baked_name()
			house.position = Vector3(x_cursor - box.position.x, 0.0, z_cursor - box.position.z)
			houses.append({"node": house, "box": box})
			x_cursor += box.size.x + gap_x
			row_depth = maxf(row_depth, box.size.z)
		var row_width := x_cursor - gap_x
		for item in houses:
			var house: GeneratedHouse = item.node
			house.position.x -= row_width * 0.5
			root.add_child(house)
			var box: AABB = item.box
			min_x = minf(min_x, house.position.x + box.position.x)
			max_x = maxf(max_x, house.position.x + box.position.x + box.size.x)
			min_z = minf(min_z, house.position.z + box.position.z)
			max_z = maxf(max_z, house.position.z + box.position.z + box.size.z)
		z_cursor += row_depth + gap_z
	var mid_z := (min_z + max_z) * 0.5
	for child in root.get_children():
		if child is GeneratedHouse:
			child.position.z -= mid_z
	return Rect2(min_x, min_z - mid_z, max_x - min_x, max_z - min_z)


func _save_demo() -> Error:
	var root := Node3D.new()
	root.name = "Village"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 0.8
	light.light_energy = 1.3
	light.look_at_from_position(Vector3(-14, 18, -22), Vector3(0, 2, 8))
	root.add_child(light)

	var rows: Array = [
		[
			{"style": HouseProperties.Style.CABIN, "seed": 2},
			{"style": HouseProperties.Style.CABIN, "seed": 11},
			{"style": HouseProperties.Style.COTTAGE, "seed": 4},
			{"style": HouseProperties.Style.COTTAGE, "seed": 9},
			{"style": HouseProperties.Style.COTTAGE, "seed": 15},
			{"style": HouseProperties.Style.SHED, "seed": 2},
			{"style": HouseProperties.Style.SHED, "seed": 8},
		],
		[
			{"style": HouseProperties.Style.CHALET, "seed": 5},
			{"style": HouseProperties.Style.CHALET, "seed": 12},
			{"style": HouseProperties.Style.FARMHOUSE, "seed": 7},
			{"style": HouseProperties.Style.FARMHOUSE, "seed": 15},
			{"style": HouseProperties.Style.TOWNHOUSE, "seed": 8},
			{"style": HouseProperties.Style.VILLA, "seed": 6},
		],
		[
			{"style": HouseProperties.Style.SHOP, "seed": 6},
			{"style": HouseProperties.Style.SHOP, "seed": 15},
			{"style": HouseProperties.Style.OFFICE, "seed": 17},
			{"style": HouseProperties.Style.OFFICE, "seed": 6},
		],
		[
			{"style": HouseProperties.Style.CHURCH, "seed": 12},
			{"style": HouseProperties.Style.CHURCH, "seed": 13},
			{"style": HouseProperties.Style.CHURCH, "seed": 14},
		],
		[
			{"style": HouseProperties.Style.HANGAR, "seed": 2, "annex": false},
			{"style": HouseProperties.Style.HANGAR, "seed": 11, "annex": true},
			{"style": HouseProperties.Style.WAREHOUSE, "seed": 4, "annex": false},
			{"style": HouseProperties.Style.WAREHOUSE, "seed": 15, "annex": true},
		],
		[
			{"style": HouseProperties.Style.ALPINE, "seed": 3},
			{"style": HouseProperties.Style.ALPINE, "seed": 5},
			{"style": HouseProperties.Style.STATION, "seed": 8},
			{"style": HouseProperties.Style.STATION, "seed": 19},
		],
	]
	var bounds := _place_village(root, rows)
	var margin := 16.0
	var ground_size := Vector2(bounds.size.x + margin * 2.0, bounds.size.y + margin * 2.0)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = ground_size
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#6d7a52")
	ground.mesh = plane
	ground.material_override = ground_mat
	ground.position.y = -0.02
	root.add_child(ground)
	root.move_child(ground, 2)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size.x, 0.2, ground_size.y)
	shape_node.shape = box
	shape_node.position.y = -0.1
	body.add_child(shape_node)
	root.add_child(body)
	root.move_child(body, 3)

	var look := Vector3(0.0, 4.0, 0.0)
	var span := maxf(bounds.size.x, bounds.size.y)
	light.look_at_from_position(Vector3(-span * 0.35, span * 0.28, -span * 0.45), look)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 48
	camera.current = true
	camera.look_at_from_position(Vector3(0.0, span * 0.48, -span * 1.2), look)
	root.add_child(camera)

	for child in root.get_children():
		child.owner = root
		if child is StaticBody3D:
			child.get_child(0).owner = root

	DirAccess.open("res://").make_dir_recursive("demo")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		root.free()
		return err
	err = ResourceSaver.save(packed, "res://demo/village.tscn")
	root.free()
	return err
