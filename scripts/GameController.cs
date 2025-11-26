using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class GameController : Node {
    private Board board;
    private AI ai;

    [Signal]
    public delegate void MovePlayedEventHandler(int from, int to, int promotionType);

    public override void _Ready() {
        GD.Print("🎮 C# GameController Initialized");
        board = new Board();
        board.SetInitialPosition();
        ai = new AI(board);
    }

    public void StartGame() {
        board.SetInitialPosition();
        GD.Print("♟️ Board Reset");
    }

    public Godot.Collections.Array<int> GetValidMoves(int fromIndex) {
        var moves = board.GenerateLegalMoves();
        var validTargets = new Godot.Collections.Array<int>();
        
        foreach (var m in moves) {
            if (m.from == fromIndex) {
                validTargets.Add(m.to);
            }
        }
        return validTargets;
    }

    public bool TryPlayMove(int from, int to) {
        var moves = board.GenerateLegalMoves();
        foreach (var m in moves) {
            if (m.from == from && m.to == to) {
                board.ApplyMove(m);
                GD.Print($"✅ Move Played: {from} -> {to}");
                EmitSignal(SignalName.MovePlayed, m.from, m.to, (int)m.promotion);
                return true;
            }
        }
        return false;
    }

    public async void PlayAIMove() {
        if (board.GenerateLegalMoves().Count == 0) {
            GD.Print("🏁 Game Over");
            return;
        }

        GD.Print("🤖 AI Thinking...");
        // Run AI in a separate task to avoid freezing UI
        Move bestMove = await Task.Run(() => ai.FindBestMove());
        
        board.ApplyMove(bestMove);
        GD.Print($"🤖 AI Played: {bestMove.from} -> {bestMove.to}");
        EmitSignal(SignalName.MovePlayed, bestMove.from, bestMove.to, (int)bestMove.promotion);
    }
    
    // Helper to get piece info for visualizer
    public int GetPieceTypeAt(int index) {
        return (int)board.Get(index).Type;
    }
    
    public int GetPieceColorAt(int index) {
        return (int)board.Get(index).Color;
    }
}
