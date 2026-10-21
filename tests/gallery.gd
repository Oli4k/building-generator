extends SceneTree

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	get_root().size = Vector2i(1920, 1080)
	get_root().msaa_3d = Viewport.MSAA_4X
	var scene := (load("res://demo/village.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var environment := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_mat := environment.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.42, 0.58, 0.78)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sky_mat.ground_bottom_color = Color(0.42, 0.48, 0.36)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.58)
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw

	var camera := scene.get_node("Camera") as Camera3D
	camera.fov = 35
	_frame(camera, _bounds(_houses(scene)))
	await _settle()
	_shot("res://docs/images/village.png")

	_solo(scene, scene.get_node("cottage_4"))
	_frame(camera, _node_box(scene.get_node("cottage_4")))
	await _settle()
	_shot("res://docs/images/cottage.png")

	_solo(scene, scene.get_node("church_14"))
	_frame(camera, _node_box(scene.get_node("church_14")))
	await _settle()
	_shot("res://docs/images/church.png")

	_solo(scene, scene.get_node("chalet_5"))
	_frame(camera, _node_box(scene.get_node("chalet_5")))
	await _settle()
	_shot("res://docs/images/chalet.png")
	quit()


## Front-right, 45° in plan and 30° down, with the subject center in the middle of the frame.
func _frame(camera: Camera3D, box: AABB) -> void:
	var yaw := PI / 4.0
	var pitch := deg_to_rad(30.0)
	var look := Vector3(-sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var basis := Basis.looking_at(look, Vector3.UP)
	var target := box.get_center()
	var radius := box.size.length() * 0.5
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
	camera.look_at_from_position(target - look * high, target)


func _subject_fits(box: AABB, eye: Vector3, basis: Basis, half_x: float, half_y: float) -> bool:
	var limit := 0.9
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


func _settle() -> void:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _solo(scene: Node, subject: Node) -> void:
	for child in scene.get_children():
		if child is GeneratedHouse:
			child.visible = child == subject


func _houses(scene: Node) -> Array[Node3D]:
	var houses: Array[Node3D] = []
	for child in scene.get_children():
		if child is GeneratedHouse:
			houses.append(child)
	return houses


func _bounds(houses: Array[Node3D]) -> AABB:
	var bounds := _node_box(houses[0])
	for house in houses:
		bounds = bounds.merge(_node_box(house))
	return bounds


func _node_box(house: Node3D) -> AABB:
	var mesh_node := house.get_node_or_null("HouseMesh") as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		return house.global_transform * mesh_node.mesh.get_aabb()
	return AABB(house.global_position, Vector3(8, 6, 8))


func _shot(path: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("Wrote ", path)
