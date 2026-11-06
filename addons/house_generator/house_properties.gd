@tool
class_name HouseProperties
extends Resource

## Dimensions, roof, openings, and colors for one house.
##
## [method randomize_from_style] fills these fields from a [HouseRecipes] style table and seed.
## After that, every field is explicit: the mesh does not hide extra randomness
## except which windows are skipped and a slight wall tint, which stay tied to [member seed].
## Mesh topology follows [method HouseRecipes.composition_for], not the style name alone.
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
	HANGAR,
	WAREHOUSE,
	ALPINE,
	STATION,
}

enum RoofType {
	GABLE,
	HIP,
	FLAT,
	SHED,
	GAMBREL,
}

## How the main roof is built. SHELL uses [member roof_type]; CROSS / SPAN are topologies.
enum RoofProfile {
	SHELL,
	CROSS,
	SPAN,
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

## How [HouseOpeningLayout] places openings on a wall. Set by the style recipe.
enum FacadeProfile {
	GRID,
	SHOP_FRONT,
	NONE,
}

## Front porch / platform canopy. Used when [member porch] is true.
enum PorchProfile {
	DECK,
	CANOPY,
}

## Bits for [member window_walls] and [member slit_walls]. Front is the -Z face.
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
## Church massing plan from the style recipe. 0 west tower, 1 aisle, 2 1960s hall. Ignored for other styles.
@export_range(0, 2, 1) var church_plan: int = 0

@export_group("Structure")
## Front facade length, along local X.
@export_range(2.0, 30.0, 0.1, "suffix:m") var width: float = 7.0
## Side length, along local Z.
@export_range(2.0, 30.0, 0.1, "suffix:m") var depth: float = 6.0
@export_range(1, 5, 1) var floors: int = 1
@export_range(2.2, 6.5, 0.05, "suffix:m") var floor_height: float = 2.65
@export_range(0.0, 1.5, 0.05, "suffix:m") var foundation_height: float = 0.35
@export_range(0.08, 0.4, 0.01, "suffix:m") var wall_thickness: float = 0.16
## SHELL dispatches on [member roof_type]. CROSS and SPAN use dedicated elements.
@export var roof_profile: RoofProfile = RoofProfile.SHELL
@export var roof_type: RoofType = RoofType.GABLE
## Rise divided by run. Ignored for flat roofs.
@export_range(0.05, 1.4, 0.01) var roof_pitch: float = 0.65
@export_range(0.0, 2.4, 0.01, "suffix:m") var roof_overhang: float = 0.4
@export var chimney: bool = true
@export var chimney_side: HouseSide = HouseSide.RIGHT
@export var porch: bool = false
## DECK has a floor and posts; CANOPY is an eave-hung platform roof (keeps silhouette far).
@export var porch_profile: PorchProfile = PorchProfile.DECK
@export_range(0.8, 3.5, 0.05, "suffix:m") var porch_depth: float = 1.4
## Lower entry unit in the front corner, with a person door and one window. Hangars and warehouses use it.
@export var annex: bool = false

@export_group("Openings")
## Front, right, back, and left. The door stays on the front.
@export_flags("Front", "Right", "Back", "Left") var window_walls: int = WINDOW_ALL
## Walls that use a tall slit row instead of the grid (e.g. modern church back wall).
@export_flags("Front", "Right", "Back", "Left") var slit_walls: int = 0
@export var facade_profile: FacadeProfile = FacadeProfile.GRID
@export var door_side: HouseSide = HouseSide.CENTER
## Window columns. 0 fills each wall at a fixed bay pitch; a positive value caps the count.
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
## Max window columns when baking a catalog mesh. Office/station recipes raise this.
@export_range(1, 99, 1) var catalog_column_cap: int = 2
## Hangar/warehouse hall door width as a fraction of the hall front.
@export_range(0.2, 0.9, 0.01) var garage_width_fraction: float = 0.5
## Clearance from the hall door head up to the wall plate.
@export_range(0.3, 1.5, 0.01, "suffix:m") var garage_top_clearance: float = 0.55
## Hard cap on hangar/warehouse door height.
@export_range(2.5, 6.0, 0.05, "suffix:m") var garage_max_height: float = 4.5

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
	HouseRecipes.apply(self, which, seed_value)
	set_block_signals(false)
	emit_changed()


func baked_name() -> String:
	return "%s_%d" % [_style_name(), seed]


func _style_name() -> String:
	return Style.keys()[style].to_lower()

