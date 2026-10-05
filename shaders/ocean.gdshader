shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Océan stylisé : couleur selon la profondeur + écume douce sur les rivages.
uniform vec4 shallow_color : source_color = vec4(0.44, 0.88, 0.85, 0.55);
uniform vec4 deep_color : source_color = vec4(0.18, 0.56, 0.82, 0.92);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_range = 3.5;
uniform float foam_width = 0.45;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.45 + TIME * 1.1) * 0.05 + cos(world_pos.z * 0.38 + TIME * 0.9) * 0.05;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = clamp(VERTEX.z - view.z, 0.0, 100.0);

	float t = clamp(water_depth / depth_range, 0.0, 1.0);
	vec4 col = mix(shallow_color, deep_color, t);

	// Écume animée en bandes douces (style cartoon).
	float wobble = sin(TIME * 1.6 + world_pos.x * 1.3 + world_pos.z * 0.9) * 0.08;
	float foam = 1.0 - smoothstep(foam_width * 0.6 + wobble, foam_width + wobble, water_depth);
	float stripe = step(0.5, fract(water_depth * 1.4 - TIME * 0.35)) * (1.0 - smoothstep(0.0, 1.6, water_depth)) * 0.35;
	foam = clamp(foam + stripe, 0.0, 1.0);

	// Petits reflets scintillants.
	vec2 g = floor(world_pos.xz * 1.5);
	float sparkle = step(0.985, fract(sin(dot(g, vec2(12.9898, 78.233)) + floor(TIME * 2.0)) * 43758.5453));

	ALBEDO = mix(col.rgb, foam_color.rgb, foam) + sparkle * 0.35;
	ALPHA = mix(col.a, 1.0, foam);
	ROUGHNESS = 0.12;
	SPECULAR = 0.45;
}
