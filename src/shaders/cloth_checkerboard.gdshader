shader_type spatial;
render_mode unshaded, cull_disabled;

// Shader damier procédural pour le ClothBoardMesh
// Mode UNSHADED pour couleurs pures et nettes (anti-TV cathodique)

// Couleurs du plateau original, réduites à 70% pour moins de luminosité
uniform vec3 color_white : source_color = vec3(0.579, 0.579, 0.579); // 0.827 * 0.7
uniform vec3 color_grey : source_color = vec3(0.310, 0.310, 0.310);  // 0.443 * 0.7

// Texture de highlight (8x8 pixels, 1 pixel = 1 case)
// L'alpha détermine l'intensité du highlight
uniform sampler2D highlight_texture : filter_nearest;

void fragment() {
	// UV va de 0 à 1, on multiplie par 8 pour avoir 8 cases
	vec2 uv = UV * 8.0;
	
	// Calcul entier strict pour éviter le filtrage linéaire baveux
	int cx = int(floor(uv.x));
	int cy = int(floor(uv.y));
	
	// Parité (damier)
	bool is_white = (cx + cy) % 2 == 0;
	
	// Couleur de base
	vec3 base_color = is_white ? color_white : color_grey;
	
	// Lire le highlight depuis la texture (pixel au centre de la case)
	vec2 highlight_uv = (vec2(float(cx), float(cy)) + 0.5) / 8.0;
	vec4 highlight = texture(highlight_texture, highlight_uv);
	
	// Couleur finale : on remplace COMPLÈTEMENT la base si alpha > 0
	// Pas de mix() qui dilue la couleur avec le gris du plateau
	vec3 final_color = base_color;
	if (highlight.a > 0.01) {
		// Couleur saturée avec léger fond visible
		final_color = mix(base_color, highlight.rgb, highlight.a * 0.9);
	}
	
	// EMISSION forte pour que la couleur "brille" (Cyan reste Cyan, pas verdâtre)
	EMISSION = highlight.rgb * highlight.a * 0.6;
	
	ALBEDO = final_color;
}

