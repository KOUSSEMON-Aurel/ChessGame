shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Losange lumineux ChessFX (◇ 45°)
// Bords brillants, intérieur vide, couleur selon emoji

uniform vec3 highlight_color : source_color = vec3(0, 0.8, 1); // Cyan par défaut
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	// UV centré (-0.5 à 0.5)
	vec2 uv = UV - 0.5;
	
	// Distance Manhattan (losange parfait)
	float dist = abs(uv.x) + abs(uv.y);
	
	// Bords lumineux avec glow
	// Zone de bord : entre 0.40 et 0.5 (extérieur)
	float outer_edge = smoothstep(0.38, 0.42, dist);    // Fade-in extérieur
	float inner_edge = 1.0 - smoothstep(0.46, 0.5, dist); // Fade-out intérieur
	
	float edge_mask = outer_edge * inner_edge;
	
	// Glow additionnel au centre du bord
	float glow = exp(-pow((dist - 0.44) * 20.0, 2.0)) * 0.5;
	
	// Combiner
	float final_intensity = (edge_mask + glow) * glow_intensity;
	
	ALBEDO = highlight_color;
	ALPHA = final_intensity * fade;
	
	// Emission pour renforcer la luminosité
	EMISSION = highlight_color * final_intensity * fade;
}
