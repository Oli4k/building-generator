extends SceneTree

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	get_root().size = Vector2i(1400, 900)
	var scene := (load("res://demo/village.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("res://tests/preview.png")

	var cottage := scene.get_node("cottage_4") as Node3D
	var camera := scene.get_node("Camera") as Camera3D
	camera.fov = 36
	camera.look_at_from_position(cottage.global_position + Vector3(7.5, 3.2, -8.0), cottage.global_position + Vector3(0, 2.6, 0))
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("res://tests/closeup.png")
	quit()


func _shot(path: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("Wrote ", path)
