@tool
class_name HouseGenerator
extends RefCounted

## Entry point for the editor, for [HouseScatter], and for other plugins.
##
## Baked scenes contain sibling [MeshInstance3D] nodes named [code]LOD0[/code],
## [code]LOD1[/code], and [code]LOD2[/code]. Terrain3D mesh assets read that layout.
## Each LOD is one mesh. The near mesh has several materials; the far mesh keeps
## walls and roof.
## The ground contact is the node origin. On a slope the house stays upright and the
## foundation bottom sits on the lowest ground under the footprint.


static func build_mesh(properties: HouseProperties, lod: int = 0, post_bottoms: PackedFloat32Array = PackedFloat32Array(), catalog: bool = false) -> ArrayMesh:
	return HouseMeshBuilder.build(properties, lod, post_bottoms, catalog)


## Root node with LOD0, LOD1, and LOD2. The caller owns it until it is packed or freed.
static func build_scatter_root(properties: HouseProperties) -> Node3D:
	var root := Node3D.new()
	root.name = properties.baked_name()
	root.set_meta("house_properties", properties.duplicate(true))
	for level in 3:
		var lod := _lod_instance(properties, level)
		root.add_child(lod)
		lod.owner = root
	return root


static func build_scatter_scene(properties: HouseProperties) -> PackedScene:
	var root := build_scatter_root(properties)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		push_error("HouseGenerator: failed to pack scene (%s)" % error_string(err))
		return null
	return packed


static func save_scatter_scene(properties: HouseProperties, path: String) -> Error:
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		push_error("HouseGenerator: path must be a res:// .tscn file")
		return ERR_INVALID_PARAMETER
	var directory := path.get_base_dir()
	var dir := DirAccess.open("res://")
	if dir == null:
		return ERR_CANT_OPEN
	var relative := directory.trim_prefix("res://")
	if relative != "" and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		var made := dir.make_dir_recursive(relative)
		if made != OK:
			return made
	var packed := build_scatter_scene(properties)
	if packed == null:
		return ERR_CANT_CREATE
	return ResourceSaver.save(packed, path)


## Places [GeneratedHouse] children on [param parent].
##
## [param settings] keys: [code]count[/code], [code]seed[/code], [code]area[/code] ([Vector2] on XZ),
## [code]styles[/code] (array of [enum HouseProperties.Style]), [code]min_spacing[/code],
## [code]align_to_collision[/code], [code]collision_mask[/code], [code]snap_yaw[/code],
## [code]clear_existing[/code]. Houses stay upright. When alignment is on, the
## foundation bottom is placed on the lowest ground under the footprint.
static func scatter(parent: Node3D, settings: Dictionary = {}) -> Array[GeneratedHouse]:
	if bool(settings.get("clear_existing", true)):
		clear(parent)
	var houses := _make_houses(parent, settings)
	var scene_root: Node = parent.owner if parent.owner != null else parent
	for house in houses:
		parent.add_child(house)
		if Engine.is_editor_hint() and scene_root != house:
			house.owner = scene_root
	return houses


static func clear(parent: Node3D) -> void:
	var doomed: Array[Node] = []
	for child in parent.get_children():
		if child.is_in_group("generated_house"):
			doomed.append(child)
	for child in doomed:
		parent.remove_child(child)
		child.free()


static func _make_houses(parent: Node3D, settings: Dictionary) -> Array[GeneratedHouse]:
	var count: int = clampi(int(settings.get("count", 8)), 1, 200)
	var area: Vector2 = settings.get("area", Vector2(40, 40))
	var min_spacing: float = maxf(float(settings.get("min_spacing", 8.0)), 0.0)
	var snap_yaw: bool = bool(settings.get("snap_yaw", true))
	var align: bool = bool(settings.get("align_to_collision", true))
	var mask: int = int(settings.get("collision_mask", 1))
	var styles: Array = settings.get("styles", [])
	if styles.is_empty():
		for style in HouseProperties.Style.values():
			if style == HouseProperties.Style.CHURCH or style == HouseProperties.Style.SHOP or style == HouseProperties.Style.OFFICE:
				continue
			styles.append(style)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.get("seed", 1))
	var spots := _scatter_spots(rng, count, area, min_spacing)
	if spots.size() < count:
		push_warning("HouseGenerator placed %d of %d houses. Increase the area or reduce spacing." % [spots.size(), count])
	var houses: Array[GeneratedHouse] = []
	for spot in spots:
		var style: int = styles[rng.randi_range(0, styles.size() - 1)]
		var house := GeneratedHouse.new()
		house.properties = HouseProperties.make(style, rng.randi())
		house.name = "House_%s" % house.properties.baked_name()
		house.add_to_group("generated_house")
		var yaw := rng.randi_range(0, 3) * (PI * 0.5) if snap_yaw else rng.randf() * TAU
		var world_pos := parent.to_global(Vector3(spot.x, 0.0, spot.y))
		if align:
			house.grounded = true
			house.ground_mask = mask
			var contact := foundation_bottom_y(parent.get_world_3d(), world_pos, yaw, house.properties.width, house.properties.depth, mask)
			if contact != INF:
				world_pos.y = contact
		else:
			house.grounded = false
		house.transform = parent.global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP, yaw), world_pos)
		houses.append(house)
	return houses


static func _scatter_spots(rng: RandomNumberGenerator, count: int, area: Vector2, min_spacing: float) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	var attempts := 0
	var limit := count * 40
	while placed.size() < count and attempts < limit:
		attempts += 1
		var spot := Vector2(rng.randf_range(-area.x * 0.5, area.x * 0.5), rng.randf_range(-area.y * 0.5, area.y * 0.5))
		var clear_spot := true
		for other in placed:
			if spot.distance_to(other) < min_spacing:
				clear_spot = false
				break
		if clear_spot:
			placed.append(spot)
	return placed


## Upright transform whose origin is the foundation bottom on [param world_position]'s XZ.
##
## Yaw is the only rotation. The origin Y is the lowest collision under the foundation,
## so a slope buries the uphill side instead of leaving the downhill side in the air.
static func upright_on_ground(space_owner: Node3D, world_position: Vector3, yaw: float, width: float, depth: float, mask: int = 1) -> Transform3D:
	var world := space_owner.get_world_3d() if space_owner != null else null
	var y := foundation_bottom_y(world, world_position, yaw, width, depth, mask)
	if y == INF:
		y = world_position.y
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(world_position.x, y, world_position.z))


## World Y of the foundation bottom. [constant INF] when no ground is hit.
static func foundation_bottom_y(world: World3D, origin: Vector3, yaw: float, width: float, depth: float, mask: int, exclude: Array[RID] = []) -> float:
	if world == null:
		return INF
	var hx := (maxf(width, 2.0) + HouseMeshBuilder.FOUNDATION_PAD) * 0.5
	var hz := (maxf(depth, 2.0) + HouseMeshBuilder.FOUNDATION_PAD) * 0.5
	var basis := Basis(Vector3.UP, yaw)
	var lowest := INF
	var highest := -INF
	for u in [-1.0, 0.0, 1.0]:
		for v in [-1.0, 0.0, 1.0]:
			var point := origin + basis * Vector3(hx * u, 0.0, hz * v)
			var hit_y := _ray_y(world, point, mask, exclude)
			if hit_y == INF:
				continue
			lowest = minf(lowest, hit_y)
			highest = maxf(highest, hit_y)
	if lowest == INF:
		return INF
	# A slope would leave the bottom face grazing the terrain. Sink it slightly so the
	# downhill edge stays buried and the two surfaces do not flicker.
	if highest - lowest > 0.01:
		return lowest - 0.02
	return lowest


## World height of the scenery under [param world_point]. [constant INF] when nothing is hit.
static func ground_height(world: World3D, world_point: Vector3, mask: int, exclude: Array[RID] = []) -> float:
	if world == null:
		return INF
	return _ray_y(world, world_point, mask, exclude)


static func _ray_y(world: World3D, point: Vector3, mask: int, exclude: Array[RID]) -> float:
	var from := Vector3(point.x, point.y + 4000.0, point.z)
	var to := Vector3(point.x, point.y - 4000.0, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	if not exclude.is_empty():
		query.exclude = exclude
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return hit.position.y


static func _lod_instance(properties: HouseProperties, lod: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "LOD%d" % lod
	instance.mesh = build_mesh(properties, lod)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lod > 0:
		instance.visible = false
	return instance
