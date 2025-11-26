shader_type spatial; // Type de shader pour la 3D

uniform vec4 dark_color : source_color = vec4(0.3, 0.4, 0.3, 1.0); // Vert foncé
uniform vec4 light_color : source_color = vec4(0.85, 0.85, 0.85, 1.0); // Gris clair
uniform vec2 board_size = vec2(8.0, 8.0); // 8 colonnes x 8 lignes

void fragment() {
    // Utiliser les coordonnées UV du mesh (0 à 1)
    vec2 uv = UV * board_size;
    
    // Déterminer la cellule (case) en utilisant floor()
    vec2 cell_coords = floor(uv);
    
    // La magie du damier : la somme des coordonnées x et z modulo 2
    float checker = mod(cell_coords.x + cell_coords.y, 2.0);
    
    // Attribution des couleurs
    if (checker == 0.0) {
        ALBEDO = dark_color.rgb;
    } else {
        ALBEDO = light_color.rgb;
    }
    
    // Pour que le damier soit visible malgré l'éclairage
    ROUGHNESS = 0.8; 
    METALLIC = 0.0;
}
