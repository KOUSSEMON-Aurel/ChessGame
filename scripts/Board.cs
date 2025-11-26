using System;
using System.Collections.Generic;

public class Board {
    public Piece[] squares = new Piece[64]; // 0..63
    public PieceColor sideToMove = PieceColor.White;
    public bool whiteCanCastleKingSide, whiteCanCastleQueenSide;
    public bool blackCanCastleKingSide, blackCanCastleQueenSide;
    public int enPassantSquare = -1; // index of square that can be captured en passant, -1 none
    public int halfmoveClock = 0;
    public int fullmoveNumber = 1;

    // Stack to undo moves
    private Stack<UndoInfo> undoStack = new Stack<UndoInfo>();

    private struct UndoInfo {
        public Move move;
        public Piece captured;
        public bool prevWhiteCastleK, prevWhiteCastleQ, prevBlackCastleK, prevBlackCastleQ;
        public int prevEnPassant;
        public int prevHalfmove;
        public int prevFullmove;
    }

    public Board() {
        Clear();
    }

    public void Clear() {
        for (int i=0;i<64;i++) squares[i] = new Piece(PieceType.None, PieceColor.White);
        // reset flags
        whiteCanCastleKingSide = whiteCanCastleQueenSide = blackCanCastleKingSide = blackCanCastleQueenSide = true;
        enPassantSquare = -1;
        sideToMove = PieceColor.White;
        halfmoveClock = 0;
        fullmoveNumber = 1;
    }

    public void SetInitialPosition() {
        Clear();
        // Pawns
        for (int i = 0; i < 8; i++) {
            Set(8 + i, new Piece(PieceType.Pawn, PieceColor.White));
            Set(48 + i, new Piece(PieceType.Pawn, PieceColor.Black));
        }
        // Rooks
        Set(0, new Piece(PieceType.Rook, PieceColor.White)); Set(7, new Piece(PieceType.Rook, PieceColor.White));
        Set(56, new Piece(PieceType.Rook, PieceColor.Black)); Set(63, new Piece(PieceType.Rook, PieceColor.Black));
        // Knights
        Set(1, new Piece(PieceType.Knight, PieceColor.White)); Set(6, new Piece(PieceType.Knight, PieceColor.White));
        Set(57, new Piece(PieceType.Knight, PieceColor.Black)); Set(62, new Piece(PieceType.Knight, PieceColor.Black));
        // Bishops
        Set(2, new Piece(PieceType.Bishop, PieceColor.White)); Set(5, new Piece(PieceType.Bishop, PieceColor.White));
        Set(58, new Piece(PieceType.Bishop, PieceColor.Black)); Set(61, new Piece(PieceType.Bishop, PieceColor.Black));
        // Queens
        Set(3, new Piece(PieceType.Queen, PieceColor.White));
        Set(59, new Piece(PieceType.Queen, PieceColor.Black));
        // Kings
        Set(4, new Piece(PieceType.King, PieceColor.White));
        Set(60, new Piece(PieceType.King, PieceColor.Black));
    }

    // Helper
    public Piece Get(int idx) => squares[idx];
    public void Set(int idx, Piece p) => squares[idx] = p;
    public bool IsInBoard(int idx) => idx >= 0 && idx < 64;

    public List<Move> GenerateLegalMoves() {
        List<Move> moves = new List<Move>();
        // 1) Gen pseudo-legal
        for (int i=0;i<64;i++) {
            var p = Get(i);
            if (p.IsNone || p.Color != sideToMove) continue;
            GeneratePieceMoves(i, p, moves);
        }
        // 2) Filter moves that leave king in check
        List<Move> legal = new List<Move>();
        foreach (var m in moves) {
            var captured = ApplyMove(m);
            bool kingInCheck = IsKingInCheck(sideToMove == PieceColor.White ? PieceColor.Black : PieceColor.White);
            UndoMove(m, captured);
            if (!kingInCheck) legal.Add(m);
        }
        return legal;
    }

    private void GeneratePieceMoves(int from, Piece p, List<Move> moves) {
        switch (p.Type) {
            case PieceType.Pawn: GeneratePawnMoves(from, p, moves); break;
            case PieceType.Knight: GenerateKnightMoves(from, p, moves); break;
            case PieceType.Bishop: GenerateSlidingMoves(from, p, moves, new int[] {-9, -7, 7, 9}); break;
            case PieceType.Rook: GenerateSlidingMoves(from, p, moves, new int[] {-8, -1, 1, 8}); break;
            case PieceType.Queen: GenerateSlidingMoves(from, p, moves, new int[] {-9, -8, -7, -1, 1, 7, 8, 9}); break;
            case PieceType.King: GenerateKingMoves(from, p, moves); break;
        }
    }

    private void GeneratePawnMoves(int from, Piece pawn, List<Move> moves) {
        int dir = pawn.Color == PieceColor.White ? 1 : -1;
        int rank = from / 8;
        int file = from % 8;
        int forward = from + dir*8;
        
        // Move forward
        if (IsInBoard(forward) && Get(forward).IsNone) {
            // promotion?
            int targetRank = forward / 8;
            if (targetRank == 7 || targetRank == 0) {
                moves.Add(new Move(from, forward){ promotion = PieceType.Queen});
                moves.Add(new Move(from, forward){ promotion = PieceType.Rook});
                moves.Add(new Move(from, forward){ promotion = PieceType.Bishop});
                moves.Add(new Move(from, forward){ promotion = PieceType.Knight});
            } else {
                moves.Add(new Move(from, forward));
                // double push
                int startRank = pawn.Color == PieceColor.White ? 1 : 6;
                int doubleForward = from + dir*16;
                if (rank == startRank && Get(doubleForward).IsNone) {
                    var m = new Move(from, doubleForward);
                    moves.Add(m);
                }
            }
        }
        // captures
        int[] caps = { forward - 1, forward + 1 };
        foreach (var to in caps) {
            if (!IsInBoard(to)) continue;
            // Check file wrapping (e.g. h-file capture to a-file)
            int toFile = to % 8;
            if (Math.Abs(toFile - file) > 1) continue;

            var target = Get(to);
            if (!target.IsNone && target.Color != pawn.Color) {
                if (to/8 == 7 || to/8 == 0) {
                    // promotion captures
                    moves.Add(new Move(from,to){promotion=PieceType.Queen});
                    moves.Add(new Move(from,to){promotion=PieceType.Rook});
                    moves.Add(new Move(from,to){promotion=PieceType.Bishop});
                    moves.Add(new Move(from,to){promotion=PieceType.Knight});
                } else moves.Add(new Move(from,to));
            }
            // en passant
            if (to == enPassantSquare) {
                var m = new Move(from,to){ isEnPassant = true };
                moves.Add(m);
            }
        }
    }

    private void GenerateKnightMoves(int from, Piece p, List<Move> moves) {
        int[] offsets = { -17, -15, -10, -6, 6, 10, 15, 17 };
        int rank = from / 8;
        int file = from % 8;
        foreach (int offset in offsets) {
            int to = from + offset;
            if (!IsInBoard(to)) continue;
            int toRank = to / 8;
            int toFile = to % 8;
            // Check for large jumps wrapping around board
            if (Math.Abs(toRank - rank) > 2 || Math.Abs(toFile - file) > 2) continue;

            var target = Get(to);
            if (target.IsNone || target.Color != p.Color) {
                moves.Add(new Move(from, to));
            }
        }
    }

    private void GenerateSlidingMoves(int from, Piece p, List<Move> moves, int[] dirs) {
        int rank = from / 8;
        int file = from % 8;
        foreach (int dir in dirs) {
            for (int dist = 1; dist < 8; dist++) {
                int to = from + dir * dist;
                if (!IsInBoard(to)) break;
                
                // Check wrapping
                int toRank = to / 8;
                int toFile = to % 8;
                // Simple wrapping check: if we moved more than 1 file/rank per step, something is wrong (unless diagonal)
                // Better: check if we crossed board edge based on direction
                // For simplicity in 1D array, we need careful boundary checks.
                // Let's use coordinate logic for safety:
                int currentRank = (from + dir * (dist-1)) / 8;
                int currentFile = (from + dir * (dist-1)) % 8;
                int nextRank = to / 8;
                int nextFile = to % 8;
                if (Math.Abs(nextRank - currentRank) > 1 || Math.Abs(nextFile - currentFile) > 1) break;

                var target = Get(to);
                if (target.IsNone) {
                    moves.Add(new Move(from, to));
                } else {
                    if (target.Color != p.Color) {
                        moves.Add(new Move(from, to));
                    }
                    break; // blocked
                }
            }
        }
    }

    private void GenerateKingMoves(int from, Piece p, List<Move> moves) {
        int[] offsets = { -9, -8, -7, -1, 1, 7, 8, 9 };
        int rank = from / 8;
        int file = from % 8;
        foreach (int offset in offsets) {
            int to = from + offset;
            if (!IsInBoard(to)) continue;
            int toRank = to / 8;
            int toFile = to % 8;
            if (Math.Abs(toRank - rank) > 1 || Math.Abs(toFile - file) > 1) continue;

            var target = Get(to);
            if (target.IsNone || target.Color != p.Color) {
                moves.Add(new Move(from, to));
            }
        }
        // Castling (TODO: Add checks for attacked squares)
    }

    public Piece ApplyMove(Move m) {
        Piece moved = Get(m.from);
        Piece captured = Get(m.to);
        // push undo
        UndoInfo u = new UndoInfo {
            move = m,
            captured = captured,
            prevWhiteCastleK = whiteCanCastleKingSide,
            prevWhiteCastleQ = whiteCanCastleQueenSide,
            prevBlackCastleK = blackCanCastleKingSide,
            prevBlackCastleQ = blackCanCastleQueenSide,
            prevEnPassant = enPassantSquare,
            prevHalfmove = halfmoveClock,
            prevFullmove = fullmoveNumber
        };
        undoStack.Push(u);

        // Update halfmove clock
        if (moved.Type == PieceType.Pawn || !captured.IsNone) halfmoveClock = 0; else halfmoveClock++;

        // Handle en passant capture
        if (m.isEnPassant) {
            int capIdx = (sideToMove == PieceColor.White) ? (m.to - 8) : (m.to + 8);
            captured = Get(capIdx);
            Set(capIdx, new Piece(PieceType.None, PieceColor.White));
        }

        // Move piece
        Set(m.to, moved);
        Set(m.from, new Piece(PieceType.None, PieceColor.White));

        // Handle promotion
        if (m.promotion != PieceType.None) {
            Set(m.to, new Piece(m.promotion, moved.Color));
        }

        // Handle castling
        if (m.isCastling) {
            if (m.to % 8 == 6) { // king-side
                int rookFrom = m.to + 1;
                int rookTo = m.to - 1;
                Set(rookTo, Get(rookFrom));
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
            } else if (m.to % 8 == 2) { // queen-side
                int rookFrom = m.to - 2;
                int rookTo = m.to + 1;
                Set(rookTo, Get(rookFrom));
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
            }
        }

        // Update enPassantSquare
        enPassantSquare = -1;
        if (moved.Type == PieceType.Pawn && Math.Abs(m.to - m.from) == 16) {
            enPassantSquare = (m.from + m.to) / 2;
        }

        // swap side
        sideToMove = (sideToMove == PieceColor.White) ? PieceColor.Black : PieceColor.White;
        if (sideToMove == PieceColor.White) fullmoveNumber++;

        return captured;
    }

    public void UndoMove(Move m, Piece captured) {
        // pop undo
        var u = undoStack.Pop();
        // restore side
        sideToMove = (sideToMove == PieceColor.White) ? PieceColor.Black : PieceColor.White;
        // restore moved piece
        Piece moved = Get(m.to);
        // revert promotion
        if (m.promotion != PieceType.None) moved = new Piece(PieceType.Pawn, sideToMove);
        Set(m.from, moved);
        // restore captured piece
        Set(m.to, captured);

        // handle en passant undocapture
        if (m.isEnPassant) {
            int capIdx = (sideToMove == PieceColor.White) ? (m.to - 8) : (m.to + 8);
            Set(capIdx, new Piece(PieceType.Pawn, sideToMove == PieceColor.White ? PieceColor.Black : PieceColor.White));
            Set(m.to, new Piece(PieceType.None, PieceColor.White));
        }

        // undo castling rook move
        if (m.isCastling) {
            if (m.to % 8 == 6) {
                int rookFrom = m.to - 1;
                int rookTo = m.to + 1;
                Set(rookTo, Get(rookFrom));
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
            } else if (m.to % 8 == 2) {
                int rookFrom = m.to + 1;
                int rookTo = m.to - 2;
                Set(rookTo, Get(rookFrom));
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
            }
        }

        // restore other state flags
        whiteCanCastleKingSide = u.prevWhiteCastleK;
        whiteCanCastleQueenSide = u.prevWhiteCastleQ;
        blackCanCastleKingSide = u.prevBlackCastleK;
        blackCanCastleQueenSide = u.prevBlackCastleQ;
        enPassantSquare = u.prevEnPassant;
        halfmoveClock = u.prevHalfmove;
        fullmoveNumber = u.prevFullmove;
    }

    public bool IsKingInCheck(PieceColor color) {
        int kingSq = -1;
        for (int i = 0; i < 64; i++) {
            var p = Get(i);
            if (p.Type == PieceType.King && p.Color == color) {
                kingSq = i;
                break;
            }
        }
        if (kingSq == -1) return false; // Should not happen
        return IsSquareAttacked(kingSq, color == PieceColor.White ? PieceColor.Black : PieceColor.White);
    }

    public bool IsSquareAttacked(int sq, PieceColor byColor) {
        // Check pawn attacks
        int pawnDir = byColor == PieceColor.White ? -1 : 1; // Attack comes from opposite direction
        // Actually, if 'byColor' is White, they attack Up (index + 7/9).
        // If we are checking if 'sq' is attacked BY White, we look for White pawns at sq - 7 or sq - 9 (if white moves +8)
        // Wait, White pawns move +8. They attack +7 and +9.
        // So if we are at 'sq', a White pawn at 'sq - 7' attacks 'sq' (if valid).
        
        int attackDir = byColor == PieceColor.White ? 1 : -1;
        
        // Check for pawns
        int[] pawnOffsets = { -7, -9 }; // Reverse of attack direction
        foreach (int offset in pawnOffsets) {
            int from = sq - (offset * attackDir); // Look backwards
            if (IsInBoard(from)) {
                var p = Get(from);
                if (p.Type == PieceType.Pawn && p.Color == byColor) {
                    // Check file adjacency to ensure no wrapping
                    if (Math.Abs((from % 8) - (sq % 8)) == 1) return true;
                }
            }
        }

        // Check knights
        int[] knightOffsets = { -17, -15, -10, -6, 6, 10, 15, 17 };
        foreach (int offset in knightOffsets) {
            int from = sq + offset;
            if (IsInBoard(from)) {
                var p = Get(from);
                if (p.Type == PieceType.Knight && p.Color == byColor) {
                     if (Math.Abs((from % 8) - (sq % 8)) <= 2) return true;
                }
            }
        }

        // Check sliding (Queen, Rook, Bishop)
        int[] rookDirs = {-8, -1, 1, 8};
        int[] bishopDirs = {-9, -7, 7, 9};
        
        if (CheckSlidingAttack(sq, byColor, rookDirs, PieceType.Rook)) return true;
        if (CheckSlidingAttack(sq, byColor, bishopDirs, PieceType.Bishop)) return true;

        // Check King
        int[] kingOffsets = { -9, -8, -7, -1, 1, 7, 8, 9 };
        foreach (int offset in kingOffsets) {
            int from = sq + offset;
            if (IsInBoard(from)) {
                var p = Get(from);
                if (p.Type == PieceType.King && p.Color == byColor) {
                    if (Math.Abs((from % 8) - (sq % 8)) <= 1) return true;
                }
            }
        }

        return false;
    }

    private bool CheckSlidingAttack(int sq, PieceColor byColor, int[] dirs, PieceType type) {
        foreach (int dir in dirs) {
            for (int dist = 1; dist < 8; dist++) {
                int from = sq + dir * dist;
                if (!IsInBoard(from)) break;
                
                // Wrapping check
                int currentRank = (sq + dir * (dist-1)) / 8;
                int currentFile = (sq + dir * (dist-1)) % 8;
                int nextRank = from / 8;
                int nextFile = from % 8;
                if (Math.Abs(nextRank - currentRank) > 1 || Math.Abs(nextFile - currentFile) > 1) break;

                var p = Get(from);
                if (!p.IsNone) {
                    if (p.Color == byColor && (p.Type == type || p.Type == PieceType.Queen)) return true;
                    break; // Blocked by any piece
                }
            }
        }
        return false;
    }
}
