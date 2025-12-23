package org.godotengine.chessgame;

import android.util.Log;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class StockfishEngine extends GodotPlugin {
    private static final String TAG = "StockfishEngine";
    private Process stockfishProcess;
    private BufferedWriter writer;
    private BufferedReader reader;
    private Thread outputThread;
    private boolean isRunning = false;

    public StockfishEngine(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "StockfishEngine";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("engine_output", String.class));
        return signals;
    }

    @UsedByGodot
    public boolean startEngine() {
        if (isRunning) return true;

        try {
            // Locate the native library extracted by Android
            // Android extracts JNI libs to user's nativeLibraryDir
            // Library name is "libstockfish.so", so we look for that file or use the dir
            String nativeLibDir = getActivity().getApplicationInfo().nativeLibraryDir;
            String stockfishPath = nativeLibDir + "/libstockfish.so";
            File stockfishBin = new File(stockfishPath);

            if (!stockfishBin.exists()) {
                Log.e(TAG, "Stockfish binary not found at: " + stockfishPath);
                return false;
            }

            Log.d(TAG, "Starting Stockfish from: " + stockfishPath);

            ProcessBuilder pb = new ProcessBuilder(stockfishPath);
            pb.directory(new File(nativeLibDir));
            stockfishProcess = pb.start();

            writer = new BufferedWriter(new OutputStreamWriter(stockfishProcess.getOutputStream()));
            reader = new BufferedReader(new InputStreamReader(stockfishProcess.getInputStream()));

            isRunning = true;

            // Start reading output in a separate thread
            outputThread = new Thread(() -> {
                try {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        // Emit signal to Godot on the main thread is NOT required for emitSignal,
                        // but safer. emitSignal is thread-safe in Godot 4 Android Plugin API?
                        // Usually yes.
                        emitSignal("engine_output", line);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error reading stockfish output", e);
                } finally {
                    isRunning = false;
                }
            });
            outputThread.start();

            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to start Stockfish", e);
            return false;
        }
    }

    @UsedByGodot
    public void sendCommand(String command) {
        if (!isRunning || writer == null) {
            Log.w(TAG, "Engine not running, cannot send: " + command);
            return;
        }
        try {
            writer.write(command);
            writer.write("\n");
            writer.flush();
        } catch (Exception e) {
            Log.e(TAG, "Error writing command", e);
        }
    }

    @UsedByGodot
    public void stopEngine() {
        if (stockfishProcess != null) {
            stockfishProcess.destroy();
            stockfishProcess = null;
        }
        isRunning = false;
        Log.d(TAG, "Stockfish engine stopped.");
    }
}
