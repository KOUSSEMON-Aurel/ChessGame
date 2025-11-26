using System;
using System.Collections.Generic;

public class AI {
    private Board board;
    public int maxDepth = 3;

    public AI(Board b) { board = b; }

    public Move FindBestMove() {
        int alpha = int.MinValue + 1;
        int beta = int.MaxValue - 1;
        Move best = new Move(0,0);
        int bestScore = int.MinValue + 1;
        
        var moves = board.GenerateLegalMoves();
        // Simple move ordering: captures first could be added here
        
        foreach (var m in moves) {
            var captured = board.ApplyMove(m);
            int score = -AlphaBeta(maxDepth - 1, -beta, -alpha);
            board.UndoMove(m, captured);
            
            if (score > bestScore) {
                bestScore = score;
                best = m;
            }
            if (score > alpha) alpha = score;
        }
        return best;
    }

    private int AlphaBeta(int depth, int alpha, int beta) {
        if (depth == 0) return Evaluate();
        
        var moves = board.GenerateLegalMoves();
        if (moves.Count == 0) {
            // checkmate or stalemate
            if (board.IsKingInCheck(board.sideToMove)) return -100000 - depth; // mate preference
            else return 0; // stalemate
        }
        
        foreach (var m in moves) {
            var captured = board.ApplyMove(m);
            int score = -AlphaBeta(depth - 1, -beta, -alpha);
            board.UndoMove(m, captured);
            
            if (score >= beta) return beta; // cutoff
            if (score > alpha) alpha = score;
        }
        return alpha;
    }

    private int Evaluate() {
        // simple material + piece-square tables
        int score = 0;
        for (int i=0;i<64;i++) {
            var p = board.Get(i);
            if (p.IsNone) continue;
            int v = PieceValue(p.Type);
            score += (p.Color == PieceColor.White ? v : -v);
        }
        return (board.sideToMove == PieceColor.White) ? score : -score;
    }

    private int PieceValue(PieceType t) {
        switch (t) {
            case PieceType.Pawn: return 100;
            case PieceType.Knight: return 320;
            case PieceType.Bishop: return 330;
            case PieceType.Rook: return 500;
            case PieceType.Queen: return 900;
            case PieceType.King: return 20000;
        }
        return 0;
    }
}
