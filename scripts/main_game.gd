extends Node3D

# Préchargement de la scène de surlignage
const HIGHLIGHT_SCENE = preload("res://scenes/pieces/highlight.tscn")

# Chemins vers les modèles de pièces
const PIECE_MODELS = {
	"pawn": "res://Assets/Pawn.glb",
	"rook": "res://Assets/Rook.glb",
	"knight": "res://Assets/Knight.glb",
	"bishop": "res://Assets/Bishop.glb",
	"queen": "res://Assets/Queen.glb",
	"king": "res://Assets/King.glb"
}

# Variables pour la logique du jeu
var selected_piece = null
var current_highlights = []
var board_pieces = {}  # Dictionnaire pour stocker les pièces par position

# Matériaux
var white_material = preload("res://materials/piece_white.tres")
var black_material = preload("res://materials/piece_black.tres")

# Taille du plateau standard (8 colonnes x 8 lignes)
const BOARD_WIDTH = 8
const BOARD_HEIGHT = 8
const CELL_SIZE = 1.0

func _ready():
	print("Jeu d'échecs initialisé!")
	setup_board()

func setup_board():
	# Initialisation du plateau avec toutes les pièces
	print("Placement des pièces...")
	
	# === BLANCS (rangées 1 et 2) ===
	
	# Pions blancs sur la rangée 2 (ligne 1) : a2-h2
	for i in range(8):
		create_piece("pawn", "white", Vector2i(i, 1))
	
	# Pièces majeures blanches sur la rangée 1 (ligne 0)
	create_piece("rook", "white", Vector2i(0, 0))    # a1
	create_piece("knight", "white", Vector2i(1, 0))  # b1
	create_piece("bishop", "white", Vector2i(2, 0))  # c1
	create_piece("queen", "white", Vector2i(3, 0))   # d1
	create_piece("king", "white", Vector2i(4, 0))    # e1
	create_piece("bishop", "white", Vector2i(5, 0))  # f1
	create_piece("knight", "white", Vector2i(6, 0))  # g1
	create_piece("rook", "white", Vector2i(7, 0))    # h1
	
	# === NOIRS (rangées 7 et 8) ===
	
	# Pions noirs sur la rangée 7 (ligne 6) : a7-h7
	for i in range(8):
		create_piece("pawn", "black", Vector2i(i, 6))
	
	# Pièces majeures noires sur la rangée 8 (ligne 7)
	create_piece("rook", "black", Vector2i(0, 7))    # a8
	create_piece("knight", "black", Vector2i(1, 7))  # b8
	create_piece("bishop", "black", Vector2i(2, 7))  # c8
	create_piece("queen", "black", Vector2i(3, 7))   # d8
	create_piece("king", "black", Vector2i(4, 7))    # e8
	create_piece("bishop", "black", Vector2i(5, 7))  # f8
	create_piece("knight", "black", Vector2i(6, 7))  # g8
	create_piece("rook", "black", Vector2i(7, 7))    # h8
	
	print("Toutes les pièces placées!")

func create_piece(piece_type: String, color: String, board_pos: Vector2i):
	# Charger le modèle
	var model_path = PIECE_MODELS.get(piece_type)
	if model_path == null:
		print("❌ Erreur: type de pièce inconnu: ", piece_type)
		return
	
	print("📦 Chargement de: ", model_path)
	var piece_scene = load(model_path)
	if piece_scene == null:
		print("❌ ERREUR: Impossible de charger ", model_path)
		return
	
	var piece = piece_scene.instantiate()
	if piece == null:
		print("❌ ERREUR: Impossible d'instancier la scène")
		return
	
	print("✅ Pièce instanciée: ", piece.name)
	
	# === CONTENEURISATION : Créer un conteneur pour la pièce ===
	var piece_container = Node3D.new()
	piece_container.name = color + "_" + piece_type + "_container"
	
	# Positionner le CONTENEUR au centre exact de la case
	var world_pos = board_to_world_position(board_pos)
	world_pos.y = 0.0  # Au niveau du plateau
	piece_container.position = world_pos
	
	# Ajouter le conteneur à la scène
	add_child(piece_container)
	
	# Ajouter la pièce au conteneur
	piece_container.add_child(piece)
	
	# Définir d'abord l'échelle
	piece.scale = Vector3(15.0, 15.0, 15.0)
	
	# === CENTRAGE AUTOMATIQUE PAR BOUNDING BOX ===
	# Attendre un frame pour que le mesh soit bien chargé
	await get_tree().process_frame
	
	# Calculer le centre géométrique de la pièce
	var aabb = calculate_piece_aabb(piece)
	if aabb != null:
		# Le centre de la boîte englobante (en espace local non-scalé)
		var center_offset = aabb.get_center()
		
		# IMPORTANT : Comme la pièce est scalée, il faut multiplier l'offset par l'échelle !
		# On veut que (Position + Center * Scale) = 0 (relativement au conteneur)
		# Donc Position = -Center * Scale
		
		var offset_x = -center_offset.x * piece.scale.x
		var offset_z = -center_offset.z * piece.scale.z
		
		# Pour Y, on veut que le bas de la pièce (aabb.position.y) soit à 0
		var offset_y = -aabb.position.y * piece.scale.y
		
		piece.position = Vector3(offset_x, offset_y, offset_z)
		
		print("  📏 AABB: ", aabb)
		print("  📍 Offset appliqué (avec scale): ", piece.position)
		
		# DEBUG : Ajouter un petit marqueur rouge au centre du conteneur (là où la pièce devrait être centrée)
		var marker = MeshInstance3D.new()
		var marker_mesh = SphereMesh.new()
		marker_mesh.radius = 0.05
		marker_mesh.height = 0.1
		marker.mesh = marker_mesh
		var marker_mat = StandardMaterial3D.new()
		marker_mat.albedo_color = Color.RED
		marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.set_surface_override_material(0, marker_mat)
		piece_container.add_child(marker)
		
	else:
		# Fallback si pas de mesh trouvé
		piece.position = Vector3(0, 0, 0)
		print("  ⚠️ Pas de bounding box - position par défaut")
	
	# Pas de rotation
	piece.rotation_degrees = Vector3(0, 0, 0)
	
	print("  📦 Conteneur à: ", piece_container.position)
	
	# Appliquer le matériau approprié
	apply_material_to_piece(piece, color)
	
	# Stocker le CONTENEUR dans le dictionnaire
	board_pieces[board_pos] = {
		"container": piece_container,
		"node": piece,
		"type": piece_type,
		"color": color,
		"position": board_pos
	}
	
	print("✅ Pièce containerisée et centrée: ", color, " ", piece_type, " à case ", board_pos)

# Fonction pour calculer la bounding box (AABB) d'une pièce
# Retourne AABB ou null si aucun mesh trouvé
func calculate_piece_aabb(root_node: Node3D):
	var combined_aabb: AABB
	var first = true
	
	# Parcourir récursivement pour trouver tous les MeshInstance3D
	var mesh_instances = find_all_mesh_instances(root_node)
	
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh != null:
			# Obtenir l'AABB locale du mesh
			var local_aabb = mesh_instance.mesh.get_aabb()
			
			# Calculer la transformation relative du MeshInstance par rapport à la racine de la pièce
			# On utilise les transformations globales pour gérer toute la hiérarchie
			var relative_transform = root_node.global_transform.affine_inverse() * mesh_instance.global_transform
			
			# Transformer l'AABB locale vers l'espace de la racine
			var transformed_aabb = relative_transform * local_aabb
			
			if first:
				combined_aabb = transformed_aabb
				first = false
			else:
				combined_aabb = combined_aabb.merge(transformed_aabb)
	
	if first:
		# Aucun mesh trouvé
		return null
	
	return combined_aabb

# Fonction récursive pour trouver tous les MeshInstance3D
func find_all_mesh_instances(node: Node) -> Array:
	var instances = []
	
	if node is MeshInstance3D:
		instances.append(node)
	
	for child in node.get_children():
		instances.append_array(find_all_mesh_instances(child))
	
	return instances

func apply_material_to_piece(node: Node, color: String, depth: int = 0):
	# Appliquer le matériau à tous les MeshInstance3D (récursif)
	var material = white_material if color == "white" else black_material
	var indent = "  ".repeat(depth)
	
	if node is MeshInstance3D:
		# Appliquer le matériau à toutes les surfaces
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			var surface_count = mesh_instance.mesh.get_surface_count()
			for i in range(surface_count):
				mesh_instance.set_surface_override_material(i, material)
			print(indent, "🎨 Matériau ", color, " appliqué à '", node.name, "' (", surface_count, " surfaces)")
	
	# Parcourir récursivement tous les enfants
	for child in node.get_children():
		apply_material_to_piece(child, color, depth + 1)


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position)

func handle_click(screen_pos):
	# Convertir la position de l'écran en position 3D
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
		
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var clicked_pos = result.position
		var board_pos = world_to_board_position(clicked_pos)
		
		if selected_piece:
			# Tenter de déplacer la pièce
			move_piece_to(board_pos)
		else:
			# Sélectionner une pièce
			select_piece_at(board_pos)

func world_to_board_position(world_pos: Vector3) -> Vector2i:
	# Convertir les coordonnées mondiales en coordonnées du plateau (0-7, 0-7)
	# L'origine (0,0) est en bas à gauche (a1)
	# Chaque case fait 1.0 unité
	
	var x = int(floor(world_pos.x / CELL_SIZE))
	var z = int(floor(world_pos.z / CELL_SIZE))
	
	# Clamper pour rester dans les limites du plateau
	x = clamp(x, 0, BOARD_WIDTH - 1)
	z = clamp(z, 0, BOARD_HEIGHT - 1)
	
	return Vector2i(x, z)

func board_to_world_position(board_pos: Vector2i) -> Vector3:
	# Convertir les coordonnées du plateau en coordonnées mondiales
	# Formule standard : file × taille_case + taille_case/2
	# 
	# Origine (0,0) = a1 en bas à gauche
	# Case a1 (0,0) → (0.5, 0, 0.5)
	# Case b1 (1,0) → (1.5, 0, 0.5)
	# Case e4 (4,3) → (4.5, 0, 3.5)
	
	var x = board_pos.x * CELL_SIZE + (CELL_SIZE / 2.0)
	var z = board_pos.y * CELL_SIZE + (CELL_SIZE / 2.0)
	
	return Vector3(x, 0.0, z)

func select_piece_at(board_pos: Vector2i):
	# Vérifier s'il y a une pièce à cette position
	if board_pieces.has(board_pos):
		var piece_data = board_pieces[board_pos]
		selected_piece = piece_data
		print("Pièce sélectionnée: ", piece_data.color, " ", piece_data.type, " à ", board_pos)
		
		clear_highlights()
		# Afficher les cases valides autour (pour test)
		show_valid_moves(board_pos)
	else:
		print("Aucune pièce à la position: ", board_pos)

func show_valid_moves(from_pos: Vector2i):
	# Exemple simple: montrer quelques cases autour
	var test_positions = [
		from_pos + Vector2i(1, 0),
		from_pos + Vector2i(-1, 0),
		from_pos + Vector2i(0, 1),
		from_pos + Vector2i(0, -1),
	]
	
	for pos in test_positions:
		if is_valid_board_position(pos):
			create_highlight(pos, Color.GREEN)

func move_piece_to(board_pos: Vector2i):
	# TODO: Logique de déplacement de pièce
	clear_highlights()
	selected_piece = null

func create_highlight(board_pos: Vector2i, color: Color):
	var highlight = HIGHLIGHT_SCENE.instantiate()
	add_child(highlight)
	
	var world_pos = board_to_world_position(board_pos)
	highlight.position = world_pos
	
	# Configurer la couleur du highlight
	if highlight.has_method("set_color"):
		highlight.set_color(color)
	
	current_highlights.append(highlight)

func clear_highlights():
	for highlight in current_highlights:
		highlight.queue_free()
	current_highlights.clear()

func is_valid_board_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_WIDTH and pos.y >= 0 and pos.y < BOARD_HEIGHT
