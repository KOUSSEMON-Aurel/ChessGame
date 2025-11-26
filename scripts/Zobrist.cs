using System;

public static class Zobrist {
    public static ulong[,] pieces = new ulong[64, 14]; // [square, piece_type_index] (0-13 to be safe)
    public static ulong[] castling = new ulong[16];
    public static ulong[] enPassant = new ulong[9]; // 0-7 files, 8 = none
    public static ulong sideToMove;

    static Zobrist() {
        // Use a fixed seed for deterministic behavior
        Random rng = new Random(123456);

        for (int i = 0; i < 64; i++) {
            for (int j = 0; j < 14; j++) {
                pieces[i, j] = Random64(rng);
            }
        }

        for (int i = 0; i < 16; i++) {
            castling[i] = Random64(rng);
        }

        for (int i = 0; i < 9; i++) {
            enPassant[i] = Random64(rng);
        }

        sideToMove = Random64(rng);
    }

    private static ulong Random64(Random rng) {
        byte[] buffer = new byte[8];
        rng.NextBytes(buffer);
        return BitConverter.ToUInt64(buffer, 0);
    }

    // Helper to map PieceType + Color to index 0-11
    // White: Pawn=0, Knight=1, Bishop=2, Rook=3, Queen=4, King=5
    // Black: Pawn=6, Knight=7, Bishop=8, Rook=9, Queen=10, King=11
    public static int GetPieceIndex(Piece p) {
        if (p.IsNone) return 12; // Should not happen for hashing usually
        int offset = (p.Color == PieceColor.White) ? 0 : 6;
        return offset + (int)p.Type - 1; // Type enum starts at 1 for Pawn
    }
}
