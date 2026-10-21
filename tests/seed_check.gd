extends SceneTree

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var props := HouseProperties.make(HouseProperties.Style.COTTAGE, 1)
	var base := props.wall_color
	var house := GeneratedHouse.new()
	house.properties = props
	get_root().add_child(house)
	await process_frame

	var first := _wall(house)
	var shift := _distance(base, first)
	if shift < 0.004 or shift > 0.16:
		push_error("Wall tint is out of range (%s, distance %s)" % [first, shift])
		quit(1)
		return

	house.seed = 40
	await process_frame
	if house.properties.seed != 40 or house.seed != 40:
		push_error("House seed did not update the placed instance")
		quit(1)
		return
	var second := _wall(house)
	if first.is_equal_approx(second):
		push_error("A new seed did not change the wall color")
		quit(1)
		return
	if _distance(base, second) > 0.16:
		push_error("Wall tint after reseeding is too strong (%s)" % second)
		quit(1)
		return

	house.properties.seed = 7
	await process_frame
	if house.seed != 7:
		push_error("Editing properties.seed did not show on the house")
		quit(1)
		return
	if _wall(house).is_equal_approx(second):
		push_error("Editing properties.seed did not rebuild the house")
		quit(1)
		return

	print("Seed edit ok")
	quit(0)


func _wall(house: GeneratedHouse) -> Color:
	var mesh := (house.get_node("HouseMesh") as MeshInstance3D).mesh as ArrayMesh
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) == "wall":
			return (mesh.surface_get_material(i) as StandardMaterial3D).albedo_color
	push_error("No wall surface")
	return Color()


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))
