@tool
class_name HouseLodPolicy
extends RefCounted

## Which building features appear at each LOD.

var lod: int = 0
## Station keeps a canopy silhouette at LOD2.
var keep_porch_far: bool = false


static func for_build(lod: int, props: HouseProperties) -> HouseLodPolicy:
	var policy := HouseLodPolicy.new()
	policy.lod = clampi(lod, 0, 2)
	policy.keep_porch_far = props != null and props.style == HouseProperties.Style.STATION
	return policy


func wall_mode() -> int:
	if lod >= 2:
		return HouseBuildContext.WallMode.SHELL
	if lod == 0:
		return HouseBuildContext.WallMode.DETAILED
	return HouseBuildContext.WallMode.SOLID


func openings() -> bool:
	return lod == 0


func foundation() -> bool:
	return lod < 2


func porch() -> bool:
	return keep_porch_far or lod < 2


func porch_posts_and_deck() -> bool:
	return lod == 0


func alpine_balcony() -> bool:
	return lod < 2


func alpine_balcony_rails() -> bool:
	return lod == 0


func step() -> bool:
	return lod == 0


func chimney() -> bool:
	return lod < 2


func chimney_cap() -> bool:
	return lod == 0


func flat_roof_trim() -> bool:
	return lod == 0


func church_aisle() -> bool:
	return lod < 2


func church_cross_boxes() -> bool:
	return lod < 2


func wall_inner_faces() -> bool:
	return lod < 2


func roof_thickness() -> bool:
	return lod < 2
