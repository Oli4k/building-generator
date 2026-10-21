@tool
class_name HouseCatalog
extends RefCounted

## Bakes a small house catalog for Terrain3D and fits rectangular OSM footprints to it.
##
## Each variant is an external mesh per LOD plus a thin scene, with no house script,
## so another project can load it without this addon. Townhouses and villas stay
## out of the catalog. A church, shop, or office is used only when the OSM tag asks
## for one. Everything that is not a near-rectangle stays on the extruded OSM mesh.

const FOLDER := "res://house_catalog"
const FIT_ERROR := 0.22
const MAX_WIDTH := 22.0
const MAX_DEPTH := 16.0
const MAX_AREA := 250.0
const MIN_WIDTH := 3.0
const MIN_DEPTH := 2.4

const VARIANTS: Array[Dictionary] = [
	{"name": "cabin_a", "style": HouseProperties.Style.CABIN, "seed": 2},
	{"name": "cabin_b", "style": HouseProperties.Style.CABIN, "seed": 11},
	{"name": "cottage_a", "style": HouseProperties.Style.COTTAGE, "seed": 4},
	{"name": "cottage_b", "style": HouseProperties.Style.COTTAGE, "seed": 9},
	{"name": "cottage_c", "style": HouseProperties.Style.COTTAGE, "seed": 15},
	{"name": "farmhouse_a", "style": HouseProperties.Style.FARMHOUSE, "seed": 7},
	{"name": "farmhouse_b", "style": HouseProperties.Style.FARMHOUSE, "seed": 15},
	{"name": "shed_a", "style": HouseProperties.Style.SHED, "seed": 2},
	{"name": "shed_b", "style": HouseProperties.Style.SHED, "seed": 8},
	{"name": "chalet_a", "style": HouseProperties.Style.CHALET, "seed": 5},
	{"name": "chalet_b", "style": HouseProperties.Style.CHALET, "seed": 12},
	{"name": "church_a", "style": HouseProperties.Style.CHURCH, "seed": 12},
	{"name": "church_b", "style": HouseProperties.Style.CHURCH, "seed": 13},
	{"name": "church_c", "style": HouseProperties.Style.CHURCH, "seed": 14},
	{"name": "shop_a", "style": HouseProperties.Style.SHOP, "seed": 6},
	{"name": "shop_b", "style": HouseProperties.Style.SHOP, "seed": 15},
	{"name": "office_a", "style": HouseProperties.Style.OFFICE, "seed": 17},
	{"name": "office_b", "style": HouseProperties.Style.OFFICE, "seed": 6},
]

const _SKIP_KINDS: PackedStringArray = [
	"terrace", "apartments", "commercial", "industrial", "warehouse", "hangar",
	"stadium", "hotel", "public", "school", "hospital", "train_station", "civic",
	"college", "university", "parking", "garages",
]

const _ROLE_KINDS := {
	"church": "church",
	"chapel": "church",
	"office": "office",
	"retail": "shop",
	"shop": "shop",
	"kiosk": "shop",
	"supermarket": "shop",
}


static func variants() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for spec in VARIANTS:
		var props := _properties(spec)
		entries.append({
			"name": spec.name,
			"scene": "%s/%s.tscn" % [FOLDER, spec.name],
			"style": HouseProperties.Style.keys()[int(spec.style)].to_lower(),
			"seed": int(spec.seed),
			"width": props.width,
			"depth": props.depth,
			"foundation_height": props.foundation_height,
			"porch_depth": props.porch_depth if props.porch else 0.0,
			"wall_color": props.wall_color.to_html(false),
			"roof_color": props.roof_color.to_html(false),
		})
	return entries


## Writes external LOD meshes, thin scenes, and catalog.json. The scenes have no script.
static func save_catalog(folder: String = FOLDER) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var houses: Array = []
	for spec in VARIANTS:
		var props := _properties(spec)
		var root := Node3D.new()
		root.name = spec.name
		for level in 3:
			var mesh := HouseGenerator.build_mesh(props, level, PackedFloat32Array(), true)
			var mesh_path := "%s/%s_lod%d.res" % [folder, spec.name, level]
			var mesh_error := ResourceSaver.save(mesh, mesh_path)
			if mesh_error != OK:
				root.free()
				return mesh_error
			var instance := MeshInstance3D.new()
			instance.name = "LOD%d" % level
			instance.mesh = load(mesh_path)
			instance.visible = level == 0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(instance)
			instance.owner = root
		var packed := PackedScene.new()
		var pack_error := packed.pack(root)
		if pack_error != OK:
			root.free()
			return pack_error
		var scene_path := "%s/%s.tscn" % [folder, spec.name]
		var scene_error := ResourceSaver.save(packed, scene_path)
		root.free()
		if scene_error != OK:
			return scene_error
		var record := {
			"name": spec.name,
			"scene": scene_path,
			"style": HouseProperties.Style.keys()[int(spec.style)].to_lower(),
			"seed": int(spec.seed),
			"width": props.width,
			"depth": props.depth,
			"foundation_height": props.foundation_height,
			"porch_depth": props.porch_depth if props.porch else 0.0,
			"wall_color": props.wall_color.to_html(false),
			"roof_color": props.roof_color.to_html(false),
		}
		houses.append(record)
	var catalog := {
		"skirt_m": HouseMeshBuilder.CATALOG_SKIRT,
		"houses": houses,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(folder.path_join("catalog.json")), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(catalog, "\t"))
	return OK


## Fits one OSM footprint to the catalog.
##
## Returns width, depth, yaw, and the closest variant, or [code]ok: false[/code] with a reason.
## Yaw follows the long edge. The front of the chosen house stays on local -Z.
## The mesh is not stretched to the footprint. A heightmap rejects a slope that would
## bury the uphill floor or drop the downhill side past the foundation skirt.
static func fit_footprint(
	points: PackedVector2Array,
	tags: Dictionary = {},
	catalog: Array = [],
	heightmap: Image = null,
	height_origin: Vector2 = Vector2.ZERO,
	spacing_m: float = 1.0,
) -> Dictionary:
	var kind := str(tags.get("building", "")).to_lower()
	if _SKIP_KINDS.has(kind):
		return _no("not_house")
	if tags.has("building:part"):
		var part := str(tags["building:part"]).to_lower()
		if part != "" and part != "no":
			return _no("building_part")
	var ring := _ring(points)
	if ring.size() < 4:
		return _no("too_few_points")
	var measured := _measure(ring)
	if measured.hull_area > 0.01 and measured.area / measured.hull_area < 0.85:
		return _no("courtyard")
	if measured.width * measured.depth < 0.01 or measured.area / (measured.width * measured.depth) < 0.82 or measured.inset > 1.25:
		return _no("not_rectangular")
	if measured.width > MAX_WIDTH or measured.depth > MAX_DEPTH or measured.area > MAX_AREA:
		return _no("too_large")
	if measured.width < MIN_WIDTH or measured.depth < MIN_DEPTH:
		return _no("too_small")
	var entries: Array = catalog if not catalog.is_empty() else _entries_for(tags, variants())
	var best: Dictionary = {}
	var best_error := INF
	for entry in entries:
		var err := _fit_error(measured.width, measured.depth, float(entry.width), float(entry.depth))
		if err < best_error:
			best_error = err
			best = entry
	if best.is_empty() or best_error > FIT_ERROR:
		return _no("no_variant")
	var result := {
		"ok": true,
		"name": str(best.name),
		"scene": str(best.scene),
		"width": measured.width,
		"depth": measured.depth,
		"yaw": measured.yaw,
		"center": measured.center,
		"variant_width": float(best.width),
		"variant_depth": float(best.depth),
	}
	if heightmap == null:
		return result
	var foundation := float(best.get("foundation_height", HouseMeshBuilder.CATALOG_SKIRT))
	var ground := ground_on_heightmap(heightmap, measured.center, measured.yaw, float(best.width), float(best.depth), height_origin, spacing_m, foundation)
	if not ground.ok:
		return ground
	var porch := float(best.get("porch_depth", 0.0))
	if porch > 0.05:
		var porch_min := _sample_porch(heightmap, measured.center, measured.yaw, float(best.width), float(best.depth), porch, height_origin, spacing_m)
		if float(ground.min) - porch_min > HouseMeshBuilder.CATALOG_SKIRT:
			return _no("slope")
	result["y"] = ground.y
	result["relief"] = ground.relief
	result["position"] = Vector3(measured.center.x, ground.y, measured.center.y)
	return result


## Samples a height image the way scenery generation does and keeps the house upright.
##
## [param rise_limit] is the variant foundation height. A larger change would put the
## uphill ground above the floor, so the caller should keep the extruded OSM mesh.
static func ground_on_heightmap(
	image: Image,
	center: Vector2,
	yaw: float,
	width: float,
	depth: float,
	height_origin: Vector2,
	spacing_m: float,
	rise_limit: float = HouseMeshBuilder.CATALOG_SKIRT,
) -> Dictionary:
	if image == null or spacing_m <= 0.0:
		return _no("heightmap")
	var samples := _sample_rect(image, center, yaw, width, depth, height_origin, spacing_m)
	var relief := float(samples.max) - float(samples.min)
	if relief > rise_limit:
		return _no("slope")
	var y := float(samples.min)
	if relief > 0.01:
		y -= 0.02
	return {"ok": true, "y": y, "relief": relief, "min": samples.min, "max": samples.max}


## Bilinear sample of the red channel. Pixel (0, 0) is [param] world [code]height_origin[/code].
static func sample_height(image: Image, x: float, y: float) -> float:
	x = clampf(x, 0.0, image.get_width() - 1)
	y = clampf(y, 0.0, image.get_height() - 1)
	var ix := int(x)
	var iy := int(y)
	var tx := x - ix
	var ty := y - iy
	var x1 := mini(ix + 1, image.get_width() - 1)
	var y1 := mini(iy + 1, image.get_height() - 1)
	return lerpf(lerpf(image.get_pixel(ix, iy).r, image.get_pixel(x1, iy).r, tx), lerpf(image.get_pixel(ix, y1).r, image.get_pixel(x1, y1).r, tx), ty)


static func _properties(spec: Dictionary) -> HouseProperties:
	var props := HouseProperties.make(spec.style, int(spec.seed))
	if props.depth > props.width:
		var swap := props.width
		props.width = props.depth
		props.depth = swap
	return props


static func _sample_rect(image: Image, center: Vector2, yaw: float, width: float, depth: float, height_origin: Vector2, spacing_m: float) -> Dictionary:
	var basis := Basis(Vector3.UP, yaw)
	var lo := INF
	var hi := -INF
	for ix in 3:
		for iz in 3:
			var local := Vector3(lerpf(-width * 0.5, width * 0.5, ix / 2.0), 0.0, lerpf(-depth * 0.5, depth * 0.5, iz / 2.0))
			var world := Vector3(center.x, 0.0, center.y) + basis * local
			var height := sample_height(image, (world.x - height_origin.x) / spacing_m, (world.z - height_origin.y) / spacing_m)
			lo = minf(lo, height)
			hi = maxf(hi, height)
	return {"min": lo, "max": hi}


static func _sample_porch(image: Image, center: Vector2, yaw: float, width: float, depth: float, porch: float, height_origin: Vector2, spacing_m: float) -> float:
	var basis := Basis(Vector3.UP, yaw)
	var lo := INF
	for ix in 3:
		var local := Vector3(lerpf(-width * 0.5, width * 0.5, ix / 2.0), 0.0, -depth * 0.5 - porch)
		var world := Vector3(center.x, 0.0, center.y) + basis * local
		lo = minf(lo, sample_height(image, (world.x - height_origin.x) / spacing_m, (world.z - height_origin.y) / spacing_m))
	return lo


static func _entries_for(tags: Dictionary, entries: Array) -> Array:
	var kind := str(tags.get("building", "")).to_lower()
	var role := str(_ROLE_KINDS.get(kind, ""))
	if role == "" and str(tags.get("shop", "")) != "":
		role = "shop"
	var filtered: Array = []
	for entry in entries:
		var style := str(entry.get("style", ""))
		var civic := style == "church" or style == "shop" or style == "office"
		if role == "":
			if not civic:
				filtered.append(entry)
		elif style == role:
			filtered.append(entry)
	return filtered


static func _fit_error(foot_w: float, foot_d: float, var_w: float, var_d: float) -> float:
	return maxf(absf(var_w - foot_w) / maxf(foot_w, 0.01), absf(var_d - foot_d) / maxf(foot_d, 0.01))


static func _ring(points: PackedVector2Array) -> PackedVector2Array:
	var ring := points.duplicate()
	if ring.size() >= 2 and ring[0].distance_to(ring[ring.size() - 1]) < 0.05:
		ring.remove_at(ring.size() - 1)
	return ring


static func _measure(ring: PackedVector2Array) -> Dictionary:
	var edge := _longest_edge(ring)
	var axis_x := edge.normalized()
	var yaw := atan2(-axis_x.y, axis_x.x)
	var basis := Basis(Vector3.UP, yaw)
	var axis_z := Vector2(basis.z.x, basis.z.z)
	var origin := ring[0]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for point in ring:
		var delta := point - origin
		var x := delta.dot(axis_x)
		var z := delta.dot(axis_z)
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
		min_z = minf(min_z, z)
		max_z = maxf(max_z, z)
	var inset := 0.0
	for point in ring:
		var delta := point - origin
		var x := delta.dot(axis_x)
		var z := delta.dot(axis_z)
		var inside_x := minf(x - min_x, max_x - x)
		var inside_z := minf(z - min_z, max_z - z)
		if inside_x >= 0.0 and inside_z >= 0.0:
			inset = maxf(inset, minf(inside_x, inside_z))
	var mid := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	return {
		"width": max_x - min_x,
		"depth": max_z - min_z,
		"yaw": yaw,
		"center": origin + axis_x * mid.x + axis_z * mid.y,
		"area": absf(_polygon_area(ring)),
		"hull_area": absf(_polygon_area(Geometry2D.convex_hull(ring))),
		"inset": inset,
	}


static func _longest_edge(ring: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var best_len := -1.0
	for i in ring.size():
		var edge: Vector2 = ring[(i + 1) % ring.size()] - ring[i]
		if edge.length() > best_len:
			best_len = edge.length()
			best = edge
	return best if best_len > 0.01 else Vector2.RIGHT


static func _polygon_area(ring: PackedVector2Array) -> float:
	var sum := 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
