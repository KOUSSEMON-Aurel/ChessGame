extends Node3D
class_name BoardEffects

## Système d'effets visuels pour le plateau d'échecs (Version Shaders)
## Utilise Vertex Displacement pour une déformation fluide

# Référence aux tuiles du plateau
var board_tiles: Array = []

# Matériau partagé pour toutes les tuiles
var board_material: ShaderMaterial
var ripple_shader = preload("res://effects/board_ripple.gdshader")

# Liste des tweens actifs
var active_tweens: Array[Tween] = []

# Échelle du plateau (pour conversion distances)
var board_scale: float = 1.0

func _ready():
	print("✨ BoardEffects (Shared Shader) ready")

# Appelé depuis Board.gd après assignation des tuiles
func initialize_materials():
	if board_tiles.is_empty(): 
		push_warning("BoardEffects: No tiles to initialize")
		return
	
	_ensure_board_scale()
	
	# Créer le matériau partagé
	board_material = ShaderMaterial.new()
	board_material.shader = ripple_shader
	
	# Initialiser toutes les tuiles avec ce matériau et leur couleur propre
	for tile in board_tiles:
		if not tile: continue
		
		# Récupérer la couleur originale
		var base_color = Color.WHITE
		# Vérifier l'override existant (posé par Board.gd)
		if tile.material_override:
			base_color = tile.material_override.albedo_color
		# Sinon vérifier le mesh
		elif tile.mesh and tile.mesh.surface_get_material(0):
			base_color = tile.mesh.surface_get_material(0).albedo_color
			
		# Assigner le matériau partagé
		tile.material_override = board_material
		
		# Configurer les paramètres UNIQUES par instance
		tile.set_instance_shader_parameter("base_color", base_color)
		tile.set_instance_shader_parameter("highlight_color", Color(0, 0, 0, 0)) # Transparent
	
	print("🎨 Converted ", board_tiles.size(), " tiles to ShaderMaterial")
	
	# Augmenter la subdivision du mesh pour permettre la déformation (Vertex Displacement)
	# Sans subdivision, le shader ne bouge que les coins (invisible ou rigide)
	if not board_tiles.is_empty() and board_tiles[0] and board_tiles[0].mesh:
		var m = board_tiles[0].mesh
		if m is BoxMesh or m is PlaneMesh:
			# On modifie la ressource partagée, donc ça s'applique à toutes les tuiles
			m.subdivide_width = 16 
			m.subdivide_depth = 16
			print("🕸️ Mesh subdivided (16x16) for high-quality waves")

# ========================================
# RIPPLE / ONDULATION (Global Shader)
# ========================================

func create_ripple_effect(center_pos_grid: Vector2, intensity: float = 1.0, wave_color: Color = Color.WHITE):
	if not board_material: 
		initialize_materials()
		if not board_material: return
	
	# Trouver la position monde du centre de l'onde
	var tile_idx = int(center_pos_grid.x + center_pos_grid.y * 8)
	var world_center = Vector2.ZERO
	if tile_idx >= 0 and tile_idx < board_tiles.size():
		var t = board_tiles[tile_idx]
		if t: world_center = Vector2(t.global_position.x, t.global_position.z)
	
	# Configurer le centre de l'onde dans le shader global
	board_material.set_shader_parameter("ripple_center", world_center)
	board_material.set_shader_parameter("ripple_color", Vector3(wave_color.r, wave_color.g, wave_color.b))
	
	var tween = _create_managed_tween()
	tween.set_parallel(true)
	
	# 1. Amplitude (Montée puis Descente)
	# BUGFIX: L'amplitude doit être proportionnelle à l'échelle du plateau !
	# Si scale=70, amp=0.3 est invisible. On veut ~10-20% de la taille d'une case.
	# intensity ~ 1.5. Scale ~ 1.0 ou 70.0.
	# target_amp = 1.5 * 70 * 0.15 = ~15.0 units.
	var scale_factor = board_scale if board_scale > 0.1 else 1.0
	var target_amp = intensity * scale_factor * 0.15
	
	print("🌊 Ripple Triggered! Center:", center_pos_grid, " Scale:", scale_factor, " TargetAmp:", target_amp)
	
	tween.tween_method(
		func(v): board_material.set_shader_parameter("ripple_amplitude", v),
		0.0, target_amp, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(
		func(v): board_material.set_shader_parameter("ripple_amplitude", v),
		target_amp, 0.0, 0.8
	).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Propsulse
	# Scale = 70.0 approx.
	# Pulse Width desiree ~ 2.5 tiles.
	# Shader x = (dist - pos) * freq. Pulse active pour x dans [-2, 2].
	# Donc largeur = 4 / freq.
	# 2. Propsulse
	# Scale = 70.0 approx.
	# Pulse Width : On élargit pour éviter les "trous" entre cases (Plus "mou/élastique")
	# freq = 0.8 / scale au lieu de 1.6
	var freq = 0.8 / scale_factor
	board_material.set_shader_parameter("ripple_frequency", freq)
	
	# Vitesse : Adaptée à la largeur
	var speed = 7.0 * scale_factor
	board_material.set_shader_parameter("ripple_speed", speed) 
	
	# Decay : Effet plus LOCAL demandé.
	# Avant: 1.0 / (10 * scale) -> Rayon ~10 cases.
	# Maintenant: 1.0 / (4 * scale) -> Rayon ~4 cases. Ça s'arrête vite.
	var decay = 1.0 / (4.0 * scale_factor)
	board_material.set_shader_parameter("ripple_decay", decay)
	
	print("🌊 Pulse Localized - Scale:", scale_factor, " Decay:", decay)
	
	board_material.set_shader_parameter("ripple_time", 0.0)
	tween.tween_method(
		func(v): board_material.set_shader_parameter("ripple_time", v),
		0.0, 1.5, 1.2 # Time 0->1.5 (Distance parcourue = 1.5 * 9 tiles = 13 tiles. Suffisant)
	).set_trans(Tween.TRANS_LINEAR)

# ========================================
# HIGHLIGHT (Instance Parameter)
# ========================================

func highlight_square(grid_pos: Vector2, color: Color, duration: float = 0.5):
	var tile_idx = int(grid_pos.x + grid_pos.y * 8)
	if tile_idx < 0 or tile_idx >= board_tiles.size(): return
	var tile = board_tiles[tile_idx]
	if not tile: return
	
	# S'assurer que les matériaux sont prêts
	if not board_material: initialize_materials()
	
	var tween = _create_managed_tween()
	
	# Animer la couleur via parameter d'instance
	# On doit passer par une méthode intermédiaire car tween_property ne marche pas direct sur set_instance...
	
	var start_col = Color(color.r, color.g, color.b, 0.0)
	var peak_col = color # Alpha utilisé comme mix intensity
	
	# Montée
	tween.tween_method(
		func(c): tile.set_instance_shader_parameter("highlight_color", c),
		start_col, peak_col, 0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_interval(duration * 0.5)
	
	# Descente
	tween.tween_method(
		func(c): tile.set_instance_shader_parameter("highlight_color", c),
		peak_col, start_col, duration * 0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

# ========================================
# PULSE (Scale Transform) - Checkmate
# ========================================

func pulse_square(grid_pos: Vector2, intensity: float = 1.3, cycles: int = 3):
	var tile_idx = int(grid_pos.x + grid_pos.y * 8)
	if tile_idx < 0 or tile_idx >= board_tiles.size(): return
	var tile = board_tiles[tile_idx]
	if not tile: return
	
	var original_scale = Vector3.ONE
	if tile.scale.length() > 0.1: original_scale = tile.scale
	
	var target_scale = original_scale * intensity
	var tween = _create_managed_tween()
	
	for k in range(cycles):
		tween.tween_property(tile, "scale", target_scale, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", original_scale, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.tween_property(tile, "scale", original_scale, 0.1)

# ========================================
# FLASH (Instance loop)
# ========================================

func flash_board(_color: Color, _duration: float = 0.8):
	if board_tiles.is_empty(): return
	if not board_material: initialize_materials()
	
	# TODO: Implementer flash shader global
	# Pour l'instant on ne fait rien pour éviter le coût CPU de 64 tweens
	pass

# ========================================
# UTILITAIRES
# ========================================

func _ensure_board_scale():
	if board_scale == 1.0 and board_tiles.size() > 1:
		var p0 = board_tiles[0].global_position
		var p1 = board_tiles[1].global_position
		var dist = p0.distance_to(p1)
		if dist > 0.1:
			board_scale = dist

func reset_all_effects():
	for tween in active_tweens:
		if tween and tween.is_valid(): tween.kill()
	active_tweens.clear()
	
	# Reset shader params if needed
	if board_material:
		board_material.set_shader_parameter("ripple_amplitude", 0.0)
		for tile in board_tiles:
			if tile:
				tile.set_instance_shader_parameter("highlight_color", Color(0,0,0,0))
				tile.scale = Vector3.ONE # Reset pulse

func _create_managed_tween() -> Tween:
	var t = create_tween()
	active_tweens.append(t)
	t.finished.connect(func(): 
		if t in active_tweens: active_tweens.erase(t)
	)
	return t
