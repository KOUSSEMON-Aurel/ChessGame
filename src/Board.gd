extends Control

class_name Board
# Board script - Force recompile

signal clicked(p)
signal unclicked(p)
signal halfmove(m)
signal fullmove(m)
signal taken(p)

@export var square_width = 70 # pixels (base for calculations)
@export var white: Color # Square color
@export var grey: Color # Square color
@export var mod_color: Color # For highlighting squares

const num_squares = 64
enum { SIDE, UNDER }

var grid : Array # Map of what pieces are placed on the board
var r_count = 0 # Rook counter
var R_count = 0 # Rook counter
var halfmoves = 0 # Used with fifty-move rule. Reset after pawn move or piece capture
var fullmoves = 0 # Incremented after Black's move
var passant_pawn : Piece
var kings = {}
var fen = ""
var default_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 0"
var cleared = true
var highlighed_tiles = []
var pieces_3d_container : Node3D # Container for 3D pieces
var board_3d_container : Node3D # Container for 3D board tiles

# Visuals & Audio
var last_move_highlights = [] # Stores indices of start/end squares
var tween_move: Tween
var audio_players = {}
var highlight_pulse_tween: Tween
var move_indicator: MoveIndicator
var board_tiles_meshes = [] # To store references to MeshInstance3D tokens

# 3D Materials
var mat_white: StandardMaterial3D
var mat_grey: StandardMaterial3D
var mat_highlight: StandardMaterial3D
var mat_last_move_white: StandardMaterial3D
var mat_last_move_black: StandardMaterial3D
var mat_hint_move: StandardMaterial3D
var mat_hint_capture: StandardMaterial3D
var mat_hint_risk_red: StandardMaterial3D
var mat_hint_risk_yellow: StandardMaterial3D

var dragged_piece: Piece = null
var drag_offset: Vector3 = Vector3.ZERO
var camera_controller: ChessCameraController = null
var board_effects: BoardEffects = null
var cloth_board_mesh: ClothBoardMesh = null

# Input control - set by Main.gd
var input_enabled: bool = true

func _ready():
	# grid will map the pieces in the game
	grid.resize(num_squares)
	
	# Override highlight color to Cyan (remove Yellow)
	mod_color = Color(0.0, 1.0, 1.0, 0.7)
	
	_init_materials()
	
	# Create 3D container for pieces in the SubViewport
	var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if subviewport != null:
		if not subviewport.has_node("Pieces3D"):
			pieces_3d_container = Node3D.new()
			pieces_3d_container.name = "Pieces3D"
			subviewport.add_child(pieces_3d_container)
		else:
			pieces_3d_container = subviewport.get_node("Pieces3D")
			
		if not subviewport.has_node("Board3D"):
			board_3d_container = Node3D.new()
			board_3d_container.name = "Board3D"
			subviewport.add_child(board_3d_container)
			subviewport.move_child(board_3d_container, 0)
		else:
			board_3d_container = subviewport.get_node("Board3D")
	else:
		# Fallback
		if not has_node("Pieces3D"):
			pieces_3d_container = Node3D.new()
			pieces_3d_container.name = "Pieces3D"
			add_child(pieces_3d_container)
			
			board_3d_container = Node3D.new()
			board_3d_container.name = "Board3D"
			add_child(board_3d_container)
		else:
			pieces_3d_container = get_node("Pieces3D")
			if has_node("Board3D"):
				board_3d_container = get_node("Board3D")
			else:
				board_3d_container = Node3D.new()
				board_3d_container.name = "Board3D"
				add_child(board_3d_container)
	
	if not has_node("MoveIndicator"):
		move_indicator = MoveIndicator.new()
		move_indicator.name = "MoveIndicator"
		add_child(move_indicator)
	else:
		move_indicator = get_node("MoveIndicator")
	
	# Initialiser le contrôleur de caméra
	var sub_vp = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if sub_vp:
		camera_controller = sub_vp.get_node_or_null("Camera3D") as ChessCameraController
		if camera_controller:
			print("✅ Camera Controller initialized in Board")
	
	# Initialiser le système d'effets visuels
	board_effects = BoardEffects.new()
	board_effects.name = "BoardEffects"
	add_child(board_effects)
	# Les tiles seront assignées après draw_tiles_3d()
	
	draw_tiles_3d()
	
	# Initialiser le mesh tissu (ClothBoardMesh)
	if sub_vp:
		cloth_board_mesh = sub_vp.get_node_or_null("ClothBoardMesh") as ClothBoardMesh
		if cloth_board_mesh:
			print("✅ ClothBoardMesh initialized in Board")
			# Masquer les tiles 3D individuelles - le mesh tissu les remplace visuellement
			if board_3d_container:
				board_3d_container.visible = false
	
	# Initialize markers after viewport and tiles are ready
	_init_markers()
	
	_init_audio()
	
	setup_pieces()

func _init_materials():
	mat_white = StandardMaterial3D.new()
	mat_white.albedo_color = white
	mat_white.roughness = 1.0
	mat_white.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	mat_grey = StandardMaterial3D.new()
	mat_grey.albedo_color = grey
	mat_grey.roughness = 1.0
	mat_grey.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	mat_highlight = StandardMaterial3D.new()
	mat_highlight.albedo_color = mod_color
	mat_highlight.emission_enabled = true
	mat_highlight.emission = mod_color
	mat_highlight.emission_energy_multiplier = 0.3
	
	mat_last_move_white = StandardMaterial3D.new()
	mat_last_move_white.albedo_color = Color(0.4, 0.6, 1.0, 1.0)
	mat_last_move_white.roughness = 1.0
	mat_last_move_white.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	mat_last_move_black = StandardMaterial3D.new()
	mat_last_move_black.albedo_color = Color(0.2, 0.4, 0.8, 1.0)
	mat_last_move_black.roughness = 1.0
	mat_last_move_black.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	mat_hint_move = StandardMaterial3D.new()
	mat_hint_move.albedo_color = Color.GREEN
	
	mat_hint_capture = StandardMaterial3D.new()
	mat_hint_capture.albedo_color = Color.RED
	mat_hint_capture.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_hint_capture.albedo_color.a = 0.5
	
	mat_hint_risk_red = StandardMaterial3D.new()
	mat_hint_risk_red.albedo_color = Color.RED
	
	mat_hint_risk_yellow = StandardMaterial3D.new()
	mat_hint_risk_yellow.albedo_color = Color.YELLOW

func _init_audio():
	var sounds = {
		"move": "res://assets/audio/move.wav",
		"capture": "res://assets/audio/capture.wav",
		"check": "res://assets/audio/check.wav",
		"start": "res://assets/audio/start.wav",
		"end": "res://assets/audio/end.wav"
	}
	
	for key in sounds:
		var player = AudioStreamPlayer.new()
		player.name = "Audio_" + key
		if FileAccess.file_exists(sounds[key]):
			var stream = load(sounds[key])
			if stream:
				player.stream = stream
		else:
			print("Warning: Audio file not found: ", sounds[key])
		add_child(player)
		audio_players[key] = player

func play_sound(key):
	if audio_players.has(key) and audio_players[key].stream != null:
		audio_players[key].play()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		pass # print("[BOARD] _input appelé, input_enabled=", input_enabled)
	
	# Check if input is disabled (e.g., menu is open)
	if not input_enabled:
		pass # print("[BOARD] Input désactivé, abandon")
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var grid_pos = get_grid_from_mouse()
			if grid_pos != Vector2(-1, -1):
				_handle_board_click(grid_pos.x, grid_pos.y)
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var grid_pos = get_grid_from_mouse()
			_handle_board_release(grid_pos.x, grid_pos.y)
			
	elif event is InputEventMouseMotion:
		_handle_mouse_motion()
		
	# DEBUG: Test indicators
	if event is InputEventKey and event.pressed:
		var test_pos = Vector2(4, 4)
		if event.keycode == KEY_1:
			show_indicator(test_pos, MoveIndicator.Type.GOOD)
		elif event.keycode == KEY_2:
			show_indicator(test_pos, MoveIndicator.Type.BRILLIANT)
		elif event.keycode == KEY_3:
			show_indicator(test_pos, MoveIndicator.Type.EXCELLENT)
		elif event.keycode == KEY_4:
			show_indicator(test_pos, MoveIndicator.Type.BEST)
		elif event.keycode == KEY_5:
			show_indicator(test_pos, MoveIndicator.Type.BLUNDER)
		elif event.keycode == KEY_6:
			show_indicator(test_pos, MoveIndicator.Type.INACCURACY)
		# TEST: Déformation tissu avec touche T
		elif event.keycode == KEY_T:
			if cloth_board_mesh:
				print("🧪 Test déformation tissu à (4, 4)")
				cloth_board_mesh.deform_at(4, 4, 1.0)

func _on_HighlightTimer_timeout():
	pass

func get_grid_from_mouse() -> Vector2:
	var subviewport_container = get_node_or_null("Container/SubViewportContainer")
	if not subviewport_container: return Vector2(-1, -1)
	var subviewport = subviewport_container.get_node_or_null("SubViewport")
	if not subviewport: return Vector2(-1, -1)
	var camera = subviewport.get_node_or_null("Camera3D")
	if not camera: return Vector2(-1, -1)
	
	# Convertir la position globale de la souris en position locale au SubViewportContainer
	var global_mouse_pos = get_viewport().get_mouse_position()
	var local_mouse_pos = global_mouse_pos - subviewport_container.get_global_rect().position
	
	# Ajuster pour le ratio entre la taille du container et celle du SubViewport
	var container_size = subviewport_container.size
	var viewport_size = subviewport.size
	if container_size.x > 0 and container_size.y > 0:
		local_mouse_pos.x = local_mouse_pos.x * viewport_size.x / container_size.x
		local_mouse_pos.y = local_mouse_pos.y * viewport_size.y / container_size.y
	
	var from = camera.project_ray_origin(local_mouse_pos)
	var dir = camera.project_ray_normal(local_mouse_pos)
	
	var n = Vector3(0, 1, 0)
	var denom = dir.dot(n)
	if abs(denom) < 0.0001: return Vector2(-1, -1)
	
	var t = -from.dot(n) / denom
	var hit_pos = from + dir * t
	
	# DEBUG: Print pour diagnostiquer
	# print("[DEBUG] global=", global_mouse_pos, " local=", local_mouse_pos, " hit=", hit_pos)
	
	# Find closest tile
	var best_dist = 99999.0
	var best_grid = Vector2(-1, -1)
	
	for y in 8:
		for x in 8:
			var idx = get_grid_index(x, y)
			if markers.has(idx):
				var pos = markers[idx]
				var dist = Vector2(hit_pos.x, hit_pos.z).distance_to(Vector2(pos.x, pos.z))
				if dist < best_dist:
					best_dist = dist
					best_grid = Vector2(x, y)
	
	if best_dist < 100.0:
		return best_grid
	return Vector2(-1, -1)

func _handle_board_click(x, y):
	var p = get_piece_in_grid(x, y)
	if p != null:
		dragged_piece = p
		Pieces.set_piece_drag_state(p.obj, true)
		
		# Drag offset - utiliser les coordonnées locales
		var hit_pos = _get_mouse_hit_on_plane()
		if hit_pos != null and p.obj:
			drag_offset = p.obj.position - hit_pos
		
		# print("DEBUG: Drag start ", p.key)
		emit_signal("clicked", p)

func _handle_board_release(x, y):
	if dragged_piece != null:
		if x != -1 and y != -1:
			# print("DEBUG: Drag end ", dragged_piece.key, " at ", x, ",", y)
			dragged_piece.new_pos = Vector2(x, y)
		Pieces.set_piece_drag_state(dragged_piece.obj, false)
		emit_signal("unclicked", dragged_piece)
		dragged_piece = null

func _handle_mouse_motion():
	if dragged_piece != null and dragged_piece.obj != null:
		var hit_pos = _get_mouse_hit_on_plane()
		if hit_pos != null:
			dragged_piece.obj.position = hit_pos + drag_offset + Vector3(0, 10, 0)

# Helper: Obtenir la position 3D de la souris sur le plan Y=0
func _get_mouse_hit_on_plane():
	var subviewport_container = get_node_or_null("Container/SubViewportContainer")
	if not subviewport_container: return null
	var subviewport = subviewport_container.get_node_or_null("SubViewport")
	if not subviewport: return null
	var camera = subviewport.get_node_or_null("Camera3D")
	if not camera: return null
	
	# Convertir en coordonnées locales
	var global_mouse_pos = get_viewport().get_mouse_position()
	var local_mouse_pos = global_mouse_pos - subviewport_container.get_global_rect().position
	
	var container_size = subviewport_container.size
	var viewport_size = subviewport.size
	if container_size.x > 0 and container_size.y > 0:
		local_mouse_pos.x = local_mouse_pos.x * viewport_size.x / container_size.x
		local_mouse_pos.y = local_mouse_pos.y * viewport_size.y / container_size.y
	
	var from = camera.project_ray_origin(local_mouse_pos)
	var dir = camera.project_ray_normal(local_mouse_pos)
	
	if abs(dir.y) < 0.0001: return null
	var t = -from.y / dir.y
	return from + dir * t

# Added missing functions
func cancel_drag():
	if dragged_piece != null:
		# print("DEBUG: Cancelling drag for ", dragged_piece.key)
		Pieces.set_piece_drag_state(dragged_piece.obj, false) 
		return_piece(dragged_piece)
		dragged_piece = null

func return_piece(p):
	if p.obj != null:
		var target = get_marker_position(get_grid_index(p.pos.x, p.pos.y))
		p.obj.position = target

# Legacy 2D grid generation removed, replaced by empty func or just removed
func draw_tiles():
	pass

func draw_tiles_3d():
	board_tiles_meshes.resize(64)
	
	# Compute mesh size roughly from markers of (0,0) and (1,1) if they existed
	# Or just rely on markers generation which is based on square_width
	var p0 = get_3d_pos_from_2d(Vector2(0,0))
	var p1 = get_3d_pos_from_2d(Vector2(1,0))
	var p2 = get_3d_pos_from_2d(Vector2(0,1))
	
	var tile_width = p0.distance_to(p1)
	var tile_height = p0.distance_to(p2)
	
	if tile_width < 1.0 or tile_height < 1.0:
		# Markers not initialized yet properly or camera issue?
		# get_3d_pos_from_2d depends on camera in subviewport.
		# If this runs in _ready, camera should be there.
		# Fallback to estimation from 2D mapping
		tile_width = 70.0 # Just a guess but likely inaccurate in 3D world units
		# Actually, Looking at Tscn: Camera Y is 1000. 
		# If fov is default, scale is large.
		pass

	var mesh = BoxMesh.new()
	# Height 5.0 thickness
	mesh.size = Vector3(tile_width, 5.0, tile_height)
	
	var odd = true
	for y in 8:
		odd = !odd
		for x in 8:
			odd = !odd
			var idx = get_grid_index(x, y)
			
			var tile = MeshInstance3D.new()
			tile.name = "Tile_%d_%d" % [x, y]
			tile.mesh = mesh
			
			if odd:
				tile.material_override = mat_white
			else:
				tile.material_override = mat_grey
			
			var pos = get_3d_pos_from_2d(Vector2(x,y))
			# Center is at pos, but pos is surface Y=0
			# We want top face at 0. BoxMesh origin is center.
			tile.position = pos - Vector3(0, 2.5, 0) 
			
			board_3d_container.add_child(tile)
			board_tiles_meshes[idx] = tile
	
	# Assigner les tiles au système d'effets
	if board_effects:
		board_effects.board_tiles = board_tiles_meshes
		board_effects.set_board_reference(self)  # Pour le losange
		print("✅ Board tiles assigned to BoardEffects (%d tiles)" % board_tiles_meshes.size())

func get_grid_index(x: int, y: int):
	return x + 8 * y

func get_piece_in_grid(x: int, y: int):
	var p = grid[get_grid_index(x, y)]
	return p

# Conversion helpers
func position_to_move(pos: Vector2) -> String:
	assert(pos.x >= 0)
	assert(pos.y >= 0)
	assert(pos.x < 8)
	assert(pos.y < 8)
	return "%s%d" % [char(97 + int(pos.x)), 8 - int(pos.y)]

func move_to_position(move: String) -> Vector2:
	assert(move.length() == 2)
	var pos = Vector2(move.unicode_at(0) - 97, 8 - int(move[1]))
	assert(pos.x >= 0)
	assert(pos.y >= 0)
	assert(pos.x < 8)
	assert(pos.y < 8)
	return pos

func pgn_to_long(pgn: String, side: String):
	print(pgn, " ", side)
	var m = ""
	var ch = pgn[0]
	if ch.unicode_at(0) > 96: # a .. h
		var y
		if pgn[1] == "x":
			m = pgn.substr(0, 4)
			y = int(pgn[3])
		else:
			m = pgn.substr(0, 2)
			m += m
			y = int(pgn[1])
		m[1] = String(8 - find_pawn_in_col(ch, y, side))
		return m
	if pgn.begins_with("O-O-O"):
		if side == "B": return "e8b8"
		else: return "e1b1"
	if pgn.begins_with("O-O"):
		if side == "B": return "e8g8"
		else: return "e1g1"
	pgn = pgn.replace("x", "").substr(1).rstrip("+")
	if pgn.length() > 2:
		if pgn[0].is_valid_int():
			m = char(97 + find_piece_in_row(pgn[0], ch, side)) + pgn
		else:
			m = pgn[0] + String(8 - find_piece_in_col(pgn[0], ch, side)) + pgn.substr(1)
	else:
		m = find_piece_in_grid(ch, side, move_to_position(pgn)) + pgn
	return m

func find_piece_in_row(n, key, side):
	var y = 8 - int(n)
	for x in 8:
		var i = get_grid_index(x, y)
		if grid[i] != null and grid[i].key == key and grid[i].side == side:
			return x
	return -1

func find_piece_in_col(ch, key, side):
	var x = ch.unicode_at(0) - 97
	for y in 8:
		var i = get_grid_index(x, y)
		if grid[i] != null and grid[i].key == key and grid[i].side == side:
			return y
	return -1

func find_piece_in_grid(key, side, pos: Vector2):
	for i in 64:
		var p = grid[i]
		if p != null and p.key == key and p.side == side:
			p.new_pos = pos
			if get_position_info(p, true, true).ok:
				return position_to_move(p.pos)

func find_pawn_in_col(ch, y, side):
	var x = ch.unicode_at(0) - 97
	var dy = 1 if side == "W" else -1
	y = 8 - y + dy
	var i = get_grid_index(x, y)
	if grid[i] != null:
		return y if grid[i].key == "P" else -1
	else: 
		y += dy
		i = get_grid_index(x, y)
		if grid[i] != null:
			return y if grid[i].key == "P" else -1
	return -1

func setup_pieces(_fen = default_fen):
	var parts = _fen.split(" ")
	var next_move_white = parts.size() < 2 or parts[1] == "w"
	var castling = "" if parts.size() < 3 else parts[2]
	r_count = 0
	R_count = 0
	var i = 0
	for ch in parts[0]:
		match ch:
			"/": pass
			"1", "2", "3", "4", "5", "6", "7", "8": i += int(ch)
			_:
				set_piece(ch, i, castling)
				i += 1 
	if parts.size() >= 4 and parts[3].length() == 2:
		i = parts[3][0].to_ascii_buffer()[0] - 96
		if i >= 0 and i < 8:
			match parts[3][1]:
				"3": tag_piece(i + 32)
				"6": tag_piece(i + 24)
	if parts.size() >= 5 and parts[4].is_valid_int():
		set_halfmoves(parts[4].to_int())
	if parts.size() >= 6 and parts[5].is_valid_int():
		set_fullmoves(parts[5].to_int())
	return next_move_white

func get_fen(next_move):
	var gi = 0
	var ns = 0
	var castling = ""
	var _fen = ""
	for y in 8:
		for x in 8:
			var p = grid[gi]
			gi += 1
			if p == null:
				ns += 1
			else:
				if ns > 0:
					_fen += str(ns)
					ns = 0
				var key = p.key
				if p.side == "B": key = key.to_lower()
				_fen += key
		if ns > 0:
			_fen += str(ns)
			ns = 0
		if y < 7: _fen += "/"
	if is_tagged(0) and is_tagged(4): castling += "q"
	if is_tagged(4) and is_tagged(7): castling += "k"
	if is_tagged(56) and is_tagged(60): castling += "Q"
	if is_tagged(60) and is_tagged(63): castling += "K"
	var pas = "-"
	var pos
	if passant_pawn != null:
		pos = passant_pawn.pos
		if passant_pawn.side == "B": pos.y -= 1
		else: pos.y += 1
		pas = position_to_move(pos)
	_fen += " %s %s %s %d %d" % [next_move, castling, pas, halfmoves, fullmoves]
	return _fen

func is_tagged(i):
	return grid[i] != null and grid[i].tagged

func tag_piece(i: int):
	if grid[i] != null:
		grid[i].tagged = true

func set_piece(key: String, i: int, castling: String):
	var p = Piece.new()
	p.key = key.to_upper()
	p.side = "W" if "a" > key else "B"
	@warning_ignore("integer_division")
	p.pos = Vector2(i % 8, i / 8)
	p.obj = Pieces.get_piece(p.key, p.side)
	grid[i] = p
	
	if p.obj != null:
		var marker_pos = get_marker_position(i)
		p.obj.position = marker_pos
		pieces_3d_container.add_child(p.obj)
	
	match key:
		"r":
			r_count += 1
			if r_count == 1: p.tagged = "q" in castling
			else: p.tagged = "k" in castling
		"k":
			p.tagged = "k" in castling or "q" in castling
			kings[p.side] = p
		"R":
			R_count += 1
			if R_count == 1: p.tagged = "Q" in castling
			else: p.tagged = "K" in castling
		"K":
			p.tagged = "K" in castling or "Q" in castling
			kings[p.side] = p

var markers = {}

func get_marker_position(index: int) -> Vector3:
	if markers.has(index): return markers[index]
	var x = index % 8
	@warning_ignore("integer_division")
	var y = index / 8
	return get_3d_pos_from_2d(Vector2(x, y))

func _init_markers():
	for y in 8:
		for x in 8:
			var index = get_grid_index(x, y)
			var pos3d = get_3d_pos_from_2d(Vector2(x, y))
			markers[index] = pos3d

func get_3d_pos_from_2d(grid_pos: Vector2) -> Vector3:
	var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if subviewport == null: return Vector3.ZERO
	var camera = subviewport.get_node_or_null("Camera3D")
	if camera == null: return Vector3.ZERO
	
	var width = float(square_width) if square_width else 70.0
	var offset = width / 2.0
	var screen_pos = Vector2(
		grid_pos.x * width + offset,
		grid_pos.y * width + offset
	)
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var n = Vector3(0, 1, 0)
	var t = -from.dot(n) / dir.dot(n)
	var intersection = from + dir * t
	return intersection

func clear_board():
	for i in 64:
		take_piece(grid[i], false)
	cleared = true

func take_piece(p: Piece, emit = true):
	if p == null: return
	if p.obj != null and p.obj.get_parent() != null:
		p.obj.get_parent().remove_child(p.obj)
		p.obj.queue_free()
	grid[get_grid_index(p.pos.x, p.pos.y)] = null
	set_halfmoves(0)
	if emit: emit_signal("taken", p)

func set_halfmoves(n):
	halfmoves = n
	emit_signal("halfmove", n)

func set_fullmoves(n):
	fullmoves = n
	emit_signal("fullmove", n)

func move_piece(p: Piece, _engine_turn: bool, was_capture: bool = false):
	var start_pos_idx = get_grid_index(p.pos.x, p.pos.y)
	var end_pos_idx = get_grid_index(p.new_pos.x, p.new_pos.y)
	
	var is_promotion = (p.key == "P" and (p.new_pos.y == 0 or p.new_pos.y == 7))
	var is_castling = (p.key == "K" and abs(p.new_pos.x - p.pos.x) > 1)
	
	var indicator_type = null
	
	# 🎬 CAMERA: Préparer la position cible 3D pour le zoom
	var target_3d_pos = get_marker_position(end_pos_idx)
	
	if is_promotion:
		indicator_type = MoveIndicator.Type.BRILLIANT
		play_sound("promote")
		if camera_controller: camera_controller.dynamic_zoom("promotion", target_3d_pos)
		# 🎨 EFFETS: Ondulation dorée + Highlight
		if board_effects:
			board_effects.highlight_square(p.new_pos, Color.GOLD, 1.0)
			# Couleur BRILLIANT (bleu) pour promotion
			if move_indicator:
				board_effects.create_ripple_effect(p.new_pos, 1.2, move_indicator.type_colors[MoveIndicator.Type.BRILLIANT])

	elif is_castling:
		indicator_type = MoveIndicator.Type.EXCELLENT
		play_sound("castle")
		if camera_controller: camera_controller.dynamic_zoom("castle", target_3d_pos)
		# 🎨 EFFETS: Double ondulation (roi + tour)
		if board_effects:
			# Couleur EXCELLENT (vert) pour roque
			var castle_color = Color.GREEN
			if move_indicator: castle_color = move_indicator.type_colors[MoveIndicator.Type.EXCELLENT]
			board_effects.create_ripple_effect(p.pos, 0.8, castle_color)
			board_effects.create_ripple_effect(p.new_pos, 0.8, castle_color)

	elif grid[end_pos_idx] != null or was_capture:
		play_sound("capture")
		var r = randf()
		if r < 0.1: indicator_type = MoveIndicator.Type.BRILLIANT
		elif r < 0.4: indicator_type = MoveIndicator.Type.BEST
		else: indicator_type = MoveIndicator.Type.GOOD
		
		# 🎨 EFFETS: Ondulation rouge pour capture
		if board_effects:
			board_effects.highlight_square(p.new_pos, Color.RED, 0.6)
			if p.key != "P": # Pas pour pions
				board_effects.create_ripple_effect(p.new_pos, 1.5, Color.RED)
		
		# 🎬 CAMERA: Zoom sur capture
		if camera_controller:
			var captured_piece = grid[end_pos_idx]
			if captured_piece and (captured_piece.key == "Q" or captured_piece.key == "R"):
				camera_controller.dynamic_zoom("capture_major", target_3d_pos)
			else:
				camera_controller.dynamic_zoom("capture", target_3d_pos)
		


	else:
		play_sound("move")
		if randf() < 0.3: indicator_type = MoveIndicator.Type.GOOD
		
		# 🎬 CAMERA: Zoom léger sur coup normal
		if camera_controller: camera_controller.dynamic_zoom("normal", target_3d_pos)
		

	
	if indicator_type != null:
		show_indicator(p.new_pos, indicator_type)
	
	grid[start_pos_idx] = null
	grid[end_pos_idx] = p
	p.pos = p.new_pos
	
	if p.obj != null:
		var target_pos = get_marker_position(end_pos_idx)
		var start_pos = get_marker_position(start_pos_idx)
		var distance = start_pos.distance_to(target_pos)
		
		# 🎨 ANIMATIONS SPÉCIALES: Déterminer l'animation selon contexte
		var is_capture = (grid[end_pos_idx] != null or was_capture)
		var move_context = {
			"is_capture": is_capture,
			"is_promotion": is_promotion,
			"is_castling": is_castling,
			"distance": distance
		}
		
		# Sélection automatique de l'animation
		var anim_type = PieceAnimations.get_animation_for_piece(p.key, move_context)
		var anim_params = PieceAnimations.get_animation_params(start_pos, target_pos, p.key, move_context)
		
		# SCREEN SHAKE: Configurer callback d'impact pour pièces lourdes
		if camera_controller:
			var shake_intensity = 0.0
			# Captures lourdes (Dame, Tour, Roi) ou Roque
			if (p.key in ["Q", "R", "K"] and is_capture) or is_castling:
				shake_intensity = 0.3
			# Sauts longs (Tour)
			elif p.key == "R" and distance > 200:
				shake_intensity = 0.25
			# Captures standard
			elif is_capture:
				shake_intensity = 0.15
				
			if shake_intensity > 0.0:
				anim_params["on_impact"] = func(): 
					camera_controller.add_camera_shake(shake_intensity, 0.2)
		
		# Jouer l'animation
		p.is_moving = true # 🌊 Empêcher la vague de modifier la hauteur pendant le saut
		var _tween = PieceAnimations.play_animation(p.obj, anim_type, anim_params)
		
		# Réactiver la physique de vague + Effés après atterrissage
		if _tween:
			_tween.finished.connect(func(): 
				p.is_moving = false
				# 🎯 Cratère modulé selon emoji (ChessFX)
				if cloth_board_mesh:
					# Intensité selon rareté de l'emoji
					var crater_intensity = 0.8  # Augmenté pour visibilité (était 0.4)
					var return_time = 0.35
					
					if indicator_type == MoveIndicator.Type.BRILLIANT:
						crater_intensity = 1.5  # Très rare, très visible
						return_time = 0.4
					elif indicator_type == MoveIndicator.Type.EXCELLENT:
						crater_intensity = 1.2
						return_time = 0.4
					elif indicator_type == MoveIndicator.Type.INACCURACY:
						crater_intensity = 1.0
						return_time = 0.4
					elif indicator_type == MoveIndicator.Type.BLUNDER:
						crater_intensity = 1.3
						return_time = 0.5  # Plus lent = "pèse"
					
					cloth_board_mesh.deform_at(int(p.new_pos.x), int(p.new_pos.y), crater_intensity, return_time)
				
				# 💎 Losange lumineux SEULEMENT pour les emojis spéciaux
				_trigger_diamond_highlight(p.new_pos, indicator_type)
			)
		else:
			p.is_moving = false
		
		# Attendre la fin de l'animation avant de continuer (optionnel)
		# Note: Comme le code original n'attendait pas, on garde ce comportement

	
	if p != passant_pawn:
		passant_pawn = null
	
	if p.key == "P" and abs(p.new_pos.y - p.pos.y) == 2:
		passant_pawn = p
		
	p.tagged = false
	if p.key == "P": set_halfmoves(0)
	else: set_halfmoves(halfmoves + 1)
	if p.side == "B": set_fullmoves(fullmoves + 1)
	
	clear_last_move_highlights()
	
	# Colorer le mouvement UNIQUEMENT si un emoji est présent (Demande utilisateur)
	# Les coups normaux (70%) n'auront plus de highlight jaune
	if indicator_type != null and move_indicator:
		var move_color = Color(1, 0.84, 0, 0.5) # Fallback
		if move_indicator.type_colors.has(indicator_type):
			var c = move_indicator.type_colors[indicator_type]
			move_color = Color(c.r, c.g, c.b, 0.85) # Plus opaque pour garder la vraie couleur (Bleu reste Bleu)
			
		highlight_last_move(start_pos_idx, end_pos_idx, move_color)
	
	cleared = false
	
	# 🎬 CAMERA: Vérifier si ce coup a causé un échec ou mat pour l'effet de caméra
	if camera_controller:
		# On vérifie si ce coup met le roi adverse en échec
		var check_info = is_king_checked(p) 
		# Note: is_king_checked vérifie l'état actuel. Si on vient de bouger, p est la pièce qui a bougé.
		# La fonction originale semble vérifier si "side" est en échec. 
		# Si p.side vient de jouer, on veut savoir si l'ADVERSAIRE est en échec.
		# La fonction is_king_checked utilise p.side ou l'inverse.
		# Regardons l'implémentation de is_king_checked : 
		# "if p.side == "B": side = "W"; else: side = "B"" -> Elle checke l'opposant !
		# Donc c'est parfait.
		
		if check_info.mated:
			var king = kings[check_info.side]
			var king_pos = get_marker_position(get_grid_index(king.pos.x, king.pos.y))
			# NOTE: Détection de mat locale potentiellement instable (voir Main.gd), 
			# on utilise l'effet de check standard pour éviter de bloquer la caméra sur un faux mat.
			camera_controller.dynamic_zoom("check", king_pos)
			
			# 🎨 EFFETS: Pulsation + Flash pour Mat
			if board_effects:
				board_effects.pulse_square(king.pos, 1.4, 3)
				board_effects.flash_board(Color(0.5, 0, 0, 0.3), 1.0) 
		elif check_info.checked:
			var king = kings[check_info.side]
			var king_pos = get_marker_position(get_grid_index(king.pos.x, king.pos.y))
			camera_controller.dynamic_zoom("check", king_pos)
			
			# 🎨 EFFETS: Highlight orange pour Échec
			if board_effects:
				board_effects.highlight_square(king.pos, Color.ORANGE, 0.8)
		else:
			# Si pas de check/mat, on reset la caméra après un délai
			# Nous utilisons un timer oneshot pour ne pas bloquer
			get_tree().create_timer(1.5).timeout.connect(func(): camera_controller.reset_camera())

func highlight_last_move(start_idx, end_idx, color: Color = Color(1, 1, 0, 0.4)):
	last_move_highlights = []
	
	# Coins de départ et d'arrivée
	var start_pos = Vector2(start_idx % 8, start_idx / 8)
	var end_pos = Vector2(end_idx % 8, end_idx / 8)
	
	# Ajouter départ et arrivée
	last_move_highlights.append(start_idx)
	last_move_highlights.append(end_idx)
	
	# Calculer le chemin (trajet) - Sauf pour Cavalier qui saute
	var diff = end_pos - start_pos
	var steps = int(max(abs(diff.x), abs(diff.y)))
	
	# Si c'est un mouvement linéaire (ligne, colonne, diagonale)
	# Le cavalier a steps != max(dx, dy) sauf si dx ou dy est 0, mais cavalier fait (1,2) ou (2,1).
	# Cavalier : |dx|=1,|dy|=2 -> steps=2. Mais diff n'est pas multiple entier de direction unitaire simple.
	# Vérif: abs(dx) == abs(dy) (diag) OU dx=0 OU dy=0 (ortho)
	var is_linear = (abs(diff.x) == abs(diff.y)) or (diff.x == 0) or (diff.y == 0)
	
	if is_linear and steps > 1:
		var dir = diff / steps
		for i in range(1, steps):
			var inter_pos = start_pos + dir * i
			var idx = int(inter_pos.x + inter_pos.y * 8)
			if not idx in last_move_highlights:
				last_move_highlights.append(idx)
	
	# Appliquer la couleur via ClothBoardMesh (Shader texture)
	if cloth_board_mesh:
		for idx in last_move_highlights:
			var grid_x = idx % 8
			var grid_y = idx / 8
			cloth_board_mesh.set_highlight(grid_x, grid_y, color)
	else:
		# Fallback vers board_effects si pas de ClothBoardMesh
		if board_effects:
			for idx in last_move_highlights:
				var pos = Vector2(idx % 8, idx / 8)
				board_effects.set_permanent_highlight(pos, color)

func clear_last_move_highlights():
	if cloth_board_mesh:
		cloth_board_mesh.clear_all_highlights()
	elif board_effects:
		for idx in last_move_highlights:
			var pos = Vector2(idx % 8, idx / 8)
			board_effects.clear_permanent_highlight(pos)
	
	last_move_highlights = []



func is_king_checked(p: Piece):
	var side = p.side
	if p.key == "K":
		return { "checked": is_checked(p.new_pos.x, p.new_pos.y, side), "mated": false, "side": side }
	else:
		if p.side == "B": side = "W"
		else: side = "B"
		var pos = Vector2(kings[side].pos.x, kings[side].pos.y)
		var mated = false
		var checked = is_checked(pos.x, pos.y, side)
		if checked:
			var offsets = [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]]
			mated = true
			for o in offsets:
				if king_can_move_to(pos.x + o[0], pos.y + o[1], side):
					mated = is_checked(pos.x + o[0], pos.y + o[1], side)
				if !mated: break
		return { "checked": checked, "mated": mated, "side": side }

func king_can_move_to(x, y, side):
	if x < 0 or x > 7 or y < 0 or y > 7: return false
	var p = get_piece_in_grid(x, y)
	return p == null or p.side != side

func is_checked(x, y, side):
	var key1 = "P"
	var key2 = ""
	var can = false
	if side == "B":
		can = can_attack(x - 1, y + 1, side, key1) or can_attack(x + 1, y + 1, side, key1)
	else:
		can = can_attack(x - 1, y - 1, side, key1) or can_attack(x + 1, y - 1, side, key1)
	if can: return can
	
	key1 = "K"
	if can_attack(x - 1, y + 1, side, key1) or can_attack(x + 1, y + 1, side, key1) or can_attack(x - 1, y - 1, side, key1) or can_attack(x + 1, y - 1, side, key1):
		return true
	
	key1 = "R"
	key2 = "Q"
	if scan_for_attacking_piece(x, y, 1, 0, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, -1, 0, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, 0, -1, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, 0, 1, side, key1, key2): return true
	
	key1 = "B"
	if scan_for_attacking_piece(x, y, -1, -1, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, 1, -1, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, -1, 1, side, key1, key2): return true
	if scan_for_attacking_piece(x, y, 1, 1, side, key1, key2): return true
	
	key1 = "N"
	if can_attack(x - 1, y + 2, side, key1) or can_attack(x + 1, y + 2, side, key1) or can_attack(x - 1, y - 2, side, key1) or can_attack(x + 1, y - 2, side, key1) or can_attack(x - 2, y - 1, side, key1) or can_attack(x - 2, y + 1, side, key1) or can_attack(x + 2, y - 1, side, key1) or can_attack(x + 2, y + 1, side, key1):
		return true
	return false

func scan_for_attacking_piece(ox, oy, incx, incy, side, key1, key2 = ""):
	var can = false
	var j = ox
	var k = oy
	var p = null
	while(p == null):
		j += incx
		k += incy
		if j < 0 or j > 7 or k < 0 or k > 7:
			break
		p = get_piece_in_grid(j, k)
		can = p != null and p.side != side and (p.key == key1 or p.key == key2)
	return can


func can_attack(x, y, side, key):
	if x < 0 or x > 7 or y < 0 or y > 7:
		return false
	var p = get_piece_in_grid(x, y)
	return p != null and p.side != side and p.key == key


# Hints & Highlights

func test_highlight_square():
	for n in num_squares:
		highlight_square(n)
		await get_tree().create_timer(0.1).timeout
		highlight_square(n, false)


func highlight_square(n: int, apply = true):
	assert(n >= 0)
	assert(n < num_squares)
	
	if board_tiles_meshes[n] == null: return
	var tile = board_tiles_meshes[n]
	
	# Stop any existing pulse
	if highlight_pulse_tween and highlight_pulse_tween.is_running():
		pass
		
	if apply:
		tile.material_override = mat_highlight
		# Pulse effect for selection
		# Note: tweening material properties on shared materials affects all instances if not unique
		# MeshInstance3D has material_override which can be unique-ified
		# Current implementation uses shared mat_highlight, so no color tweening unless we duplicate material
		# For performance, maybe just stick to static highlight for now or duplicate material
		
		# Simple static highlight for now to avoid complexity of unique materials
		
	else:
		var x = n % 8
		@warning_ignore("integer_division")
		var y = n / 8
		var is_white_square = ((x + y) % 2) == 0
		if is_white_square:
			tile.material_override = mat_white
		else:
			tile.material_override = mat_grey


func show_indicator(grid_pos: Vector2, type: MoveIndicator.Type):
	if move_indicator:
		# Use 3D position logic
		var idx = get_grid_index(int(grid_pos.x), int(grid_pos.y))
		var pos3d = get_marker_position(idx)
		
		# MoveIndicator seems to be 2D/Control based (extends Control potentially?) in previous code
		# Let's check if MoveIndicator is a Node3D or Control.
		# Original code used spawn_indicator_at_pos with local_pos from 2D grid.
		# If MoveIndicator is 2D, we need to map 3D pos to 2D screen pos.
		
		var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
		var camera = subviewport.get_node_or_null("Camera3D")
		if camera:

			# MoveIndicator is child of Board (UI), so coordinates must be local to Board
			# Board is full screen or margin container?
			# get_global_transform() ... 
			
			# Simplified: Just pass screen_pos relative to MoveIndicator
			# But MoveIndicator code isn't visible here to know its parent space.
			# Assuming MoveIndicator is direct child of Board (MarginContainer/Control)
			
			# Correction: We can still use 2D logic but we need to find where the square IS on screen
			# get_3d_pos_from_2d was doing 2D -> 3D.
			# Now we reverse.
			
			# Use 3D tracking with 3D offset to maintain visual position regardless of zoom
			# Calculate tile orientation vectors
			var p0 = get_marker_position(0)
			var p1 = get_marker_position(1)
			var p8 = get_marker_position(8)
			var v_right = p1 - p0  # Full width vector
			var v_down = p8 - p0   # Full height vector
			
			# Original screen offset was (55, -38) on a ~70px tile
			# This translates to ~0.78 right and ~0.54 up from center
			# Apply this ratio in 3D space so it scales with zoom
			var offset_3d = (v_right * 0.78) - (v_down * 0.54)
			var target_3d = pos3d + offset_3d
			
			# Now use minimal 2D offset since positioning is handled in 3D
			move_indicator.spawn_indicator_3d(target_3d, camera, type, 1.5, Vector2.ZERO)
	else:
		push_warning("MoveIndicator not found")


func test_square_is_white():
	# Removed test dependency on 2D grid
	pass

# Hints - 3D Implementation Reference
# Reusing markers system, but using 3D meshes for hints
var hint_mesh_instances = []

func show_hints(piece: Piece):
	clear_hints()
	var piece_vals = { "P": 1, "N": 3, "B": 3, "R": 5, "Q": 9, "K": 100 }
	
	for y in 8:
		for x in 8:
			var original_new_pos = piece.new_pos
			piece.new_pos = Vector2(x, y)
			
			var info = get_position_info(piece, true)
			
			if info["ok"]:
				var target_piece = info["piece"]
				var is_capture = target_piece != null or (info["passant"] and passant_pawn != null)
				
				var mat = mat_hint_move 
				
				if is_capture:
					var my_val = piece_vals.get(piece.key, 0)
					var target_val = 0
					if target_piece:
						target_val = piece_vals.get(target_piece.key, 0)
					elif info["passant"]:
						target_val = 1
					
					var is_defended = is_checked(x, y, piece.side)
					
					if not is_defended:
						mat = mat_hint_risk_yellow 
					else:
						if my_val > target_val:
							mat = mat_hint_risk_red 
						else:
							mat = mat_hint_capture # Brownish/Red logic
				
				add_hint_marker_3d(x, y, mat)
			
			piece.new_pos = original_new_pos

func clear_hints():
	for m in hint_mesh_instances:
		m.queue_free()
	hint_mesh_instances = []

func add_hint_marker_3d(x, y, p_material):
	var pos = get_marker_position(get_grid_index(x, y))
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 15.0 # World units
	sphere.height = 30.0
	mesh_inst.mesh = sphere
	mesh_inst.material_override = p_material
	mesh_inst.position = pos + Vector3(0, 5, 0) # Slightly above board
	
	board_3d_container.add_child(mesh_inst)
	hint_mesh_instances.append(mesh_inst)

# Fallback AI (kept same logic)
func get_fallback_moves(side: String) -> Array:
	var moves = []
	var enemy_side = "B" if side == "W" else "W"
	# ... (Complete Logic preserved below)
	
	for i in range(num_squares):
		var p = grid[i]
		if p != null and p.side == side:
			var piece_moves = []
			var x = i % 8
			@warning_ignore("integer_division")
			var y = i / 8
			
			match p.key:
				"P":
					var dir = -1 if side == "W" else 1
					var promo_rank = 0 if side == "W" else 7
					if is_valid_pos(x, y + dir) and get_piece_in_grid(x, y + dir) == null:
						var move_str = pos_to_str(x, y) + pos_to_str(x, y + dir)
						if y + dir == promo_rank: move_str += "q"
						piece_moves.append(move_str)
						if (side == "W" and y == 6) or (side == "B" and y == 1):
							if is_valid_pos(x, y + dir * 2) and get_piece_in_grid(x, y + dir * 2) == null:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(x, y + dir * 2))
					for dx in [-1, 1]:
						if is_valid_pos(x + dx, y + dir):
							var target = get_piece_in_grid(x + dx, y + dir)
							if target != null and target.side == enemy_side:
								var cap_str = pos_to_str(x, y) + pos_to_str(x + dx, y + dir)
								if y + dir == promo_rank: cap_str += "q"
								piece_moves.append(cap_str)
				"N":
					var offsets = [[-1, -2], [1, -2], [-2, -1], [2, -1], [-2, 1], [2, 1], [-1, 2], [1, 2]]
					for o in offsets:
						var tx = x + o[0]
						var ty = y + o[1]
						if is_valid_pos(tx, ty):
							var target = get_piece_in_grid(tx, ty)
							if target == null or target.side == enemy_side:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
				"K":
					var offsets = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]
					for o in offsets:
						var tx = x + o[0]
						var ty = y + o[1]
						if is_valid_pos(tx, ty):
							var target = get_piece_in_grid(tx, ty)
							if (target == null or target.side == enemy_side):
								if !is_checked(tx, ty, side):
									piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
				"R", "B", "Q":
					var dirs = []
					if p.key == "R" or p.key == "Q":
						dirs.append_array([[0, 1], [0, -1], [1, 0], [-1, 0]])
					if p.key == "B" or p.key == "Q":
						dirs.append_array([[1, 1], [1, -1], [-1, 1], [-1, -1]])
					for d in dirs:
						var tx = x
						var ty = y
						while true:
							tx += d[0]
							ty += d[1]
							if !is_valid_pos(tx, ty): break
							var target = get_piece_in_grid(tx, ty)
							if target == null:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
							else:
								if target.side == enemy_side:
									piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
								break
			moves.append_array(piece_moves)
	return moves

func is_valid_pos(x, y):
	return x >= 0 and x < 8 and y >= 0 and y < 8

func pos_to_str(x, y):
	var cols = ["a", "b", "c", "d", "e", "f", "g", "h"]
	var rows = ["8", "7", "6", "5", "4", "3", "2", "1"]
	return cols[x] + rows[y]

func square_is_white(n: int):
	@warning_ignore("integer_division")
	return 0 == ((n / 8) + n) % 2

func get_position_info(p: Piece, non_player_move, _offset_divisor = square_width):
	# Re-adding the full body of get_position_info which was previously captured
	# It is identical to the one in previous step but ensures file completeness
	var castling = false
	var passant = false
	var x: int
	var y: int
	if non_player_move:
		x = int(p.new_pos.x - p.pos.x)
		y = int(p.new_pos.y - p.pos.y)
	else:
		var best_dist = INF
		var best_pos = p.pos
		for cy in 8:
			for cx in 8:
				var marker = get_marker_position(get_grid_index(cx, cy))
				var dist = Vector2(p.obj.position.x, p.obj.position.z).distance_to(Vector2(marker.x, marker.z))
				if dist < best_dist:
					best_dist = dist
					best_pos = Vector2(cx, cy)
		p.new_pos = best_pos
		x = int(p.new_pos.x - p.pos.x)
		y = int(p.new_pos.y - p.pos.y)
		
	if p.new_pos.x < 0 or p.new_pos.y < 0 or p.new_pos.x > 7 or p.new_pos.y > 7:
		return { "ok": false }
	var ax = int(abs(x))
	var ay = int(abs(y))
	var p2 = get_piece_in_grid(p.new_pos.x, p.new_pos.y)
	var ok = false
	var check_path = true
	match p.key:
		"P":
			if p.side == "B":
				ok = y == 1
				if p.pos.y == 1 and y == 2: ok = true
				passant = y == 1 and ax == 1 and p.pos.y == 4
			else:
				ok = y == -1
				if p.pos.y == 6 and -2 == y: ok = true
				passant = y == -1 and ax == 1 and p.pos.y == 3
			if ok:
				if ax == 1 and ay == 1: ok = p2 != null or passant
				else: ok = ax == 0 and p2 == null
		"R": ok = ax > 0 and ay == 0 or ax == 0 and ay > 0
		"B": ok = ax == ay
		"K":
			ok = ax < 2 and ay < 2
			if ax == 2 and ay == 0 and p2 == null and p.tagged:
				if p.side == "B" and p.pos.x == 4 and p.pos.y == 0 or p.side == "W" and p.pos.x == 4 and p.pos.y == 7:
					castling = true
					ok = true
		"N":
			check_path = false
			ok = ax == 2 and ay == 1 or ax == 1 and ay == 2
		"Q": ok = true
	if ok and p2 != null:
		ok = p.side == "B" and p2.side == "W" or p.side == "W" and p2.side == "B"
	if check_path and ok and (ax > 1 or ay > 1):
		var checking = true
		while checking:
			if ax > 0: x -= int(sign(x))
			if ay > 0: y -= int(sign(y))
			var p3 = get_piece_in_grid(p.pos.x + x, p.pos.y + y)
			ok = p3 == null
			ax -= 1
			ay -= 1
			checking = (ax > 1 or ay > 1) and ok
	if !ok and p == passant_pawn:
		passant_pawn = null
	return { "ok": ok, "piece": p2, "castling": castling, "passant": passant }

func _process(delta):
	# 🌊 EFFET VAGUE : Synchronisation pièces/mesh
	if not cloth_board_mesh:
		return
		
	for piece in grid:
		# Ignorer les cases vides et les pièces en animation
		if piece == null or piece.obj == null:
			continue
		if piece.is_moving:
			continue
			
		# Calculer la hauteur cible sous la pièce
		var target_height = cloth_board_mesh.get_height_at(piece.obj.position)
		
		# Suivre la hauteur avec lissage rapide (quasi instantané mais sans jitter)
		piece.obj.position.y = lerpf(piece.obj.position.y, target_height, delta * 25.0)

func _trigger_diamond_highlight(grid_pos: Vector2, indicator_type):
	"""
	Affiche le losange lumineux UNIQUEMENT pour les coups marquants.
	Filtrage strict : BRILLIANT/EXCELLENT/INACCURACY/BLUNDER
	"""
	
	if indicator_type == null or not board_effects:
		return
	
	# Filtre : seulement les emojis qui méritent un losange coloré
	var special_types = [
		MoveIndicator.Type.BRILLIANT,
		MoveIndicator.Type.EXCELLENT,
		MoveIndicator.Type.INACCURACY,
		MoveIndicator.Type.BLUNDER
	]
	
	if not indicator_type in special_types:
		return  # Pas de losange pour GOOD/BEST/null
	
	# Couleurs selon type (via MoveIndicator pour cohérence totale)
	var diamond_color = Color.WHITE
	if move_indicator and move_indicator.type_colors.has(indicator_type):
		diamond_color = move_indicator.type_colors[indicator_type]
	else:
		# Fallback manuel si nécessaire (ne devrait pas arriver avec le filtre ci-dessus)
		match indicator_type:
			MoveIndicator.Type.BRILLIANT: diamond_color = Color(0, 0.8, 1)
			MoveIndicator.Type.EXCELLENT: diamond_color = Color(0, 1, 0.3)
			MoveIndicator.Type.INACCURACY: diamond_color = Color(1, 0.7, 0)
			MoveIndicator.Type.BLUNDER: diamond_color = Color(1, 0.2, 0.2)
			_: return
	
	# Petit délai pour effet pro
	await get_tree().create_timer(0.03).timeout
	
	# Afficher le losange lumineux
	board_effects.create_diamond_highlight(grid_pos, diamond_color, 0.6)
