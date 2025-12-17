extends MeshInstance3D
class_name ClothBoardMesh

## Mesh unique subdivisé pour effet tissu/membrane
## Déformation locale par vertices partagés

@export var subdivisions := 16

# Vertices du mesh
var original_vertices: PackedVector3Array
var current_vertices: PackedVector3Array
var uvs: PackedVector2Array
var indices: PackedInt32Array

# Bounds calculés dynamiquement
var board_min: Vector3  # Coin (0,0) du plateau
var board_max: Vector3  # Coin (7,7) du plateau
var tile_size: float = 70.0

# Animation
var is_deforming := false
var deform_tween: Tween

# Highlight system (texture 8x8)
var highlight_image: Image
var highlight_texture: ImageTexture
var shader_material: ShaderMaterial

func _ready():
	# 🧱 Reset transform complet (Règle n°3)
	transform = Transform3D.IDENTITY
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	position = Vector3(0, -0.02, 0) # Juste le léger décalage Y requis
	
	# On attend un frame pour que Board.gd ait initialisé les marqueurs
	await get_tree().process_frame
	await get_tree().process_frame
	_calculate_bounds_and_generate()

func _calculate_bounds_and_generate():
	"""Calcule les limites du plateau depuis les marqueurs puis génère le mesh"""
	# Trouver le Board pour accéder aux marqueurs
	var board = _find_board()
	if board == null:
		push_error("ClothBoardMesh: Board non trouvé!")
		return
	
	# Obtenir les positions des 4 coins du plateau
	var pos_00 = board.get_marker_position(0)   # Case (0,0) - a8
	var pos_70 = board.get_marker_position(7)   # Case (7,0) - h8
	var pos_07 = board.get_marker_position(56)  # Case (0,7) - a1
	var pos_77 = board.get_marker_position(63)  # Case (7,7) - h1
	
	# Calculer la taille d'une case (séparer largeur et hauteur pour gérer la perspective)
	# La caméra inclinée peut étirer l'axe Z par rapport à X
	var width_total = pos_00.distance_to(pos_70)
	var height_total = pos_00.distance_to(pos_07) # Distance sur Z (colonne a)
	
	var tile_width = width_total / 7.0
	var tile_height = height_total / 7.0
	
	# Mettre à jour la variable globale (moyenne ou max, peu importe pour l'instant)
	tile_size = tile_width 
	
	print("📐 Dimensions calculées: Width=%.2f Height=%.2f (Ratio Z/X: %.2f)" % [
		tile_width, tile_height, tile_height/tile_width
	])

	# Trouver les vraies limites en utilisant min/max
	var all_x = [pos_00.x, pos_70.x, pos_07.x, pos_77.x]
	var all_z = [pos_00.z, pos_70.z, pos_07.z, pos_77.z]
	
	# Offset avec la dimension correspondante à l'axe
	var min_x = all_x.min() - tile_width / 2.0
	var max_x = all_x.max() + tile_width / 2.0
	var min_z = all_z.min() - tile_height / 2.0  # Utiliser height ici !
	var max_z = all_z.max() + tile_height / 2.0  # Utiliser height ici !
	
	board_min = Vector3(min_x, 0, min_z)
	board_max = Vector3(max_x, 0, max_z)
	
	print("📐 ClothBoardMesh bounds: min=%s max=%s tile_size=%.1f" % [board_min, board_max, tile_size])
	print("   Coins: 00=%s 70=%s 07=%s 77=%s" % [pos_00, pos_70, pos_07, pos_77])
	
	generate()


func _find_board():
	"""Trouve le node Board dans l'arbre"""
	# Remonter jusqu'à trouver Board
	var node = get_parent()
	while node != null:
		if node.has_method("get_marker_position"):
			return node
		# Chercher dans les enfants du viewport principal
		var root = get_tree().root
		var board = root.find_child("Board", true, false)
		if board:
			return board
		node = node.get_parent()
	return null

func generate():
	"""Génère un mesh plan subdivisé avec vertices partagés"""
	var arr_mesh := ArrayMesh.new()
	
	original_vertices = PackedVector3Array()
	uvs = PackedVector2Array()
	indices = PackedInt32Array()
	
	var size_x = board_max.x - board_min.x
	var size_z = board_max.z - board_min.z
	
	# Créer la grille de vertices (subdivisions+1)²
	var vertex_count := subdivisions + 1
	for vy in range(vertex_count):
		for vx in range(vertex_count):
			var fx := float(vx) / subdivisions
			var fy := float(vy) / subdivisions
			# Position interpolée entre les coins
			var pos := Vector3(
				board_min.x + fx * size_x,
				0.0,  # Surface du plateau (tiles invisibles, pas de z-fighting)
				board_min.z + fy * size_z
			)
			original_vertices.append(pos)
			uvs.append(Vector2(fx, fy))
	
	# Créer les triangles (2 par quad)
	for vy in range(subdivisions):
		for vx in range(subdivisions):
			var i := vy * vertex_count + vx
			# Premier triangle du quad
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + vertex_count)
			# Second triangle du quad
			indices.append(i + 1)
			indices.append(i + vertex_count + 1)
			indices.append(i + vertex_count)
	
	# Copier pour manipulation
	current_vertices = original_vertices.duplicate()
	
	# Construire le mesh
	_build_mesh(arr_mesh)
	self.mesh = arr_mesh
	
	# Initialiser le système de highlight
	_init_highlight_texture()
	
	@warning_ignore("integer_division")
	print("✅ ClothBoardMesh généré: %d vertices, %d triangles" % [
		original_vertices.size(), 
		indices.size() / 3
	])

func _init_highlight_texture():
	"""Crée la texture 8x8 pour les highlights et l'assigne au shader"""
	# Créer une image 8x8 transparente
	highlight_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	highlight_image.fill(Color(0, 0, 0, 0))  # Transparent
	
	# Créer la texture
	highlight_texture = ImageTexture.create_from_image(highlight_image)
	
	# Récupérer le material du mesh et lui assigner la texture
	if material_override and material_override is ShaderMaterial:
		shader_material = material_override as ShaderMaterial
		shader_material.set_shader_parameter("highlight_texture", highlight_texture)
		print("✅ Highlight texture assignée au ClothBoardMesh")

func set_highlight(grid_x: int, grid_y: int, color: Color):
	"""Définit la couleur de highlight d'une case"""
	if not highlight_image:
		return
	
	# Coordonnées dans la texture (potentiellement inversées selon UV du mesh)
	# UV.x va de gauche à droite = a->h = 0->7 OK
	# UV.y va de bas en haut dans Godot, mais l'image a origine haut-gauche
	# grid_y=0 est en haut du plateau (rangée 8), donc correspond à img_y=0
	var img_x = grid_x
	var img_y = grid_y  # Pas d'inversion, on	
	# Mettre à jour l'image
	highlight_image.set_pixel(img_x, img_y, color)
	
	# Mettre à jour la texture
	highlight_texture.update(highlight_image)
	
	# Forcer la réassignation du paramètre shader si nécessaire (pour certains drivers)
	if shader_material:
		shader_material.set_shader_parameter("highlight_texture", highlight_texture)

func clear_all_highlights():
	"""Efface tous les highlights"""
	if not highlight_image:
		return
	
	highlight_image.fill(Color(0, 0, 0, 0))
	highlight_texture.update(highlight_image)

func _build_mesh(arr_mesh: ArrayMesh):
	"""Reconstruit le mesh avec les vertices actuels"""
	# Nettoyer les surfaces existantes
	arr_mesh.clear_surfaces()
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = current_vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func get_height_at(world_pos: Vector3) -> float:
	"""
	Retourne la hauteur Y du mesh à la position world donnée.
	Utilise une interpolation bilinéaire pour suivre les courbes.
	"""
	if current_vertices.size() == 0:
		return 0.0
		
	# 1. Convertir en coordonnées locales normalisées (0..1)
	var size_x = board_max.x - board_min.x
	var size_z = board_max.z - board_min.z
	
	if size_x <= 0 or size_z <= 0: return 0.0
	
	var t_x = (world_pos.x - board_min.x) / size_x
	var t_z = (world_pos.z - board_min.z) / size_z
	
	# Clamper pour éviter les crashs si un peu hors bord
	t_x = clampf(t_x, 0.0, 1.0)
	t_z = clampf(t_z, 0.0, 1.0)
	
	# 2. Convertir en coordonnées grille
	var grid_x_float = t_x * subdivisions
	var grid_z_float = t_z * subdivisions
	
	# Indices du quad supérieur gauche
	var x0 = int(floor(grid_x_float))
	var z0 = int(floor(grid_z_float))
	
	# S'assurer qu'on ne déborde pas (dernier quad)
	x0 = min(x0, subdivisions - 1)
	z0 = min(z0, subdivisions - 1)
	
	# 3. Récupérer les 4 hauteurs
	# vertex_index = y * (subdivisions + 1) + x
	var stride = subdivisions + 1
	var idx00 = z0 * stride + x0
	var idx10 = idx00 + 1
	var idx01 = idx00 + stride
	var idx11 = idx01 + 1
	
	var h00 = current_vertices[idx00].y
	var h10 = current_vertices[idx10].y
	var h01 = current_vertices[idx01].y
	var h11 = current_vertices[idx11].y
	
	# 4. Interpolation bilinéaire
	var fx = grid_x_float - x0
	var fz = grid_z_float - z0
	
	var h_top = lerpf(h00, h10, fx)
	var h_bot = lerpf(h01, h11, fx)
	
	return lerpf(h_top, h_bot, fz)

func deform_at(board_x: int, board_y: int, intensity: float = 1.0, return_duration: float = 0.4):
	"""
	Déformation cratère (ChessFX) :
	- Impact local rapide (descente)
	- Retour progressif et lisse
	- PAS d'oscillation ni rebond
	"""
	# Annuler la déformation précédente si en cours
	if deform_tween and deform_tween.is_valid():
		deform_tween.kill()
	
	is_deforming = true
	
	# Convertir coordonnées grille (0-7) en coordonnées mesh
	var vertices_per_tile := float(subdivisions) / 8.0
	var center_vx := int((board_x + 0.5) * vertices_per_tile)
	var center_vy := int((board_y + 0.5) * vertices_per_tile)
	
	# Rayon d'effet en vertices (Manhattan ≤ 3 cases)
	var radius_tiles := 3
	var radius_vertices := int(radius_tiles * vertices_per_tile)
	
	# Amplitude de déformation (DESCENTE = négative)
	var max_depth := -tile_size * 0.5 * intensity  # Négatif = cratère
	
	print("🎯 Cratère: case(%d,%d) profondeur=%.1f retour=%.2fs" % [
		board_x, board_y, abs(max_depth), return_duration
	])
	
	# Identifier les vertices à déformer
	var vertex_count := subdivisions + 1
	var affected_indices: Array[int] = []
	var affected_weights: Array[float] = []
	
	for y in range(vertex_count):
		for x in range(vertex_count):
			var manhattan: int = abs(x - center_vx) + abs(y - center_vy)
			if manhattan <= radius_vertices:
				var idx := y * vertex_count + x
				affected_indices.append(idx)
				# Poids décroissant avec la distance
				var weight := 1.0 - float(manhattan) / float(radius_vertices + 1)
				affected_weights.append(weight)
	
	# Animation CRATÈRE : Descente rapide → Retour lisse
	if deform_tween and deform_tween.is_valid():
		deform_tween.kill()
	
	deform_tween = create_tween()
	
	# Phase 1: Impact - Descente rapide (0.1s)
	deform_tween.tween_method(
		func(t): _apply_deformation(affected_indices, affected_weights, max_depth * t),
		0.0, 1.0, 0.1
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Phase 2: Retour au repos - Lent et lisse (0.4s par défaut, 0.5s pour BLUNDER)
	deform_tween.tween_method(
		func(t): _apply_deformation(affected_indices, affected_weights, max_depth * t),
		1.0, 0.0, return_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	deform_tween.finished.connect(func(): is_deforming = false)

func _apply_deformation(indices_list: Array[int], weights: Array[float], amplitude: float):
	"""Applique la déformation aux vertices spécifiés"""
	# Restaurer depuis les originaux
	current_vertices = original_vertices.duplicate()
	
	# Appliquer la déformation
	for i in range(indices_list.size()):
		var idx := indices_list[i]
		var weight := weights[i]
		var v := current_vertices[idx]
		v.y = amplitude * weight
		current_vertices[idx] = v
	
	# Mettre à jour le mesh
	if mesh is ArrayMesh:
		_build_mesh(mesh as ArrayMesh)

func reset():
	"""Réinitialise le mesh à son état original"""
	current_vertices = original_vertices.duplicate()
	if mesh is ArrayMesh:
		_build_mesh(mesh as ArrayMesh)
	is_deforming = false
