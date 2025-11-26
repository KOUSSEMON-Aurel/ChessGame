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

    public ulong currentKey = 0;
    public List<ulong> history = new List<ulong>();

    // Stack to undo moves
    private Stack<UndoInfo> undoStack = new Stack<UndoInfo>();

    private struct UndoInfo {
        public Move move;
        public Piece captured;
        public bool prevWhiteCastleK, prevWhiteCastleQ, prevBlackCastleK, prevBlackCastleQ;
        public int prevEnPassant;
        public int prevHalfmove;
        public int prevFullmove;
        public ulong prevKey;
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
        currentKey = 0;
        history.Clear();
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

        // Initialize Zobrist Key
        currentKey = GenerateZobristKey();
        history.Add(currentKey);
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
                
                // Wrapping check
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
        
        // Castling
        // Cannot castle if in check
        if (IsSquareAttacked(from, p.Color == PieceColor.White ? PieceColor.Black : PieceColor.White)) return;

        if (p.Color == PieceColor.White) {
            // King Side (e1 -> g1)
            if (whiteCanCastleKingSide && Get(5).IsNone && Get(6).IsNone) {
                if (!IsSquareAttacked(5, PieceColor.Black) && !IsSquareAttacked(6, PieceColor.Black)) {
                    moves.Add(new Move(from, 6) { isCastling = true });
                }
            }
            // Queen Side (e1 -> c1)
            if (whiteCanCastleQueenSide && Get(3).IsNone && Get(2).IsNone && Get(1).IsNone) {
                if (!IsSquareAttacked(3, PieceColor.Black) && !IsSquareAttacked(2, PieceColor.Black)) {
                    moves.Add(new Move(from, 2) { isCastling = true });
                }
            }
        } else {
            // Black King Side (e8 -> g8)
            if (blackCanCastleKingSide && Get(61).IsNone && Get(62).IsNone) {
                if (!IsSquareAttacked(61, PieceColor.White) && !IsSquareAttacked(62, PieceColor.White)) {
                    moves.Add(new Move(from, 62) { isCastling = true });
                }
            }
            // Black Queen Side (e8 -> c8)
            if (blackCanCastleQueenSide && Get(59).IsNone && Get(58).IsNone && Get(57).IsNone) {
                if (!IsSquareAttacked(59, PieceColor.White) && !IsSquareAttacked(58, PieceColor.White)) {
                    moves.Add(new Move(from, 58) { isCastling = true });
                }
            }
        }
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
            prevFullmove = fullmoveNumber,
            prevKey = currentKey
        };
        undoStack.Push(u);

        // --- UPDATE ZOBRIST FOR REMOVED PIECES ---
        // Remove moved piece from source
        currentKey ^= Zobrist.pieces[m.from, Zobrist.GetPieceIndex(moved)];
        
        // Remove captured piece from target (if any)
        if (!captured.IsNone) {
            currentKey ^= Zobrist.pieces[m.to, Zobrist.GetPieceIndex(captured)];
        }

        // Update halfmove clock
        if (moved.Type == PieceType.Pawn || !captured.IsNone) halfmoveClock = 0; else halfmoveClock++;

        // Handle en passant capture
        if (m.isEnPassant) {
            int capIdx = (sideToMove == PieceColor.White) ? (m.to - 8) : (m.to + 8);
            Piece epCaptured = Get(capIdx);
            Set(capIdx, new Piece(PieceType.None, PieceColor.White));
            // Remove EP captured piece from Zobrist
            currentKey ^= Zobrist.pieces[capIdx, Zobrist.GetPieceIndex(epCaptured)];
        }

        // Move piece
        Set(m.to, moved);
        Set(m.from, new Piece(PieceType.None, PieceColor.White));
        
        // Add moved piece to target
        currentKey ^= Zobrist.pieces[m.to, Zobrist.GetPieceIndex(moved)];

        // Handle promotion
        if (m.promotion != PieceType.None) {
            // Remove pawn from target
            currentKey ^= Zobrist.pieces[m.to, Zobrist.GetPieceIndex(moved)];
            // Add promoted piece
            Piece promoPiece = new Piece(m.promotion, moved.Color);
            Set(m.to, promoPiece);
            currentKey ^= Zobrist.pieces[m.to, Zobrist.GetPieceIndex(promoPiece)];
        }

        // Handle castling move of rook
        if (m.isCastling) {
            if (m.to % 8 == 6) { // king-side
                int rookFrom = m.to + 1;
                int rookTo = m.to - 1;
                Piece rook = Get(rookFrom);
                Set(rookTo, rook);
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
                
                // Update Zobrist for Rook
                currentKey ^= Zobrist.pieces[rookFrom, Zobrist.GetPieceIndex(rook)];
                currentKey ^= Zobrist.pieces[rookTo, Zobrist.GetPieceIndex(rook)];
                
            } else if (m.to % 8 == 2) { // queen-side
                int rookFrom = m.to - 2;
                int rookTo = m.to + 1;
                Piece rook = Get(rookFrom);
                Set(rookTo, rook);
                Set(rookFrom, new Piece(PieceType.None, PieceColor.White));
                
                // Update Zobrist for Rook
                currentKey ^= Zobrist.pieces[rookFrom, Zobrist.GetPieceIndex(rook)];
                currentKey ^= Zobrist.pieces[rookTo, Zobrist.GetPieceIndex(rook)];
            }
        }

        // Update castling rights
        // Remove old castling rights from key
        currentKey ^= Zobrist.castling[GetCastlingRightsIndex()];
        
        if (moved.Type == PieceType.King) {
            if (moved.Color == PieceColor.White) {
                whiteCanCastleKingSide = false;
                whiteCanCastleQueenSide = false;
            } else {
                blackCanCastleKingSide = false;
                blackCanCastleQueenSide = false;
            }
        }
        if (moved.Type == PieceType.Rook) {
            if (m.from == 0) whiteCanCastleQueenSide = false;
            if (m.from == 7) whiteCanCastleKingSide = false;
            if (m.from == 56) blackCanCastleQueenSide = false;
            if (m.from == 63) blackCanCastleKingSide = false;
        }
        // If rook is captured
        if (m.to == 0) whiteCanCastleQueenSide = false;
        if (m.to == 7) whiteCanCastleKingSide = false;
        if (m.to == 56) blackCanCastleQueenSide = false;
        if (m.to == 63) blackCanCastleKingSide = false;
        
        // Add new castling rights to key
        currentKey ^= Zobrist.castling[GetCastlingRightsIndex()];

        // Update enPassantSquare
        // Remove old EP from key
        if (enPassantSquare != -1) {
            currentKey ^= Zobrist.enPassant[enPassantSquare % 8];
        }
        
        enPassantSquare = -1;
        if (moved.Type == PieceType.Pawn && Math.Abs(m.to - m.from) == 16) {
            enPassantSquare = (m.from + m.to) / 2;
            // Add new EP to key
            currentKey ^= Zobrist.enPassant[enPassantSquare % 8];
        } else {
            // No EP available
            currentKey ^= Zobrist.enPassant[8];
        }

        // swap side
        sideToMove = (sideToMove == PieceColor.White) ? PieceColor.Black : PieceColor.White;
        currentKey ^= Zobrist.sideToMove;
        
        if (sideToMove == PieceColor.White) fullmoveNumber++;
        
        // Add to history
        history.Add(currentKey);

        return captured;
    }

    public void UndoMove(Move m, Piece captured) {
        // pop undo
        var u = undoStack.Pop();
        
        // Remove current key from history
        history.RemoveAt(history.Count - 1);
        
        // Restore state
        sideToMove = (sideToMove == PieceColor.White) ? PieceColor.Black : PieceColor.White;
        
        // Restore pieces
        Piece moved = Get(m.to);
        if (m.promotion != PieceType.None) moved = new Piece(PieceType.Pawn, sideToMove);
        
        Set(m.from, moved);
        Set(m.to, captured);
        
        // Handle en passant undo
        if (m.isEnPassant) {
            int capIdx = (sideToMove == PieceColor.White) ? (m.to - 8) : (m.to + 8);
            Set(capIdx, new Piece(PieceType.Pawn, sideToMove == PieceColor.White ? PieceColor.Black : PieceColor.White));
            Set(m.to, new Piece(PieceType.None, PieceColor.White));
        }
        
        // Undo castling rook
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

        // Restore flags
        whiteCanCastleKingSide = u.prevWhiteCastleK;
        whiteCanCastleQueenSide = u.prevWhiteCastleQ;
        blackCanCastleKingSide = u.prevBlackCastleK;
        blackCanCastleQueenSide = u.prevBlackCastleQ;
        enPassantSquare = u.prevEnPassant;
        halfmoveClock = u.prevHalfmove;
        fullmoveNumber = u.prevFullmove;
        currentKey = u.prevKey;
    }

    private int GetCastlingRightsIndex() {
        int idx = 0;
        if (whiteCanCastleKingSide) idx |= 1;
        if (whiteCanCastleQueenSide) idx |= 2;
        if (blackCanCastleKingSide) idx |= 4;
        if (blackCanCastleQueenSide) idx |= 8;
        return idx;
    }
    
    private ulong GenerateZobristKey() {
        ulong key = 0;
        for (int i = 0; i < 64; i++) {
            Piece p = Get(i);
            if (!p.IsNone) {
                key ^= Zobrist.pieces[i, Zobrist.GetPieceIndex(p)];
            }
        }
        key ^= Zobrist.castling[GetCastlingRightsIndex()];
        if (enPassantSquare != -1) {
            key ^= Zobrist.enPassant[enPassantSquare % 8];
        } else {
            key ^= Zobrist.enPassant[8];
        }
        if (sideToMove == PieceColor.Black) {
            key ^= Zobrist.sideToMove;
        }
        return key;
    }

    public bool IsDraw() {
        if (halfmoveClock >= 100) return true; // 50-move rule
        if (IsRepetition()) return true;
        return false;
    }

    public bool IsRepetition() {
        // Check history for current key
        // We need to check if it appears 3 times.
        // History includes current position.
        int count = 0;
        for (int i = history.Count - 1; i >= 0; i--) {
            if (history[i] == currentKey) {
                count++;
                if (count >= 3) return true;
            }
            // Optimization: can stop if halfmove clock resets?
            // Yes, repetition is only possible within the current halfmove clock window (irreversible moves reset it)
            // But for simplicity, checking list is fast enough for now.
        }
        return false;
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
