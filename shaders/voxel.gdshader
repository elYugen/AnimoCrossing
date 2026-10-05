shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Blocs voxel (couleurs de sommets sRGB). Les blocs d'arbres (alpha de la
// couleur de sommet à 0) situés entre la caméra et le joueur sont effacés en
// tramé, pour que les arbres ne bloquent jamais la vue.
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 cam_pos = vec3(0.0);
uniform float cut_radius = 2.2;
uniform float roughness_value = 0.92;

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Tramage ordonné 4x4 pour un fondu « voxel » doux.
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_player = player_pos + vec3(0.0, 0.7, 0.0) - cam_pos;
	float d_player = length(to_player);
	if (COLOR.a < 0.5 && d_player > 0.01 && world_pos.y > player_pos.y - 0.2) {
		vec3 dir = to_player / d_player;
		vec3 rel = world_pos - cam_pos;
		float t = dot(rel, dir);
		if (t > 0.0 && t < d_player - 0.6) {
			float perp = length(rel - dir * t);
			// Rayon qui s'élargit vers le joueur (cône).
			float r = cut_radius * clamp(t / d_player + 0.35, 0.0, 1.0);
			float fade = 1.0 - smoothstep(r * 0.55, r, perp);
			if (fade > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
