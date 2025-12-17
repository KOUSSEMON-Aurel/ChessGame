shader_type spatial;

// Global Ripple Parameters
uniform vec2 ripple_center = vec2(0.0, 0.0);
uniform float ripple_amplitude = 0.0;
uniform float ripple_time = 0.0;
uniform float ripple_frequency = 5.0;
uniform float ripple_decay = 0.5;
uniform float ripple_speed = 5.0;
uniform vec3 ripple_color = vec3(1.0, 1.0, 1.0); // Default white

// Per-instance parameters
instance uniform vec3 base_color : source_color = vec3(1.0);
instance uniform vec4 highlight_color : source_color = vec4(0.0);

// Varying to pass world position and wave intensity to fragment
varying vec3 world_position;
varying float wave_intensity;

void vertex() {
	// Get world position of the vertex
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calculate distance from ripple center (in world XZ plane)
	vec2 diff = world_position.xz - ripple_center;
	float dist = length(diff);
	
	// Avoid division by zero
	vec2 dir = (dist > 0.001) ? diff / dist : vec2(0.0);
	
	// Wave params
	// "Pulse" wave instead of continuous sine
	// We want a single hump traveling outward.
	// Function: -4 * x * exp(-2 * x^2) -> Derivative of Gaussian (Mexican Hat-ish)
	// Let x = (dist - travel_pos) * width_factor
	// We reuse ripple_frequency as "Wave Width Factor" (Inverse Size)
	
	float travel_pos = ripple_time * ripple_speed;
	float x = (dist - travel_pos) * ripple_frequency; 
	
	// Pulse Formula: Simple Gaussian Pulse approximating a splash
	// y = amp * exp(-x*x) * sin(x * 3.0) -> Damped packet
	// Or simpler: Single hump
	// y = amp * exp(-x*x) * 2.0; (just up)
	// But riples go Up AND Down.
	// Mexican Hat: (1 - x*x) * exp(-0.5 * x*x)
	float wave_shape = (1.0 - x*x) * exp(-0.5 * x*x);
	
	float attenuation = max(0.0, 1.0 - dist * ripple_decay);
	
	// Amplitude effective
	float amp = ripple_amplitude * attenuation * 2.0; // Boosted
	
	// Calculate wave intensity for fragment shader (0 to 1)
	wave_intensity = abs(wave_shape) * attenuation;
	
	if (abs(amp) > 0.001) {
		// 1. Vertical Displacement
		VERTEX.y += wave_shape * amp;
		
		// 2. Lateral Displacement (Shockwave)
		// REMOVED completely to fix "separation des cases".
		// Pure vertical elasticity is cleaner.
		VERTEX.xz += dir * 0.0;
		
		// 3. Normal Recalculation
		// Fix "Black areas": The slope was too extreme, causing the normal to point sideways/down
		// resulting in pitch black shadows.
		// Solution: Reduce slope influence and blend with original normal (Up).
		
		float slope = -x * wave_shape * 0.5 * amp; // Reduced factor from 1.5 to 0.5
		
		vec3 calculated_normal = normalize(vec3(-slope * dir.x, 1.0, -slope * dir.y));
		
		// Blend with strict UP vector to keep it "safe"
		NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), calculated_normal, 0.5));
	}
}

void fragment() {
	// Base Color from Instance Uniform
	vec3 base = base_color.rgb;
	
	// Apply ripple color tint based on wave intensity (passed from vertex shader)
	// Boost visibility with stronger blend
	vec3 tinted = mix(base, ripple_color, wave_intensity * 0.9);
	
	ALBEDO = tinted;
	
	// Highlight overlay (pour les highlights rouges/dorés)
	ALBEDO = mix(ALBEDO, highlight_color.rgb, highlight_color.a);
	
	// EMISSION pour être sûr que c'est visible (Glow)
	EMISSION = highlight_color.rgb * highlight_color.a * 0.5;
	
	// PBR Properties for Visibility!
	ROUGHNESS = 0.2; 
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
