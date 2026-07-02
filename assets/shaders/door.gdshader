shader_type spatial;
// Porta de saida. Fica preta no escuro como tudo. Quando uma onda passa, a
// superficie inteira brilha em ciano (igual revelacao do sonar) e, dali em
// diante, SO A MOLDURA continua acesa permanentemente (a "amostra" da porta).
// Quando o jogador a abre (apertar E de frente), o MIOLO acende em verde neon.

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

uniform vec3 color_frame : source_color = vec3(0.45, 0.85, 1.0);  // ciano da moldura
uniform vec3 color_open : source_color = vec3(0.05, 1.0, 0.30);   // verde neon do miolo
// Brilhos contidos: superficies grandes saturam pra branco com o glow HDR se
// forem muito fortes, entao a porta usa valores menores que os tablets.
uniform float frame_brightness = 3.2;
uniform float reveal_brightness = 3.6;
uniform float open_brightness = 2.2;
uniform float half_w = 0.7;        // metade da largura da porta (local x)
uniform float half_h = 1.3;        // metade da altura da porta (local y)
uniform float border = 0.16;       // espessura da moldura
uniform bool revealed = false;     // onda ja passou: moldura fica acesa de vez
uniform bool opened = false;       // jogador abriu: miolo verde

varying vec3 w_pos;
varying vec3 l_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	l_pos = VERTEX;
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

	// Distancia ate a borda mais proxima na face frontal (x-y locais).
	float edge_x = half_w - abs(l_pos.x);
	float edge_y = half_h - abs(l_pos.y);
	bool is_frame = (edge_x < border) || (edge_y < border);

	// Revelacao transiente pela onda (vale para a porta toda).
	float f = 0.0;
	f = max(f, wave_fade(wave_0, wave_dir_0.xyz, w_pos));
	f = max(f, wave_fade(wave_1, wave_dir_1.xyz, w_pos));
	f = max(f, wave_fade(wave_2, wave_dir_2.xyz, w_pos));
	f = max(f, wave_fade(wave_3, wave_dir_3.xyz, w_pos));
	f = max(f, wave_fade(wave_4, wave_dir_4.xyz, w_pos));
	f = max(f, wave_fade(wave_5, wave_dir_5.xyz, w_pos));

	vec3 em = vec3(0.0);

	if (is_frame) {
		// Moldura: brilha com a onda e, se ja foi revelada, fica acesa de vez.
		float base = revealed ? 1.0 : 0.0;
		float g = max(base, f);
		em = color_frame * frame_brightness * g;
	} else {
		// Miolo: verde neon quando aberta; senao so a revelacao transiente.
		if (opened) {
			em = color_open * open_brightness;
		} else {
			em = color_frame * reveal_brightness * f;
		}
	}

	EMISSION = em;
}
