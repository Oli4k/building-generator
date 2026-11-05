shader_type spatial;

// Tiles in a 4×3 atlas, one per mesh surface: wall, roof, trim, foundation, door, glass, chimney, metal, metal roof.
// UV repeats in meters (one tile is 4 m). UV2.x is the tile index.
uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D roughness_atlas : filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 3.0);

void fragment() {
	vec2 cell = vec2(mod(UV2.x, atlas_grid.x), floor(UV2.x / atlas_grid.x));
	vec2 uv = (cell + fract(UV)) / atlas_grid;
	// Gradients come from the repeating face UV, so a tile edge does not sample the neighbour.
	vec2 dx = dFdx(UV) / atlas_grid;
	vec2 dy = dFdy(UV) / atlas_grid;
	ALBEDO = textureGrad(albedo_atlas, uv, dx, dy).rgb * COLOR.rgb;
	ROUGHNESS = textureGrad(roughness_atlas, uv, dx, dy).a;
	float metallic = 0.0;
	if (UV2.x > 4.5 && UV2.x < 5.5)
		metallic = 0.62;
	else if (UV2.x > 6.5 && UV2.x < 8.5)
		metallic = 0.8;
	METALLIC = metallic;
}
