@tool
class_name HouseSurface
extends RefCounted

## Shared plaster, tile, stone, and corrugated-metal grain for every house.
##
## Editor surfaces each sample their own tile. Catalog meshes share one material
## and pick a layer with UV2, so Terrain3D can still tint from the vertex color.

const TILE_PX := 128
const LAYER_COUNT := 9
const _LAYER_REVISION := 4
const CATALOG_FOLDER := "res://house_catalog"
const _WALL := 0
const _ROOF := 1
const _TRIM := 2
const _FOUNDATION := 3
const _DOOR := 4
const _GLASS := 5
const _CHIMNEY := 6
const _METAL := 7
const _METAL_ROOF := 8

static var _albedo_layers: Array[Image] = []
static var _roughness_layers: Array[Image] = []
static var _normal_layers: Array[Image] = []
static var _albedo_tiles: Array[Texture2D] = []
static var _roughness_tiles: Array[Texture2D] = []
static var _normal_tiles: Array[Texture2D] = []
static var _catalog_material: ShaderMaterial
static var _layer_revision := 0


static func editor_material(surface: int, color: Color, glass: bool) -> StandardMaterial3D:
	_ensure_layers()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = _albedo_tiles[surface]
	mat.roughness = 1.0
	mat.roughness_texture = _roughness_tiles[surface]
	mat.vertex_color_use_as_albedo = true
	if glass:
		mat.metallic = 0.62
		mat.roughness = 0.08
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		mat.normal_enabled = true
		mat.normal_texture = _normal_tiles[surface]
		if surface == _METAL or surface == _METAL_ROOF:
			mat.metallic = 0.8
			mat.normal_scale = 1.15
		elif surface == _ROOF or surface == _FOUNDATION or surface == _CHIMNEY:
			mat.normal_scale = 1.0
		else:
			mat.normal_scale = 0.7
	return mat


static func catalog_material() -> ShaderMaterial:
	if _catalog_material != null:
		return _catalog_material
	var folder := CATALOG_FOLDER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://addons/house_generator/house_surface.gdshader")
	var shader_path := folder.path_join("house_surface.tres")
	ResourceSaver.save(shader, shader_path)
	var albedo := ImageTexture.create_from_image(_pack(_albedo_images()))
	var roughness := ImageTexture.create_from_image(_pack(_roughness_images()))
	var normal := ImageTexture.create_from_image(_pack(_normal_images()))
	var albedo_path := folder.path_join("house_albedo.tres")
	var roughness_path := folder.path_join("house_roughness.tres")
	var normal_path := folder.path_join("house_normal.tres")
	ResourceSaver.save(albedo, albedo_path)
	ResourceSaver.save(roughness, roughness_path)
	ResourceSaver.save(normal, normal_path)
	# These paths were saved as texture arrays. The editor reloads a changed
	# file into that old type, which rejects the image.
	_remove_file(folder.path_join("surface_albedo.tres"))
	_remove_file(folder.path_join("surface_roughness.tres"))
	_remove_file(folder.path_join("surface_normal.tres"))
	var mat := ShaderMaterial.new()
	mat.shader = ResourceLoader.load(shader_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	mat.set_shader_parameter("albedo_atlas", ResourceLoader.load(albedo_path, "", ResourceLoader.CACHE_MODE_REPLACE))
	mat.set_shader_parameter("roughness_atlas", ResourceLoader.load(roughness_path, "", ResourceLoader.CACHE_MODE_REPLACE))
	mat.set_shader_parameter("normal_atlas", ResourceLoader.load(normal_path, "", ResourceLoader.CACHE_MODE_REPLACE))
	mat.set_shader_parameter("atlas_grid", Vector2(4, 3))
	var mat_path := folder.path_join("house_material.tres")
	ResourceSaver.save(mat, mat_path)
	_catalog_material = ResourceLoader.load(mat_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	return _catalog_material


static func _ensure_layers() -> void:
	# A script reload keeps these static arrays. The old seven tiles would then
	# miss the corrugated metal layers.
	if (
		_albedo_tiles.size() == LAYER_COUNT
		and _roughness_tiles.size() == LAYER_COUNT
		and _normal_tiles.size() == LAYER_COUNT
		and _layer_revision == _LAYER_REVISION
	):
		return
	_albedo_layers.clear()
	_roughness_layers.clear()
	_normal_layers.clear()
	_albedo_tiles.clear()
	_roughness_tiles.clear()
	_normal_tiles.clear()
	_catalog_material = null
	_layer_revision = _LAYER_REVISION
	var albedo := _albedo_images()
	var roughness := _roughness_images()
	var normal := _normal_images()
	for image in albedo:
		image.generate_mipmaps()
		_albedo_tiles.append(ImageTexture.create_from_image(image))
	for image in roughness:
		image.generate_mipmaps()
		_roughness_tiles.append(ImageTexture.create_from_image(image))
	for image in normal:
		image.generate_mipmaps()
		_normal_tiles.append(ImageTexture.create_from_image(image))


static func _albedo_images() -> Array[Image]:
	if _albedo_layers.size() != LAYER_COUNT:
		_build_layers()
	return _albedo_layers


static func _roughness_images() -> Array[Image]:
	if _roughness_layers.size() != LAYER_COUNT:
		_build_layers()
	return _roughness_layers


static func _normal_images() -> Array[Image]:
	if _normal_layers.size() != LAYER_COUNT:
		_build_layers()
	return _normal_layers


static func _pack(layers: Array[Image]) -> Image:
	var image := Image.create(TILE_PX * 4, TILE_PX * 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	for i in layers.size():
		var base := _copy_image(layers[i])
		var col := i % 4
		var row := int(i / 4.0)
		image.blit_rect(base, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(col * TILE_PX, row * TILE_PX))
	image.generate_mipmaps()
	return image


static func _remove_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


static func _copy_image(source: Image) -> Image:
	var copy := Image.create(source.get_width(), source.get_height(), false, source.get_format())
	copy.blit_rect(source, Rect2i(0, 0, source.get_width(), source.get_height()), Vector2i.ZERO)
	return copy


static func _build_layers() -> void:
	_albedo_layers.clear()
	_roughness_layers.clear()
	_normal_layers.clear()
	for surface in LAYER_COUNT:
		var albedo := Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
		var roughness := Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
		var heights: PackedFloat32Array = PackedFloat32Array()
		heights.resize(TILE_PX * TILE_PX)
		for y in TILE_PX:
			for x in TILE_PX:
				var grain := _grain(surface, x, y)
				var rough := _rough(surface, x, y)
				albedo.set_pixel(x, y, Color(grain, grain, grain, 1.0))
				roughness.set_pixel(x, y, Color(1.0, 1.0, 1.0, rough))
				heights[y * TILE_PX + x] = _height(surface, x, y)
		_albedo_layers.append(albedo)
		_roughness_layers.append(roughness)
		_normal_layers.append(_normal_from_heights(heights, _normal_strength(surface)))


static func _normal_strength(surface: int) -> float:
	match surface:
		_ROOF, _METAL, _METAL_ROOF:
			return 2.4
		_FOUNDATION, _CHIMNEY, _DOOR:
			return 1.8
		_WALL, _TRIM:
			return 1.1
		_:
			return 0.0


static func _normal_from_heights(heights: PackedFloat32Array, strength: float) -> Image:
	var image := Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
	if strength <= 0.001:
		image.fill(Color(0.5, 0.5, 1.0, 1.0))
		return image
	for y in TILE_PX:
		for x in TILE_PX:
			var h_l := heights[y * TILE_PX + posmod(x - 1, TILE_PX)]
			var h_r := heights[y * TILE_PX + posmod(x + 1, TILE_PX)]
			var h_d := heights[posmod(y - 1, TILE_PX) * TILE_PX + x]
			var h_u := heights[posmod(y + 1, TILE_PX) * TILE_PX + x]
			var dx := (h_l - h_r) * strength
			var dy := (h_d - h_u) * strength
			var n := Vector3(dx, dy, 1.0).normalized()
			image.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return image


static func _height(surface: int, x: int, y: int) -> float:
	var fine := _noise(x, y, 8, surface * 41 + 7)
	var broad := _noise(x, y, 4, surface * 41 + 19)
	match surface:
		_ROOF:
			return 0.28 if y % 8 == 0 else 0.72 + fine * 0.06
		_FOUNDATION:
			return 0.32 if _block_mortar(x, y, 32) else 0.78 + broad * 0.08
		_DOOR:
			return 0.38 if x % 8 == 0 else 0.72 + fine * 0.05
		_GLASS:
			return 0.5
		_CHIMNEY:
			return 0.3 if _brick_mortar(x, y) else 0.76 + fine * 0.05
		_TRIM:
			return 0.55 + fine * 0.08
		_WALL:
			return 0.5 + broad * 0.12 + fine * 0.06
		_METAL, _METAL_ROOF:
			return 0.22 if x % 6 == 0 else 0.78 + fine * 0.04
	return 0.5


static func _grain(surface: int, x: int, y: int) -> float:
	var fine := _noise(x, y, 8, surface * 17 + 3)
	var broad := _noise(x, y, 4, surface * 17 + 11)
	match surface:
		_ROOF:
			var mortar := 0.74 if y % 8 == 0 else 1.0
			return (0.9 + fine * 0.08) * mortar
		_FOUNDATION:
			return (0.78 if _block_mortar(x, y, 32) else 0.94 + broad * 0.05)
		_DOOR:
			var streak := 0.9 if x % 8 == 0 else 1.0
			return (0.9 + fine * 0.06) * streak
		_GLASS:
			# Soft sky falloff + diagonal sheen so panes read as reflective glass.
			var u := (float(x) + 0.5) / float(TILE_PX)
			var v := (float(y) + 0.5) / float(TILE_PX)
			var sky := lerpf(1.0, 0.58, v)
			var sheen := exp(-pow((u * 0.75 + v - 0.95) / 0.22, 2.0)) * 0.48
			var rim := exp(-pow((u - 0.18) / 0.55, 2.0)) * exp(-pow((v - 0.22) / 0.4, 2.0)) * 0.16
			return clampf(sky * 0.78 + sheen + rim + fine * 0.02, 0.48, 1.0)
		_CHIMNEY:
			return 0.76 if _brick_mortar(x, y) else 0.92 + fine * 0.06
		_TRIM:
			return 0.94 + fine * 0.05
		_WALL:
			return 0.84 + broad * 0.12 + fine * 0.05
		_METAL, _METAL_ROOF:
			var rib := 0.62 if x % 6 == 0 else 1.0
			return (0.78 + fine * 0.05) * rib
	return 0.9


static func _rough(surface: int, x: int, y: int) -> float:
	var fine := _noise(x, y, 8, surface * 29 + 5)
	match surface:
		_ROOF:
			return 0.8 if y % 8 == 0 else 0.72 + fine * 0.05
		_FOUNDATION:
			return 0.98
		_TRIM:
			return 0.68 + fine * 0.04
		_DOOR:
			return 0.46 + fine * 0.06
		_GLASS:
			var u := (float(x) + 0.5) / float(TILE_PX)
			var v := (float(y) + 0.5) / float(TILE_PX)
			var sheen := exp(-pow((u * 0.75 + v - 0.95) / 0.22, 2.0))
			return lerpf(0.16, 0.03, sheen) + fine * 0.015
		_CHIMNEY:
			return 0.9
		_METAL, _METAL_ROOF:
			return 0.58 if x % 6 == 0 else 0.42 + fine * 0.04
		_:
			return 0.9 + fine * 0.03


static func _block_mortar(x: int, y: int, cell: int) -> bool:
	var row := int(y / float(cell))
	var shift := cell / 2 if row % 2 == 1 else 0
	var bx := (x + shift) % cell
	var by := y % cell
	return bx < 2 or by < 2


static func _brick_mortar(x: int, y: int) -> bool:
	return _block_mortar(x, y, 16) or y % 8 < 1


static func _noise(x: int, y: int, cells: int, seed: int) -> float:
	var u := (float(x) + 0.5) / float(TILE_PX) * float(cells)
	var v := (float(y) + 0.5) / float(TILE_PX) * float(cells)
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx := _fade(u - float(x0))
	var fy := _fade(v - float(y0))
	var a := _hash_unit(x0, y0, seed, cells)
	var b := _hash_unit(x0 + 1, y0, seed, cells)
	var c := _hash_unit(x0, y0 + 1, seed, cells)
	var d := _hash_unit(x0 + 1, y0 + 1, seed, cells)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _fade(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _hash_unit(x: int, y: int, seed: int, period: int) -> float:
	var ix := posmod(x, period)
	var iy := posmod(y, period)
	var n := ix * 73856093 ^ iy * 19349663 ^ seed * 83492791
	n = (n ^ (n >> 13)) * 1274126177
	return float(posmod(n, 100000)) / 99999.0
