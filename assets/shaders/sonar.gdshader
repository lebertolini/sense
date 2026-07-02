shader_type spatial;
// Material de "sonar": tudo fica preto até uma onda passar.
// Onde a onda toca, surgem pontos neon que vao sumindo com o tempo.
// Pontos atingidos primeiro (mais perto da origem) somem antes.

// Ondas ativas (xyz = origem no mundo, w = tempo decorrido desde a emissao).
// w < 0 => onda inativa. Atualizadas pelo autoload WaveManager.
global uniform vec4 wave_0;
global uniform vec4 wave_1;
global uniform vec4 wave_2;
global uniform vec4 wave_3;
global uniform vec4 wave_4;
global uniform vec4 wave_5;

// Direcao para onde cada onda se propaga (xyz normalizado). A onda so atinge
// fragmentos a frente dessa direcao.
global uniform vec4 wave_dir_0;
global uniform vec4 wave_dir_1;
global uniform vec4 wave_dir_2;
global uniform vec4 wave_dir_3;
global uniform vec4 wave_dir_4;
global uniform vec4 wave_dir_5;

global uniform float wave_speed;          // unidades/seg
global uniform float wave_lifetime;       // vida base de um ponto (seg)
global uniform float wave_dist_lifetime;  // vida extra por unidade de distancia
global uniform float wave_max_dist;       // alcance maximo da onda
global uniform float wave_cone;           // cos do semi-angulo do cone frontal

uniform vec3 color_near : source_color = vec3(0.25, 1.0, 0.75);
uniform vec3 color_far : source_color = vec3(0.55, 0.30, 1.0);
uniform float density = 2.4;       // frequencia dos pontos
uniform float sparsity = 0.55;     // maior = menos pontos
uniform float edge_width = 2.2;    // espessura da frente de onda
uniform float brightness = 6.0;    // brilho dos pontos
uniform float edge_brightness = 11.0; // brilho da frente de onda

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Padrao de pontos espalhados (duas oitavas) baseado na posicao no mundo.
float dot_mask(vec3 wp) {
	float n1 = hash13(floor(wp * density));
	float m1 = smoothstep(sparsity, 1.0, n1);
	float n2 = hash13(floor(wp * density * 2.0) + vec3(7.0));
	float m2 = smoothstep(0.75, 1.0, n2);
	return clamp(m1 + m2 * 0.7, 0.0, 1.0);
}

// Retorna (corpo, frente) da contribuicao de uma onda neste fragmento.
vec2 wave_contrib(vec4 w, vec3 dir, vec3 wp) {
	float elapsed = w.w;
	if (elapsed < 0.0) {
		return vec2(0.0);
	}
	vec3 to_frag = wp - w.xyz;
	float d = length(to_frag);
	if (d > wave_max_dist) {
		return vec2(0.0);
	}
	// Cone frontal: so atinge superficies a frente da direcao da onda.
	float facing = dot(to_frag / max(d, 0.0001), dir);
	float cone = smoothstep(wave_cone, wave_cone + 0.12, facing);
	if (cone <= 0.0) {
		return vec2(0.0);
	}
	float radius = elapsed * wave_speed;
	if (radius < d) {
		return vec2(0.0); // a frente ainda nao chegou aqui
	}
	float age = (radius - d) / wave_speed;          // tempo desde que foi atingido
	float life = wave_lifetime + d * wave_dist_lifetime; // perto = vida menor
	float fade = clamp(1.0 - age / life, 0.0, 1.0);
	fade *= fade;
	fade *= cone;
	float edge = smoothstep(edge_width, 0.0, abs(radius - d)) * fade;
	return vec2(fade, edge);
}

void fragment() {
	vec3 wp = w_pos;
	vec2 acc = vec2(0.0);
	acc += wave_contrib(wave_0, wave_dir_0.xyz, wp);
	acc += wave_contrib(wave_1, wave_dir_1.xyz, wp);
	acc += wave_contrib(wave_2, wave_dir_2.xyz, wp);
	acc += wave_contrib(wave_3, wave_dir_3.xyz, wp);
	acc += wave_contrib(wave_4, wave_dir_4.xyz, wp);
	acc += wave_contrib(wave_5, wave_dir_5.xyz, wp);

	float body = acc.x;
	float edge = acc.y;

	float dm = dot_mask(wp);
	float t = clamp(distance(wp, wave_0.xyz) / wave_max_dist, 0.0, 1.0);
	vec3 col = mix(color_near, color_far, t);

	float intensity = body * dm * brightness + edge * edge_brightness;

	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = col * intensity;
}
