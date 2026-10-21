extends SceneTree

## Headless check for the house catalog, rectangle fit, and heightmap grounding.


func _init() -> void:
	var failed := false
	failed = _check_chalet() or failed
	failed = _check_civic() or failed
	failed = _check_catalog_mesh() or failed
	failed = _check_fit() or failed
	failed = _check_height() or failed
	failed = _check_catalog() or failed
	quit(1 if failed else 0)


func _check_chalet() -> bool:
	var props := HouseProperties.make(HouseProperties.Style.CHALET, 5)
	if props.roof_type != HouseProperties.RoofType.GABLE or props.roof_pitch < 0.9 or props.foundation_height < 0.6:
		push_error("chalet is not a steep timber house on a tall base (%s pitch, %s foundation)" % [props.roof_pitch, props.foundation_height])
		return true
	var names: PackedStringArray = []
	for entry in HouseCatalog.variants():
		names.append(entry.name)
		if entry.width + 0.01 < entry.depth:
			push_error("%s is deeper than it is wide" % entry.name)
			return true
	if names.size() < 8 or names.size() > 20:
		push_error("catalog has %d variants" % names.size())
		return true
	for required in ["church_a", "shop_a", "office_a"]:
		if not names.has(required):
			push_error("catalog is missing %s" % required)
			return true
	for banned in ["townhouse", "villa"]:
		for name in names:
			if name.begins_with(banned):
				push_error("catalog includes %s" % name)
				return true
	print("chalet and %d variants ok" % names.size())
	return false


func _check_civic() -> bool:
	var church := HouseProperties.make(HouseProperties.Style.CHURCH, 3)
	if church.floors != 1 or church.roof_pitch < 1.0 or church.roof_type != HouseProperties.RoofType.GABLE:
		push_error("church is not a small steep chapel")
		return true
	var church_mesh := HouseGenerator.build_mesh(church, 0)
	var ridge := church.foundation_height + church.floor_height + church.depth * 0.5 * church.roof_pitch
	var church_box := church_mesh.get_aabb()
	var church_top := church_box.position.y + church_box.size.y
	if church_top < ridge + 2.5:
		push_error("church tower does not clear the ridge (top %.2f, ridge %.2f)" % [church_top, ridge])
		return true
	if church_box.position.x > -church.width * 0.5 or church_box.position.x + church_box.size.x < church.width * 0.5 + 1.0:
		push_error("chapel plan does not step out to a west tower and chancel (%s)" % church_box)
		return true
	var tower_cull := _tower_wall_cull(church_mesh, church.width, church.depth)
	if tower_cull != "":
		push_error(tower_cull)
		return true
	var aisle := HouseGenerator.build_mesh(HouseProperties.make(HouseProperties.Style.CHURCH, 13), 0)
	var aisle_far := HouseGenerator.build_mesh(HouseProperties.make(HouseProperties.Style.CHURCH, 13), 2)
	var aisle_back := aisle.get_aabb().position.z + aisle.get_aabb().size.z
	var aisle_far_back := aisle_far.get_aabb().position.z + aisle_far.get_aabb().size.z
	if aisle_back < aisle_far_back + 0.8:
		push_error("side aisle is missing from the near chapel")
		return true
	var modern := HouseProperties.make(HouseProperties.Style.CHURCH, 14)
	if modern.roof_type != HouseProperties.RoofType.SHED or modern.roof_pitch < 0.55:
		push_error("1960s church does not have a tilted roof")
		return true
	var modern_mesh := HouseGenerator.build_mesh(modern, 0)
	var slits := _back_slit_widths(modern_mesh, modern.depth)
	if slits.size() < 4 or slits.size() > 5:
		push_error("1960s church has %d slits" % slits.size())
		return true
	for slit_w in slits:
		if slit_w > 0.6:
			push_error("1960s church slit is %.2f m wide" % slit_w)
			return true
	if _back_glass_height(modern_mesh, modern.depth) < 4.0:
		push_error("1960s church slits are not tall")
		return true
	if _back_span(modern_mesh, "glass", modern.depth) < modern.width * 0.55:
		push_error("1960s church slits do not span the high wall")
		return true
	var cap_cull := _campanile_cap_cull(modern_mesh, modern)
	if cap_cull != "":
		push_error(cap_cull)
		return true
	var chapel_cull := _check_cross_cull(HouseProperties.make(HouseProperties.Style.CHURCH, 12))
	if chapel_cull != "":
		push_error(chapel_cull)
		return true
	var modern_cull := _check_cross_cull(modern)
	if modern_cull != "":
		push_error(modern_cull)
		return true
	var cross_low := INF
	var cross_high := -INF
	for plan_seed in [2, 8, 14, 20]:
		var span := _modern_cross_span(HouseProperties.make(HouseProperties.Style.CHURCH, plan_seed))
		if span.y < 1.6:
			push_error("modern cross is not larger than the chapel cross (%.2f)" % span.y)
			return true
		if span.z < span.x + 0.45:
			push_error("modern cross arms do not run north-south (x %.2f, z %.2f)" % [span.x, span.z])
			return true
		cross_low = minf(cross_low, span.y)
		cross_high = maxf(cross_high, span.y)
	if cross_high - cross_low < 0.55:
		push_error("modern cross size barely varies (%.2f to %.2f)" % [cross_low, cross_high])
		return true
	var shortest := INF
	var tallest := -INF
	for chapel_seed in [0, 3, 6, 9, 12, 15, 18]:
		var clearance := _tower_clearance(HouseProperties.make(HouseProperties.Style.CHURCH, chapel_seed))
		shortest = minf(shortest, clearance)
		tallest = maxf(tallest, clearance)
	if tallest - shortest < 1.2:
		push_error("tower roofs barely vary (%.2f to %.2f)" % [shortest, tallest])
		return true
	for plan_seed in [3, 13, 14]:
		var far := HouseGenerator.build_mesh(HouseProperties.make(HouseProperties.Style.CHURCH, plan_seed), 2)
		if _vertex_count(far) > 160:
			push_error("church seed %d far mesh has %d vertices" % [plan_seed, _vertex_count(far)])
			return true
	var shop := HouseProperties.make(HouseProperties.Style.SHOP, 6)
	var shop_mesh := HouseGenerator.build_mesh(shop, 0)
	var glass_width := _front_span(shop_mesh, "glass", shop.depth)
	if glass_width < shop.width * 0.45:
		push_error("shop front glass is only %.2f m on a %.2f m facade" % [glass_width, shop.width])
		return true
	var office := HouseProperties.make(HouseProperties.Style.OFFICE, 4)
	if office.floors < 3 or office.roof_type != HouseProperties.RoofType.FLAT or office.window_columns < 4:
		push_error("office is not a multi-storey flat block")
		return true
	for entry in HouseCatalog.variants():
		if entry.style == "church":
			var tagged := HouseCatalog.fit_footprint(_rect(Vector2(20, 20), entry.width, entry.depth, 0.2), {"building": "church"})
			if not tagged.ok or not str(tagged.name).begins_with("church"):
				push_error("church tag was not matched: %s" % tagged)
				return true
			var plain := HouseCatalog.fit_footprint(_rect(Vector2(20, 20), entry.width, entry.depth, 0.2))
			if plain.ok and str(plain.name).begins_with("church"):
				push_error("untagged footprint used a church: %s" % plain)
				return true
			break
	for entry in HouseCatalog.variants():
		if entry.style == "shop":
			var tagged := HouseCatalog.fit_footprint(_rect(Vector2.ZERO, entry.width, entry.depth, 0.0), {"building": "retail"})
			if not tagged.ok or not str(tagged.name).begins_with("shop"):
				push_error("retail tag was not matched: %s" % tagged)
				return true
			break
	for entry in HouseCatalog.variants():
		if entry.style == "office":
			var tagged := HouseCatalog.fit_footprint(_rect(Vector2(5, 5), entry.width, entry.depth, -0.4), {"building": "office"})
			if not tagged.ok or not str(tagged.name).begins_with("office"):
				push_error("office tag was not matched: %s" % tagged)
				return true
			break
	print("church, shop, and office ok")
	return false


func _tower_clearance(props: HouseProperties) -> float:
	var mesh := HouseGenerator.build_mesh(props, 0)
	var box := mesh.get_aabb()
	var ridge := props.foundation_height + props.floor_height + props.depth * 0.5 * props.roof_pitch
	return box.position.y + box.size.y - ridge


func _check_cross_cull(props: HouseProperties) -> String:
	var mesh := HouseGenerator.build_mesh(props, 0)
	var top := mesh.get_aabb().position.y + mesh.get_aabb().size.y
	var dirs := {"+x": false, "-x": false, "+y": false, "-y": false, "+z": false, "-z": false}
	var center := Vector3.ZERO
	var tops := 0
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "wall":
			continue
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
			var centroid := (vertices[a] + vertices[b] + vertices[c]) / 3.0
			if centroid.y < top - 0.12 or absf(normals[a].y) < 0.8 or normals[a].y < 0.0:
				continue
			center += centroid
			tops += 1
	if tops == 0:
		return "cross has no top"
	center /= tops
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "wall":
			continue
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
			var centroid := (vertices[a] + vertices[b] + vertices[c]) / 3.0
			if centroid.y < top - 1.8:
				continue
			var geometric: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if geometric.dot(normals[a]) > 0.0:
				return "cross face is wound counter-clockwise at %s" % centroid
			var normal := normals[a]
			if absf(normal.x) > 0.8:
				dirs["+x" if normal.x > 0.0 else "-x"] = true
				if normal.x * (centroid.x - center.x) < 0.0:
					return "cross face points inward at %s" % centroid
			elif absf(normal.z) > 0.8:
				dirs["+z" if normal.z > 0.0 else "-z"] = true
				if normal.z * (centroid.z - center.z) < 0.0:
					return "cross face points inward at %s" % centroid
			elif normal.y > 0.8:
				dirs["+y"] = true
			elif normal.y < -0.8:
				dirs["-y"] = true
				if centroid.y > top - 0.2:
					return "cross top faces down at %s" % centroid
	for key in dirs:
		if not dirs[key]:
			return "cross is missing the %s face" % key
	return ""


func _modern_cross_span(props: HouseProperties) -> Vector3:
	var mesh := HouseGenerator.build_mesh(props, 0)
	var far := HouseGenerator.build_mesh(props, 2)
	var top := mesh.get_aabb().position.y + mesh.get_aabb().size.y
	var far_top := far.get_aabb().position.y + far.get_aabb().size.y
	if absf(top - far_top) > 0.05:
		return Vector3.ZERO
	var cap := props.foundation_height + props.floor_height + props.depth * props.roof_pitch + 3.3
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "wall":
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.y < top - (top - cap) * 0.5:
				continue
			min_x = minf(min_x, vertex.x)
			max_x = maxf(max_x, vertex.x)
			min_z = minf(min_z, vertex.z)
			max_z = maxf(max_z, vertex.z)
	if max_x <= min_x:
		return Vector3.ZERO
	return Vector3(max_x - min_x, top - cap, max_z - min_z)


func _campanile_cap_cull(mesh: ArrayMesh, props: HouseProperties) -> String:
	var hall_top := props.foundation_height + props.floor_height + props.depth * props.roof_pitch
	var found_up := false
	var found_down := false
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "roof":
			continue
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
			var centroid := (vertices[a] + vertices[b] + vertices[c]) / 3.0
			if centroid.y < hall_top + 2.4 or centroid.x < props.width * 0.5:
				continue
			if absf(normals[a].y) < 0.9:
				continue
			var geometric: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if geometric.dot(normals[a]) > 0.0:
				return "campanile cap is wound counter-clockwise at %s" % centroid
			if normals[a].y > 0.0:
				found_up = true
			else:
				found_down = true
	if not found_up:
		return "campanile cap has no upward face"
	if not found_down:
		return "campanile cap has no underside"
	return ""


func _tower_wall_cull(mesh: ArrayMesh, width: float, depth: float) -> String:
	var top := mesh.get_aabb().position.y + mesh.get_aabb().size.y
	var side := clampf(depth * 0.46, 2.8, 3.4)
	var hx := width * 0.5
	var center := Vector3.ZERO
	var faces: Array[Dictionary] = []
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "wall":
			continue
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
			var centroid := (vertices[a] + vertices[b] + vertices[c]) / 3.0
			if centroid.x > -hx + 0.45 or absf(normals[a].y) > 0.25:
				continue
			var z_span := maxf(vertices[a].z, maxf(vertices[b].z, vertices[c].z)) - minf(vertices[a].z, minf(vertices[b].z, vertices[c].z))
			if z_span > side + 0.4:
				continue
			var geometric: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if geometric.length_squared() < 1e-10:
				continue
			if geometric.dot(normals[a]) > 0.0:
				return "tower wall is wound counter-clockwise at %s" % centroid
			faces.append({"at": centroid, "normal": normals[a]})
			center += centroid
	if faces.size() < 4:
		return "tower shaft has %d wall faces above the roof" % faces.size()
	center /= faces.size()
	var outward := [false, false, false, false]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	for face in faces:
		var at: Vector3 = face.at
		var normal: Vector3 = face.normal
		var away := Vector3(at.x - center.x, 0.0, at.z - center.z)
		if away.length_squared() > 0.04 and normal.dot(away.normalized()) < 0.7:
			return "tower wall faces inward at %s (normal %s)" % [at, normal]
		for i in axes.size():
			if normal.dot(axes[i]) > 0.9:
				outward[i] = true
	for i in outward.size():
		if not outward[i]:
			return "tower is missing the %s wall" % ["east", "west", "north", "south"][i]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "wall":
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.y < top - 1.05:
				continue
			min_x = minf(min_x, vertex.x)
			max_x = maxf(max_x, vertex.x)
			min_z = minf(min_z, vertex.z)
			max_z = maxf(max_z, vertex.z)
	if max_z - min_z < max_x - min_x + 0.3:
		return "cross arms still run east-west (x %.2f, z %.2f)" % [max_x - min_x, max_z - min_z]
	return ""


func _back_glass_height(mesh: ArrayMesh, depth: float) -> float:
	var min_y := INF
	var max_y := -INF
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "glass":
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.z < depth * 0.5 - 0.45:
				continue
			min_y = minf(min_y, vertex.y)
			max_y = maxf(max_y, vertex.y)
	if max_y <= min_y:
		return 0.0
	return max_y - min_y


func _back_slit_widths(mesh: ArrayMesh, depth: float) -> Array:
	var xs: Array[float] = []
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != "glass":
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.z < depth * 0.5 - 0.45:
				continue
			var known := false
			for existing in xs:
				if absf(existing - vertex.x) < 0.02:
					known = true
					break
			if not known:
				xs.append(vertex.x)
	xs.sort()
	var widths: Array = []
	var i := 0
	while i + 1 < xs.size():
		var slit_w := xs[i + 1] - xs[i]
		if slit_w > 0.15:
			widths.append(slit_w)
			i += 2
		else:
			i += 1
	return widths


func _back_span(mesh: ArrayMesh, surface_name: String, depth: float) -> float:
	var min_x := INF
	var max_x := -INF
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != surface_name:
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.z < depth * 0.5 - 0.45:
				continue
			min_x = minf(min_x, vertex.x)
			max_x = maxf(max_x, vertex.x)
	if max_x <= min_x:
		return 0.0
	return max_x - min_x


func _front_span(mesh: ArrayMesh, surface_name: String, depth: float) -> float:
	var min_x := INF
	var max_x := -INF
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) != surface_name:
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.z > -depth * 0.5 + 0.3:
				continue
			min_x = minf(min_x, vertex.x)
			max_x = maxf(max_x, vertex.x)
	if max_x <= min_x:
		return 0.0
	return max_x - min_x


func _check_catalog_mesh() -> bool:
	var props := HouseProperties.make(HouseProperties.Style.VILLA, 6)
	var editor := HouseGenerator.build_mesh(props, 0)
	var catalog := HouseGenerator.build_mesh(props, 0, PackedFloat32Array(), true)
	var far := HouseGenerator.build_mesh(props, 2, PackedFloat32Array(), true)
	var editor_count := _vertex_count(editor)
	var catalog_count := _vertex_count(catalog)
	if catalog.get_surface_count() != 1 or far.get_surface_count() != 1:
		push_error("catalog mesh has more than one surface")
		return true
	if catalog_count > editor_count * 0.45:
		push_error("catalog near mesh is still heavy (%d vs %d)" % [catalog_count, editor_count])
		return true
	if _vertex_count(far) > 160:
		push_error("catalog far mesh has %d vertices" % _vertex_count(far))
		return true
	if catalog.get_aabb().position.y > -1.4 or far.get_aabb().position.y > -1.4:
		push_error("catalog skirt is missing (%s / %s)" % [catalog.get_aabb(), far.get_aabb()])
		return true
	var mat := catalog.surface_get_material(0) as ShaderMaterial
	var arrays: Array = catalog.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var atlas: Variant = mat.get_shader_parameter("albedo_atlas") if mat != null else null
	if mat == null or not (atlas is Texture2D) or colors.size() != catalog_count:
		push_error("catalog mesh has no shared vertex colors")
		return true
	if not _has_two_colors(colors):
		push_error("catalog mesh does not carry both wall and roof colors")
		return true
	var shade := _shade_gap(arrays)
	if shade < 0.04:
		push_error("ground contact is not darker than the wall (%.3f)" % shade)
		return true
	var gable := HouseGenerator.build_mesh(HouseProperties.make(HouseProperties.Style.COTTAGE, 1), 0)
	var gable_gap := _gable_shade_gap(gable)
	if gable_gap > 0.04:
		push_error("gable is darker than the wall below it (%.3f)" % gable_gap)
		return true
	var rough := mat.get_shader_parameter("roughness_atlas") as Texture2D
	var rough_image := rough.get_image() if rough != null else null
	if rough_image == null or rough_image.get_pixel(128 + 4, 128 + 4).a > 0.2 or rough_image.get_pixel(4, 4).a < 0.7:
		push_error("glass roughness is not split from the walls")
		return true
	if not _roof_uv_follows_plan(arrays):
		push_error("roof UVs still run diagonally")
		return true
	var wall_mat := editor.surface_get_material(editor.surface_find_by_name("wall")) as StandardMaterial3D
	if wall_mat == null or wall_mat.albedo_texture == null or not wall_mat.vertex_color_use_as_albedo:
		push_error("editor walls have no grain")
		return true
	print("catalog mesh ok  near=%d editor=%d far=%d" % [catalog_count, editor_count, _vertex_count(far)])
	return false


func _check_fit() -> bool:
	var entries := HouseCatalog.variants()
	var cottage: Dictionary = entries[2]
	var yaw := 0.7
	var fit := HouseCatalog.fit_footprint(_rect(Vector2(50, -20), cottage.width, cottage.depth, yaw))
	if not fit.ok or fit.name != cottage.name:
		push_error("exact cottage fit failed: %s" % fit)
		return true
	var basis := Basis(Vector3.UP, fit.yaw)
	var expected := Basis(Vector3.UP, yaw)
	var aligned := absf(absf(Vector2(basis.x.x, basis.x.z).dot(Vector2(expected.x.x, expected.x.z))) - 1.0)
	if aligned > 0.02 or absf(fit.width - cottage.width) > 0.05:
		push_error("yaw or size drifted: %s" % fit)
		return true
	var courtyard := HouseCatalog.fit_footprint(PackedVector2Array([
		Vector2(0, 0), Vector2(12, 0), Vector2(12, 5), Vector2(5, 5), Vector2(5, 12), Vector2(0, 12),
	]))
	if courtyard.ok or not (courtyard.reason == "courtyard" or courtyard.reason == "not_rectangular"):
		push_error("courtyard was accepted: %s" % courtyard)
		return true
	if HouseCatalog.fit_footprint(_rect(Vector2.ZERO, 8, 6, 0), {"building": "terrace"}).reason != "not_house":
		push_error("terrace was accepted")
		return true
	if HouseCatalog.fit_footprint(_rect(Vector2.ZERO, 8, 6, 0), {"building:part": "house"}).reason != "building_part":
		push_error("building part was accepted")
		return true
	if HouseCatalog.fit_footprint(_rect(Vector2.ZERO, 40, 20, 0)).reason != "too_large":
		push_error("hall was accepted")
		return true
	if HouseCatalog.fit_footprint(_rect(Vector2.ZERO, 20, 4, 0)).reason != "no_variant":
		push_error("unmatched rectangle was accepted")
		return true
	print("footprint fit ok (%s yaw %.2f)" % [fit.name, fit.yaw])
	return false


func _check_height() -> bool:
	var flat := _image(func(x: int, _y: int) -> float: return 12.5)
	var gentle := HouseCatalog.ground_on_heightmap(flat, Vector2(8, 8), 0.0, 8.0, 6.0, Vector2.ZERO, 1.0, 0.8)
	if not gentle.ok or absf(gentle.y - 12.5) > 0.001:
		push_error("flat heightmap failed: %s" % gentle)
		return true
	var slope := _image(func(x: int, _y: int) -> float: return x * 0.05)
	var seated := HouseCatalog.ground_on_heightmap(slope, Vector2(10, 10), 0.0, 8.0, 6.0, Vector2.ZERO, 1.0, 0.8)
	if not seated.ok or seated.relief > 0.8 or absf(seated.y - (0.3 - 0.02)) > 0.08:
		push_error("gentle slope failed: %s" % seated)
		return true
	var steep := _image(func(x: int, _y: int) -> float: return x * 0.36)
	var rejected := HouseCatalog.ground_on_heightmap(steep, Vector2(10, 10), 0.0, 10.0, 8.0, Vector2.ZERO, 1.0, 0.9)
	if rejected.ok or rejected.reason != "slope":
		push_error("20 degree slope was accepted: %s" % rejected)
		return true
	var chalet: Dictionary = {}
	for entry in HouseCatalog.variants():
		if entry.name == "chalet_a":
			chalet = entry
	var placed := HouseCatalog.fit_footprint(_rect(Vector2(10, 10), chalet.width, chalet.depth, 0.0), {}, [], steep, Vector2.ZERO, 1.0)
	if placed.ok:
		push_error("fit accepted a steep site: %s" % placed)
		return true
	print("heightmap ok  relief=%.2f y=%.2f" % [seated.relief, seated.y])
	return false


func _check_catalog() -> bool:
	var err := HouseCatalog.save_catalog()
	if err != OK:
		push_error("save failed: %s" % error_string(err))
		return true
	var text := FileAccess.get_file_as_string("res://house_catalog/cabin_a.tscn")
	if text.is_empty() or text.contains("HouseProperties") or text.contains("house_generator"):
		push_error("catalog scene still depends on the addon")
		return true
	if not text.contains("ext_resource") or not text.contains("LOD0") or not text.contains("LOD2"):
		push_error("catalog scene is not an external LOD scene")
		return true
	if not text.contains("cast_shadow = 0"):
		push_error("approach mesh still casts shadows")
		return true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://house_catalog/catalog.json"))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.houses.size() != HouseCatalog.VARIANTS.size():
		push_error("catalog.json is incomplete")
		return true
	print("catalog ok  %d scenes" % parsed.houses.size())
	return false


func _rect(center: Vector2, width: float, depth: float, yaw: float) -> PackedVector2Array:
	var basis := Basis(Vector3.UP, yaw)
	var points := PackedVector2Array()
	var corners: Array[Vector3] = [
		Vector3(-width * 0.5, 0, -depth * 0.5),
		Vector3(width * 0.5, 0, -depth * 0.5),
		Vector3(width * 0.5, 0, depth * 0.5),
		Vector3(-width * 0.5, 0, depth * 0.5),
		Vector3(-width * 0.5, 0, -depth * 0.5),
	]
	for corner in corners:
		var world := Vector3(center.x, 0, center.y) + basis * corner
		points.append(Vector2(world.x, world.z))
	return points


func _image(fn: Callable) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RF)
	for y in 32:
		for x in 32:
			image.set_pixel(x, y, Color(fn.call(x, y), 0, 0))
	return image


func _shade_gap(arrays: Array) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var low := 0.0
	var low_n := 0
	var high := 0.0
	var high_n := 0
	for i in vertices.size():
		if absf(uv2[i].x) > 0.1 or absf(normals[i].y) > 0.35:
			continue
		var value := colors[i].r + colors[i].g + colors[i].b
		if vertices[i].y < 0.45:
			low += value
			low_n += 1
		elif vertices[i].y > 1.4 and vertices[i].y < 2.4:
			high += value
			high_n += 1
	if low_n == 0 or high_n == 0:
		return 0.0
	return high / float(high_n) - low / float(low_n)


func _gable_shade_gap(mesh: ArrayMesh) -> float:
	var arrays: Array = mesh.surface_get_arrays(mesh.surface_find_by_name("wall"))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var peak_y := -INF
	for i in vertices.size():
		if absf(normals[i].x) > 0.75 and normals[i].x * vertices[i].x > 0.0:
			peak_y = maxf(peak_y, vertices[i].y)
	var ridge := 0.0
	var ridge_n := 0
	var body := 0.0
	var body_n := 0
	for i in vertices.size():
		if absf(normals[i].x) < 0.75 or normals[i].x * vertices[i].x <= 0.0:
			continue
		var value := colors[i].r + colors[i].g + colors[i].b
		if vertices[i].y > peak_y - 0.35:
			ridge += value
			ridge_n += 1
		elif vertices[i].y > 1.0 and vertices[i].y < peak_y - 0.7:
			body += value
			body_n += 1
	if ridge_n == 0 or body_n == 0:
		return 1.0
	return body / float(body_n) - ridge / float(ridge_n)


func _roof_uv_follows_plan(arrays: Array) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for i in vertices.size():
		if absf(uv2[i].x - float(HouseMeshBuilder.ROOF)) > 0.1:
			continue
		for j in range(i + 1, vertices.size()):
			if absf(uv2[j].x - float(HouseMeshBuilder.ROOF)) > 0.1:
				continue
			if absf(vertices[i].x - vertices[j].x) > 0.02 or absf(vertices[i].z - vertices[j].z) < 0.5:
				continue
			return absf(uvs[i].x - uvs[j].x) < 0.02 and absf(uvs[i].y - uvs[j].y) > 0.05
	return false


func _has_two_colors(colors: PackedColorArray) -> bool:
	var first := colors[0]
	for color in colors:
		if absf(color.r - first.r) + absf(color.g - first.g) + absf(color.b - first.b) > 0.05:
			return true
	return false


func _vertex_count(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
	return count
