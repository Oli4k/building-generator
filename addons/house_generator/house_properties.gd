@tool
class_name HouseProperties
extends Resource

## Dimensions, roof, openings, and colors for one house.
##
## [method randomize_from_style] fills these fields from a style and seed.
## After that, every field is explicit: the mesh does not hide extra randomness
## except which windows are skipped and a slight wall tint, which stay tied to [member seed].
## Width runs along local X. Depth runs along local Z. The front faces -Z, and the
## origin sits on the ground at the footprint center. On a slope, place that origin on the lowest ground under the foundation and leave the house upright.

enum Style {
	COTTAGE,
	CABIN,
	TOWNHOUSE,
	FARMHOUSE,
	VILLA,
	SHED,
	CHALET,
	CHURCH,
	SHOP,
	OFFICE,
}

enum RoofType {
	GABLE,
	HIP,
	FLAT,
	SHED,
	GAMBREL,
}

enum HouseSide {
	LEFT,
	CENTER,
	RIGHT,
}

## How the base window size is distributed. Panes stay on a shared head line.
enum WindowPattern {
	UNIFORM,
	SMALLER_ABOVE,
	WIDER_ABOVE,
	WIDE_CENTER,
	ALTERNATING,
	IRREGULAR,
}

## Bits for [member window_walls]. Front is the -Z face.
const WINDOW_FRONT := 1
const WINDOW_RIGHT := 2
const WINDOW_BACK := 4
const WINDOW_LEFT := 8
const WINDOW_ALL := WINDOW_FRONT | WINDOW_RIGHT | WINDOW_BACK | WINDOW_LEFT

@export_group("Preset")
@export var style: Style = Style.COTTAGE
## Which windows are skipped, and a slight wall tint. Dimensions stay as they are.
@export var seed: int = 1:
	set(value):
		if seed == value:
			return
		seed = value
		emit_changed()

@export_group("Structure")
## Front facade length, along local X.
@export_range(2.0, 30.0, 0.1, "suffix:m") var width: float = 7.0
## Side length, along local Z.
@export_range(2.0, 30.0, 0.1, "suffix:m") var depth: float = 6.0
@export_range(1, 5, 1) var floors: int = 1
@export_range(2.2, 4.0, 0.05, "suffix:m") var floor_height: float = 2.65
@export_range(0.0, 1.5, 0.05, "suffix:m") var foundation_height: float = 0.35
@export_range(0.08, 0.4, 0.01, "suffix:m") var wall_thickness: float = 0.16
@export var roof_type: RoofType = RoofType.GABLE
## Rise divided by run. Ignored for flat roofs.
@export_range(0.05, 1.4, 0.01) var roof_pitch: float = 0.65
@export_range(0.0, 1.2, 0.01, "suffix:m") var roof_overhang: float = 0.4
@export var chimney: bool = true
@export var chimney_side: HouseSide = HouseSide.RIGHT
@export var porch: bool = false
@export_range(0.8, 3.5, 0.05, "suffix:m") var porch_depth: float = 1.4

@export_group("Openings")
## Front, right, back, and left. The door stays on the front.
@export_flags("Front", "Right", "Back", "Left") var window_walls: int = WINDOW_ALL
@export var door_side: HouseSide = HouseSide.CENTER
## How many window columns to attempt. 0 fills the wall.
@export_range(0, 8, 1) var window_columns: int = 0
## Chance each candidate window is skipped. Placement is deterministic for [member seed].
@export_range(0.0, 0.85, 0.01) var window_omit: float = 0.05
@export_range(0.4, 1.8, 0.01, "suffix:m") var window_width: float = 0.75
@export_range(0.45, 2.2, 0.01, "suffix:m") var window_height: float = 1.05
## Base size is the largest pane. Upstairs, center, and alternating patterns step away from it.
@export var window_pattern: WindowPattern = WindowPattern.UNIFORM
## How far the pattern may depart from the base size. 0 keeps every window equal.
@export_range(0.0, 1.0, 0.01) var window_variation: float = 0.0
@export_range(0.6, 1.6, 0.01, "suffix:m") var door_width: float = 0.9
@export_range(1.6, 2.5, 0.01, "suffix:m") var door_height: float = 2.05

@export_group("Colors")
@export var wall_color: Color = Color("#e4d2b0")
@export var roof_color: Color = Color("#8d4034")
@export var trim_color: Color = Color("#f3efe6")
@export var door_color: Color = Color("#6b341f")
@export var foundation_color: Color = Color("#6d675f")
@export var glass_color: Color = Color("#7aa4b5")
@export var chimney_color: Color = Color("#5c534c")


func _init() -> void:
	resource_local_to_scene = true


static func make(which: Style, seed_value: int) -> HouseProperties:
	var props := HouseProperties.new()
	props.randomize_from_style(which, seed_value)
	return props


## Fills every exported field from the style, using [param seed_value] so the same pair always matches.
func randomize_from_style(which: Style, seed_value: int) -> void:
	set_block_signals(true)
	style = which
	seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_apply_common_defaults()
	match which:
		Style.COTTAGE:
			_apply_cottage(rng)
		Style.CABIN:
			_apply_cabin(rng)
		Style.TOWNHOUSE:
			_apply_townhouse(rng)
		Style.FARMHOUSE:
			_apply_farmhouse(rng)
		Style.VILLA:
			_apply_villa(rng)
		Style.SHED:
			_apply_shed(rng)
		Style.CHALET:
			_apply_chalet(rng)
		Style.CHURCH:
			_apply_church(rng)
		Style.SHOP:
			_apply_shop(rng)
		Style.OFFICE:
			_apply_office(rng)
	_apply_sides()
	set_block_signals(false)
	emit_changed()


func baked_name() -> String:
	return "%s_%d" % [_style_name(), seed]


func _style_name() -> String:
	return Style.keys()[style].to_lower()


func _apply_common_defaults() -> void:
	foundation_height = 0.32
	wall_thickness = 0.16
	door_width = 0.9
	door_height = 2.05
	window_columns = 0
	window_walls = WINDOW_ALL
	door_side = HouseSide.CENTER
	chimney_side = HouseSide.RIGHT
	window_omit = 0.08
	window_width = 0.75
	window_height = 1.05
	window_pattern = WindowPattern.UNIFORM
	window_variation = 0.0
	porch = false
	porch_depth = 1.4
	chimney = false
	glass_color = Color("#7aa4b5")
	trim_color = Color("#f3efe6")
	foundation_color = Color("#6d675f")
	chimney_color = Color("#5c534c")


func _apply_cottage(rng: RandomNumberGenerator) -> void:
	floors = rng.randi_range(1, 2)
	width = rng.randf_range(6.0, 8.6)
	depth = rng.randf_range(5.0, 7.2)
	floor_height = rng.randf_range(2.5, 2.75)
	roof_type = RoofType.GABLE
	roof_pitch = rng.randf_range(0.55, 0.85)
	roof_overhang = rng.randf_range(0.35, 0.55)
	chimney = rng.randf() > 0.2
	porch = rng.randf() > 0.45
	porch_depth = rng.randf_range(1.15, 1.6)
	window_omit = 0.12
	window_width = 0.66
	window_height = 1.25
	window_pattern = WindowPattern.SMALLER_ABOVE
	window_variation = 0.75
	wall_color = _pick(rng, [Color("#e4d2b0"), Color("#efe6d6"), Color("#d9c4a4"), Color("#eadfce")])
	roof_color = _pick(rng, [Color("#8d4034"), Color("#6e3b32"), Color("#3e4650"), Color("#704533")])
	door_color = _pick(rng, [Color("#6b341f"), Color("#2f3d36"), Color("#4a2c22")])
	trim_color = Color("#f7f1e6")
	foundation_color = Color("#74685c")


func _apply_cabin(rng: RandomNumberGenerator) -> void:
	floors = 1
	width = rng.randf_range(5.2, 8.0)
	depth = rng.randf_range(4.4, 6.6)
	floor_height = rng.randf_range(2.4, 2.65)
	roof_type = RoofType.GABLE
	roof_pitch = rng.randf_range(0.6, 0.95)
	roof_overhang = rng.randf_range(0.4, 0.65)
	chimney = rng.randf() > 0.15
	porch = rng.randf() > 0.75
	porch_depth = 1.2
	window_columns = 2
	window_omit = 0.15
	window_width = 0.52
	window_height = 0.64
	window_pattern = WindowPattern.ALTERNATING
	window_variation = 0.75
	wall_color = _pick(rng, [Color("#6b4630"), Color("#5c3a24"), Color("#7a5340"), Color("#4e3424")])
	roof_color = _pick(rng, [Color("#3a3f45"), Color("#2c3330"), Color("#4a4038")])
	door_color = Color("#2a211c")
	trim_color = Color("#cbb89a")
	foundation_color = Color("#5a554e")
	chimney_color = Color("#6a6258")


func _apply_townhouse(rng: RandomNumberGenerator) -> void:
	floors = rng.randi_range(2, 4)
	width = rng.randf_range(4.4, 6.2)
	depth = rng.randf_range(8.0, 12.0)
	floor_height = rng.randf_range(2.55, 2.85)
	roof_type = RoofType.FLAT if rng.randf() > 0.35 else RoofType.GABLE
	roof_pitch = rng.randf_range(0.45, 0.7)
	roof_overhang = 0.12 if roof_type == RoofType.FLAT else 0.28
	chimney = roof_type != RoofType.FLAT and rng.randf() > 0.55
	porch = false
	window_columns = 2
	window_omit = 0.0
	window_width = 0.56
	window_height = 1.68
	wall_color = _pick(rng, [Color("#8d4a42"), Color("#c9c2b2"), Color("#d8d2c6"), Color("#7e403c"), Color("#b7b1a4")])
	roof_color = _pick(rng, [Color("#2c2c30"), Color("#3a3532"), Color("#4a342e")])
	door_color = _pick(rng, [Color("#1e2428"), Color("#5a2e24"), Color("#243028")])
	trim_color = Color("#f4f0e8")
	foundation_color = Color("#5e5a55")


func _apply_farmhouse(rng: RandomNumberGenerator) -> void:
	floors = 2
	width = rng.randf_range(10.0, 15.5)
	depth = rng.randf_range(6.5, 9.0)
	floor_height = rng.randf_range(2.6, 2.9)
	roof_type = RoofType.GAMBREL if rng.randf() > 0.45 else RoofType.GABLE
	roof_pitch = rng.randf_range(0.55, 0.8)
	roof_overhang = rng.randf_range(0.4, 0.6)
	chimney = rng.randf() > 0.15
	porch = rng.randf() > 0.1
	porch_depth = rng.randf_range(1.6, 2.2)
	window_columns = 4
	window_omit = 0.05
	window_width = 1.18
	window_height = 0.98
	window_pattern = WindowPattern.WIDE_CENTER
	window_variation = 0.6
	wall_color = _pick(rng, [Color("#f4efe6"), Color("#efe4d4"), Color("#f7f3ea"), Color("#e7d7c0")])
	roof_color = _pick(rng, [Color("#6e2e2a"), Color("#3f4650"), Color("#7a3a30")])
	door_color = Color("#5c2f22")
	trim_color = Color("#fbf7f0")
	foundation_color = Color("#6e6860")


func _apply_villa(rng: RandomNumberGenerator) -> void:
	floors = 2
	width = rng.randf_range(12.0, 18.0)
	depth = rng.randf_range(8.0, 12.0)
	floor_height = rng.randf_range(2.9, 3.2)
	roof_type = RoofType.HIP
	roof_pitch = rng.randf_range(0.35, 0.55)
	roof_overhang = rng.randf_range(0.45, 0.7)
	chimney = rng.randf() > 0.8
	porch = rng.randf() > 0.55
	porch_depth = rng.randf_range(1.4, 2.0)
	window_columns = 4
	window_omit = 0.0
	window_width = 1.28
	window_height = 1.82
	window_pattern = WindowPattern.SMALLER_ABOVE
	window_variation = 0.45
	wall_color = _pick(rng, [Color("#f6f1e7"), Color("#f3e6d4"), Color("#efeae2"), Color("#e7efe8")])
	roof_color = _pick(rng, [Color("#b85a3d"), Color("#a24b34"), Color("#8d4e3a")])
	door_color = _pick(rng, [Color("#6e3a28"), Color("#1f4d45"), Color("#243044")])
	trim_color = Color("#fffaf3")
	foundation_color = Color("#d9d1c4")


func _apply_shed(rng: RandomNumberGenerator) -> void:
	floors = 1
	width = rng.randf_range(3.2, 5.4)
	depth = rng.randf_range(2.6, 4.2)
	floor_height = rng.randf_range(2.3, 2.55)
	roof_type = RoofType.SHED
	roof_pitch = rng.randf_range(0.16, 0.32)
	roof_overhang = rng.randf_range(0.15, 0.28)
	chimney = false
	porch = false
	window_columns = 1
	window_omit = 0.0
	window_width = 0.46
	window_height = 0.5
	door_width = 0.82
	door_height = 1.9
	foundation_height = 0.12
	wall_color = _pick(rng, [Color("#8d7b5e"), Color("#6f624c"), Color("#9a8668"), Color("#5e6a58")])
	roof_color = _pick(rng, [Color("#3e443c"), Color("#596068"), Color("#4a4038")])
	door_color = Color("#4a3428")
	trim_color = Color("#d2c4aa")
	foundation_color = Color("#5c574f")


func _apply_chalet(rng: RandomNumberGenerator) -> void:
	floors = 2 if rng.randf() > 0.35 else 1
	width = rng.randf_range(8.0, 12.0)
	depth = rng.randf_range(6.0, 8.5)
	floor_height = rng.randf_range(2.55, 2.8)
	roof_type = RoofType.GABLE
	roof_pitch = rng.randf_range(0.95, 1.2)
	roof_overhang = rng.randf_range(0.7, 1.0)
	foundation_height = rng.randf_range(0.65, 0.95)
	chimney = rng.randf() > 0.25
	porch = rng.randf() > 0.3
	porch_depth = rng.randf_range(1.4, 2.0)
	window_columns = 2
	window_omit = 0.08
	window_width = 1.32
	window_height = 0.78
	window_pattern = WindowPattern.WIDER_ABOVE
	window_variation = 0.75
	wall_color = _pick(rng, [Color("#6a4a32"), Color("#5c4030"), Color("#7a5640"), Color("#4e3828")])
	roof_color = _pick(rng, [Color("#3a3f46"), Color("#2e3438"), Color("#4a4038")])
	door_color = Color("#3a2418")
	trim_color = Color("#d7c4a4")
	foundation_color = Color("#8a8680")
	chimney_color = Color("#6e6860")


func _apply_church(rng: RandomNumberGenerator) -> void:
	# Seed picks the plan: 0 west tower and chancel, 1 the same plus a side aisle, 2 a tilted 1960s hall.
	var plan := posmod(seed, 3)
	floors = 1
	chimney = false
	porch = false
	foundation_height = rng.randf_range(0.18, 0.32)
	door_width = 1.15
	door_height = 2.35
	door_color = Color("#3a2a22")
	trim_color = Color("#f7f4ee")
	if plan == 2:
		width = rng.randf_range(13.5, 16.0)
		depth = rng.randf_range(9.0, 11.0)
		if depth > width - 0.8:
			depth = width - 0.8
		floor_height = rng.randf_range(3.15, 3.5)
		roof_type = RoofType.SHED
		roof_pitch = rng.randf_range(0.58, 0.82)
		roof_overhang = rng.randf_range(0.9, 1.15)
		window_columns = 2
		window_walls = WINDOW_ALL
		window_omit = 0.35
		window_width = 1.5
		window_height = 0.62
		wall_color = _pick(rng, [Color("#e4e0d8"), Color("#d4d0c8"), Color("#ece7df"), Color("#c8c4bc")])
		roof_color = _pick(rng, [Color("#8a4e32"), Color("#3e4448"), Color("#6e3d32")])
		foundation_color = Color("#b7b2aa")
		glass_color = Color("#c5d5d4")
		return
	if plan == 0:
		width = rng.randf_range(12.4, 14.6)
		depth = rng.randf_range(6.0, 7.0)
	else:
		width = rng.randf_range(9.6, 11.6)
		depth = rng.randf_range(6.6, 7.6)
	floor_height = rng.randf_range(3.6, 3.95)
	roof_type = RoofType.GABLE
	roof_pitch = rng.randf_range(1.02, 1.25)
	roof_overhang = rng.randf_range(0.26, 0.4)
	window_columns = 3
	window_walls = WINDOW_FRONT | WINDOW_BACK
	window_omit = 0.1
	window_width = 0.4
	window_height = 2.1
	wall_color = _pick(rng, [Color("#e8e2d6"), Color("#f3efe6"), Color("#ddd6c8"), Color("#e4e0d8")])
	roof_color = _pick(rng, [Color("#3e4450"), Color("#4a4038"), Color("#2f343c")])
	foundation_color = Color("#8a8680")


func _apply_shop(rng: RandomNumberGenerator) -> void:
	floors = 1 if rng.randf() > 0.5 else 2
	width = rng.randf_range(8.0, 12.0)
	depth = rng.randf_range(5.4, 7.6)
	floor_height = rng.randf_range(3.05, 3.35) if floors == 1 else rng.randf_range(2.75, 3.0)
	roof_type = RoofType.FLAT if floors == 1 else RoofType.GABLE
	roof_pitch = 0.35 if roof_type == RoofType.GABLE else 0.2
	roof_overhang = 0.15 if roof_type == RoofType.FLAT else 0.35
	foundation_height = 0.12
	chimney = false
	porch = false
	window_columns = 2
	window_omit = 0.0
	window_width = 0.7
	window_height = 1.08
	window_pattern = WindowPattern.SMALLER_ABOVE
	window_variation = 0.4
	door_width = 1.05
	door_height = 2.2
	wall_color = _pick(rng, [Color("#f0e6d4"), Color("#e7d3c0"), Color("#d5ddd2"), Color("#f4efe4")])
	roof_color = _pick(rng, [Color("#3a3532"), Color("#4a4038"), Color("#2c3338")])
	door_color = Color("#2a2420")
	trim_color = Color("#f7f3ea")
	foundation_color = Color("#6a6560")
	glass_color = Color("#9ec4d2")


func _apply_office(rng: RandomNumberGenerator) -> void:
	floors = 4 if rng.randf() > 0.55 else 3
	width = rng.randf_range(12.0, 16.0)
	depth = rng.randf_range(8.0, 10.4)
	floor_height = rng.randf_range(3.0, 3.25)
	roof_type = RoofType.FLAT
	roof_pitch = 0.2
	roof_overhang = 0.12
	foundation_height = 0.18
	chimney = false
	porch = false
	window_columns = 4
	window_omit = 0.0
	window_width = 1.4
	window_height = 1.6
	door_width = 1.2
	door_height = 2.3
	wall_color = _pick(rng, [Color("#d5d8dc"), Color("#c8c2b6"), Color("#e4e1da"), Color("#b7c0c6")])
	roof_color = Color("#2c3136")
	door_color = Color("#1e2428")
	trim_color = Color("#f4f1ea")
	foundation_color = Color("#5e6468")
	glass_color = Color("#8eb4c6")


func _apply_sides() -> void:
	chimney_side = HouseSide.LEFT if _salted_unit(seed, 777) < 0.5 else HouseSide.RIGHT
	if style == Style.TOWNHOUSE:
		door_side = HouseSide.LEFT if _salted_unit(seed, 41) < 0.5 else HouseSide.RIGHT
	elif style == Style.SHOP:
		door_side = HouseSide.LEFT if _salted_unit(seed, 40) < 0.5 else HouseSide.RIGHT
	else:
		door_side = HouseSide.CENTER


static func _salted_unit(seed_value: int, salt: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + salt * 7919
	return rng.randf()


func _pick(rng: RandomNumberGenerator, options: Array) -> Color:
	return options[rng.randi_range(0, options.size() - 1)]
