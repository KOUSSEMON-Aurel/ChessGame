#!/bin/bash
set -e

echo "🏗️  Stockfish Android Cross-Compilation (All Archs)"
echo "==================================================="

PROJECT_ROOT="$(pwd)"

# 1. Detect NDK
NDK_PATH="$HOME/Android/ndk/current"
if [ ! -d "$NDK_PATH" ]; then
    NDK_PATH="$HOME/Android/Sdk/ndk/current"
fi

if [ ! -d "$NDK_PATH" ]; then
    echo "❌ NDK not found. Please install via Android Studio or sdkmanager."
    exit 1
fi
echo "✅ NDK found: $NDK_PATH"

# 2. Setup Sources
STOCK_DIR="temp_stockfish_src"
if [ ! -d "$STOCK_DIR" ]; then
    echo "📥 Cloning Stockfish..."
    git clone --depth 1 https://github.com/official-stockfish/Stockfish.git "$STOCK_DIR"
fi

# 3. Compilation Loop
HOST_TAG="linux-x86_64"
TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_TAG"
API_LEVEL="21"

# Map: ABI -> Target Triple Prefix
declare -A TARGETS
TARGETS["armeabi-v7a"]="armv7a-linux-androideabi"
TARGETS["arm64-v8a"]="aarch64-linux-android"
TARGETS["x86"]="i686-linux-android"
TARGETS["x86_64"]="x86_64-linux-android"

# Map: ABI -> Stockfish ARCH
declare -A SF_ARCHS
SF_ARCHS["armeabi-v7a"]="armv7-neon"
SF_ARCHS["arm64-v8a"]="armv8"
SF_ARCHS["x86"]="x86-32"
SF_ARCHS["x86_64"]="x86-64"

DEST_BASE="src/android/plugins/StockfishEngine/libs"
mkdir -p "$DEST_BASE"

export PATH="$TOOLCHAIN/bin:$PATH"

for ABI in "${!TARGETS[@]}"; do
    TARGET="${TARGETS[$ABI]}"
    SF_ARCH="${SF_ARCHS[$ABI]}"
    
    echo "---------------------------------------------------"
    echo "🔨 Building for $ABI ($SF_ARCH)..."
    
    # Determine compiler name
    # Logic: API level is appended to target for clang++
    CXX_COMPILER="${TARGET}${API_LEVEL}-clang++"
    
    # Special case for 32-bit ARM (uses armv7a...21-clang++)
    if [ "$ABI" == "armeabi-v7a" ]; then
         CXX_COMPILER="armv7a-linux-androideabi${API_LEVEL}-clang++"
    fi

    OUT_DIR="$DEST_BASE/$ABI"
    mkdir -p "$OUT_DIR"

    cd "$STOCK_DIR/src"
    make clean > /dev/null

    make -j$(nproc) build \
        ARCH="$SF_ARCH" \
        COMP=ndk \
        ANDROID_NDK="$NDK_PATH" \
        CXX="$TOOLCHAIN/bin/$CXX_COMPILER" \
        > ../build_$ABI.log 2>&1

    if [ -f "stockfish" ]; then
        echo "✅ Compilaton success for $ABI"
        # Use absolute path to avoid confusion
        cp stockfish "$PROJECT_ROOT/$OUT_DIR/libstockfish.so"
        "$TOOLCHAIN/bin/llvm-strip" "$PROJECT_ROOT/$OUT_DIR/libstockfish.so"
    else
        echo "❌ Compilation failed for $ABI. Check logs."
        cat ../build_$ABI.log | tail -n 10
        exit 1
    fi
    cd ../..
done

echo ""
echo "🎉 All architectures compiled successfully!"
ls -R "$DEST_BASE"
