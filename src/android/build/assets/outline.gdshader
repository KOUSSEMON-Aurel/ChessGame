shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0, 10) = 1.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	
	float outline = 0.0;
	
	// Check neighbors to detect edges
	outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	
	outline = min(outline, 1.0);
	
	vec4 color = texture(TEXTURE, UV);
	
	// If current pixel is transparent but has opaque neighbors, draw outline
	// Also draw outline if current pixel is opaque (mix) - wait, standard outline is outside
	// This logic draws outline "under" the sprite if we mix based on alpha
	
	// Logic: 
	// If pixel is fully transparent (a=0) and outline > 0 -> Draw Line
	// If pixel is opaque -> Draw Texture
	
	vec4 outline_result = mix(color, line_color, outline - color.a);
	COLOR = mix(color, outline_result, outline_result.a);
	
	// Simpler logic:
	// If alpha is low but neighbor alpha is high -> Outline
	// Use smoothstep for softer edges
	float is_outline = smoothstep(0.1, 0.6, outline - color.a);
	COLOR = mix(color, line_color, is_outline);
}
