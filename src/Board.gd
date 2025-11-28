extends Control

class_name Board

signal clicked
signal unclicked
signal halfmove
signal fullmove
signal taken

@export var square_width = 64 # pixels (same as chess piece images)
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

# Visuals & Audio
var last_move_highlights = [] # Stores indices of start/end squares
var tween_move: Tween
var audio_players = {}
var highlight_pulse_tween: Tween


func _ready():
	# grid will map the pieces in the game
	grid.resize(num_squares)
	
	# Override highlight color to Cyan (remove Yellow)
	mod_color = Color(0.0, 1.0, 1.0, 0.7)
	
	# Create 3D container for pieces in the SubViewport
	var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if subviewport != null:
		if not subviewport.has_node("Pieces3D"):
			pieces_3d_container = Node3D.new()
			pieces_3d_container.name = "Pieces3D"
			subviewport.add_child(pieces_3d_container)
		else:
			pieces_3d_container = subviewport.get_node("Pieces3D")
	else:
		# Fallback: create as direct child
		if not has_node("Pieces3D"):
			pieces_3d_container = Node3D.new()
			pieces_3d_container.name = "Pieces3D"
			add_child(pieces_3d_container)
		else:
			pieces_3d_container = get_node("Pieces3D")
	
	draw_tiles()
	
	# Initialize markers after viewport and tiles are ready
	# We need to wait one frame for the camera to be fully updated? 
	# Actually Raycast depends on Camera transform which is set in scene.
	_init_markers()
	
	_init_audio()
	
	#hide_labels()
	# Set board layout using Forsyth Edwards encoded string
	#setup_pieces("r1b1k2r/5pp1/p3p2p/2b4P/2BnnKP1/1P41q/P1PP4/1RBQ4 w qk - 43 21")
	setup_pieces()

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

	#test_square_is_white()
	#test_highlight_square()
	#print(position_to_move(Vector2(0, 0)))
	#print(move_to_position("h1"))
	#highlighed_tiles = [0,2,4,6,8]
	#$HighlightTimer.start()
	#highlight_square(highlighed_tiles[0])
	#test_pgn_to_long_conversion()

#func _gui_input(event):
#	print("Main receive Event : ", event)

func test_pgn_to_long_conversion():
	print(pgn_to_long("a4", "W"))
	print(pgn_to_long("h3", "W"))
	print(pgn_to_long("axb3", "W"))
	print(pgn_to_long("Nbc3", "W"))
	print(pgn_to_long("Nbxc3", "W"))
	print(pgn_to_long("Nf3", "W"))
	print(pgn_to_long("Nxf3", "W"))
	print(pgn_to_long("N1xc3", "W"))
	print(pgn_to_long("N1c3", "W"))
	print(pgn_to_long("O-O", "W"))
	print(pgn_to_long("O-O-O", "W"))
	print(pgn_to_long("O-O", "B"))
	print(pgn_to_long("O-O-O", "B"))
	print(pgn_to_long("a5", "B"))
	print(pgn_to_long("h6", "B"))
	print(pgn_to_long("axb6", "B"))
	print(pgn_to_long("Nbc6", "B"))
	print(pgn_to_long("Nbxc6", "B"))
	print(pgn_to_long("Nf6", "B"))
	print(pgn_to_long("Nxf6", "B"))
	print(pgn_to_long("N8xc6", "B"))
	print(pgn_to_long("N8c6", "B"))


# convert grid position to move code e.g. 0,0 -> a8
func position_to_move(pos: Vector2) -> String:
	assert(pos.x >= 0)
	assert(pos.y >= 0)
	assert(pos.x < 8)
	assert(pos.y < 8)
	return "%s%d" % [char(97 + int(pos.x)), 8 - int(pos.y)]


# convert move code to grid position e.g. h1 -> 7,7
func move_to_position(move: String) -> Vector2:
	assert(move.length() == 2)
	var pos = Vector2(move.unicode_at(0) - 97, 8 - int(move[1]))
	assert(pos.x >= 0)
	assert(pos.y >= 0)
	assert(pos.x < 8)
	assert(pos.y < 8)
	return pos


# The following code requires that the piece layout is in sync with the moves
# If the user moves a piece, then the pgn move list should be wiped
# The idea is to play back the moves of a game and take over at any point
func pgn_to_long(pgn: String, side: String):
	print(pgn, " ", side)
	var m = ""
	var ch = pgn[0]
	# Pawn moves ignoring =Q in dxc1=Q
	if ch.unicode_at(0) > 96: # a .. h
		var y
		if pgn[1] == "x":
			m = pgn.substr(0, 4) #exf6 e?f6
			y = int(pgn[3])
		else:
			m = pgn.substr(0, 2) #f4
			m += m # fff4 f?f4
			y = int(pgn[1])
		m[1] = String(8 - find_pawn_in_col(ch, y, side))
		return m
	# Castling
	if pgn.begins_with("O-O-O"):
		if side == "B":
			return "e8b8"
		else:
			return "e1b1"
	if pgn.begins_with("O-O"):
		if side == "B":
			return "e8g8"
		else:
			return "e1g1"
	pgn = pgn.replace("x", "").substr(1).rstrip("+")
	if pgn.length() > 2: #Nef6 e?f6
		if pgn[0].is_valid_int(): # B1d4 ?1d4
			m = char(97 + find_piece_in_row(pgn[0], ch, side)) + pgn
		else:
			m = pgn[0] + String(8 - find_piece_in_col(pgn[0], ch, side)) + pgn.substr(1)
	else:
		# Here we have the least amount of move information e.g. #Nf6
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
			# See if piece can move to destination
			p.new_pos = pos
			if get_position_info(p, true, true).ok:
				return position_to_move(p.pos)


# Return -1 on error
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
			"/": # Next rank
				pass
			"1", "2", "3", "4", "5", "6", "7", "8":
				i += int(ch)
			_:
				set_piece(ch, i, castling)
				i += 1 
	# Tag pawn for en passant
	if parts.size() >= 4 and parts[3].length() == 2:
		i = parts[3][0].to_ascii_buffer()[0] - 96 # ASCII 'a' = 97
		if i >= 0 and i < 8:
			# Only valid rank is 3 or 6
			match parts[3][1]:
				"3":
					tag_piece(i + 32)
				"6":
					tag_piece(i + 24)
	# Set halfmoves value
	if parts.size() >= 5 and parts[4].is_valid_int():
		set_halfmoves(parts[4].to_int())
	# Set fullmoves value
	if parts.size() >= 6 and parts[5].is_valid_int():
		set_fullmoves(parts[5].to_int())
	return next_move_white


func get_fen(next_move):
	var gi = 0 # Grid index
	var ns = 0 # Number of blank horizontal tile places counter
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
				if p.side == "B":
					key = key.to_lower()
				_fen += key
		if ns > 0:
			_fen += str(ns)
			ns = 0
		if y < 7:
			_fen += "/"
	if is_tagged(0) and is_tagged(4):
		castling += "q"
	if is_tagged(4) and is_tagged(7):
		castling += "k"
	if is_tagged(56) and is_tagged(60):
		castling += "Q"
	if is_tagged(60) and is_tagged(63):
		castling += "K"
	var pas = "-"
	var pos
	if passant_pawn != null:
		pos = passant_pawn.pos
		if passant_pawn.side == "B":
			pos.y -= 1
		else:
			pos.y += 1
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
	
	# Position the 3D piece
	if p.obj != null:
		# Use pre-calculated marker position
		var marker_pos = get_marker_position(i)
		p.obj.position = marker_pos
		pieces_3d_container.add_child(p.obj)
	
	# Check castling rights
	match key:
		"r":
			r_count += 1
			if r_count == 1:
				p.tagged = "q" in castling
			else:
				p.tagged = "k" in castling
		"k":
			p.tagged = "k" in castling or "q" in castling
			kings[p.side] = p
		"R":
			R_count += 1
			if R_count == 1:
				p.tagged = "Q" in castling
			else:
				p.tagged = "K" in castling
		"K":
			p.tagged = "K" in castling or "Q" in castling
			kings[p.side] = p


var markers = {} # Cache for marker positions

func get_marker_position(index: int) -> Vector3:
	if markers.has(index):
		return markers[index]
	
	# Calculate position on the fly if not cached (fallback)
	var x = index % 8
	@warning_ignore("integer_division")
	var y = index / 8
	return get_3d_pos_from_2d(Vector2(x, y))

func _init_markers():
	# Create debug markers to visualize alignment
	for y in 8:
		for x in 8:
			var index = get_grid_index(x, y)
			var pos3d = get_3d_pos_from_2d(Vector2(x, y))
			markers[index] = pos3d
			
			# DEBUG: Add a small red sphere to see where the center is
			# Uncomment to see alignment dots
			# var debug_mesh = MeshInstance3D.new()
			# var sphere = SphereMesh.new()
			# sphere.radius = 10.0
			# sphere.height = 20.0
			# debug_mesh.mesh = sphere
			# var mat = StandardMaterial3D.new()
			# mat.albedo_color = Color(1, 0, 0)
			# debug_mesh.material_override = mat
			# debug_mesh.position = pos3d
			# if pieces_3d_container != null:
			# 	pieces_3d_container.add_child(debug_mesh)


func get_3d_pos_from_2d(grid_pos: Vector2) -> Vector3:
	var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if subviewport == null:
		return Vector3.ZERO
		
	var camera = subviewport.get_node_or_null("Camera3D")
	if camera == null:
		return Vector3.ZERO
	
	# Calculate center of the square in pixels relative to the viewport
	var offset = square_width / 2.0
	var screen_pos = Vector2(
		grid_pos.x * square_width + offset,
		grid_pos.y * square_width + offset
	)
	
	# Project ray from camera
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	# Intersect with plane Y=0
	# Plane equation: (p - p0) . n = 0
	# Ray equation: p = from + t * dir
	# t = (p0 - from) . n / (dir . n)
	# p0 = (0,0,0), n = (0,1,0)
	
	var n = Vector3(0, 1, 0)
	var t = -from.dot(n) / dir.dot(n)
	var intersection = from + dir * t
	
	return intersection


func clear_board():
	for i in 64:
		take_piece(grid[i], false)
	cleared = true


func take_piece(p: Piece, emit = true):
	if p == null:
		return
	if p.obj != null and p.obj.get_parent() != null:
		p.obj.get_parent().remove_child(p.obj)
		p.obj.queue_free()
	grid[get_grid_index(p.pos.x, p.pos.y)] = null
	set_halfmoves(0)
	if emit:
		emit_signal("taken", p)


func set_halfmoves(n):
	halfmoves = n
	emit_signal("halfmove", n)


func set_fullmoves(n):
	fullmoves = n
	emit_signal("fullmove", n)


func draw_tiles():
	var white_square = ColorRect.new()
	white_square.color = white
	white_square.mouse_filter = Control.MOUSE_FILTER_STOP
	white_square.custom_minimum_size = Vector2(square_width, square_width)
	var grey_square = white_square.duplicate()
	grey_square.color = grey
	# Add squares to grid
	var odd = true
	for y in 8:
		odd = !odd
		for x in 8:
			odd = !odd
			if odd:
				add_square(white_square.duplicate(), x, y)
			else:
				add_square(grey_square.duplicate(), x, y)


func add_square(s: ColorRect, x: int, y: int):
	s.connect("gui_input", Callable(self, "square_event").bind(x, y))
	#if x == 0:
	#	add_label(s, SIDE, str(8 - y))
	#if y == 7:
	#	add_label(s, UNDER, char(97 + x))
	$Container/Grid.add_child(s)


func add_label(node, pos, chr):
	var l = Label.new()
	l.add_to_group("labels")
	l.text = chr
	if pos == SIDE:
		l.position = Vector2(-square_width / 4.0, square_width / 2.3)
	else:
		l.position = Vector2(square_width / 2.3, square_width * 1.1)
	node.add_child(l)


var dragged_piece: Piece = null
var drag_offset: Vector3 = Vector3.ZERO

func cancel_drag():
	if dragged_piece != null:
		print("DEBUG: Cancelling drag for ", dragged_piece.key)
		Pieces.set_piece_drag_state(dragged_piece.obj, false) # Reset visual state
		return_piece(dragged_piece) # Snap back to original position
		dragged_piece = null

func square_event(event: InputEvent, x: int, y: int):
	if event is InputEventMouseButton:
		if event.pressed:
			get_viewport().set_input_as_handled()
			var p = get_piece_in_grid(x, y)
			if p != null:
				dragged_piece = p
				
				# Enable drag visual state (draw on top)
				Pieces.set_piece_drag_state(p.obj, true)
				
				# Calculate offset to prevent jumping
				var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
				if subviewport and p.obj:
					var camera = subviewport.get_node_or_null("Camera3D")
					if camera:
						var mouse_pos = get_viewport().get_mouse_position()
						var from = camera.project_ray_origin(mouse_pos)
						var dir = camera.project_ray_normal(mouse_pos)
						# Intersect with plane Y=0
						var t = -from.y / dir.y
						var hit_pos = from + dir * t
						drag_offset = p.obj.position - hit_pos
				
				print("DEBUG: Drag start ", p.key)
				emit_signal("clicked", p)
		else:
			# Release
			if dragged_piece != null:
				print("DEBUG: Drag end ", dragged_piece.key)
				Pieces.set_piece_drag_state(dragged_piece.obj, false) # Reset visual state
				emit_signal("unclicked", dragged_piece)
				dragged_piece = null
	
	elif event is InputEventMouseMotion:
		if dragged_piece != null and dragged_piece.obj != null:
			# Dragging logic
			var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
			if subviewport:
				var camera = subviewport.get_node_or_null("Camera3D")
				if camera:
					var mouse_pos = get_viewport().get_mouse_position()
					var from = camera.project_ray_origin(mouse_pos)
					var dir = camera.project_ray_normal(mouse_pos)
					
					# Intersect with plane Y=0
					var t = -from.y / dir.y
					var pos3d = from + dir * t
					
					# Apply offset
					# Add small Y offset (10) to lift slightly, rely on no_depth_test for visibility
					dragged_piece.obj.position = pos3d + drag_offset + Vector3(0, 10, 0)


func get_grid_index(x: int, y: int):
	return x + 8 * y


func get_piece_in_grid(x: int, y: int):
	var p = grid[get_grid_index(x, y)]
	return p


func move_piece(p: Piece, _engine_turn: bool):
	print("DEBUG: move_piece called for ", p.key, " to ", p.new_pos)
	var start_pos_idx = get_grid_index(p.pos.x, p.pos.y)
	var end_pos_idx = get_grid_index(p.new_pos.x, p.new_pos.y)
	
	# Handle Capture Sound
	var captured_piece = grid[end_pos_idx]
	if captured_piece != null:
		play_sound("capture")
	else:
		play_sound("move")
		
	# Update Grid
	grid[start_pos_idx] = null
	grid[end_pos_idx] = p
	p.pos = p.new_pos
	
	# Update 3D position with Animation
	if p.obj != null:
		var target_pos = get_marker_position(end_pos_idx)
		
		# Create Tween for smooth movement
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(p.obj, "position", target_pos, 0.3)
		
		# Add a small "hop" effect for knights or just general feel
		if p.key == "N":
			var mid_pos = (p.obj.position + target_pos) / 2.0
			mid_pos.y += 20.0 # Hop height
			# We would need a separate tween or property for arc, simplified here to direct slide
			pass
	
	if p != passant_pawn:
		passant_pawn = null
	
	# Set en passant pawn if double push
	if p.key == "P" and abs(p.new_pos.y - p.pos.y) == 2:
		passant_pawn = p
		
	p.tagged = false # Prevent castling after move
	if p.key == "P":
		set_halfmoves(0)
	else:
		set_halfmoves(halfmoves + 1)
	if p.side == "B":
		set_fullmoves(fullmoves + 1)
	
	# Highlights
	clear_last_move_highlights()
	highlight_last_move(start_pos_idx, end_pos_idx, p.side)
	
	cleared = false


func highlight_last_move(start_idx, end_idx, side):
	last_move_highlights = [start_idx, end_idx]
	for idx in last_move_highlights:
		var sqr = $Container/Grid.get_child(idx)
		var is_white_sq = square_is_white(idx)
		
		if side == "W":
			# Blue theme for White
			sqr.color = Color(0.4, 0.6, 1.0, 1.0) if is_white_sq else Color(0.2, 0.4, 0.8, 1.0)
		else:
			# Red/Purple theme for Black
			sqr.color = Color(1.0, 0.5, 0.5, 1.0) if is_white_sq else Color(0.8, 0.3, 0.3, 1.0)

func clear_last_move_highlights():
	for idx in last_move_highlights:
		highlight_square(idx, false)
	last_move_highlights = []



func is_king_checked(p: Piece):
	# We flip the side to be checked here depending on if the piece is a king or not
	var side = p.side
	if p.key == "K":
		return { "checked": is_checked(p.new_pos.x, p.new_pos.y, side) }
	else:
		if p.side == "B":
			side = "W"
		else:
			side = "B"
		var pos = Vector2(kings[side].pos.x, kings[side].pos.y)
		var mated = false
		var checked = is_checked(pos.x, pos.y, side)
		if checked:
			# Scan for check mate
			var offsets = [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]]
			mated = true
			for o in offsets:
				if king_can_move_to(pos.x + o[0], pos.y + o[1], side):
					mated = is_checked(pos.x + o[0], pos.y + o[1], side)
				if !mated:
					break
		return { "checked": checked, "mated": mated, "side": side }


func king_can_move_to(x, y, side):
	if x < 0 or x > 7 or y < 0 or y > 7:
		return false
	var p = get_piece_in_grid(x, y)
	return p == null or p.side != side


# Check if position is under attack
func is_checked(x, y, side):
	# pawns
	var key1 = "P"
	var key2 = ""
	var can = false
	if side == "B":
		can = can_attack(x - 1, y + 1, side, key1) or can_attack(x + 1, y + 1, side, key1)
	else:
		can = can_attack(x - 1, y - 1, side, key1) or can_attack(x + 1, y - 1, side, key1)
	if can:
		return can
	
	# king
	key1 = "K"
	if can_attack(x - 1, y + 1, side, key1) or can_attack(x + 1, y + 1, side, key1) or can_attack(x - 1, y - 1, side, key1) or can_attack(x + 1, y - 1, side, key1):
		return true
	
	# rooks and queen
	key1 = "R"
	key2 = "Q"
	if scan_for_attacking_piece(x, y, 1, 0, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, -1, 0, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, 0, -1, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, 0, 1, side, key1, key2):
		return true
	
	# bishops and queen
	key1 = "B"
	if scan_for_attacking_piece(x, y, -1, -1, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, 1, -1, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, -1, 1, side, key1, key2):
		return true
	if scan_for_attacking_piece(x, y, 1, 1, side, key1, key2):
		return true
	
	# Knight
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


func test_highlight_square():
	for n in num_squares:
		highlight_square(n)
		await get_tree().create_timer(0.1).timeout
		highlight_square(n, false)


func highlight_square(n: int, apply = true):
	assert(n >= 0)
	assert(n < num_squares)
	var sqr: ColorRect = $Container/Grid.get_child(n)
	
	# Stop any existing pulse
	if highlight_pulse_tween and highlight_pulse_tween.is_running():
		# Ideally we should track tweens per square, but for single selection this is ok
		pass
		
	if apply:
		sqr.color = mod_color
		# Pulse effect for selection
		var t = create_tween().set_loops()
		t.tween_property(sqr, "color", mod_color.lightened(0.2), 0.5)
		t.tween_property(sqr, "color", mod_color, 0.5)
		highlight_pulse_tween = t
	else:
		if highlight_pulse_tween:
			highlight_pulse_tween.kill()
			
		if square_is_white(n):
			sqr.color = white
		else:
			sqr.color = grey


func test_square_is_white():
	for n in num_squares:
		if $Container/Grid.get_child(n).color == white:
			assert(square_is_white(n))
		else:
			assert(!square_is_white(n))


# Génère tous les coups pseudo-légaux pour le mode élimination
# Autorise de laisser le Roi en échec, mais interdit de mettre le Roi en prise volontairement
func get_fallback_moves(side: String) -> Array:
	var moves = []
	var enemy_side = "B" if side == "W" else "W"
	print("DEBUG: get_fallback_moves called for side: ", side)
	
	for i in range(num_squares):
		var p = grid[i]
		if p != null and p.side == side:
			# print("DEBUG: Checking piece ", p.key, " at ", i)
			var piece_moves = []
			var x = i % 8
			@warning_ignore("integer_division")
			var y = i / 8
			
			match p.key:
				"P":
					var dir = -1 if side == "W" else 1
					# Avance de 1
					if is_valid_pos(x, y + dir) and get_piece_in_grid(x, y + dir) == null:
						piece_moves.append(pos_to_str(x, y) + pos_to_str(x, y + dir))
						# Avance de 2
						if (side == "W" and y == 6) or (side == "B" and y == 1):
							if is_valid_pos(x, y + dir * 2) and get_piece_in_grid(x, y + dir * 2) == null:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(x, y + dir * 2))
					# Captures
					for dx in [-1, 1]:
						if is_valid_pos(x + dx, y + dir):
							var target = get_piece_in_grid(x + dx, y + dir)
							if target != null and target.side == enemy_side:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(x + dx, y + dir))
				
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
								# Pour le Roi, on vérifie quand même s'il se met en échec (suicide interdit)
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
							if !is_valid_pos(tx, ty):
								break
							var target = get_piece_in_grid(tx, ty)
							if target == null:
								piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
							else:
								if target.side == enemy_side:
									piece_moves.append(pos_to_str(x, y) + pos_to_str(tx, ty))
								break # Bloqué par une pièce (amie ou ennemie)
			
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


# Check if it is valid to move to the new position of a piece
# Return true/false and null/piece that occupies the position plus
# castling and passant flags to indicate to check for these situations
func get_position_info(p: Piece, non_player_move, _offset_divisor = square_width):
	var castling = false
	var passant = false
	var x: int
	var y: int
	if non_player_move:
		x = int(p.new_pos.x - p.pos.x)
		y = int(p.new_pos.y - p.pos.y)
	else:
		# Calculate new_pos based on current 3D position
		# Find the closest square center (marker)
		var best_dist = INF
		var best_pos = p.pos
		
		# Optimization: only check nearby squares or all 64 (64 is fast enough)
		for cy in 8:
			for cx in 8:
				var marker = get_marker_position(get_grid_index(cx, cy))
				# Ignore Y height difference, only X/Z distance
				var dist = Vector2(p.obj.position.x, p.obj.position.z).distance_to(Vector2(marker.x, marker.z))
				if dist < best_dist:
					best_dist = dist
					best_pos = Vector2(cx, cy)
		
		p.new_pos = best_pos
		x = int(p.new_pos.x - p.pos.x)
		y = int(p.new_pos.y - p.pos.y)
		
	if p.new_pos.x < 0 or p.new_pos.y < 0 or p.new_pos.x > 7 or p.new_pos.y > 7:
		# piece dropped outside of grid
		return { "ok": false }
	var ax = int(abs(x))
	var ay = int(abs(y))
	var p2 = get_piece_in_grid(p.new_pos.x, p.new_pos.y)
	# Check for valid move
	# Don't care about bounds of the board since the piece will be released if outside
	var ok = false
	var check_path = true
	match p.key:
		"P": # Check for valid move of pawn
			if p.side == "B":
				ok = y == 1
				if p.pos.y == 1 and y == 2:
					ok = true
					# passant_pawn = p # Do not set it here, only in move_piece
				passant = y == 1 and ax == 1 and p.pos.y == 4
			else:
				ok = y == -1
				if p.pos.y == 6 and -2 == y:
					ok = true
					# passant_pawn = p # Do not set it here, only in move_piece
				passant = y == -1 and ax == 1 and p.pos.y == 3
			# Check for valid horizontal move
			if ok:
				if ax == 1 and ay == 1:
					# Diagonal move: only valid if capturing or en passant
					ok = p2 != null or passant
				else:
					# Forward move: only valid if empty
					ok = ax == 0 and p2 == null
		"R": # Check for valid horizontal or vertical move of rook
			ok = ax > 0 and ay == 0 or ax == 0 and ay > 0
		"B": # Check for valid diagonal move of bishop
			ok = ax == ay
		"K": # Check for valid move of king
			ok = ax < 2 and ay < 2
			if ax == 2 and ay == 0 and p2 == null and p.tagged: # Moved 2 steps in x and tagged
				if p.side == "B" and p.pos.x == 4 and p.pos.y == 0 or p.side == "W" and p.pos.x == 4 and p.pos.y == 7:
					castling = true # Potential castling situation
					ok = true
		"N": # Check for valid move of knight
			check_path = false # knight may jump over pieces
			ok = ax == 2 and ay == 1 or ax == 1 and ay == 2
		"Q": # Add the queen to the checking process of hopping over pieces
			ok = true
	# Check for landing on own piece
	if ok and p2 != null:
		ok = p.side == "B" and p2.side == "W" or p.side == "W" and p2.side == "B"
	# Check for passing over a piece
	if check_path and ok and (ax > 1 or ay > 1):
		var checking = true
		while checking:
			if ax > 0:
				x -= int(sign(x)) # Move back horizontally
			if ay > 0:
				y -= int(sign(y)) # Move back vertically
			var p3 = get_piece_in_grid(p.pos.x + x, p.pos.y + y)
			ok = p3 == null
			ax -= 1
			ay -= 1
			checking = (ax > 1 or ay > 1) and ok
	if !ok and p == passant_pawn:
		passant_pawn = null
	return { "ok": ok, "piece": p2, "castling": castling, "passant": passant }


# Helper to snap piece back to its grid position visually
func return_piece(p: Piece):
	if p != null and p.obj != null:
		var index = get_grid_index(p.pos.x, p.pos.y)
		p.obj.position = get_marker_position(index)


# Visual Hints Logic
var hint_markers = []

func show_hints(piece: Piece):
	clear_hints()
	var piece_vals = { "P": 1, "N": 3, "B": 3, "R": 5, "Q": 9, "K": 100 }
	
	for y in 8:
		for x in 8:
			# Temporarily set new_pos to check validity
			var original_new_pos = piece.new_pos
			piece.new_pos = Vector2(x, y)
			
			# Check if it's a valid move
			# non_player_move=true because we are simulating
			var info = get_position_info(piece, true)
			
			if info["ok"]:
				var target_piece = info["piece"]
				var is_capture = target_piece != null or (info["passant"] and passant_pawn != null)
				
				var color = Color.GREEN # Default move
				var is_ring = false
				
				if is_capture:
					is_ring = true
					var my_val = piece_vals.get(piece.key, 0)
					var target_val = 0
					if target_piece:
						target_val = piece_vals.get(target_piece.key, 0)
					elif info["passant"]:
						target_val = 1 # Pawn
					
					# Check if target square is defended by enemy (enemy of my side)
					# is_checked(x, y, my_side) checks if (x,y) is attacked by enemies of my_side
					var is_defended = is_checked(x, y, piece.side)
					
					if not is_defended:
						color = Color.YELLOW # Safe capture
					else:
						if my_val > target_val:
							color = Color.RED # High risk (Bad trade)
						else:
							color = Color.BROWN # Medium risk (Trade or Good trade)
				
				add_hint_marker(x, y, color, is_ring)
			
			piece.new_pos = original_new_pos


func clear_hints():
	for marker in hint_markers:
		marker.queue_free()
	hint_markers = []


func add_hint_marker(x, y, color, is_ring = false):
	var index = get_grid_index(x, y)
	var sqr = $Container/Grid.get_child(index)
	
	var marker = Control.new()
	marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var circle = Panel.new()
	var marker_size = square_width * (0.9 if is_ring else 0.4)
	circle.custom_minimum_size = Vector2(marker_size, marker_size)
	@warning_ignore("integer_division")
	circle.position = Vector2(square_width/2 - marker_size/2, square_width/2 - marker_size/2)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	if is_ring:
		style.bg_color = Color.TRANSPARENT
		style.set_border_width_all(4)
		style.border_color = color
	else:
		style.bg_color = color
	
	style.set_corner_radius_all(marker_size/2)
	style.set_anti_aliased(true)
	circle.add_theme_stylebox_override("panel", style)
	
	marker.add_child(circle)
	sqr.add_child(marker)
	hint_markers.append(marker)


func _on_HighlightTimer_timeout():
	var tile = highlighed_tiles.pop_front()
	if tile != null:
		highlight_square(tile, false)
	if highlighed_tiles.size() > 0:
		highlight_square(highlighed_tiles[0])
		$HighlightTimer.start()
