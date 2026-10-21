@tool
@icon("res://addons/house_generator/icon.svg")
class_name HouseScatter
extends Node3D

## Drops a handful of [GeneratedHouse] nodes inside a rectangle on XZ.
## Houses stay vertical. On uneven ground the foundation bottom follows the lowest point under the footprint.
##
## For hundreds of copies of the same mesh, bake scenes with the Houses dock and
## paint them with Terrain3D. This node is for editable houses in the current scene.

@export_range(1, 200, 1) var count: int = 8
@export var area: Vector2 = Vector2(48, 48)
@export var seed: int = 1
@export var styles: Array[HouseProperties.Style] = [
	HouseProperties.Style.COTTAGE,
	HouseProperties.Style.CABIN,
	HouseProperties.Style.TOWNHOUSE,
	HouseProperties.Style.FARMHOUSE,
]
@export var min_spacing: float = 10.0
@export var align_to_collision: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var snap_yaw: bool = true
@export_tool_button("Scatter houses") var scatter_action = scatter
@export_tool_button("Clear houses") var clear_action = clear_houses


func scatter() -> void:
	if Engine.is_editor_hint():
		_scatter_with_undo()
		return
	_scatter_now()


func clear_houses() -> void:
	if Engine.is_editor_hint():
		_clear_with_undo()
		return
	HouseGenerator.clear(self)


func _scatter_now() -> void:
	HouseGenerator.scatter(self, _settings())


func _scatter_with_undo() -> void:
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Scatter houses")
	for child in get_children():
		if child.is_in_group("generated_house"):
			undo.add_do_method(self, "remove_child", child)
			undo.add_undo_method(self, "add_child", child)
			undo.add_undo_method(child, "set_owner", child.owner)
			undo.add_undo_reference(child)
	var scene_root: Node = owner if owner != null else self
	for house in HouseGenerator._make_houses(self, _settings()):
		undo.add_do_method(self, "add_child", house)
		undo.add_do_method(house, "set_owner", scene_root)
		undo.add_undo_method(self, "remove_child", house)
		undo.add_do_reference(house)
	undo.commit_action()


func _clear_with_undo() -> void:
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Clear houses")
	for child in get_children():
		if not child.is_in_group("generated_house"):
			continue
		undo.add_do_method(self, "remove_child", child)
		undo.add_undo_method(self, "add_child", child)
		undo.add_undo_method(child, "set_owner", child.owner)
		undo.add_undo_reference(child)
	undo.commit_action()


func _settings() -> Dictionary:
	return {
		"count": count,
		"seed": seed,
		"area": area,
		"styles": styles,
		"min_spacing": min_spacing,
		"align_to_collision": align_to_collision,
		"collision_mask": collision_mask,
		"snap_yaw": snap_yaw,
		"clear_existing": true,
	}
