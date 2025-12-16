shader_type spatial;
render_mode unshaded, cull_disabled;

// Shader damier procédural pour le ClothBoardMesh
// Mode UNSHADED pour couleurs pures et nettes (anti-TV cathodique)

// Couleurs du plateau original (Board.tscn)
uniform vec3 color_white : source_color = vec3(0.827451, 0.827451, 0.827451);
uniform vec3 color_grey : source_color = vec3(0.443137, 0.443137, 0.443137);

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
