shader_type spatial;
render_mode unshaded, cull_disabled;

// Shader damier procédural pour le ClothBoardMesh
// Mode UNSHADED pour couleurs pures et nettes (anti-TV cathodique)

// Couleurs du plateau original, réduites à 70% pour moins de luminosité
uniform vec3 color_white : source_color = vec3(0.579, 0.579, 0.579); // 0.827 * 0.7
uniform vec3 color_grey : source_color = vec3(0.310, 0.310, 0.310);  // 0.443 * 0.7

void fragment() {
	// UV va de 0 à 1, on multiplie par 8 pour avoir 8 cases
	vec2 uv = UV * 8.0;
	
	// Calcul entier strict pour éviter le filtrage linéaire baveux
	int cx = int(floor(uv.x));
	int cy = int(floor(uv.y));
	
	// Parité (damier)
	bool is_white = (cx + cy) % 2 == 0;
	
	// Couleur directe sans lighting
	ALBEDO = is_white ? color_white : color_grey;
}
