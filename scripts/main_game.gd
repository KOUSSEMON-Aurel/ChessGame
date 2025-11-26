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

# Mapping des types C# vers noms de modèles
const TYPE_MAPPING = {
	1: "pawn",
	2: "knight",
	3: "bishop",
	4: "rook",
	5: "queen",
	6: "king"
}

# Variables pour la logique visuelle
var selected_piece = null
var current_highlights = []
var board_pieces = {}  # Dictionnaire visuel : index (0-63) -> {container, node, type, color}

# Matériaux
var white_material = preload("res://materials/piece_white.tres")
var black_material = preload("res://materials/piece_black.tres")

# Référence au contrôleur C#
@onready var game_controller = $GameController

func _ready():
	print("🚀 Démarrage du jeu (Mode Hybride C#/GDScript)...")
	
	# Connecter le signal du contrôleur C#
	game_controller.MovePlayed.connect(_on_move_played)
	
	# Initialiser le plateau visuel
	setup_visual_board()
	
	print("✅ Jeu prêt !")

func setup_visual_board():
	print("  - Initialisation visuelle du plateau...")
	
	# Nettoyer l'existant
	for idx in board_pieces:
		board_pieces[idx].container.queue_free()
	board_pieces.clear()
	
	# Parcourir les 64 cases et créer les pièces selon l'état du C#
	for i in range(64):
		var type_int = game_controller.GetPieceTypeAt(i)
		if type_int != 0: # Pas vide
			var color_int = game_controller.GetPieceColorAt(i)
			var piece_type = TYPE_MAPPING.get(type_int, "pawn")
			var color_str = "white" if color_int == 0 else "black"
			
			create_visual_piece(piece_type, color_str, i)
			
	print("✅ Plateau visuel synchronisé !")

func create_visual_piece(piece_type: String, color: String, index: int):
	# Charger le modèle
	var model_path = PIECE_MODELS.get(piece_type)
	if model_path == null: return
	
	var piece_scene = load(model_path)
	if piece_scene == null: return
	
	var piece = piece_scene.instantiate()
	
	# === CONTENEURISATION ===
	var piece_container = Node3D.new()
	piece_container.name = color + "_" + piece_type + "_" + str(index)
	
	# Positionner
	var world_pos = index_to_world(index)
	piece_container.position = world_pos
	
	add_child(piece_container)
	piece_container.add_child(piece)
	
	# Échelle et Centrage
	piece.scale = Vector3(15.0, 15.0, 15.0)
	
	if piece.is_inside_tree():
		piece.force_update_transform()
	
	var aabb = calculate_piece_aabb(piece)
	if aabb != null:
		var center_offset = aabb.get_center()
		var offset_x = -center_offset.x * piece.scale.x
		var offset_z = -center_offset.z * piece.scale.z
		var offset_y = -aabb.position.y * piece.scale.y
		piece.position = Vector3(offset_x, offset_y, offset_z)
	else:
		piece.position = Vector3.ZERO
		
	piece.rotation_degrees = Vector3.ZERO
	
	# Matériau
	apply_material_to_piece(piece, color)
	
	# Stocker
	board_pieces[index] = {
		"container": piece_container,
		"node": piece,
		"type": piece_type,
		"color": color,
		"index": index
	}

# --- Conversion Coordonnées ---

func index_to_world(index: int) -> Vector3:
	var x = index % 8
	var z = index / 8
	# Formule standard : file * 1.0 + 0.5
	return Vector3(x * 1.0 + 0.5, 0.0, z * 1.0 + 0.5)

func world_to_index(world_pos: Vector3) -> int:
	var x = int(floor(world_pos.x))
	var z = int(floor(world_pos.z))
	if x < 0 or x > 7 or z < 0 or z > 7: return -1
	return z * 8 + x

# --- Gestion des Inputs ---

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Test IA avec Espace
		game_controller.PlayAIMove()

func handle_click(screen_pos):
	var camera = get_viewport().get_camera_3d()
	if camera == null: return
		
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var clicked_index = world_to_index(result.position)
		if clicked_index == -1: return
		
		if selected_piece:
			# Tenter de jouer le coup via C#
			var success = game_controller.TryPlayMove(selected_piece.index, clicked_index)
			if not success:
				# Si échec, peut-être changer de sélection ?
				if board_pieces.has(clicked_index) and board_pieces[clicked_index].color == selected_piece.color:
					select_piece(clicked_index)
				else:
					deselect()
			else:
				deselect()
		else:
			select_piece(clicked_index)

func select_piece(index: int):
	if not board_pieces.has(index): return
	
	# Vérifier si c'est notre tour ou couleur (optionnel, géré par C# mais bon pour UI)
	# Pour l'instant on sélectionne tout
	
	selected_piece = board_pieces[index]
	print("Selection: ", index)
	
	clear_highlights()
	
	# Demander les coups valides au C#
	var valid_moves = game_controller.GetValidMoves(index)
	for target in valid_moves:
		create_highlight(index_to_world(target), Color.GREEN)

func deselect():
	selected_piece = null
	clear_highlights()

func create_highlight(world_pos: Vector3, color: Color):
	var highlight = HIGHLIGHT_SCENE.instantiate()
	add_child(highlight)
	highlight.position = world_pos
	if highlight.has_method("set_color"):
		highlight.set_color(color)
	current_highlights.append(highlight)

func clear_highlights():
	for h in current_highlights: h.queue_free()
	current_highlights.clear()

# --- Callbacks du Jeu ---

func _on_move_played(from: int, to: int, promotion_type: int):
	print("⚡ Move confirmed by Engine: ", from, " -> ", to)
	
	# Animer le déplacement visuel
	if not board_pieces.has(from): return # Erreur sync ?
	
	var piece_data = board_pieces[from]
	var target_world = index_to_world(to)
	
	# Capture ?
	if board_pieces.has(to):
		var captured = board_pieces[to]
		# VFX Explosion
		spawn_explosion(captured.container.position)
		captured.container.queue_free()
		board_pieces.erase(to)
	
	# Mise à jour données
	board_pieces.erase(from)
	board_pieces[to] = piece_data
	piece_data.index = to
	
	# Animation Juice
	animate_move(piece_data, target_world)

func animate_move(piece_data, target_pos):
	var container = piece_data.container
	var node = piece_data.node
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Saut parabolique
	var jump_h = 2.0
	var duration = 0.4
	
	tween.tween_property(container, "position:x", target_pos.x, duration)
	tween.tween_property(container, "position:z", target_pos.z, duration)
	
	var jump_tween = create_tween()
	jump_tween.tween_property(container, "position:y", jump_h, duration/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(container, "position:y", 0.0, duration/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Squash & Stretch
	var normal_scale = Vector3(15, 15, 15)
	var stretch = Vector3(12, 18, 12)
	var squash = Vector3(18, 12, 18)
	
	var scale_tween = create_tween()
	scale_tween.tween_property(node, "scale", stretch, duration * 0.2)
	scale_tween.tween_property(node, "scale", normal_scale, duration * 0.6)
	scale_tween.tween_callback(func():
		var land = create_tween()
		land.tween_property(node, "scale", squash, 0.1)
		land.tween_property(node, "scale", normal_scale, 0.2)
		
		# Screen Shake
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("apply_shake"): cam.apply_shake(0.3)
	).set_delay(duration)

func spawn_explosion(pos):
	var explosion = load("res://scenes/vfx/capture_explosion.tscn").instantiate()
	add_child(explosion)
	explosion.position = pos
	explosion.emitting = true
	get_tree().create_timer(2.0).timeout.connect(explosion.queue_free)

# --- Utilitaires ---

func calculate_piece_aabb(root_node: Node3D):
	var combined_aabb: AABB
	var first = true
	var has_mesh = false
	var mesh_instances = find_all_mesh_instances(root_node)
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh != null:
			has_mesh = true
			var local_aabb = mesh_instance.mesh.get_aabb()
			var relative_transform = root_node.global_transform.affine_inverse() * mesh_instance.global_transform
			var transformed_aabb = relative_transform * local_aabb
			if first:
				combined_aabb = transformed_aabb
				first = false
			else:
				combined_aabb = combined_aabb.merge(transformed_aabb)
	if not has_mesh: return null
	return combined_aabb

func find_all_mesh_instances(node: Node) -> Array:
	var instances = []
	if node is MeshInstance3D: instances.append(node)
	for child in node.get_children(): instances.append_array(find_all_mesh_instances(child))
	return instances

func apply_material_to_piece(node: Node, color: String):
	var material = white_material if color == "white" else black_material
	if node is MeshInstance3D:
		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				node.set_surface_override_material(i, material)
	for child in node.get_children():
		apply_material_to_piece(child, color)
