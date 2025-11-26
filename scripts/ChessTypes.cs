using System;

public enum PieceType { None, Pawn, Knight, Bishop, Rook, Queen, King }
public enum PieceColor { White, Black }

public struct Piece {
    public PieceType Type;
    public PieceColor Color;
    public Piece(PieceType t, PieceColor c) { Type = t; Color = c; }
    public bool IsNone => Type == PieceType.None;
}

public struct Move {
    public int from; // 0..63
    public int to;   // 0..63
    public PieceType promotion; // None if not a promo
    public bool isEnPassant;
    public bool isCastling;
    public Move(int f, int t) { from = f; to = t; promotion = PieceType.None; isEnPassant=false; isCastling=false; }
}
