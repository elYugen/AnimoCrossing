shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Blocs voxel (couleurs de sommets sRGB) avec un motif « pixel art » de
// 16 x 16 par face, dessiné ici selon le type de bloc (UV.x) : grain de
// l'herbe, cailloux de la terre, taches de la pierre, lattes des planches,
// joints des briques, écorce et cernes du bois...
// Les blocs d'arbres (alpha de la couleur de sommet à 0) situés entre la
// caméra et le joueur sont effacés en tramé, pour que les arbres ne bloquent
// jamais la vue.
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 cam_pos = vec3(0.0);
uniform float cut_radius = 2.2;
uniform float roughness_value = 0.92;
// Force du motif (0 : couleurs unies).
uniform float texture_strength = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

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

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Facteur de luminosité du motif (autour de 1) pour un pixel `px` (0..15)
// d'une face du bloc `cell`. `top` : face du dessus ou du dessous.
float pattern(int id, vec2 px, vec3 cell, bool top) {
	float r = h3(vec3(px, 0.0) + cell * 17.0);
	float big = h3(vec3(floor(px / 4.0), 3.0) + cell * 11.0);
	float f = 1.0;
	if (id == 1) {  // herbe : brins plus clairs ou plus sombres
		f = 1.0 + (r - 0.5) * 0.16;
		if (r > 0.93) f *= 1.1;
		if (r < 0.05) f *= 0.88;
	} else if (id == 2) {  // terre : grain et petits cailloux
		f = 1.0 + (r - 0.5) * 0.16;
		if (r < 0.07) f *= 0.8;
		if (r > 0.96) f *= 1.12;
	} else if (id == 3 || id == 11) {  // pierre, basalte : taches et fissures
		f = 0.93 + big * 0.12 + (r - 0.5) * 0.08;
		float crack = abs(px.x + px.y * 0.5 - mod(cell.x * 5.0 + cell.z * 3.0, 16.0) - 4.0);
		if (crack < 0.6 && big > 0.5) f *= 0.8;
	} else if (id == 4) {  // sable : grain fin
		f = 1.0 + (r - 0.5) * 0.08;
		if (r > 0.97) f *= 0.86;
	} else if (id == 5 || id == 18) {  // rondin : cernes dessus, écorce sur les côtés
		if (top) {
			float d = length(px - vec2(7.5));
			f = 1.0 - 0.1 * step(0.5, fract(d / 2.6)) + (r - 0.5) * 0.05;
		} else {
			float stripe = h3(vec3(px.x, 7.0, 0.0) + cell * 5.0);
			f = 0.88 + stripe * 0.2 + (r - 0.5) * 0.06;
			if (id == 18 && mod(px.y, 5.0) < 1.0) f *= 0.85;
		}
	} else if (id == 6 || id == 12 || id == 13 || id == 14) {  // feuillages
		f = 1.0 + (r - 0.5) * 0.26;
		if (r < 0.1) f *= 0.72;
	} else if (id == 7) {  // planches : lattes de 4 pixels, joints décalés
		float row = floor(px.y / 4.0);
		if (top) row = floor(px.x / 4.0);
		float along = top ? px.y : px.x;
		float across = top ? px.x : px.y;
		f = 1.0 + (h3(vec3(row, 1.0, 0.0) + cell) - 0.5) * 0.12 + (r - 0.5) * 0.05;
		if (mod(across, 4.0) < 1.0) f *= 0.78;
		if (mod(along + row * 5.0, 16.0) < 1.0) f *= 0.82;
	} else if (id == 8) {  // briques : joints clairs, briques nuancées
		float row = floor(px.y / 4.0);
		float shift = mod(row, 2.0) * 4.0;
		float brick = floor((px.x + shift) / 8.0);
		f = 0.94 + h3(vec3(row, brick, 2.0) + cell) * 0.14 + (r - 0.5) * 0.05;
		if (mod(px.y, 4.0) < 1.0 || mod(px.x + shift, 8.0) < 1.0) f = 1.22;
	} else if (id == 9) {  // neige
		f = 1.0 + (r - 0.5) * 0.05;
	} else if (id == 10) {  // glace : reflets en diagonale
		f = 1.0 + (r - 0.5) * 0.04;
		if (abs(mod(px.x - px.y, 9.0)) < 1.0) f *= 1.1;
	} else if (id == 15) {  // terre cuite : rangs
		f = 1.0 + (r - 0.5) * 0.1;
		if (mod(px.y, 5.0) < 1.0) f *= 0.9;
	} else if (id == 16) {  // tissu : trame
		f = 1.0 + (mod(px.x + px.y, 2.0) - 0.5) * 0.06 + (r - 0.5) * 0.05;
	} else if (id == 17) {  // pierre moussue : taches de mousse
		f = 0.93 + big * 0.14 + (r - 0.5) * 0.1;
	} else if (id == 19) {  // déchets : très irréguliers
		f = 0.8 + r * 0.4;
	} else if (id == 20) {  // vase
		f = 0.85 + big * 0.2 + (r - 0.5) * 0.12;
	}
	return mix(1.0, f, texture_strength);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	vec3 base = srgb_to_linear(COLOR.rgb);
	int id = int(UV.x + 0.5);
	if (id > 0) {
		// Coordonnées sur la face (16 pixels par bloc) selon son orientation.
		vec3 n = world_normal;
		bool top = abs(n.y) > 0.5;
		vec2 face = top ? world_pos.xz : (abs(n.x) > 0.5 ? world_pos.zy : world_pos.xy);
		vec2 px = floor(fract(face) * 16.0);
		vec3 cell = floor(world_pos - n * 0.01);
		base *= pattern(id, px, cell, top);
	}
	ALBEDO = base;
	ROUGHNESS = roughness_value;
}
