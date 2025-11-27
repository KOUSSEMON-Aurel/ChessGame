#tool

extends Node

# Return a chess piece object defaulting to a White Pawn
# Now returns a Node3D with a GLB model loaded
func get_piece(key = "P", side = "W"):
	# Map piece keys to GLB filenames
	var piece_names = {
		"B": "Bishop",
		"K": "King",
		"N": "Knight",
		"P": "Pawn",
		"Q": "Queen",
		"R": "Rook"
	}
	
	var piece_name = piece_names.get(key, "Pawn")
	var glb_path = "res://Assets_Pieces/" + piece_name + ".glb"
	
	# Load the GLB scene
	var piece_scene = load(glb_path)
	if piece_scene == null:
		push_error("Failed to load piece: " + glb_path)
		return null
	
	# Instance the scene
	var piece_node = piece_scene.instantiate()
	if piece_node == null:
		push_error("Failed to instantiate piece: " + glb_path)
		return null
	
	# Create a container Node3D to hold the piece
	var container = Node3D.new()
	container.add_child(piece_node)
	
	# Center the piece node relative to the container
	# We use a smart centering that focuses on the base of the piece
	_center_piece_smart(piece_node)
	
	# GLB models are EXTREMELY small - need massive scale
	# Adjust if too big or too small (try 700.0, 1000.0, 1500.0)
	container.scale = Vector3(1500.0, 1500.0, 1500.0)
	
	# Rotate pieces for white side to face the correct direction
	if side == "W":
		container.rotation_degrees.y = 0
		_colorize_white_piece(container)
	else:
		# Colorize Black pieces
		_colorize_black_piece(container)
	
	return container

func _center_piece_smart(piece_node: Node3D):
	# Smart centering:
	# 1. Calculate global AABB to fix Y (put bottom at 0)
	# 2. Find the "base" mesh (lowest Y) to fix X and Z centering
	
	var meshes = _find_all_mesh_instances(piece_node)
	if meshes.is_empty():
		return

	var combined_aabb: AABB
	var base_mesh_aabb: AABB
	var min_y = INF
	var first = true
	
	for mesh in meshes:
		var aabb = mesh.get_aabb()
		# Transform to piece_node space
		var trans = piece_node.transform.affine_inverse() * _get_relative_transform(mesh, piece_node)
		aabb = trans * aabb
		
		if first:
			combined_aabb = aabb
			first = false
		else:
			combined_aabb = combined_aabb.merge(aabb)
		
		# Check if this is the base (lowest mesh)
		# We look for the mesh with the lowest bottom edge
		if aabb.position.y < min_y:
			min_y = aabb.position.y
			base_mesh_aabb = aabb
		elif abs(aabb.position.y - min_y) < 0.01:
			# If multiple meshes are at the bottom, merge their AABBs for base calculation
			base_mesh_aabb = base_mesh_aabb.merge(aabb)
	
	if not first:
		# For X and Z, use the center of the BASE mesh(es) only
		# This avoids Knights being off-center due to their head sticking out
		var base_center = base_mesh_aabb.position + base_mesh_aabb.size / 2.0
		
		# For Y, use the bottom of the combined AABB (should be same as base min_y)
		var bottom_y = combined_aabb.position.y
		
		var offset = Vector3(-base_center.x, -bottom_y, -base_center.z)
		
		# Apply offset
		piece_node.position = offset

func _get_relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t = Transform3D.IDENTITY
	var current = node
	while current != root and current != null:
		t = current.transform * t
		current = current.get_parent()
	return t

func _find_all_mesh_instances(node: Node) -> Array:
	var meshes = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_find_all_mesh_instances(child))
	return meshes

func _colorize_black_piece(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			# Create a new material or override existing
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.2, 0.2) # Dark Grey
			mat.roughness = 1.0 # Matte
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			child.material_override = mat
		_colorize_black_piece(child)

func _colorize_white_piece(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			# Create a new material or override existing
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.85, 0.85) # Brighter white/grey
			mat.roughness = 1.0 # Matte
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			child.material_override = mat
		_colorize_white_piece(child)


func set_piece_drag_state(node: Node3D, active: bool):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.material_override
			if mat:
				mat.no_depth_test = active
				mat.render_priority = 1 if active else 0
		set_piece_drag_state(child, active)


func promote(p: Piece, promote_to = "q"):
	p.key = promote_to.to_upper()
	var parent = p.obj.get_parent()
	if p.obj != null:
		p.obj.queue_free() # Delete pawn
	# Now add the new piece in place of the pawn
	p.obj = get_piece(p.key, p.side)
	if p.obj != null and parent != null:
		parent.add_child(p.obj)
