shader_type spatial;
// Abbath, a criatura. Fica preta no escuro como tudo o mais. Quando uma onda
// passa por ela, AO CONTRARIO dos demais objetos, ela NAO acende o corpo
// inteiro: so a LATERAL (a silhueta/contorno em relacao a camera) e marcada,
// nunca o centro. Isso da o efeito de um vulto humanoide so delineado pelas
// bordas, como na referencia.

// Mesmos globals do sonar (declarados em [shader_globals] no project.godot).
global uniform vec4 wave_0;
global uniform vec4 wave_1;
global uniform vec4 wave_2;
global uniform vec4 wave_3;
global uniform vec4 wave_4;
global uniform vec4 wave_5;

global uniform vec4 wave_dir_0;
global uniform vec4 wave_dir_1;
global uniform vec4 wave_dir_2;
global uniform vec4 wave_dir_3;
global uniform vec4 wave_dir_4;
global uniform vec4 wave_dir_5;

global uniform float wave_speed;
global uniform float wave_lifetime;
global uniform float wave_dist_lifetime;
global uniform float wave_max_dist;
global uniform float wave_cone;

uniform vec3 edge_color : source_color = vec3(0.85, 0.90, 1.0); // contorno branco espectral
uniform float edge_brightness = 2.8;
uniform float body_fill = 0.0;       // centro totalmente apagado (so a lateral acende)
uniform float rim_power = 8.0;       // o quao concentrada nas bordas fica a marca
uniform float rim_threshold = 0.85;  // so o contorno mais extremo acende (queixo, relevos internos NAO)
uniform float preview_reveal = 0.0;  // usado pelo --abbathmodeltest, sem onda/game

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Fade da contribuicao de uma onda neste fragmento (0..1), mesma logica do sonar.
float wave_fade(vec4 w, vec3 dir, vec3 wp) {
	float elapsed = w.w;
	if (elapsed < 0.0) {
		return 0.0;
	}
	vec3 to_frag = wp - w.xyz;
	float d = length(to_frag);
	if (d > wave_max_dist) {
		return 0.0;
	}
	float facing = dot(to_frag / max(d, 0.0001), dir);
	float cone = smoothstep(wave_cone, wave_cone + 0.12, facing);
	if (cone <= 0.0) {
		return 0.0;
	}
	float radius = elapsed * wave_speed;
	if (radius < d) {
		return 0.0;
	}
	float age = (radius - d) / wave_speed;
	float life = wave_lifetime + d * wave_dist_lifetime;
	float fade = clamp(1.0 - age / life, 0.0, 1.0);
	fade *= fade;
	return fade * cone;
}

void fragment() {
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	float f = 0.0;
	f = max(f, wave_fade(wave_0, wave_dir_0.xyz, w_pos));
	f = max(f, wave_fade(wave_1, wave_dir_1.xyz, w_pos));
	f = max(f, wave_fade(wave_2, wave_dir_2.xyz, w_pos));
	f = max(f, wave_fade(wave_3, wave_dir_3.xyz, w_pos));
	f = max(f, wave_fade(wave_4, wave_dir_4.xyz, w_pos));
	f = max(f, wave_fade(wave_5, wave_dir_5.xyz, w_pos));

	// Lateral = silhueta em relacao a camera. NORMAL e VIEW vem em view-space.
	// No centro (normal apontando pra camera) ndv ~ 1 => rim ~ 0 => nao marca.
	// Nas bordas (normal perpendicular ao olhar) ndv ~ 0 => rim alto => marca.
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - ndv, rim_power);
	rim = smoothstep(rim_threshold, 1.0, rim);

	float reveal = max(f, preview_reveal);
	EMISSION = edge_color * edge_brightness * reveal * max(rim, body_fill);
}
