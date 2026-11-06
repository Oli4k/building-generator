extends SceneTree

## Headless gallery shots for the README.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	print("gallery: start")
	get_root().size = Vector2i(1920, 1080)
	get_root().msaa_3d = Viewport.MSAA_4X
	var scene := (load("res://demo/village.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	_freeze_to_meshes(scene)
	print("gallery: village frozen, meshes=", _meshes(scene).size())
	var environment := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_mat := environment.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.42, 0.58, 0.78)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sky_mat.ground_bottom_color = Color(0.42, 0.48, 0.36)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.58)
	await _settle(6)
	print("gallery: settled")

	var camera := scene.get_node("Camera") as Camera3D
	camera.current = true
	camera.fov = 35
	_frame(camera, _bounds(_meshes(scene)))
	await _settle(3)
	_shot("res://docs/images/village.png")

	_solo(scene, scene.get_node("cottage_4"))
	_frame(camera, _node_box(scene.get_node("cottage_4")))
	await _settle(3)
	_shot("res://docs/images/cottage.png")

	_solo(scene, scene.get_node("church_14"))
	_frame(camera, _node_box(scene.get_node("church_14")))
	await _settle(3)
	_shot("res://docs/images/church.png")

	_solo(scene, scene.get_node("chalet_5"))
	_frame(camera, _node_box(scene.get_node("chalet_5")))
	await _settle(3)
	_shot("res://docs/images/chalet.png")
	print("gallery: done")
	quit()


## Drop GeneratedHouse scripts (physics / grounding) so headless frames keep ticking.
func _freeze_to_meshes(scene: Node) -> void:
	var houses: Array[GeneratedHouse] = []
	for child in scene.get_children():
		if child is GeneratedHouse:
			houses.append(child)
	for house in houses:
		house.grounded = false
		house.set_notify_transform(false)
		var src := house.get_node_or_null("HouseMesh") as MeshInstance3D
		var mesh: Mesh = src.mesh if src != null else null
		if mesh == null and house.properties != null:
			mesh = HouseGenerator.build_mesh(house.properties, 0)
		var mi := MeshInstance3D.new()
		mi.name = house.name
		mi.mesh = mesh
		mi.transform = house.global_transform
		var index := house.get_index()
		scene.add_child(mi)
		scene.move_child(mi, index)
		house.free()


## Front-right, 45° in plan and 30° down. Fit the subject, then nudge so its
## projected bounds sit on the screen center (isometric views otherwise drift).
func _frame(camera: Camera3D, box: AABB) -> void:
	var yaw := PI / 4.0
	var pitch := deg_to_rad(30.0)
	var look := Vector3(-sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var basis := Basis.looking_at(look, Vector3.UP)
	var target := Vector3(
		box.position.x + box.size.x * 0.5,
		box.position.y + box.size.y * 0.28,
		box.position.z + box.size.z * 0.5,
	)
	# Dampen height so a church tower does not shove the camera too far back.
	var radius := Vector3(box.size.x, box.size.y * 0.55, box.size.z).length() * 0.5
	var aspect := 1920.0 / 1080.0
	var half_y := deg_to_rad(camera.fov) * 0.5
	var half_x := atan(tan(half_y) * aspect)
	var low := radius * 0.4
	var high := radius * 14.0
	for _step in 20:
		var mid := (low + high) * 0.5
		if _subject_fits(box, target - look * mid, basis, half_x, half_y):
			high = mid
		else:
			low = mid
	var distance := high
	for _pass in 3:
		camera.look_at_from_position(target - look * distance, target)
		var error := _projected_center_error(camera, box)
		if error.length() < 4.0:
			break
		var world_y := (2.0 * distance * tan(half_y)) / 1080.0
		var world_x := (2.0 * distance * tan(half_x)) / 1920.0
		var right := camera.global_transform.basis.x
		var up := camera.global_transform.basis.y
		target += right * error.x * world_x - up * error.y * world_y
	camera.look_at_from_position(target - look * distance, target)


func _projected_center_error(camera: Camera3D, box: AABB) -> Vector2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var origin := box.position
	var size := box.size
	for x in [origin.x, origin.x + size.x]:
		for y in [origin.y, origin.y + size.y]:
			for z in [origin.z, origin.z + size.z]:
				var p := camera.unproject_position(Vector3(x, y, z))
				min_p.x = minf(min_p.x, p.x)
				min_p.y = minf(min_p.y, p.y)
				max_p.x = maxf(max_p.x, p.x)
				max_p.y = maxf(max_p.y, p.y)
	var content := (min_p + max_p) * 0.5
	return content - Vector2(960.0, 540.0)


func _subject_fits(box: AABB, eye: Vector3, basis: Basis, half_x: float, half_y: float) -> bool:
	var limit := 0.93
	var origin := box.position
	var size := box.size
	for x in [origin.x, origin.x + size.x]:
		for y in [origin.y, origin.y + size.y]:
			for z in [origin.z, origin.z + size.z]:
				var local := basis.inverse() * (Vector3(x, y, z) - eye)
				if local.z > -0.2:
					return false
				if absf(atan(local.x / -local.z)) > half_x * limit:
					return false
				if absf(atan(local.y / -local.z)) > half_y * limit:
					return false
	return true


func _settle(frames: int = 3) -> void:
	for _i in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _solo(scene: Node, subject: Node) -> void:
	for child in _meshes(scene):
		child.visible = child == subject


func _meshes(scene: Node) -> Array[Node3D]:
	var meshes: Array[Node3D] = []
	for child in scene.get_children():
		if child is MeshInstance3D and child.mesh != null and str(child.name) != "Ground":
			# Skip the ground plane mesh if named differently — village uses MeshInstance3D for ground.
			if child.mesh is PlaneMesh:
				continue
			meshes.append(child)
	return meshes


func _bounds(houses: Array[Node3D]) -> AABB:
	var bounds := _node_box(houses[0])
	for house in houses:
		bounds = bounds.merge(_node_box(house))
	return bounds


func _node_box(house: Node3D) -> AABB:
	if house is MeshInstance3D and (house as MeshInstance3D).mesh != null:
		return house.global_transform * (house as MeshInstance3D).mesh.get_aabb()
	var mesh_node := house.get_node_or_null("HouseMesh") as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		return house.global_transform * mesh_node.mesh.get_aabb()
	return AABB(house.global_position, Vector3(8, 6, 8))


func _shot(path: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("Wrote ", path)
