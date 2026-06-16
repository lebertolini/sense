shader_type spatial;
// Tablet do desafio. Fica preto no escuro como todo o resto.
// Quando uma onda o atinge ele brilha em AMARELO neon (mesma logica de fade
// das particulas). Quando o jogador o ativa (apertar de frente), passa a
// brilhar permanentemente em VERDE, independente das ondas.

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

uniform vec3 color_reveal : source_color = vec3(1.0, 0.82, 0.12); // amarelo neon
uniform vec3 color_active : source_color = vec3(0.25, 1.0, 0.75); // verde das particulas
uniform float reveal_brightness = 7.0;
uniform float active_brightness = 5.0;
uniform float min_reveal = 0.18; // brilho minimo enquanto a onda passa (corpo solido)
uniform float extra_life = 1.5;  // segundos a mais que o tablet fica aceso em amarelo
uniform bool activated = false;

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
	// Tablet segura o brilho amarelo por mais tempo que as superficies comuns.
	float life = wave_lifetime + d * wave_dist_lifetime + extra_life;
	float fade = clamp(1.0 - age / life, 0.0, 1.0);
	fade *= fade;
	return fade * cone;
}

void fragment() {
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	if (activated) {
		EMISSION = color_active * active_brightness;
	} else {
		float f = 0.0;
		f = max(f, wave_fade(wave_0, wave_dir_0.xyz, w_pos));
		f = max(f, wave_fade(wave_1, wave_dir_1.xyz, w_pos));
		f = max(f, wave_fade(wave_2, wave_dir_2.xyz, w_pos));
		f = max(f, wave_fade(wave_3, wave_dir_3.xyz, w_pos));
		f = max(f, wave_fade(wave_4, wave_dir_4.xyz, w_pos));
		f = max(f, wave_fade(wave_5, wave_dir_5.xyz, w_pos));
		// Enquanto a onda esta sobre o tablet ele brilha solido (corpo cheio),
		// nao so pontinhos, para ficar bem visivel como um alvo.
		float body = f > 0.001 ? mix(min_reveal, 1.0, f) : 0.0;
		EMISSION = color_reveal * reveal_brightness * body;
	}
}
