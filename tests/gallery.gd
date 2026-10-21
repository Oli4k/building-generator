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
	var houses := _houses(scene)
	var bounds := _bounds(houses)
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	camera.fov = 44
	camera.look_at_from_position(center + Vector3(span * 0.06, span * 0.30, -span * 0.86), center + Vector3(0, 4.0, 0))
	await _settle()
	_shot("res://docs/images/village.png")

	var cottage := scene.get_node("cottage_4") as Node3D
	var cottage_at := _node_box(cottage).get_center()
	camera.fov = 32
	camera.look_at_from_position(cottage_at + Vector3(-5.2, 1.8, -12.5), cottage_at + Vector3(0.4, -0.6, 0))
	await _settle()
	_shot("res://docs/images/cottage.png")

	var church := scene.get_node("church_14") as Node3D
	var church_at := _node_box(church).get_center()
	camera.fov = 38
	camera.look_at_from_position(church_at + Vector3(13.0, 7.5, 30.0), church_at + Vector3(0.0, -1.2, 0.0))
	await _settle()
	_shot("res://docs/images/church.png")

	var chalet := scene.get_node("chalet_5") as Node3D
	var chalet_at := _node_box(chalet).get_center()
	camera.fov = 34
	camera.look_at_from_position(chalet_at + Vector3(11.0, 3.4, -16.0), chalet_at + Vector3(-0.4, 0.6, 0.4))
	await _settle()
	_shot("res://docs/images/chalet.png")
	quit()


func _settle() -> void:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


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
