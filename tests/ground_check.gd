extends SceneTree

## Places a house across two ground heights and checks that it stays upright
## with the foundation bottom on the lower one.


var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var root := Node3D.new()
	root.name = "Slope"
	get_root().add_child(root)
	_box(root, Vector3(-5, -1, 0), Vector3(10, 2, 16))
	_box(root, Vector3(5, 1, 0), Vector3(10, 2, 16))
	await physics_frame

	var props := HouseProperties.make(HouseProperties.Style.COTTAGE, 3)
	props.width = 8.0
	props.depth = 6.0
	var sampled := HouseGenerator.foundation_bottom_y(root.get_world_3d(), Vector3.ZERO, 0.2, props.width, props.depth, 1)
	if not is_equal_approx(sampled, -0.02):
		push_error("Footprint sample expected -0.02, got %s" % sampled)
		quit(1)
		return

	var house := GeneratedHouse.new()
	house.properties = props
	house.position = Vector3(0, 5, 0)
	house.rotation = Vector3(0.45, 0.3, -0.35)
	root.add_child(house)
	await physics_frame
	await physics_frame
	if not _upright(house):
		push_error("House stayed tilted: %s" % house.global_transform.basis)
		quit(1)
		return
	if not is_equal_approx(house.global_position.y, -0.02):
		push_error("Foundation bottom expected -0.02, got %s" % house.global_position.y)
		quit(1)
		return

	var tilted := Node3D.new()
	tilted.rotation.x = 0.5
	root.add_child(tilted)
	var child := GeneratedHouse.new()
	child.properties = props
	child.position = Vector3(0, 4, 0)
	child.rotation = Vector3(0.2, 1.0, 0.2)
	tilted.add_child(child)
	await physics_frame
	await physics_frame
	if not _upright(child) or not is_equal_approx(child.global_position.y, -0.02):
		push_error("Child of a tilted parent is not vertical on the low ground: y=%s basis.y=%s" % [child.global_position.y, child.global_transform.basis.y])
		quit(1)
		return

	var flat := Node3D.new()
	get_root().add_child(flat)
	_box(flat, Vector3(0, 2, 30), Vector3(30, 2, 30))
	await physics_frame
	var level := GeneratedHouse.new()
	level.properties = props
	level.position = Vector3(0, 0, 30)
	flat.add_child(level)
	await physics_frame
	await physics_frame
	if not is_equal_approx(level.global_position.y, 3.0):
		push_error("Flat ground expected y=3, got %s" % level.global_position.y)
		quit(1)
		return

	var wide := HouseProperties.make(HouseProperties.Style.FARMHOUSE, 2)
	wide.porch = true
	wide.width = 14.0
	wide.depth = 8.0
	wide.porch_depth = 2.0
	var posts := HouseMeshBuilder.porch_post_layout(wide)
	if posts.size() < 6:
		push_error("Wide porch has %d posts, expected at least 6" % posts.size())
		quit(1)
		return
	for i in posts.size() - 1:
		if posts[i + 1].x - posts[i].x > HouseMeshBuilder.PORCH_POST_SPAN + 0.05:
			push_error("Porch span %s is wider than %s" % [posts[i + 1].x - posts[i].x, HouseMeshBuilder.PORCH_POST_SPAN])
			quit(1)
			return

	var porch_root := Node3D.new()
	porch_root.position = Vector3(80, 0, 80)
	get_root().add_child(porch_root)
	_box(porch_root, Vector3(0, -1, 1.85), Vector3(24, 2, 12.3))
	_box(porch_root, Vector3(0, -2.5, -8.4), Vector3(24, 2, 7.2))
	await physics_frame
	var porch_house := GeneratedHouse.new()
	porch_house.properties = wide
	porch_root.add_child(porch_house)
	await physics_frame
	await physics_frame
	var mesh_node := porch_house.get_node("HouseMesh") as MeshInstance3D
	var lowest := mesh_node.mesh.get_aabb().position.y
	if lowest > -1.3:
		push_error("Porch posts did not reach the lower ground (mesh bottom %s)" % lowest)
		quit(1)
		return

	print("Ground contact ok")
	quit(0)


func _box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	body.position = center
	parent.add_child(body)


func _upright(house: Node3D) -> bool:
	return absf(house.global_transform.basis.y.dot(Vector3.UP) - 1.0) < 0.001
