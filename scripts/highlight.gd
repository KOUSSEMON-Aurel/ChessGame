extends MeshInstance3D

# Couleur du surlignage
var highlight_color: Color = Color.GREEN

func _ready():
	# S'assurer que le matériau est bien configuré
	setup_material()

func setup_material():
	if mesh == null:
		mesh = PlaneMesh.new()
		mesh.size = Vector2(0.9, 0.9)  # Légèrement plus petit qu'une case
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.5)
	material.emission_enabled = true
	material.emission = highlight_color
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	set_surface_override_material(0, material)

func set_color(color: Color):
	highlight_color = color
	setup_material()

func _process(_delta):
	# Animation de pulsation
	var pulse = abs(sin(Time.get_ticks_msec() / 500.0))
	var material = get_surface_override_material(0)
	if material:
		material.emission_energy_multiplier = 1.5 + pulse * 1.5
