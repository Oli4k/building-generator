@tool
extends ScrollContainer

var _style: OptionButton
var _count: SpinBox
var _seed: SpinBox
var _path: LineEdit
var _status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(280, 320)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Scatter scenes"
	box.add_child(title)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Each file is one mesh with LOD0, LOD1, and LOD2. Assign it as a Terrain3D mesh asset, or instance it yourself. The origin sits on the ground, and the front faces -Z."
	box.add_child(hint)

	box.add_child(_labeled("Style", _make_style()))
	box.add_child(_labeled("Count", _make_count()))
	box.add_child(_labeled("Seed", _make_seed()))

	_path = LineEdit.new()
	_path.text = "res://generated_houses"
	_path.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(_labeled("Folder", _path))

	var generate := Button.new()
	generate.text = "Generate scenes"
	generate.pressed.connect(_generate)
	box.add_child(generate)

	var place := Button.new()
	place.text = "Place one in the open scene"
	place.pressed.connect(_place_one)
	box.add_child(place)

	var bake := Button.new()
	bake.text = "Bake selected house"
	bake.pressed.connect(_bake_selected)
	box.add_child(bake)

	var catalog := Button.new()
	catalog.text = "Bake catalog"
	catalog.pressed.connect(_bake_catalog)
	box.add_child(catalog)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _make_style() -> OptionButton:
	_style = OptionButton.new()
	_style.add_item("Mixed", -1)
	for style_name in HouseProperties.Style.keys():
		_style.add_item(style_name.capitalize(), HouseProperties.Style[style_name])
	_style.selected = 0
	return _style


func _make_count() -> SpinBox:
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 40
	_count.value = 4
	_count.rounded = true
	return _count


func _make_seed() -> SpinBox:
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 999999
	_seed.value = 1
	_seed.rounded = true
	return _seed


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 64
	row.add_child(label)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _generate() -> void:
	var folder := _path.text.strip_edges()
	if not folder.begins_with("res://"):
		_set_status("Folder must start with res://")
		return
	var saved := 0
	var count := int(_count.value)
	var base_seed := int(_seed.value)
	for i in count:
		var props := _properties_for_index(i, base_seed)
		var path := "%s/%s.tscn" % [folder.trim_suffix("/"), props.baked_name()]
		var err := HouseGenerator.save_scatter_scene(props, path)
		if err != OK:
			_set_status("Stopped on %s (%s)" % [path, error_string(err)])
			return
		saved += 1
	EditorInterface.get_resource_filesystem().scan()
	_set_status("Saved %d scene%s in %s" % [saved, "" if saved == 1 else "s", folder])


func _place_one() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_set_status("Open a scene first.")
		return
	var house := GeneratedHouse.new()
	house.properties = _properties_for_index(0, int(_seed.value))
	house.name = house.properties.baked_name()
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Place house")
	undo.add_do_method(root, "add_child", house)
	undo.add_do_method(house, "set_owner", root)
	undo.add_undo_method(root, "remove_child", house)
	undo.add_do_reference(house)
	undo.commit_action()
	_set_status("Placed %s in %s." % [house.name, root.name])


func _bake_selected() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var house: GeneratedHouse = null
	for node in selected:
		if node is GeneratedHouse:
			house = node
			break
	if house == null or house.properties == null:
		_set_status("Select a GeneratedHouse to bake.")
		return
	var folder := _path.text.strip_edges()
	if not folder.begins_with("res://"):
		_set_status("Folder must start with res://")
		return
	var path := "%s/%s.tscn" % [folder.trim_suffix("/"), house.properties.baked_name()]
	var err := HouseGenerator.save_scatter_scene(house.properties, path)
	if err != OK:
		_set_status("Bake failed (%s)" % error_string(err))
		return
	EditorInterface.get_resource_filesystem().scan()
	_set_status("Baked %s" % path)


func _properties_for_index(index: int, base_seed: int) -> HouseProperties:
	var style_id := _style.get_selected_id()
	if style_id < 0:
		var values := HouseProperties.Style.values()
		style_id = values[index % values.size()]
	return HouseProperties.make(style_id, base_seed + index)


func _bake_catalog() -> void:
	var err := HouseCatalog.save_catalog()
	if err != OK:
		_set_status("Catalog failed (%s)" % error_string(err))
		return
	EditorInterface.get_resource_filesystem().scan()
	_set_status("Saved %d houses in %s" % [HouseCatalog.VARIANTS.size(), HouseCatalog.FOLDER])


func _set_status(text: String) -> void:
	_status.text = text
