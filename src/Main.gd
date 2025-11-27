extends Control

@onready var engine = $Engine
@onready var fd = $c/FileDialog
@onready var promote = $c/Promote
@onready var board = $VBox/BoardArea/Board

# UI Elements
@onready var score_label_white = $VBox/TopBar/VBox/InfoRow/Info/ScoreWhite
@onready var score_label_black = $VBox/TopBar/VBox/InfoRow/Info/ScoreBlack
var moves_popup_content : GridContainer = null
var moves_popup : Window = null

var pid = 0
var moves : PackedStringArray = []
var long_moves : PackedStringArray = []
var selected_piece : Piece
var fen = ""
var show_suggested_move = true
var white_next = true
var pgn_moves = []
var move_index = 0
var promote_to = ""
var state = IDLE

# Game features
var game_mode = 0 # 0: vs IA, 1: vs Human, 2: IA vs IA
var score_white = 0
var score_black = 0
var piece_values = { "P": 1, "N": 3, "B": 3, "R": 5, "Q": 9 }

# states
enum { IDLE, CONNECTING, STARTING, PLAYER_TURN, ENGINE_TURN, PLAYER_WIN, ENGINE_WIN }
# events
enum { CONNECT, NEW_GAME, DONE, ERROR, MOVE }

func _ready():
	board.connect("clicked", Callable(self, "piece_clicked"))
	board.connect("unclicked", Callable(self, "piece_unclicked"))
	connect("mouse_entered", Callable(self, "mouse_entered"))
	board.connect("taken", Callable(self, "stow_taken_piece"))
	promote.connect("promotion_picked", Callable(self, "promote_pawn"))
	show_transport_buttons(false)
	
	# Connect UI signals
	$VBox/TopBar/VBox/ControlRow/Menu/Next.connect("pressed", Callable(self, "_on_Flip_button_down"))
	$VBox/TopBar/VBox/ControlRow/Menu/Load.connect("pressed", Callable(self, "_on_Load_button_down"))
	$VBox/TopBar/VBox/ControlRow/Menu/Save.connect("pressed", Callable(self, "_on_Save_button_down"))
	$VBox/TopBar/VBox/ControlRow/Menu/History.connect("pressed", Callable(self, "_on_History_pressed"))
	
	$VBox/TopBar/VBox/ControlRow/Options/CheckBox.connect("toggled", Callable(self, "_on_CheckBox_toggled"))
	$VBox/TopBar/VBox/ControlRow/Options/Reset.connect("pressed", Callable(self, "_on_Reset_button_down"))
	
	$VBox/TopBar/VBox/ControlRow/Options/TB/Begin.connect("button_down", Callable(self, "_on_Begin_button_down"))
	$VBox/TopBar/VBox/ControlRow/Options/TB/Forward.connect("button_down", Callable(self, "_on_Forward_button_down"))
	$VBox/TopBar/VBox/ControlRow/Options/TB/End.connect("button_down", Callable(self, "_on_End_button_down"))
	$VBox/TopBar/VBox/ControlRow/Options/TB/End.connect("button_up", Callable(self, "_on_End_button_up"))
	
	# Connect other signals
	board.connect("fullmove", Callable(self, "_on_Board_fullmove"))
	board.connect("halfmove", Callable(self, "_on_Board_halfmove"))
	engine.connect("done", Callable(self, "_on_engine_done"))
	fd.connect("file_selected", Callable(self, "_on_FileDialog_file_selected"))
	
	show_last_move()
	ponder() # Hide it
	
	create_moves_popup()
	create_start_menu()

func create_start_menu():
	# Overlay transparent covering the whole screen
	var overlay = Control.new()
	overlay.name = "StartMenu"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$c.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Semi-transparent background panel for the menu only
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 260)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_right", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "CHESS GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Mode Selection
	var mode_hbox = HBoxContainer.new()
	vbox.add_child(mode_hbox)
	var mode_label = Label.new()
	mode_label.text = "Mode:"
	mode_label.custom_minimum_size = Vector2(60, 0)
	mode_hbox.add_child(mode_label)
	
	var mode_opt = OptionButton.new()
	mode_opt.name = "ModeOption"
	mode_opt.add_item("Player vs AI", 0)
	mode_opt.add_item("Player vs Player", 1)
	mode_opt.add_item("AI vs AI", 2)
	mode_opt.selected = 0
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_hbox.add_child(mode_opt)
	
	# Color Selection
	var color_hbox = HBoxContainer.new()
	vbox.add_child(color_hbox)
	var color_label = Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size = Vector2(60, 0)
	color_hbox.add_child(color_label)
	
	var color_opt = OptionButton.new()
	color_opt.name = "ColorOption"
	color_opt.add_item("White", 0)
	color_opt.add_item("Black", 1)
	color_opt.selected = 0
	color_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_hbox.add_child(color_opt)
	
	# Connect mode change to toggle color visibility
	mode_opt.connect("item_selected", Callable(self, "_on_mode_changed").bind(color_hbox))
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Start Button
	var start_btn = Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(0, 40)
	start_btn.connect("pressed", Callable(self, "_on_start_menu_confirmed").bind(mode_opt, color_opt))
	vbox.add_child(start_btn)

func _on_mode_changed(index, color_container):
	# Hide color selection for AI vs AI (index 2)
	if index == 2:
		color_container.hide()
	else:
		color_container.show()

func _on_start_menu_confirmed(mode_opt, color_opt):
	var mode = mode_opt.get_selected_id()
	var color_idx = color_opt.get_selected_id()
	var is_white = (color_idx == 0)
	
	game_mode = mode
	
	var menu = $c.get_node_or_null("StartMenu")
	if menu:
		menu.queue_free()
	
	# Logic for starting game
	if mode == 0: # PvAI
		start_game_logic(is_white)
	elif mode == 1: # PvP
		start_game_logic(true) # Color doesn't matter much, White starts
	else: # AIvAI
		start_game_logic(true) # White starts

func start_game_logic(player_is_white = true):
	state = IDLE
	handle_state(NEW_GAME, player_is_white)

func create_moves_popup():
	moves_popup = Window.new()
	moves_popup.title = "Move History"
	moves_popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	moves_popup.size = Vector2(300, 400)
	moves_popup.visible = false
	moves_popup.transient = true # Make it a popup
	moves_popup.connect("close_requested", Callable(self, "_on_moves_popup_close_requested"))
	add_child(moves_popup)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	moves_popup.add_child(panel)
	
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	moves_popup_content = GridContainer.new()
	moves_popup_content.columns = 2
	moves_popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_popup_content.add_theme_constant_override("h_separation", 20)
	scroll.add_child(moves_popup_content)
	
	var label_w = Label.new()
	label_w.text = "White"
	label_w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_w.add_theme_font_size_override("font_size", 18)
	moves_popup_content.add_child(label_w)
	
	var label_b = Label.new()
	label_b.text = "Black"
	label_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_b.add_theme_font_size_override("font_size", 18)
	moves_popup_content.add_child(label_b)

func _on_moves_popup_close_requested():
	if moves_popup:
		moves_popup.hide()

func _on_History_pressed():
	if moves_popup:
		moves_popup.popup_centered()

func handle_state(event, msg = ""):
	match state:
		IDLE:
			match event:
				CONNECT:
					var status = engine.start_udp_server()
					if status.started:
						await get_tree().create_timer(0.5).timeout
						engine.send_packet("uci")
						state = CONNECTING
					else:
						alert(status.error)
				NEW_GAME:
					if game_mode == 0 or game_mode == 2: # Vs AI or AI vs AI
						if engine.server_pid > 0:
							engine.send_packet("ucinewgame")
							engine.send_packet("isready")
							state = STARTING
							# msg here is player_is_white boolean if passed
							if typeof(msg) == TYPE_BOOL:
								if !msg: # Player is Black
									# We need to trigger engine move immediately after readyok
									pass
						else:
							handle_state(CONNECT)
					elif game_mode == 1:
						alert("White to begin")
						state = PLAYER_TURN
		CONNECTING:
			match event:
				DONE:
					if msg == "uciok":
						state = IDLE
						handle_state(NEW_GAME)
				ERROR:
					alert("Unable to connect to Chess Engine!")
					state = IDLE
		STARTING:
			match event:
				DONE:
					if msg == "readyok":
						if white_next:
							alert("Game Started")
							if game_mode == 2: # AI vs AI
								state = ENGINE_TURN
								prompt_engine()
							else:
								state = PLAYER_TURN # Default
						else:
							alert("Engine to begin")
							prompt_engine()
				ERROR:
					alert("Lost connection to Chess Engine!")
					state = IDLE
		PLAYER_TURN:
			match event:
				DONE:
					print(msg)
				MOVE:
					ponder()
					show_last_move(msg)
					prompt_engine(msg)
		ENGINE_TURN:
			match event:
				DONE:
					var move = get_best_move(msg)
					if move != "":
						move_engine_piece(move)
						show_last_move(move)
						
						if game_mode == 2:
							# AI vs AI loop
							state = ENGINE_TURN
							prompt_engine()
						else:
							state = PLAYER_TURN
					if !msg.begins_with("info"):
						print(msg)
		PLAYER_WIN:
			match event:
				DONE:
					print("Player won")
					state = IDLE
					set_next_color()
		ENGINE_WIN:
			match event:
				DONE:
					print("Engine won")
					state = IDLE
					set_next_color()


func prompt_engine(move = ""):
	var turn = "w" if white_next else "b"
	fen = board.get_fen(turn)
	if move != "":
		engine.send_packet("position fen %s moves %s" % [fen, move])
	else:
		engine.send_packet("position fen %s" % [fen])
	engine.send_packet("go movetime 1000")
	state = ENGINE_TURN


func stow_taken_piece(p: Piece):
	print("Stowing piece: ", p.key, " Side: ", p.side)
	var val = piece_values.get(p.key, 0)
	if p.side == "B":
		score_white += val
		score_label_white.text = "W: " + str(score_white)
	else:
		score_black += val
		score_label_black.text = "B: " + str(score_black)
		
	var texture_rect = TextureRect.new()
	var color_name = "white" if p.side == "W" else "black"
	var type_map = {"P": "Pawn", "R": "Rook", "N": "Knight", "B": "Bishop", "Q": "Queen", "K": "King"}
	var type_name = type_map.get(p.key, "Pawn")
	var path = "res://pieces/" + color_name + type_name + ".png"
	
	var texture = load(path)
	if texture:
		texture_rect.texture = texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.custom_minimum_size = Vector2(32, 32)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if p.side == "W":
		$VBox/TopPiecesBar/HBox/WhitePieces.add_child(texture_rect)
	else:
		$VBox/BottomBar/HBox/BlackPieces.add_child(texture_rect)

	p.queue_free()


func show_last_move(move = ""):
	$VBox/TopBar/VBox/InfoRow/Info/LastMove.text = move
	if move != "":
		if moves_popup_content:
			var label = Label.new()
			label.text = move
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			moves_popup_content.add_child(label)


func get_best_move(s: String):
	var move = ""
	var raw_tokens = s.replace("\t", " ").split(" ")
	var tokens = []
	for t in raw_tokens:
		var tt = t.strip_edges()
		if tt != "":
			tokens.append(tt)
	if tokens.size() > 1:
		if tokens[0] == "bestmove":
			move = tokens[1]
	if tokens.size() > 3:
		if tokens[2] == "ponder":
			ponder(tokens[3])
	return move


func ponder(move = ""):
	if move != "":
		$VBox/TopBar/VBox/InfoRow/Ponder/Move.text = move
	
	if show_suggested_move and $VBox/TopBar/VBox/InfoRow/Ponder/Move.text != "":
		$VBox/TopBar/VBox/InfoRow/Ponder.modulate.a = 1.0
	else:
		$VBox/TopBar/VBox/InfoRow/Ponder.modulate.a = 0.0


func move_engine_piece(move: String):
	var pos1 = board.move_to_position(move.substr(0, 2))
	var p: Piece = board.get_piece_in_grid(pos1.x, pos1.y)
	if p == null:
		print("ERROR: Engine tried to move non-existent piece at ", pos1, " Move: ", move)
		return
	p.new_pos = board.move_to_position(move.substr(2, 2))
	if move[move.length() - 1] in "rnbq":
		promote_to = move[move.length() - 1]
	try_to_make_a_move(p)


func alert(txt, duration = 1.0):
	$c/Alert.open(txt, duration)


func mouse_entered():
	return_piece(selected_piece)


func piece_clicked(piece):
	# Block input in AI vs AI mode
	if game_mode == 2:
		return

	if state != PLAYER_TURN:
		print("Not player turn: ", state)
		board.cancel_drag()
		return
		
	var is_white_turn = white_next
	var piece_is_white = piece.side == "W"
	
	if game_mode == 1:
		if is_white_turn != piece_is_white:
			board.cancel_drag()
			return
	elif is_white_turn != piece_is_white:
		board.cancel_drag()
		return

	selected_piece = piece
	board.show_hints(piece)


func piece_unclicked(piece):
	if selected_piece == null:
		return
	board.clear_hints()
	show_transport_buttons(false)
	try_to_make_a_move(piece, false)


func try_to_make_a_move(piece: Piece, non_player_move = true):
	if not non_player_move:
		if state != PLAYER_TURN:
			board.return_piece(piece)
			return
		var is_white_turn = white_next
		var piece_is_white = piece.side == "W"
		if is_white_turn != piece_is_white:
			board.return_piece(piece)
			return

	var info = board.get_position_info(piece, non_player_move)
	var ok_to_move = false
	var rook = null
	if info["ok"]:
		if info["piece"] != null:
			ok_to_move = true
		else:
			if info["passant"] and board.passant_pawn.pos.x == piece.new_pos.x:
				board.take_piece(board.passant_pawn)
				ok_to_move = true
			else:
				ok_to_move = piece.key != "P" or piece.pos.x == piece.new_pos.x
			if info["castling"]:
				var rx
				if piece.new_pos.x == 2:
					rx = 3
					rook = board.get_piece_in_grid(0, piece.new_pos.y)
				else:
					rook = board.get_piece_in_grid(7, piece.new_pos.y)
					rx = 5
				if rook != null and rook.key == "R" and rook.tagged and rook.side == piece.side:
					ok_to_move = !board.is_checked(rx, rook.pos.y, rook.side)
					if ok_to_move:
						rook.new_pos = Vector2(rx, rook.pos.y)
					else:
						alert("Check")
				else:
					ok_to_move = false
	if info.get("piece") != null:
		ok_to_move = ok_to_move and info["piece"].key != "K"
	if ok_to_move:
		if piece.key == "K":
			if board.is_king_checked(piece)["checked"]:
				alert("Cannot move into check position!")
				ok_to_move = false
			else:
				if rook != null:
					move_piece(rook, false)
				board.take_piece(info["piece"])
				move_piece(piece)
		else:
			board.take_piece(info["piece"])
			move_piece(piece)
			var status = board.is_king_checked(piece)
			if status["mated"]:
				alert("Check Mate!")
				if status["side"] == "B":
					state = PLAYER_WIN
				else:
					state = ENGINE_WIN if game_mode == 0 else PLAYER_WIN
				handle_state(DONE)
			else:
				if status["checked"]:
					# alert("Check") # User requested to hide this
					pass
	
	if not ok_to_move:
		board.return_piece(piece)
		board.clear_hints()
	return_piece(piece)
	
	
func return_piece(piece: Piece):
	if piece != null:
		board.return_piece(piece)
		selected_piece = null
		if piece.key == "P":
			if piece.side == "B" and piece.pos.y == 7 or piece.side == "W" and piece.pos.y == 0:
				if promote_to == "":
					promote.open(piece)
				else:
					Pieces.promote(piece, promote_to)
			promote_to = ""


func move_piece(piece: Piece, not_castling = true):
	set_next_color(piece.side == "B")
	var pos = [piece.pos, piece.new_pos]
	board.move_piece(piece, state == ENGINE_TURN)
	if state == PLAYER_TURN:
		moves.append(board.position_to_move(pos[0]) + board.position_to_move(pos[1]))
		if not_castling:
			if game_mode == 0:
				handle_state(MOVE, " ".join(moves)) 
			else:
				show_last_move(" ".join(moves))
			moves = []




func promote_pawn(p: Piece, pick: String):
	Pieces.promote(p, pick)


func _on_Engine_done(ok, packet):
	if ok:
		handle_state(DONE, packet)
	else:
		handle_state(ERROR)


func _on_CheckBox_toggled(button_pressed):
	show_suggested_move = button_pressed
	ponder()


func _on_Board_fullmove(_n):
	# $VBox/HBox/Grid/Moves.text = str(n) # Label removed
	pass


func _on_Board_halfmove(n):
	$VBox/TopBar/VBox/InfoRow/Info/HalfMoves.text = "500: " + str(n)
	if n >= 500:
		alert("It's a draw!")
		state = IDLE


func reset_board():
	if !board.cleared:
		state = IDLE
		board.clear_board()
		board.setup_pieces()
		board.halfmoves = 0
		board.fullmoves = 0
		show_last_move()
		ponder()
		set_next_color()
		state = IDLE
		board.clear_board()
		board.setup_pieces()
		for node in $VBox/TopPiecesBar/HBox/WhitePieces.get_children():
			node.queue_free()
		for node in $VBox/BottomBar/HBox/BlackPieces.get_children():
			node.queue_free()
		score_white = 0
		score_black = 0
		score_label_white.text = "W: 0"
		score_label_black.text = "B: 0"
		if moves_popup_content:
			for child in moves_popup_content.get_children():
				child.queue_free()
	move_index = 0
	update_count(move_index)
	set_next_color()
	create_start_menu()


func _on_Reset_button_down():
	reset_board()


func _on_Flip_button_down():
	set_next_color(!white_next)


func set_next_color(is_white = true):
	white_next = is_white
	# $VBox/HBox/Menu/Next/Color.color = Color.WHITE if white_next else Color.BLACK # Color rect removed?
	# In Main.tscn, Next is just a button now.
	pass


func _on_Load_button_down():
	fd.mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.popup_centered()


func _on_Save_button_down():
	fd.mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.popup_centered()


func _on_FileDialog_file_selected(path: String):
	if fd.mode == FileDialog.FILE_MODE_OPEN_FILE:
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		if path.get_extension().to_lower() == "pgn":
			set_pgn_moves(pgn_from_file(content))
		else:
			fen_from_file(content)
	else:
		save_file(board.get_fen("w" if white_next else "b"), path)


func pgn_from_file(content: String) -> String:
	var pgn: PackedStringArray = []
	var lines = content.split("\n")
	var started = false
	for line in lines:
		if !started:
			if line.begins_with("1."):
				started = true
			else:
				continue
		if line.length() == 0:
			break
		else:
			pgn.append(line.strip_edges())
	return " ".join(pgn)


func fen_from_file(content: String):
	var parts = content.split(",")
	var fen_str = ""
	for s in parts:
		if "/" in s:
			fen_str = s.replace('"', '')
			break
	if is_valid_fen(fen_str):
		board.clear_board()
		set_next_color(board.setup_pieces(fen_str))
	else:
		alert("Invalid FEN string")


func is_valid_fen(_fen: String):
	var n = 0
	var rows = 1
	for ch in _fen:
		if ch == " ":
			break
		if ch == "/":
			rows += 1
		elif ch.is_valid_int():
			n += int(ch)
		elif ch in "pPrRnNbBqQkK":
			n += 1
	return n == 64 and rows == 8


func save_file(content, path):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func set_pgn_moves(_moves):
	_moves = _moves.split(" ")
	_moves.resize(_moves.size() - 1)
	pgn_moves = []
	long_moves = []
	for i in _moves.size():
		if i % 3 > 0:
			pgn_moves.append(_moves[i])
	show_transport_buttons()
	reset_board()


func update_count(n: int):
	$VBox/TopBar/VBox/ControlRow/Options/TB/Count.text = "%d/%d" % [n, pgn_moves.size()]


func show_transport_buttons(show_buttons = true):
	$VBox/TopBar/VBox/ControlRow/Options/TB.modulate.a = 1.0 if show_buttons else 0.0


func _on_Begin_button_down():
	reset_board()


func _on_Forward_button_down():
	step_forward()


func step_forward():
	if move_index >= pgn_moves.size():
		set_next_color()
		return
	if long_moves.size() <= move_index:
		long_moves.append(board.pgn_to_long(pgn_moves[move_index], "W" if move_index % 2 == 0 else "B"))
	move_engine_piece(long_moves[move_index])
	show_last_move(long_moves[move_index])
	move_index += 1
	update_count(move_index)


var stepping = false

func _on_End_button_down():
	stepping = true
	while stepping and pgn_moves.size() > move_index:
		step_forward()


func _on_End_button_up():
	stepping = false


func _on_engine_done(ok, packet):
	if ok:
		handle_state(DONE, packet)
	else:
		handle_state(ERROR)
