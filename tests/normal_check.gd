extends SceneTree

## Headless check that surface normals and mesh tangents are present.


func _init() -> void:
	var failed := false
	HouseSurface.catalog_material()
	var normal_path := "res://house_catalog/house_normal.tres"
	if not ResourceLoader.exists(normal_path):
		push_error("missing house_normal.tres")
		failed = true
	else:
		var tex := load(normal_path) as Texture2D
		if tex == null:
			push_error("house_normal.tres is not a Texture2D")
			failed = true
		else:
			var image := tex.get_image()
			if image == null or image.get_width() < 128:
				push_error("normal atlas image is empty")
				failed = true
			else:
				var flat := 0
				var relieved := 0
				for y in mini(image.get_height(), 384):
					for x in mini(image.get_width(), 512):
						var c := image.get_pixel(x, y)
						if absf(c.r - 0.5) < 0.02 and absf(c.g - 0.5) < 0.02 and c.b > 0.9:
							flat += 1
						else:
							relieved += 1
				if relieved < 1000:
					push_error("normal atlas looks flat (relieved=%d flat=%d)" % [relieved, flat])
					failed = true
				else:
					print("normal atlas ok  relieved=%d flat=%d" % [relieved, flat])

	var props := HouseProperties.make(HouseProperties.Style.COTTAGE, 4)
	var mesh := HouseGenerator.build_mesh(props, 0)
	var roof := mesh.surface_find_by_name("roof")
	if roof < 0:
		push_error("cottage missing roof")
		failed = true
	else:
		var arrays: Array = mesh.surface_get_arrays(roof)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var tangents = arrays[Mesh.ARRAY_TANGENT]
		if tangents == null or tangents.is_empty():
			push_error("roof mesh has no tangents")
			failed = true
		elif tangents.size() != verts.size() * 4:
			push_error("roof tangents %d != verts %d * 4" % [tangents.size(), verts.size()])
			failed = true
		else:
			print("roof tangents ok  verts=%d" % verts.size())
		var mat := mesh.surface_get_material(roof) as StandardMaterial3D
		if mat == null or not mat.normal_enabled or mat.normal_texture == null:
			push_error("roof editor material missing normal map")
			failed = true
		else:
			print("roof editor normal ok")

	var catalog := HouseGenerator.build_mesh(props, 0, PackedFloat32Array(), true)
	var cat_arrays: Array = catalog.surface_get_arrays(0)
	var cat_verts: PackedVector3Array = cat_arrays[Mesh.ARRAY_VERTEX]
	var cat_tangents = cat_arrays[Mesh.ARRAY_TANGENT]
	if cat_tangents == null or cat_tangents.is_empty():
		push_error("catalog mesh has no tangents")
		failed = true
	elif cat_tangents.size() != cat_verts.size() * 4:
		push_error("catalog tangents %d != verts %d * 4" % [cat_tangents.size(), cat_verts.size()])
		failed = true
	else:
		print("catalog tangents ok  verts=%d" % cat_verts.size())
	var cat_mat := catalog.surface_get_material(0) as ShaderMaterial
	if cat_mat == null or cat_mat.get_shader_parameter("normal_atlas") == null:
		push_error("catalog material missing normal_atlas")
		failed = true
	else:
		print("catalog normal_atlas ok")

	quit(1 if failed else 0)
