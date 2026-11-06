@tool
class_name HouseRecipes
extends RefCounted

## Style recipes fill [HouseProperties] from a [HouseProperties.Style] and seed.
## Mesh topology comes from [enum HouseBuildContext.Composition] via [method composition_for];
## recipes set dimensions, roof, facade opening profile, colors, and [member HouseProperties.church_plan].


static func composition_for(style: HouseProperties.Style) -> HouseBuildContext.Composition:
	match style:
		HouseProperties.Style.HANGAR, HouseProperties.Style.WAREHOUSE:
			return HouseBuildContext.Composition.INDUSTRIAL
		HouseProperties.Style.ALPINE:
			return HouseBuildContext.Composition.ALPINE
		HouseProperties.Style.CHURCH:
			return HouseBuildContext.Composition.CHURCH
		_:
			return HouseBuildContext.Composition.RESIDENTIAL


## Fills every exported field on [param props] from [param which], using [param seed_value]
## so the same pair always matches [method HouseProperties.randomize_from_style].
static func apply(props: HouseProperties, which: HouseProperties.Style, seed_value: int) -> void:
	props.style = which
	props.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_apply_common_defaults(props)
	match which:
		HouseProperties.Style.COTTAGE:
			_apply_cottage(props, rng)
		HouseProperties.Style.CABIN:
			_apply_cabin(props, rng)
		HouseProperties.Style.TOWNHOUSE:
			_apply_townhouse(props, rng)
		HouseProperties.Style.FARMHOUSE:
			_apply_farmhouse(props, rng)
		HouseProperties.Style.VILLA:
			_apply_villa(props, rng)
		HouseProperties.Style.SHED:
			_apply_shed(props, rng)
		HouseProperties.Style.CHALET:
			_apply_chalet(props, rng)
		HouseProperties.Style.CHURCH:
			_apply_church(props, rng, seed_value)
		HouseProperties.Style.SHOP:
			_apply_shop(props, rng)
		HouseProperties.Style.OFFICE:
			_apply_office(props, rng)
		HouseProperties.Style.HANGAR:
			_apply_hangar(props, rng, seed_value)
		HouseProperties.Style.WAREHOUSE:
			_apply_warehouse(props, rng, seed_value)
		HouseProperties.Style.ALPINE:
			_apply_alpine(props, rng)
		HouseProperties.Style.STATION:
			_apply_station(props, rng)
	_apply_sides(props)


static func _apply_common_defaults(props: HouseProperties) -> void:
	props.foundation_height = 0.32
	props.wall_thickness = 0.16
	props.door_width = 0.9
	props.door_height = 2.05
	props.window_columns = 0
	props.window_walls = HouseProperties.WINDOW_ALL
	props.slit_walls = 0
	props.facade_profile = HouseProperties.FacadeProfile.GRID
	props.roof_profile = HouseProperties.RoofProfile.SHELL
	props.catalog_column_cap = 2
	props.garage_width_fraction = 0.5
	props.garage_top_clearance = 0.55
	props.garage_max_height = 4.5
	props.door_side = HouseProperties.HouseSide.CENTER
	props.chimney_side = HouseProperties.HouseSide.RIGHT
	props.window_omit = 0.08
	props.window_width = 0.75
	props.window_height = 1.05
	props.window_pattern = HouseProperties.WindowPattern.UNIFORM
	props.window_variation = 0.0
	props.porch = false
	props.porch_profile = HouseProperties.PorchProfile.DECK
	props.porch_depth = 1.4
	props.annex = false
	props.chimney = false
	props.church_plan = 0
	props.frame_profile = HouseProperties.FrameProfile.SIMPLE
	props.frame_width = 0.065
	props.frame_depth = 0.055
	props.sill_depth = 0.06
	props.glass_color = Color("#7aa4b5")
	props.trim_color = Color("#f3efe6")
	props.foundation_color = Color("#6d675f")
	props.chimney_color = Color("#5c534c")


static func _apply_cottage(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = rng.randi_range(1, 2)
	props.width = rng.randf_range(6.0, 8.6)
	props.depth = rng.randf_range(5.0, 7.2)
	props.floor_height = rng.randf_range(2.5, 2.75)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.55, 0.85)
	props.roof_overhang = rng.randf_range(0.35, 0.55)
	props.chimney = rng.randf() > 0.2
	props.porch = rng.randf() > 0.45
	props.porch_depth = rng.randf_range(1.15, 1.6)
	props.window_omit = 0.12
	props.window_width = 0.66
	props.window_height = 1.25
	props.window_pattern = HouseProperties.WindowPattern.SMALLER_ABOVE
	props.window_variation = 0.75
	props.wall_color = _pick(rng, [Color("#e4d2b0"), Color("#efe6d6"), Color("#d9c4a4"), Color("#eadfce")])
	props.roof_color = _pick(rng, [Color("#8d4034"), Color("#6e3b32"), Color("#3e4650"), Color("#704533")])
	props.door_color = _pick(rng, [Color("#6b341f"), Color("#2f3d36"), Color("#4a2c22")])
	props.trim_color = Color("#f7f1e6")
	props.foundation_color = Color("#74685c")


static func _apply_cabin(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 1
	props.width = rng.randf_range(5.2, 8.0)
	props.depth = rng.randf_range(4.4, 6.6)
	props.floor_height = rng.randf_range(2.4, 2.65)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.6, 0.95)
	props.roof_overhang = rng.randf_range(0.4, 0.65)
	props.chimney = rng.randf() > 0.15
	props.porch = rng.randf() > 0.75
	props.porch_depth = 1.2
	props.window_columns = 2
	props.window_omit = 0.15
	props.window_width = 0.52
	props.window_height = 0.64
	props.window_pattern = HouseProperties.WindowPattern.ALTERNATING
	props.window_variation = 0.75
	props.wall_color = _pick(rng, [Color("#6b4630"), Color("#5c3a24"), Color("#7a5340"), Color("#4e3424")])
	props.roof_color = _pick(rng, [Color("#3a3f45"), Color("#2c3330"), Color("#4a4038")])
	props.door_color = Color("#2a211c")
	props.trim_color = Color("#cbb89a")
	props.foundation_color = Color("#5a554e")
	props.chimney_color = Color("#6a6258")


static func _apply_townhouse(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = rng.randi_range(2, 4)
	props.width = rng.randf_range(4.4, 6.2)
	props.depth = rng.randf_range(8.0, 12.0)
	props.floor_height = rng.randf_range(2.55, 2.85)
	props.roof_type = HouseProperties.RoofType.FLAT if rng.randf() > 0.35 else HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.45, 0.7)
	props.roof_overhang = 0.12 if props.roof_type == HouseProperties.RoofType.FLAT else 0.28
	props.chimney = props.roof_type != HouseProperties.RoofType.FLAT and rng.randf() > 0.55
	props.porch = false
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_width = 0.56
	props.window_height = 1.68
	props.wall_color = _pick(rng, [Color("#8d4a42"), Color("#c9c2b2"), Color("#d8d2c6"), Color("#7e403c"), Color("#b7b1a4")])
	props.roof_color = _pick(rng, [Color("#2c2c30"), Color("#3a3532"), Color("#4a342e")])
	props.door_color = _pick(rng, [Color("#1e2428"), Color("#5a2e24"), Color("#243028")])
	props.trim_color = Color("#f4f0e8")
	props.foundation_color = Color("#5e5a55")


static func _apply_farmhouse(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 2
	props.width = rng.randf_range(10.0, 15.5)
	props.depth = rng.randf_range(6.5, 9.0)
	props.floor_height = rng.randf_range(2.6, 2.9)
	props.roof_type = HouseProperties.RoofType.GAMBREL if rng.randf() > 0.45 else HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.55, 0.8)
	props.roof_overhang = rng.randf_range(0.4, 0.6)
	props.chimney = rng.randf() > 0.15
	props.porch = rng.randf() > 0.1
	props.porch_depth = rng.randf_range(1.6, 2.2)
	props.window_columns = 0
	props.window_omit = 0.05
	props.window_width = 1.18
	props.window_height = 0.98
	props.window_pattern = HouseProperties.WindowPattern.WIDE_CENTER
	props.window_variation = 0.6
	props.wall_color = _pick(rng, [Color("#f4efe6"), Color("#efe4d4"), Color("#f7f3ea"), Color("#e7d7c0")])
	props.roof_color = _pick(rng, [Color("#6e2e2a"), Color("#3f4650"), Color("#7a3a30")])
	props.door_color = Color("#5c2f22")
	props.trim_color = Color("#fbf7f0")
	props.foundation_color = Color("#6e6860")


static func _apply_villa(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 2
	props.width = rng.randf_range(12.0, 18.0)
	props.depth = rng.randf_range(8.0, 12.0)
	props.floor_height = rng.randf_range(2.9, 3.2)
	props.roof_type = HouseProperties.RoofType.HIP
	props.roof_pitch = rng.randf_range(0.35, 0.55)
	props.roof_overhang = rng.randf_range(0.45, 0.7)
	props.chimney = rng.randf() > 0.8
	props.porch = rng.randf() > 0.55
	props.porch_depth = rng.randf_range(1.4, 2.0)
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_width = 1.28
	props.window_height = 1.82
	props.window_pattern = HouseProperties.WindowPattern.SMALLER_ABOVE
	props.window_variation = 0.45
	props.wall_color = _pick(rng, [Color("#f6f1e7"), Color("#f3e6d4"), Color("#efeae2"), Color("#e7efe8")])
	props.roof_color = _pick(rng, [Color("#b85a3d"), Color("#a24b34"), Color("#8d4e3a")])
	props.door_color = _pick(rng, [Color("#6e3a28"), Color("#1f4d45"), Color("#243044")])
	props.trim_color = Color("#fffaf3")
	props.foundation_color = Color("#d9d1c4")


static func _apply_shed(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 1
	props.width = rng.randf_range(3.2, 5.4)
	props.depth = rng.randf_range(2.6, 4.2)
	props.floor_height = rng.randf_range(2.3, 2.55)
	props.roof_type = HouseProperties.RoofType.SHED
	props.roof_pitch = rng.randf_range(0.16, 0.32)
	props.roof_overhang = rng.randf_range(0.15, 0.28)
	props.chimney = false
	props.porch = false
	props.window_columns = 1
	props.window_omit = 0.0
	props.window_width = 0.46
	props.window_height = 0.5
	props.door_width = 0.82
	props.door_height = 1.9
	props.foundation_height = 0.12
	props.frame_width = 0.05
	props.frame_depth = 0.045
	props.wall_color = _pick(rng, [Color("#8d7b5e"), Color("#6f624c"), Color("#9a8668"), Color("#5e6a58")])
	props.roof_color = _pick(rng, [Color("#3e443c"), Color("#596068"), Color("#4a4038")])
	props.door_color = Color("#4a3428")
	props.trim_color = Color("#d2c4aa")
	props.foundation_color = Color("#5c574f")


static func _apply_chalet(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 2 if rng.randf() > 0.35 else 1
	props.width = rng.randf_range(8.0, 12.0)
	props.depth = rng.randf_range(6.0, 8.5)
	props.floor_height = rng.randf_range(2.55, 2.8)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.95, 1.2)
	props.roof_overhang = rng.randf_range(0.7, 1.0)
	props.foundation_height = rng.randf_range(0.65, 0.95)
	props.chimney = rng.randf() > 0.25
	props.porch = rng.randf() > 0.3
	props.porch_depth = rng.randf_range(1.4, 2.0)
	props.window_columns = 0
	props.window_omit = 0.08
	props.window_width = 1.32
	props.window_height = 0.78
	props.window_pattern = HouseProperties.WindowPattern.WIDER_ABOVE
	props.window_variation = 0.75
	props.wall_color = _pick(rng, [Color("#6a4a32"), Color("#5c4030"), Color("#7a5640"), Color("#4e3828")])
	props.roof_color = _pick(rng, [Color("#3a3f46"), Color("#2e3438"), Color("#4a4038")])
	props.door_color = Color("#3a2418")
	props.trim_color = Color("#d7c4a4")
	props.foundation_color = Color("#8a8680")
	props.chimney_color = Color("#6e6860")


static func _apply_church(props: HouseProperties, rng: RandomNumberGenerator, seed_value: int) -> void:
	# Seed picks the plan: 0 west tower and chancel, 1 the same plus a side aisle, 2 a tilted 1960s hall.
	var plan := posmod(seed_value, 3)
	props.church_plan = plan
	props.floors = 1
	props.chimney = false
	props.porch = false
	props.frame_profile = HouseProperties.FrameProfile.SILL
	props.foundation_height = rng.randf_range(0.18, 0.32)
	props.door_width = 1.15
	props.door_height = 2.35
	props.door_color = Color("#3a2a22")
	props.trim_color = Color("#f7f4ee")
	if plan == 2:
		props.width = rng.randf_range(13.5, 16.0)
		props.depth = rng.randf_range(9.0, 11.0)
		if props.depth > props.width - 0.8:
			props.depth = props.width - 0.8
		props.floor_height = rng.randf_range(3.15, 3.5)
		props.roof_type = HouseProperties.RoofType.SHED
		props.roof_pitch = rng.randf_range(0.58, 0.82)
		props.roof_overhang = rng.randf_range(0.9, 1.15)
		props.window_columns = 2
		props.window_walls = HouseProperties.WINDOW_ALL
		props.slit_walls = HouseProperties.WINDOW_BACK
		props.window_omit = 0.35
		props.window_width = 1.5
		props.window_height = 0.62
		props.wall_color = _pick(rng, [Color("#e4e0d8"), Color("#d4d0c8"), Color("#ece7df"), Color("#c8c4bc")])
		props.roof_color = _pick(rng, [Color("#8a4e32"), Color("#3e4448"), Color("#6e3d32")])
		props.foundation_color = Color("#b7b2aa")
		props.glass_color = Color("#c5d5d4")
		return
	if plan == 0:
		props.width = rng.randf_range(12.4, 14.6)
		props.depth = rng.randf_range(6.0, 7.0)
	else:
		props.width = rng.randf_range(9.6, 11.6)
		props.depth = rng.randf_range(6.6, 7.6)
	props.floor_height = rng.randf_range(3.6, 3.95)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(1.02, 1.25)
	props.roof_overhang = rng.randf_range(0.26, 0.4)
	props.window_columns = 3
	props.window_walls = HouseProperties.WINDOW_FRONT | HouseProperties.WINDOW_BACK
	props.window_omit = 0.1
	props.window_width = 0.4
	props.window_height = 2.1
	props.wall_color = _pick(rng, [Color("#e8e2d6"), Color("#f3efe6"), Color("#ddd6c8"), Color("#e4e0d8")])
	props.roof_color = _pick(rng, [Color("#3e4450"), Color("#4a4038"), Color("#2f343c")])
	props.foundation_color = Color("#8a8680")


static func _apply_shop(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 1 if rng.randf() > 0.5 else 2
	props.width = rng.randf_range(8.0, 12.0)
	props.depth = rng.randf_range(5.4, 7.6)
	props.floor_height = rng.randf_range(3.05, 3.35) if props.floors == 1 else rng.randf_range(2.75, 3.0)
	props.roof_type = HouseProperties.RoofType.FLAT if props.floors == 1 else HouseProperties.RoofType.GABLE
	props.roof_pitch = 0.35 if props.roof_type == HouseProperties.RoofType.GABLE else 0.2
	props.roof_overhang = 0.15 if props.roof_type == HouseProperties.RoofType.FLAT else 0.35
	props.foundation_height = 0.12
	props.chimney = false
	props.porch = false
	props.facade_profile = HouseProperties.FacadeProfile.SHOP_FRONT
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_width = 0.7
	props.window_height = 1.08
	props.window_pattern = HouseProperties.WindowPattern.SMALLER_ABOVE
	props.window_variation = 0.4
	props.door_width = 1.05
	props.door_height = 2.2
	props.wall_color = _pick(rng, [Color("#f0e6d4"), Color("#e7d3c0"), Color("#d5ddd2"), Color("#f4efe4")])
	props.roof_color = _pick(rng, [Color("#3a3532"), Color("#4a4038"), Color("#2c3338")])
	props.door_color = Color("#2a2420")
	props.trim_color = Color("#f7f3ea")
	props.foundation_color = Color("#6a6560")
	props.glass_color = Color("#9ec4d2")


static func _apply_office(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 4 if rng.randf() > 0.55 else 3
	props.width = rng.randf_range(12.0, 16.0)
	props.depth = rng.randf_range(8.0, 10.4)
	props.floor_height = rng.randf_range(3.0, 3.25)
	props.roof_type = HouseProperties.RoofType.FLAT
	props.roof_pitch = 0.2
	props.roof_overhang = 0.12
	props.foundation_height = 0.18
	props.chimney = false
	props.porch = false
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_width = 1.4
	props.window_height = 1.6
	props.catalog_column_cap = 99
	props.door_width = 1.2
	props.door_height = 2.3
	props.wall_color = _pick(rng, [Color("#d5d8dc"), Color("#c8c2b6"), Color("#e4e1da"), Color("#b7c0c6")])
	props.roof_color = Color("#2c3136")
	props.door_color = Color("#1e2428")
	props.trim_color = Color("#f4f1ea")
	props.foundation_color = Color("#5e6468")
	props.glass_color = Color("#8eb4c6")


static func _apply_hangar(props: HouseProperties, rng: RandomNumberGenerator, seed_value: int) -> void:
	props.floors = 1
	props.width = rng.randf_range(17.5, 21.0)
	props.depth = rng.randf_range(11.0, 13.5)
	props.floor_height = rng.randf_range(3.8, 4.05)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.16, 0.26)
	props.roof_overhang = rng.randf_range(0.5, 0.7)
	props.foundation_height = rng.randf_range(0.15, 0.25)
	props.chimney = false
	props.porch = false
	props.annex = _salted_unit(seed_value, 80) < 0.38
	props.facade_profile = HouseProperties.FacadeProfile.NONE
	props.roof_profile = HouseProperties.RoofProfile.SPAN
	props.frame_profile = HouseProperties.FrameProfile.NONE
	props.window_walls = 0
	props.window_omit = 0.0
	props.garage_width_fraction = 0.66
	props.garage_top_clearance = 0.55
	props.garage_max_height = 6.0
	_apply_metal_colors(props, rng)


static func _apply_warehouse(props: HouseProperties, rng: RandomNumberGenerator, seed_value: int) -> void:
	props.floors = 1
	props.width = rng.randf_range(16.5, 20.5)
	props.depth = rng.randf_range(10.5, 13.0)
	props.floor_height = rng.randf_range(5.7, 6.2)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.32, 0.46)
	props.roof_overhang = rng.randf_range(0.4, 0.55)
	props.foundation_height = rng.randf_range(0.18, 0.28)
	props.chimney = false
	props.porch = false
	props.annex = _salted_unit(seed_value, 80) < 0.72
	props.facade_profile = HouseProperties.FacadeProfile.NONE
	props.roof_profile = HouseProperties.RoofProfile.SPAN
	props.frame_profile = HouseProperties.FrameProfile.NONE
	props.window_walls = 0
	props.window_omit = 0.0
	props.garage_width_fraction = 0.40
	props.garage_top_clearance = 1.15
	props.garage_max_height = 4.5
	_apply_metal_colors(props, rng)


static func _apply_alpine(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 3 if rng.randf() > 0.55 else 2
	props.width = rng.randf_range(9.5, 13.5)
	props.depth = rng.randf_range(7.2, 9.0)
	props.floor_height = rng.randf_range(2.6, 2.85)
	props.roof_profile = HouseProperties.RoofProfile.CROSS
	props.roof_type = HouseProperties.RoofType.GABLE
	# Flachsatteldach: a shallow cross gable. Pitch is rise over run, about 17° to 23°.
	props.roof_pitch = rng.randf_range(0.30, 0.42)
	props.roof_overhang = rng.randf_range(1.15, 1.5)
	props.foundation_height = rng.randf_range(0.35, 0.55)
	props.chimney = rng.randf() > 0.2
	props.porch = false
	props.window_columns = 0
	props.window_omit = 0.05
	props.window_width = 1.22
	props.window_height = 0.78
	props.window_pattern = HouseProperties.WindowPattern.WIDER_ABOVE
	props.window_variation = 0.6
	props.wall_color = _pick(rng, [Color("#5c3a28"), Color("#4a3024"), Color("#6a4632"), Color("#3e2a20")])
	props.roof_color = _pick(rng, [Color("#2c3238"), Color("#3a332c"), Color("#243038")])
	props.door_color = Color("#3a2418")
	props.trim_color = Color("#d4c2a4")
	props.foundation_color = _pick(rng, [Color("#8e8a82"), Color("#7c7872"), Color("#9a948c")])
	props.chimney_color = Color("#6a6460")


static func _apply_station(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	props.floors = 1
	props.width = rng.randf_range(12.0, 16.0)
	props.depth = rng.randf_range(6.4, 8.0)
	props.floor_height = rng.randf_range(3.4, 3.7)
	props.roof_type = HouseProperties.RoofType.GABLE
	props.roof_pitch = rng.randf_range(0.42, 0.58)
	props.roof_overhang = rng.randf_range(0.4, 0.55)
	props.foundation_height = rng.randf_range(0.28, 0.42)
	props.chimney = false
	props.porch = true
	props.porch_profile = HouseProperties.PorchProfile.CANOPY
	props.porch_depth = rng.randf_range(2.3, 2.8)
	props.door_width = 1.05
	props.door_height = 2.2
	props.window_columns = 0
	props.window_omit = 0.0
	props.window_width = 0.78
	props.window_height = 1.62
	props.window_pattern = HouseProperties.WindowPattern.UNIFORM
	props.window_variation = 0.0
	props.catalog_column_cap = 99
	props.wall_color = _pick(rng, [Color("#8d4e46"), Color("#a36858"), Color("#c4b49a"), Color("#d9cbb8")])
	props.roof_color = _pick(rng, [Color("#6e322c"), Color("#4a3834"), Color("#3c4450")])
	props.door_color = Color("#3a2c24")
	props.trim_color = Color("#efe6d8")
	props.foundation_color = Color("#6e6a64")


static func _apply_metal_colors(props: HouseProperties, rng: RandomNumberGenerator) -> void:
	var schemes: Array[Dictionary] = [
		{"wall": Color("#6f736e"), "roof": Color("#4a4e50"), "trim": Color("#8e928c"), "door": Color("#262a2c")},
		{"wall": Color("#8b939a"), "roof": Color("#5c656c"), "trim": Color("#a8b0b6"), "door": Color("#2e3438")},
		{"wall": Color("#3a5670"), "roof": Color("#2c3844"), "trim": Color("#6d8aa3"), "door": Color("#1a2228")},
		{"wall": Color("#3c5648"), "roof": Color("#2a3330"), "trim": Color("#6a8578"), "door": Color("#1c2420")},
		{"wall": Color("#7c4538"), "roof": Color("#4a3834"), "trim": Color("#a56d5e"), "door": Color("#2a201c")},
		{"wall": Color("#3e4448"), "roof": Color("#2a2e32"), "trim": Color("#6a7074"), "door": Color("#16181a")},
		{"wall": Color("#7a5340"), "roof": Color("#3e3832"), "trim": Color("#a07860"), "door": Color("#2c221c")},
		{"wall": Color("#2a3c54"), "roof": Color("#3a444c"), "trim": Color("#5c7088"), "door": Color("#141820")},
	]
	var scheme: Dictionary = schemes[rng.randi_range(0, schemes.size() - 1)]
	props.wall_color = scheme.wall
	props.roof_color = scheme.roof
	props.trim_color = scheme.trim
	props.door_color = scheme.door
	props.foundation_color = Color("#5e5c58")
	props.glass_color = Color("#8eacb8")


static func _apply_sides(props: HouseProperties) -> void:
	props.chimney_side = HouseProperties.HouseSide.LEFT if _salted_unit(props.seed, 777) < 0.5 else HouseProperties.HouseSide.RIGHT
	if props.style == HouseProperties.Style.TOWNHOUSE:
		props.door_side = HouseProperties.HouseSide.LEFT if _salted_unit(props.seed, 41) < 0.5 else HouseProperties.HouseSide.RIGHT
	elif props.style == HouseProperties.Style.SHOP:
		props.door_side = HouseProperties.HouseSide.LEFT if _salted_unit(props.seed, 40) < 0.5 else HouseProperties.HouseSide.RIGHT
	else:
		props.door_side = HouseProperties.HouseSide.CENTER


static func _salted_unit(seed_value: int, salt: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + salt * 7919
	return rng.randf()


static func _pick(rng: RandomNumberGenerator, options: Array) -> Color:
	return options[rng.randi_range(0, options.size() - 1)]
