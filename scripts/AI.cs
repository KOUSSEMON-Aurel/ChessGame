using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public class AI {
    private Board board;
    
    // Search Settings
    public int maxDepth = 4;
    public int timeLimitMs = 1000;
    
    // Stats
    public int nodesVisited = 0;
    
    // Transposition Table
    private Dictionary<ulong, TTEntry> transpositionTable = new Dictionary<ulong, TTEntry>();
    
    private struct TTEntry {
        public ulong key;
        public int depth;
        public int score;
        public int flag; // 0=Exact, 1=LowerBound, 2=UpperBound
        public Move bestMove;
    }

    public AI(Board b) { board = b; }

    public Move FindBestMove() {
        nodesVisited = 0;
        Move bestMove = new Move(0,0);
        int alpha = -1000000;
        int beta = 1000000;
        
        // Iterative Deepening
        long startTime = DateTime.Now.Ticks / TimeSpan.TicksPerMillisecond;
        
        for (int depth = 1; depth <= maxDepth; depth++) {
            // Check time
            if ((DateTime.Now.Ticks / TimeSpan.TicksPerMillisecond) - startTime > timeLimitMs) break;
            
            int score = Negamax(depth, alpha, beta, out Move depthBestMove);
            
            if (depthBestMove.from != depthBestMove.to) {
                bestMove = depthBestMove;
                // Console.WriteLine($"Depth {depth}: Score {score}, Move {bestMove.from}->{bestMove.to}");
            }
        }
        
        return bestMove;
    }

    private int Negamax(int depth, int alpha, int beta, out Move bestMove) {
        bestMove = new Move(0,0);
        
        // Check for draw
        if (board.IsDraw()) return 0;
        
        // Transposition Table Lookup
        if (transpositionTable.TryGetValue(board.currentKey, out TTEntry ttEntry)) {
            if (ttEntry.depth >= depth) {
                if (ttEntry.flag == 0) return ttEntry.score;
                if (ttEntry.flag == 1) alpha = Math.Max(alpha, ttEntry.score);
                if (ttEntry.flag == 2) beta = Math.Min(beta, ttEntry.score);
                if (alpha >= beta) {
                    bestMove = ttEntry.bestMove;
                    return ttEntry.score;
                }
            }
            // Use TT move for ordering
            if (ttEntry.bestMove.from != ttEntry.bestMove.to) bestMove = ttEntry.bestMove; 
        }

        if (depth == 0) {
            return Quiescence(alpha, beta);
        }

        var moves = board.GenerateLegalMoves();
        if (moves.Count == 0) {
            if (board.IsKingInCheck(board.sideToMove)) return -100000 + (maxDepth - depth); // Mate
            return 0; // Stalemate
        }
        
        // Move Ordering
        OrderMoves(moves, bestMove); // bestMove here is from TT

        int originalAlpha = alpha;
        Move currentBestMove = new Move(0,0);
        int bestScore = -1000000;

        foreach (var m in moves) {
            var captured = board.ApplyMove(m);
            nodesVisited++;
            
            int score = -Negamax(depth - 1, -beta, -alpha, out _);
            
            board.UndoMove(m, captured);

            if (score > bestScore) {
                bestScore = score;
                currentBestMove = m;
            }
            
            if (score > alpha) {
                alpha = score;
            }
            
            if (alpha >= beta) break; // Cutoff
        }
        
        // Store in TT
        TTEntry newEntry;
        newEntry.key = board.currentKey;
        newEntry.depth = depth;
        newEntry.score = bestScore;
        newEntry.bestMove = currentBestMove;
        
        if (bestScore <= originalAlpha) newEntry.flag = 2; // UpperBound
        else if (bestScore >= beta) newEntry.flag = 1; // LowerBound
        else newEntry.flag = 0; // Exact
        
        transpositionTable[board.currentKey] = newEntry;
        
        bestMove = currentBestMove;
        return bestScore;
    }

    private int Quiescence(int alpha, int beta) {
        int standPat = Evaluate();
        if (standPat >= beta) return beta;
        if (alpha < standPat) alpha = standPat;

        var moves = board.GenerateLegalMoves(); // Should optimize to only generate captures
        // Filter captures only
        var captures = new List<Move>();
        foreach(var m in moves) {
            if (!board.Get(m.to).IsNone) captures.Add(m);
        }
        
        OrderMoves(captures, new Move(0,0));

        foreach (var m in captures) {
            var captured = board.ApplyMove(m);
            nodesVisited++;
            
            int score = -Quiescence(-beta, -alpha);
            
            board.UndoMove(m, captured);

            if (score >= beta) return beta;
            if (score > alpha) alpha = score;
        }
        return alpha;
    }

    private void OrderMoves(List<Move> moves, Move ttMove) {
        // Simple scoring: TT move > Captures (MVV-LVA) > Others
        int[] scores = new int[moves.Count];
        for (int i = 0; i < moves.Count; i++) {
            if (moves[i].from == ttMove.from && moves[i].to == ttMove.to) {
                scores[i] = 1000000;
                continue;
            }
            
            var move = moves[i];
            var captured = board.Get(move.to);
            if (!captured.IsNone) {
                // MVV-LVA: 10 * VictimValue - AttackerValue
                int victimValue = PieceValue(captured.Type);
                int attackerValue = PieceValue(board.Get(move.from).Type);
                scores[i] = 10000 + victimValue * 10 - attackerValue;
            } else {
                scores[i] = 0;
            }
        }
        
        // Sort
        Array.Sort(scores, moves.ToArray()); // This doesn't work directly as Sort expects keys/items
        // Custom sort
        moves.Sort((a, b) => {
            int scoreA = ScoreMove(a, ttMove);
            int scoreB = ScoreMove(b, ttMove);
            return scoreB.CompareTo(scoreA); // Descending
        });
    }
    
    private int ScoreMove(Move m, Move ttMove) {
        if (m.from == ttMove.from && m.to == ttMove.to) return 1000000;
        
        var captured = board.Get(m.to);
        if (!captured.IsNone) {
             int victimValue = PieceValue(captured.Type);
             int attackerValue = PieceValue(board.Get(m.from).Type);
             return 10000 + victimValue * 10 - attackerValue;
        }
        return 0;
    }

    private int Evaluate() {
        // Material + PST
        int score = 0;
        for (int i=0;i<64;i++) {
            var p = board.Get(i);
            if (p.IsNone) continue;
            
            int v = PieceValue(p.Type);
            
            // Basic PST (Centralization)
            int rank = i / 8;
            int file = i % 8;
            // Bonus for center
            if (file >= 2 && file <= 5 && rank >= 2 && rank <= 5) v += 10;
            
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
