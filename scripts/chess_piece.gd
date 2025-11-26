extends Node3D
class_name ChessPiece

enum PieceType {
	PAWN,
	ROOK,
	KNIGHT,
	BISHOP,
	QUEEN,
	KING
}

enum PieceColor {
	WHITE,
	BLACK
}

@export var piece_type: PieceType = PieceType.PAWN
@export var piece_color: PieceColor = PieceColor.WHITE
@export var board_position: Vector2i = Vector2i(0, 0)

var is_selected: bool = false

func _ready():
	# Ajouter la pièce au groupe approprié
	if piece_color == PieceColor.WHITE:
		add_to_group("white_pieces")
	else:
		add_to_group("black_pieces")

func get_valid_moves() -> Array[Vector2i]:
	# Retourne les mouvements valides pour cette pièce
	var moves: Array[Vector2i] = []
	
	match piece_type:
		PieceType.PAWN:
			moves = get_pawn_moves()
		PieceType.ROOK:
			moves = get_rook_moves()
		PieceType.KNIGHT:
			moves = get_knight_moves()
		PieceType.BISHOP:
			moves = get_bishop_moves()
		PieceType.QUEEN:
			moves = get_queen_moves()
		PieceType.KING:
			moves = get_king_moves()
	
	return moves

func get_pawn_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var direction = -1 if piece_color == PieceColor.WHITE else 1
	
	# Mouvement simple
	moves.append(board_position + Vector2i(0, direction))
	
	# Premier mouvement (2 cases)
	var start_row = 6 if piece_color == PieceColor.WHITE else 1
	if board_position.y == start_row:
		moves.append(board_position + Vector2i(0, direction * 2))
	
	return moves

func get_rook_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	# TODO: Implémenter les mouvements de la tour
	return moves

func get_knight_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var knight_offsets = [
		Vector2i(2, 1), Vector2i(2, -1),
		Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2),
		Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	for offset in knight_offsets:
		moves.append(board_position + offset)
	
	return moves

func get_bishop_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	# TODO: Implémenter les mouvements du fou
	return moves

func get_queen_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	# TODO: Implémenter les mouvements de la reine
	return moves

func get_king_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var king_offsets = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1),
		Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for offset in king_offsets:
		moves.append(board_position + offset)
	
	return moves

func set_selected(selected: bool):
	is_selected = selected
	# TODO: Ajouter une animation ou un effet visuel de sélection

func move_to(new_position: Vector2i):
	board_position = new_position
	# TODO: Animer le déplacement
