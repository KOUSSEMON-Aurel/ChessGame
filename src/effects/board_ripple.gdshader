shader_type spatial;

// Global uniforms for ripple effect
uniform vec2 ripple_center = vec2(0.0, 0.0);
uniform float ripple_time = 0.0;
uniform float ripple_amplitude = 0.0;
uniform float ripple_frequency = 5.0;
uniform float ripple_decay = 0.5;
uniform float ripple_speed = 5.0;

// Per-instance parameters
instance uniform vec3 base_color : source_color = vec3(1.0);
instance uniform vec4 highlight_color : source_color = vec4(0.0); // Alpha controls mix strength

void vertex() {
	// Get world position of the vertex
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calculate distance from ripple center (in world XZ plane)
	vec2 diff = world_pos.xz - ripple_center;
	float dist = length(diff);
	
	// Avoid division by zero
	vec2 dir = (dist > 0.001) ? diff / dist : vec2(0.0);
	
	// Wave params
	float phase = dist * ripple_frequency - ripple_time * ripple_speed;
	float attenuation = max(0.0, 1.0 - dist * ripple_decay);
	
	// Base wave: y = sin(phase)
	float sin_v = sin(phase);
	float cos_v = cos(phase);
	
	// Amplitude effective
	float amp = ripple_amplitude * attenuation;
	
	if (amp > 0.001) {
		// 1. Vertical Displacement
		VERTEX.y += sin_v * amp;
		
		// 2. Lateral Displacement (for Top-Down visibility)
		// Push vertices slightly outward/inward with the wave
		VERTEX.xz += dir * sin_v * amp * 0.4;
		
		// 3. Normal Recalculation (Analytic Derivative)
		// dy/ddist = amp * freq * cos(phase) - decay_term... (approx)
		// Simplified: just wave slope
		float slope = amp * ripple_frequency * cos_v;
		
		// Normal vector in World Space (assuming flat board initially up=(0,1,0))
		// N = (-dy/dx, 1, -dy/dz)
		// dy/dx = slope * dir.x
		// dy/dz = slope * dir.y (which is z in 3D)
		vec3 new_normal = normalize(vec3(-slope * dir.x, 1.0, -slope * dir.y));
		
		// Transform Normal back to Model Space? 
		// Or just set NORMAL and let Godot handle it?
		// Godot expects NORMAL in Model Space.
		// Since Board tiles are likely not rotated, Model Normal ~ World Normal.
		NORMAL = new_normal;
	}
}

void fragment() {
	// Set base color
	vec3 final_color = base_color;
	
	// Apply highlight if active
	if (highlight_color.a > 0.0) {
		final_color = mix(final_color, highlight_color.rgb, highlight_color.a);
	}
	
	ALBEDO = final_color;
	ROUGHNESS = 0.5;
	SPECULAR = 0.2;
}
