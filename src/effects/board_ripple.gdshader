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
	// "Pulse" wave instead of continuous sine
	// We want a single hump traveling outward.
	// Function: -4 * x * exp(-2 * x^2) -> Derivative of Gaussian (Mexican Hat-ish)
	// Let x = (dist - time_pos) * width
	
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
	
	if (abs(amp) > 0.001) {
		// 1. Vertical Displacement
		VERTEX.y += wave_shape * amp;
		
		// 2. Lateral Displacement (Shockwave)
		// Reduced from 0.5 to 0.1 to prevent "gaps" between tiles
		float shock = exp(-x*x); 
		VERTEX.xz += dir * shock * amp * 0.15;
		
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
	ALBEDO = base_color.rgb;
	
	// Highlight overlay
	// Use pre-multiplied alpha or mix
	ALBEDO = mix(ALBEDO, highlight_color.rgb, highlight_color.a);
	
	// PBR Properties for Visibility!
	// Glossy plastic look to catch light on waves
	ROUGHNESS = 0.2; 
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
