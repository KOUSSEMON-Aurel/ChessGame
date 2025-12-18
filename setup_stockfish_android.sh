#!/bin/bash
# Compilation simplifiée de Stockfish pour Android ARMv7 NEON

set -e

echo "🏗️  Compilation de Stockfish pour Android ARMv7 NEON"
echo "===================================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Trouver le NDK
NDK_PATH="$HOME/Android/ndk/current"

if [ ! -d "$NDK_PATH" ]; then
    NDK_PATH="$HOME/Android/Sdk/ndk/current"
fi

if [ ! -d "$NDK_PATH" ]; then
    echo "❌ NDK non trouvé"
    exit 1
fi

echo -e "${GREEN}✅ NDK trouvé : $NDK_PATH${NC}"

# Aller dans le répertoire de Stockfish
STOCK_DIR="/tmp/stockfish_android_build/Stockfish/src"

if [ ! -d "$STOCK_DIR" ]; then
    echo -e "${BLUE}📥 Clonage de Stockfish...${NC}"
    mkdir -p /tmp/stockfish_android_build
    cd /tmp/stockfish_android_build
    git clone --depth 1 https://github.com/official-stockfish/Stockfish.git
fi

cd "$STOCK_DIR"

echo -e "${BLUE}🔨 Compilation (peut prendre 5-10 min)...${NC}"

# Nettoyer
make clean 2>/dev/null || true

# Configurer les chemins NDK
TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export PATH="$TOOLCHAIN/bin:$PATH"

# Compiler avec les bonnes options
make -j$(nproc) build \
    ARCH=armv7-neon \
    COMP=ndk \
    ANDROID_NDK="$NDK_PATH" \
    CXX="$TOOLCHAIN/bin/armv7a-linux-androideabi21-clang++" \
    2>&1 | tee compile.log

if [ ! -f "stockfish" ]; then
    echo "❌ Compilation échouée, voir compile.log"
    exit 1
fi

echo -e "${GREEN}✅ Compilation réussie !${NC}"

# Copier vers le projet
DEST="/home/aurel/ChessGame/engine/stockfish-android-armv7"
cp stockfish "$DEST"
chmod +x "$DEST"

# Strip pour réduire la taille
"$TOOLCHAIN/bin/llvm-strip" "$DEST"

SIZE=$(du -h "$DEST" | cut -f1)
echo -e "${GREEN}✅ Binaire créé : $DEST ($SIZE)${NC}"
echo ""
echo -e "${BLUE}🎯 Proch étape : Adapter Engine.gd pour Android${NC}"
