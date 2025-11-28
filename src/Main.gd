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
var win_condition = 0 # 0: Mat/Pat classique, 1: Élimination totale
var score_white = 0
var score_black = 0

var piece_values = { "P": 1, "N": 3, "B": 3, "R": 5, "Q": 9 }

# AI variables
var multipv_data = {} # Stores best moves from info lines: { 1: {move: "e2e4", score: 0.5}, ... }
var ai_delay_min = 0.2
var ai_delay_max = 0.6
var ai_level_white = 10
var ai_level_black = 10
var turn_start_time = 0
var current_turn_id = 0

# AI Level Configuration - Allocation progressive avec temps uniforme
func get_ai_config(level: int) -> Dictionary:
	# Temps de réflexion réel (augmente avec niveau)
	var movetimes = [50, 100, 200, 400, 600, 800, 1000, 1200, 1400, 1600]
	# Temps total perçu fixe: 1200ms
	var fake_delay = 1200 - movetimes[level - 1]
	
	# Allocation progressive de ressources (Réduite pour éviter le freeze)
	var hash_values = [16, 16, 16, 32, 32, 32, 48, 48, 64, 64]  # MB (Max 64MB pour stabilité)
	var thread_counts = [1, 1, 1, 1, 1, 1, 2, 2, 2, 2] # Max 2 threads

	var multipv_values = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] # Force MultiPV 1 pour éviter buffer overflow UDP
	
	# Skill progression exponentielle
	var skills = [0, 3, 6, 9, 11, 13, 15, 17, 19, 20]
	
	# Taux d'erreur (niveaux faibles) et robotisme (niveaux hauts)
	var error_rates = [0.50, 0.35, 0.20, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	# Probabilité de jouer le meilleur coup (robotisme croissant)
	var best_move_probs = [0.50, 0.60, 0.70, 0.75, 0.80, 0.85, 0.90, 0.93, 0.95, 0.98]
	
	var idx = level - 1
	return {
		"skill": skills[idx],
		"movetime": movetimes[idx],
		"fake_delay": fake_delay,
		"multipv": multipv_values[idx],
		"hash": hash_values[idx],
		"threads": thread_counts[idx],
		"error_rate": error_rates[idx],
		"best_move_prob": best_move_probs[idx]
	}



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
	
	# AI Level Selection
	var level_vbox = VBoxContainer.new()
	level_vbox.name = "LevelVBox"
	vbox.add_child(level_vbox)
	
	# White AI Level
	var w_level_hbox = HBoxContainer.new()
	w_level_hbox.name = "WhiteLevelHBox"
	level_vbox.add_child(w_level_hbox)
	var w_level_lbl = Label.new()
	w_level_lbl.text = "White AI Level:"
	w_level_lbl.custom_minimum_size = Vector2(120, 0)
	w_level_hbox.add_child(w_level_lbl)
	var w_level_spin = SpinBox.new()
	w_level_spin.min_value = 1
	w_level_spin.max_value = 10
	w_level_spin.value = 10
	w_level_spin.name = "WhiteLevelSpin"
	w_level_hbox.add_child(w_level_spin)
	
	# Black AI Level
	var b_level_hbox = HBoxContainer.new()
	b_level_hbox.name = "BlackLevelHBox"
	level_vbox.add_child(b_level_hbox)
	var b_level_lbl = Label.new()
	b_level_lbl.text = "Black AI Level:" # Or just "AI Level" for PvAI
	b_level_lbl.name = "Label"
	b_level_lbl.custom_minimum_size = Vector2(120, 0)
	b_level_hbox.add_child(b_level_lbl)
	var b_level_spin = SpinBox.new()
	b_level_spin.min_value = 1
	b_level_spin.max_value = 10
	b_level_spin.value = 10
	b_level_spin.name = "BlackLevelSpin"
	b_level_hbox.add_child(b_level_spin)
	
	# Initial visibility update
	_on_mode_changed(mode_opt.selected, color_hbox)
	_update_level_visibility(mode_opt.selected, level_vbox, color_opt)
	
	# Update visibility on change
	mode_opt.connect("item_selected", Callable(self, "_update_level_visibility").bind(level_vbox, color_opt))
	color_opt.connect("item_selected", Callable(self, "_update_level_visibility_color").bind(level_vbox, mode_opt))

	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Win Condition Selection
	var win_label = Label.new()
	win_label.text = "Condition de Victoire:"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(win_label)
	
	var win_opt = OptionButton.new()
	win_opt.add_item("Mat/Pat (Classique)", 0)
	win_opt.add_item("Élimination Totale", 1)
	win_opt.selected = 0
	vbox.add_child(win_opt)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	# Start Button
	var start_btn = Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(0, 40)
	start_btn.connect("pressed", Callable(self, "_on_start_menu_confirmed").bind(mode_opt, color_opt, win_opt))
	vbox.add_child(start_btn)
	
	# Quit Button
	var quit_btn = Button.new()
	quit_btn.text = "QUITTER LE JEU"
	quit_btn.custom_minimum_size = Vector2(0, 35)
	quit_btn.connect("pressed", func(): get_tree().quit())
	vbox.add_child(quit_btn)

func _on_mode_changed(index, color_container):
	# Hide color selection for AI vs AI (index 2)
	if index == 2:
		color_container.hide()
	else:
		color_container.show()
	
	# Trigger level visibility update (needs to find nodes dynamically or pass them)
	# Since we can't easily pass everything here without refactoring, we'll rely on the separate connection
	pass

func _update_level_visibility(index, level_vbox, _color_opt):
	var w_hbox = level_vbox.get_node("WhiteLevelHBox")
	var b_hbox = level_vbox.get_node("BlackLevelHBox")
	var b_lbl = b_hbox.get_node("Label")
	
	if index == 0: # PvAI
		w_hbox.hide()
		b_hbox.show()
		b_lbl.text = "AI Level:"
	elif index == 1: # PvP
		w_hbox.hide()
		b_hbox.hide()
	else: # AIvAI
		w_hbox.show()
		b_hbox.show()
		b_lbl.text = "Black AI Level:"

func _update_level_visibility_color(_index, _level_vbox, _mode_opt):
	# Only relevant for PvAI if we wanted to switch which slider is shown based on player color
	# But for simplicity, we'll just use the "BlackLevelHBox" as the generic "AI Level" slider for PvAI
	pass


func _on_start_menu_confirmed(mode_opt, color_opt, win_opt):
	var mode = mode_opt.get_selected_id()
	var color_idx = color_opt.get_selected_id()
	var is_white = (color_idx == 0)
	win_condition = win_opt.get_selected_id()
	
	# Retrieve levels
	var menu = $c.get_node_or_null("StartMenu")
	if menu:
		var w_spin = menu.find_child("WhiteLevelSpin", true, false)
		var b_spin = menu.find_child("BlackLevelSpin", true, false)
		if w_spin: ai_level_white = int(w_spin.value)
		if b_spin: ai_level_black = int(b_spin.value)
		
		# In PvAI, we only showed one spinner (BlackLevelSpin) labeled "AI Level"
		# If the player plays Black, the AI is White, so we must assign that value to ai_level_white
		if mode == 0:
			if !is_white: # Player is Black, AI is White
				ai_level_white = ai_level_black


	
	game_mode = mode
	
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
						await get_tree().create_timer(1.0).timeout
						engine.send_packet("uci")
						state = CONNECTING
					else:
						# alert(status.error)
						print(status.error)
						OS.alert("Erreur de connexion IA: " + str(status.error), "Erreur IA")
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
						# alert("White to begin")
						print("White to begin")
						state = PLAYER_TURN
		CONNECTING:
			match event:
				DONE:
					if msg == "uciok":
						# Configure Engine Options
						engine.send_packet("setoption name Hash value 64")
						engine.send_packet("setoption name Threads value 2")
						engine.send_packet("setoption name Skill Level value 20")
						engine.send_packet("setoption name UCI_LimitStrength value false")
						engine.send_packet("setoption name UCI_Elo value 2800")
						engine.send_packet("setoption name MultiPV value 1")
						engine.send_packet("setoption name Move Overhead value 30")
						engine.send_packet("setoption name Slow Mover value 90")
						engine.send_packet("setoption name Ponder value true")
						
						state = IDLE
						handle_state(NEW_GAME)
				ERROR:
					# alert("Unable to connect to Chess Engine!")
					print("Unable to connect to Chess Engine!")
					state = IDLE
		STARTING:
			match event:
				DONE:
					if msg == "readyok":
						if white_next:
							# alert("Game Started")
							print("Game Started")
							if game_mode == 2: # AI vs AI
								state = ENGINE_TURN
								prompt_engine()
							else:
								state = PLAYER_TURN # Default
						else:
							# alert("Engine to begin")
							print("Engine to begin")
							prompt_engine()
				ERROR:
					# alert("Lost connection to Chess Engine!")
					print("Lost connection to Chess Engine!")
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
					if msg.begins_with("info"):
						process_engine_info(msg)
					
					var move = get_best_move(msg)
					# Debug pour comprendre pourquoi le log affiche bestmove d1d8 mais le code voit (none)
					if move == "(none)":
						print("Parsed move is (none). Raw msg: " + msg)
						print("Engine returned (none) - Mate or Stalemate")
						# Invalider le timeout car la partie est finie
						current_turn_id += 1
						
						# En mode Mat/Pat classique, on déclare la fin
						if win_condition == 0:
							if game_mode == 2: # AI vs AI
								print("AI vs AI: Game Over. Restarting in 3 seconds...")
								await get_tree().create_timer(3.0).timeout
								# Reset board and restart
								_on_Reset_button_down()
							return
						else:
							print("Mode Élimination: L'IA est bloquée (Mat/Pat) mais il reste des pièces.")
							# Essayer de trouver un coup de secours (ignorant l'échec du Roi)
							var side = "W" if white_next else "B"
							var fallback_moves = board.get_fallback_moves(side)
							
							if fallback_moves.size() > 0:
								print("Coups de secours trouvés: ", fallback_moves.size())
								# Choisir un coup (priorité aux captures ?)
								# Pour l'instant, on prend un coup au hasard
								var fallback_move = fallback_moves[randi() % fallback_moves.size()]
								print("IA joue le coup de secours: ", fallback_move)
								
								apply_fallback_move(fallback_move)
								return
							else:
								print("Aucun coup de secours possible. L'IA passe son tour.")
								# Passer la main au joueur pour qu'il puisse continuer à éliminer les pièces
								state = PLAYER_TURN
								return
					if move != "":
						# IMPORTANT: On a reçu le coup, donc on incrémente l'ID du tour immédiatement
						# Cela invalide le timeout de sécurité qui était lié à l'ID précédent
						current_turn_id += 1
						
						# Calculer le temps écoulé réel pour garantir exactement 1.2s de réflexion perçue
						var elapsed = Time.get_ticks_msec() - turn_start_time
						var target_time = 1200 # 1.2 secondes
						var wait_time = target_time - elapsed
						
						if wait_time > 0:
							await get_tree().create_timer(wait_time / 1000.0).timeout
						
						# Select move based on weighted random if we have MultiPV data
						var selected_move = select_weighted_move(move)
						
						move_engine_piece(selected_move)
						show_last_move(selected_move)
						#show_move_toast("Engine: " + selected_move)
						
						# Si le coup a causé un mat/pat, l'état a changé (PLAYER_WIN/ENGINE_WIN/IDLE)
						# On ne doit relancer l'IA que si on est toujours en ENGINE_TURN
						if state == ENGINE_TURN:
							if game_mode == 2:
								# AI vs AI loop
								prompt_engine()
							else:
								state = PLAYER_TURN
						else:
							print("Game ended, stopping engine loop. Final state: ", state)
					if !msg.begins_with("info"):
						print(msg)
		PLAYER_WIN:
			match event:
				DONE:
					print("Player won")
					# Afficher l'écran de victoire sauf en AI vs AI
					if game_mode != 2:
						show_result_screen(true)
					state = IDLE
					set_next_color()
		ENGINE_WIN:
			match event:
				DONE:
					print("Engine won")
					# Afficher l'écran de défaite sauf en AI vs AI
					if game_mode != 2:
						show_result_screen(false)
					state = IDLE
					set_next_color()


func prompt_engine(move = ""):
	var turn = "w" if white_next else "b"
	
	# Set Skill Level based on turn
	# Map 1-10 to 0-20 (approx level * 2)
	var level = ai_level_white if white_next else ai_level_black
	var config = get_ai_config(level)
	
	# Configurer les ressources allouées progressivement
	engine.send_packet("setoption name Hash value %d" % config.hash)
	engine.send_packet("setoption name Threads value %d" % config.threads)
	engine.send_packet("setoption name Skill Level value %d" % config.skill)
	engine.send_packet("setoption name MultiPV value %d" % config.multipv)
	
	fen = board.get_fen(turn)
	if move != "":
		engine.send_packet("position fen %s moves %s" % [fen, move])
	else:
		engine.send_packet("position fen %s" % [fen])
	
	# Temps réel variable selon niveau (court pour faible, long pour fort)
	engine.send_packet("go movetime %d" % config.movetime)
	
	turn_start_time = Time.get_ticks_msec()
	state = ENGINE_TURN
	multipv_data.clear() # Reset for new turn
	
	# Timeout de sécurité: Si l'IA ne répond pas après movetime + 2s, on force la fin
	# Cela évite que le jeu reste bloqué si le moteur plante ou lag
	# Note: current_turn_id est incrémenté dans prompt_engine (ici) et aussi quand on reçoit un coup
	# pour invalider le timer.
	current_turn_id += 1
	var my_turn_id = current_turn_id
	var timeout_time = (config.movetime / 1000.0) + 2.0
	get_tree().create_timer(timeout_time).timeout.connect(_on_engine_timeout.bind(my_turn_id))

func _on_engine_timeout(turn_id):
	# On vérifie si le timeout correspond bien au tour actuel
	if state == ENGINE_TURN and turn_id == current_turn_id:
		print("WARNING: Engine timeout! Checking fallback...")
		
		if win_condition == 1:
			# En mode élimination, un timeout peut signifier que Stockfish a planté sur une position illégale
			# On tente le coup de secours
			var side = "W" if white_next else "B"
			var fallback_moves = board.get_fallback_moves(side)
			if fallback_moves.size() > 0:
				print("Timeout -> Fallback move found.")
				var fallback_move = fallback_moves[randi() % fallback_moves.size()]
				# On simule la réception du coup
				# Il faut appeler la logique de traitement du coup manuellement car on n'est pas dans _process_packet
				# On utilise une fonction dédiée ou on copie la logique
				# Pour faire simple, on va injecter le coup comme si on l'avait reçu, mais on doit faire attention au thread
				# Le plus sûr est de passer par un appel différé ou de modifier l'état ici
				
				# Hack propre : on appelle une fonction qui gère le coup
				apply_fallback_move(fallback_move)
				return

		# Comportement par défaut (Mat/Pat ou pas de fallback trouvé)
		print("Forcing engine stop.")
		engine.send_packet("stop") # Force engine to stop and return best move so far


func stow_taken_piece(p: Piece):
	print("Stowing piece: ", p.key, " Side: ", p.side)
	var val = piece_values.get(p.key, 0)
	if p.side == "B":
		score_white += val
		score_label_white.text = "W: " + str(score_white)
	else:
		score_black += val
		score_label_black.text = "B: " + str(score_black)
	
	# Vérifier la condition de victoire par élimination totale
	if win_condition == 1:
		check_elimination_victory()
		
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
	var raw_tokens = s.replace("\t", " ").replace("\n", " ").split(" ")
	var tokens = []
	for t in raw_tokens:
		var tt = t.strip_edges()
		if tt != "":
			tokens.append(tt)
	
	# Chercher "bestmove" n'importe où dans les tokens
	var idx = tokens.find("bestmove")
	if idx != -1 and idx + 1 < tokens.size():
		move = tokens[idx+1]
		
	if tokens.size() > 3:
		if tokens[2] == "ponder":
			ponder(tokens[3])
	return move


func process_engine_info(_msg: String):
	# DÉSACTIVATION TEMPORAIRE POUR STOPPER LE FREEZE
	# Le traitement de milliers de lignes de texte par seconde sature Godot
	return
	
	# Optimisation: Ne pas traiter toutes les lignes pour éviter le lag UI
	#if "multipv" in msg and "pv" in msg and "score" in msg:
		# Parsing rapide sans split excessif si possible, ou juste limiter la fréquence
		#var parts = msg.split(" ")
		#var mpv_idx = -1
		#var score = 0.0
		#var pv_move = ""
		
		# Optimisation: chercher les index directement
		#var idx_mpv = parts.find("multipv")
		#if idx_mpv != -1 and idx_mpv + 1 < parts.size():
			#mpv_idx = int(parts[idx_mpv+1])
			
		#if mpv_idx == -1: return
			
		#var idx_score = parts.find("score")
		#if idx_score != -1 and idx_score + 2 < parts.size():
			#if parts[idx_score+1] == "cp":
				#score = int(parts[idx_score+2]) / 100.0
			#elif parts[idx_score+1] == "mate":
				#score = 1000.0 if int(parts[idx_score+2]) > 0 else -1000.0
		
		#var idx_pv = parts.find("pv")
		#if idx_pv != -1 and idx_pv + 1 < parts.size():
			#pv_move = parts[idx_pv+1]
		
		#if mpv_idx != -1 and pv_move != "":
			#multipv_data[mpv_idx] = {"move": pv_move, "score": score}
			# Update UI with evaluation (using best move score)
			#if mpv_idx == 1:
				#update_evaluation(score)

func select_weighted_move(best_move: String) -> String:
	if multipv_data.is_empty():
		return best_move
	
	# Obtenir le niveau et la config actuel
	var level = ai_level_white if white_next else ai_level_black
	var config = get_ai_config(level)
	
	var rand = randf()
	var selected = best_move
	
	if multipv_data.has(1): 
		selected = multipv_data[1].move
	
	# Pour les niveaux faibles (1-3), introduire des erreurs volontaires
	if config.error_rate > 0.0 and rand < config.error_rate:
		# Choisir délibérément un coup plus faible
		var available_moves = multipv_data.keys()
		if available_moves.size() > 1:
			# Prendre un coup aléatoire parmi les options (souvent mauvais)
			var worst_idx = available_moves[randi() % available_moves.size()]
			selected = multipv_data[worst_idx].move
			print("AI niveau %d fait une erreur (choix: %d)" % [level, worst_idx])
		return selected
	
	# Comportement robotique croissant (niveau 4-10)
	# Plus le niveau est haut, plus l'IA joue le meilleur coup
	var best_prob = config.best_move_prob
	
	if rand < best_prob:
		# Jouer le meilleur coup (de plus en plus fréquent)
		selected = multipv_data[1].move
	else:
		# Jouer un coup alternatif (de moins en moins fréquent)
		var remaining_prob = 1.0 - best_prob
		if rand < best_prob + remaining_prob * 0.6 and multipv_data.has(2):
			selected = multipv_data[2].move
			print("AI niveau %d: 2ème coup" % level)
		elif multipv_data.has(3):
			selected = multipv_data[3].move
			print("AI niveau %d: 3ème coup" % level)
		
	return selected

func update_evaluation(score: float):
	var score_text = "+%.2f" % score if score > 0 else "%.2f" % score
	# Update the label text to include evaluation
	# Assuming score_white is the material score
	score_label_white.text = "W: %d  Eval: %s" % [score_white, score_text]

func show_move_toast(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	# Position in center-top
	var center = get_viewport_rect().size / 2
	label.position = Vector2(center.x - 100, center.y - 50)
	label.modulate.a = 0.0
	
	add_child(label)
	
	# Animation Tween (Movement & Fade In)
	var t_anim = create_tween()
	t_anim.set_parallel(true)
	t_anim.tween_property(label, "modulate:a", 1.0, 0.3)
	t_anim.tween_property(label, "position:y", label.position.y - 50, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Lifecycle Tween (Wait -> Fade Out -> Destroy)
	var t_life = create_tween()
	t_life.tween_interval(1.5)
	t_life.tween_property(label, "modulate:a", 0.0, 0.5)
	t_life.tween_callback(label.queue_free)




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
						# alert("Check")
						print("Check")
				else:
					ok_to_move = false
	if info.get("piece") != null:
		ok_to_move = ok_to_move and info["piece"].key != "K"
	if ok_to_move:
		if piece.key == "K":
			if board.is_king_checked(piece)["checked"]:
				# alert("Cannot move into check position!")
				print("Cannot move into check position!")
				ok_to_move = false
			else:
				if rook != null:
					move_piece(rook, false)
				board.take_piece(info["piece"])
				move_piece(piece)
		else:
			board.take_piece(info["piece"])
			move_piece(piece)
			# DÉSACTIVATION DE LA DÉTECTION DE MAT
			# La fonction is_king_checked a une logique erronée : elle ne vérifie que si le Roi
			# peut bouger, sans vérifier si une autre pièce peut bloquer l'échec ou capturer l'attaquant.
			# Cela causait des faux mats. Stockfish gère déjà correctement les mats (retourne (none)),
			# donc on se contente de détecter les échecs visuellement.
			var status = board.is_king_checked(piece)
			# Commenté pour éviter les faux mats:
			# if status["mated"]:
			# 	print("Check Mate!")
			# 	if status["side"] == "B":
			# 		state = PLAYER_WIN
			# 	else:
			# 		state = ENGINE_WIN if game_mode == 0 else PLAYER_WIN
			# 	handle_state(DONE)
			# else:
			if status["checked"]:
				# alert("Check") # User requested to hide this
				board.play_sound("check")
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


func show_result_screen(player_won: bool):
	# Créer un overlay pour l'écran de résultat
	var overlay = Control.new()
	overlay.name = "ResultScreen"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$c.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Panel semi-transparent
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 250)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.set_corner_radius_all(15)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_right", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Titre
	var title = Label.new()
	if player_won:
		title.text = "🎉 VICTOIRE ! 🎉"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		title.text = "💔 DÉFAITE 💔"
		title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)
	
	# Message
	var message = Label.new()
	if player_won:
		message.text = "Félicitations ! Vous avez gagné la partie."
	else:
		message.text = "L'adversaire a gagné cette fois-ci.\nRevenche ?"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 18)
	vbox.add_child(message)
	
	# Conteneur pour les boutons côte à côte
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	var btn_center = CenterContainer.new()
	btn_center.add_child(btn_hbox)
	vbox.add_child(btn_center)
	
	# Bouton Continuer
	var continue_btn = Button.new()
	continue_btn.text = "Continuer"
	continue_btn.custom_minimum_size = Vector2(150, 50)
	continue_btn.connect("pressed", func(): overlay.queue_free(); reset_board())
	btn_hbox.add_child(continue_btn)
	
	# Bouton Quitter
	var quit_btn = Button.new()
	quit_btn.text = "Quitter"
	quit_btn.custom_minimum_size = Vector2(150, 50)
	quit_btn.connect("pressed", func(): get_tree().quit())
	btn_hbox.add_child(quit_btn)

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





func apply_fallback_move(move_str):
	print("Applying fallback move: ", move_str)
	# On incrémente l'ID pour invalider d'autres timeouts
	current_turn_id += 1
	
	# On construit un faux message "bestmove" pour réutiliser la logique existante si possible,
	# mais comme la logique est dans _process_packet (qui est appelé par le signal UDP), 
	# on peut juste appeler les fonctions de mouvement directement.
	
	# Parsing du coup (ex: "e2e4")
	var src_str = move_str.substr(0, 2)
	var dst_str = move_str.substr(2, 2)
	
	# Conversion en indices (à faire proprement si on avait les fonctions, ici on suppose que Board les a ou on les refait)
	# Mais attendez, Main.gd a déjà show_last_move et prompt_engine...
	# Le plus simple est de simuler l'événement MOVE
	
	# On doit convertir "e2e4" en indices pour board.move_piece
	# On va utiliser une méthode helper si elle existe, sinon on le fait ici
	var cols = {"a":0, "b":1, "c":2, "d":3, "e":4, "f":5, "g":6, "h":7}
	var rows = {"8":0, "7":1, "6":2, "5":3, "4":4, "3":5, "2":6, "1":7}
	
	var c1 = cols[src_str[0]]
	var r1 = rows[src_str[1]]
	var c2 = cols[dst_str[0]]
	var r2 = rows[dst_str[1]]
	
	var start_pos = Vector2(c1, r1)
	var end_pos = Vector2(c2, r2)
	
	# Exécuter le mouvement
	var p = board.get_piece_in_grid(start_pos.x, start_pos.y)
	if p:
		# Gérer la capture visuelle AVANT le déplacement
		var target = board.get_piece_in_grid(end_pos.x, end_pos.y)
		if target != null:
			board.take_piece(target)
			
		p.new_pos = end_pos
		board.move_piece(p, true)
		
		# Logique de fin de tour manuelle (car on contourne handle_state(MOVE))
		var side = p.side
		set_next_color(side == "B") # Si c'était Noir, c'est au tour des Blancs
		
		# Mettre à jour l'affichage du dernier coup
		show_last_move(move_str)
		
		# Vérifier victoire
		check_elimination_victory()
		
		# Si la partie n'est pas finie (state != DONE), on continue
		if state != DONE:
			if game_mode == 2: # AI vs AI
				# On reste en ENGINE_TURN, mais on doit relancer l'IA pour l'autre couleur
				# Attendre un peu pour l'animation
				await get_tree().create_timer(0.5).timeout
				prompt_engine()
			elif game_mode == 0: # PvAI
				# Si c'était l'IA (ENGINE_TURN), c'est maintenant au joueur
				state = PLAYER_TURN
				print("Fallback move done. Player turn.")
	else:
		print("ERROR: Fallback move piece not found!")


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Closing application...")
		if engine:
			# Tenter d'arrêter proprement Stockfish
			engine.send_packet("stop")
			engine.send_packet("quit")
		get_tree().quit()



func check_elimination_victory():
	# Compter les pièces restantes de chaque côté
	var white_pieces = 0
	var black_pieces = 0
	
	for i in 64:
		var p = board.grid[i]
		if p != null:
			if p.side == "W":
				white_pieces += 1
			else:
				black_pieces += 1
	
	# Vérifier si un côté a perdu toutes ses pièces
	if black_pieces == 0:
		print("All Black pieces eliminated! White wins!")
		state = PLAYER_WIN if game_mode == 0 else PLAYER_WIN
		handle_state(DONE)
	elif white_pieces == 0:
		print("All White pieces eliminated! Black wins!")
		state = ENGINE_WIN if game_mode == 0 else PLAYER_WIN
		handle_state(DONE)
