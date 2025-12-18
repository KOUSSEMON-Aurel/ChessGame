# Chess Game - Installation & Build

## ⚠️ Important Note on Large Files
To keep this repository lightweight and compatible with GitHub (file size < 100MB), the **compiled binaries** (APK, Executables, and native libraries like `libstockfish.so`) are **NOT** included in the source control.

## How to Build
### 1. Android Plugin (Stockfish)
The file `src/android/plugins/StockfishEngine/libs/armeabi-v7a/libstockfish.so` is required for Android export.
1. Download Stockfish source code.
2. Compile for ARMv7 Android.
3. Place the resulting `libstockfish.so` in `src/android/plugins/StockfishEngine/libs/armeabi-v7a/`.

### 2. Android Build Components
The following large build artifacts are excluded:
- `src/android/build/libs/debug/godot-lib.template_debug.aar`
- `src/android/build/libs/release/godot-lib.template_release.aar`
- `src/android/plugins/StockfishEngine/release/StockfishEngine-release.aar`

**To restore them:**
1. **Godot Libs:** In Godot Editor, go to `Project > Install Android Build Template`. This will restore the `godot-lib` files in `src/android/build/`.
2. **Stockfish Plugin:**
   - Open a terminal in `src/android/plugins/StockfishEngine/`.
   - Run `./gradlew assembleRelease`.
   - This re-creates the `StockfishEngine-release.aar`.

### 3. Exporting the Game
Open the project in **Godot 4.4+**.
- **Windows/Linux:** Use standard export presets.
- **Android:** Use the "Android" preset (ensure "Export With Debug" is checked if you want logs).
- **Web:** Requires Godot Standard version (Non-Mono) as Godot 4 Mono does not support Web export yet.

## Releases
Please verify if a Release section breaks containing the compiled versions exists on the repository page, or compile them yourself using the instructions above.
