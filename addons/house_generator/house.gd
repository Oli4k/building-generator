@tool
@icon("res://addons/house_generator/icon.svg")
class_name GeneratedHouse
extends Node3D

## A house rebuilt from [member properties] in the editor and at runtime.
##
## The generated mesh and collision are not saved with the scene; the node rebuilds
## them from the resource. Use [HouseGenerator.save_scatter_scene] when you need a
## plain mesh scene for Terrain3D.

const _MESH_NAME := "HouseMesh"
const _BODY_NAME := "HouseCollision"

## Which windows are skipped, and a slight wall tint. The size and base colors stay put.
@export var seed: int = 1:
	get:
		if _properties == null:
			return 1
		return _properties.seed
	set(value):
		if _properties == null or _properties.seed == value:
			return
		_properties.seed = value

@export var properties: HouseProperties:
	get:
		return _properties
	set(value):
		if _properties == value:
			return
		if _properties != null and _properties.changed.is_connected(_rebuild):
			_properties.changed.disconnect(_rebuild)
		_properties = value
		_connect_properties()
		_rebuild()

@export var collision: bool = true:
	set(value):
		collision = value
		_rebuild()

## Keeps the house upright and drops the foundation bottom onto the lowest ground under it.
@export var grounded: bool = true:
	set(value):
		grounded = value
		_apply_grounding()

@export_flags_3d_physics var ground_mask: int = 1:
	set(value):
		ground_mask = value
		_apply_grounding()

@export_tool_button("Randomize") var randomize_action = _randomize

var _properties: HouseProperties
var _applying_ground := false
var _fitting_posts := false
var _post_bottoms: PackedFloat32Array = PackedFloat32Array()


func _validate_property(property: Dictionary) -> void:
	if property.name == "seed":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _enter_tree() -> void:
	set_notify_transform(true)
	if _properties == null:
		properties = HouseProperties.make(HouseProperties.Style.COTTAGE, 1)
		return
	_connect_properties()
	_rebuild()


func _ready() -> void:
	_ground_when_physics_ready()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_apply_grounding()


func _ground_when_physics_ready() -> void:
	await get_tree().physics_frame
	if is_inside_tree():
		_apply_grounding()


func _apply_grounding() -> void:
	if _applying_ground or not grounded or not is_inside_tree() or _properties == null:
		return
	var world := get_world_3d()
	if world == null:
		return
	_applying_ground = true
	var xf := global_transform
	var basis := xf.basis
	if absf(basis.y.dot(Vector3.UP) - 1.0) > 0.0001:
		basis = Basis(Vector3.UP, atan2(basis.z.x, basis.z.z))
	var exclude: Array[RID] = []
	var body := get_node_or_null(_BODY_NAME) as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	var origin := xf.origin
	var contact := HouseGenerator.foundation_bottom_y(world, origin, atan2(basis.z.x, basis.z.z), _properties.width, _properties.depth, ground_mask, exclude)
	if contact != INF:
		origin.y = contact
	if origin.distance_squared_to(xf.origin) > 1e-8 or not basis.is_equal_approx(xf.basis):
		global_transform = Transform3D(basis, origin)
	_applying_ground = false
	_fit_porch_posts()


func _randomize() -> void:
	var style := HouseProperties.Style.COTTAGE
	if _properties != null:
		style = _properties.style
	properties = HouseProperties.make(style, randi())


func _connect_properties() -> void:
	if _properties != null and not _properties.changed.is_connected(_rebuild):
		_properties.changed.connect(_rebuild)


func _rebuild() -> void:
	if not is_inside_tree() or _properties == null:
		return
	var mesh_node := get_node_or_null(_MESH_NAME) as MeshInstance3D
	if mesh_node == null:
		mesh_node = MeshInstance3D.new()
		mesh_node.name = _MESH_NAME
		add_child(mesh_node)
	mesh_node.mesh = HouseGenerator.build_mesh(_properties, 0, _post_bottoms)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rebuild_collision()
	if not _fitting_posts:
		_fit_porch_posts()


func _fit_porch_posts() -> void:
	if _fitting_posts or not is_inside_tree() or _properties == null:
		return
	var target := _sample_post_bottoms()
	if not _post_bottoms_differ(_post_bottoms, target):
		return
	_fitting_posts = true
	_post_bottoms = target
	_rebuild()
	_fitting_posts = false


func _sample_post_bottoms() -> PackedFloat32Array:
	var posts := HouseMeshBuilder.porch_post_layout(_properties)
	var bottoms := PackedFloat32Array()
	if posts.is_empty():
		return bottoms
	var world := get_world_3d()
	var exclude: Array[RID] = []
	var body := get_node_or_null(_BODY_NAME) as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	for post in posts:
		var bottom := 0.0
		if grounded and world != null:
			var world_point := to_global(Vector3(post.x, 0.0, post.z))
			var hit := HouseGenerator.ground_height(world, world_point, ground_mask, exclude)
			if hit != INF:
				bottom = to_local(Vector3(world_point.x, hit, world_point.z)).y - 0.02
		bottoms.append(minf(bottom, post.y - 0.5))
	return bottoms


func _post_bottoms_differ(current: PackedFloat32Array, target: PackedFloat32Array) -> bool:
	if current.size() != target.size():
		return true
	for i in current.size():
		if absf(current[i] - target[i]) > 0.01:
			return true
	return false


func _rebuild_collision() -> void:
	var body := get_node_or_null(_BODY_NAME) as StaticBody3D
	if not collision:
		if body != null:
			body.free()
		return
	if body == null:
		body = StaticBody3D.new()
		body.name = _BODY_NAME
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		body.add_child(shape_node)
		add_child(body)
	var shape_node := body.get_node("Shape") as CollisionShape3D
	var box := BoxShape3D.new()
	var height := _properties.foundation_height + _properties.floors * _properties.floor_height
	box.size = Vector3(maxf(_properties.width, 2.0), maxf(height, 0.2), maxf(_properties.depth, 2.0))
	shape_node.shape = box
	shape_node.position = Vector3(0, box.size.y * 0.5, 0)
