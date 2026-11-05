@tool
class_name HouseMeshBuilder
extends RefCounted

## Builds one [ArrayMesh] from [HouseProperties].
##
## The mesh is centered on XZ with its base on Y = 0. Several surfaces share that
## mesh (walls, roof, trim, foundation, door, glass, chimney) so Terrain3D can
## instance it as a single MultiMesh. Geometry is assembled by [HouseBuildContext]
## from a style recipe composition and [HouseLodPolicy].

const WALL := 0
const ROOF := 1
const TRIM := 2
const FOUNDATION := 3
const DOOR := 4
const GLASS := 5
const CHIMNEY := 6
## Corrugated siding and roof. The surfaces stay named wall and roof.
const METAL := 7
const METAL_ROOF := 8
## Extra width of the foundation past the walls, on each axis.
const FOUNDATION_PAD := 0.08
## Longest gap between porch posts. Wider houses get more posts so the roof span stays short.
const PORCH_POST_SPAN := 2.4
## How far a catalog mesh continues below the origin. Steeper sites are rejected instead of buried.
const CATALOG_SKIRT := 1.5


static func build(properties: HouseProperties, lod: int = 0, post_bottoms: PackedFloat32Array = PackedFloat32Array(), catalog: bool = false) -> ArrayMesh:
	var ctx := HouseBuildContext.new()
	ctx.post_bottoms = post_bottoms
	ctx.catalog = catalog
	return ctx.run(properties, lod)


## Local post positions. X and Z are the post center; Y is the top, where it meets the porch roof.
static func porch_post_layout(properties: HouseProperties) -> PackedVector3Array:
	if properties == null or not properties.porch:
		return PackedVector3Array()
	var ctx := HouseBuildContext.new()
	ctx.props = properties
	ctx.composition = HouseRecipes.composition_for(properties.style)
	ctx._compute_dimensions()
	return ctx._porch_post_points()
