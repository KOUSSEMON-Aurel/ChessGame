#!/bin/bash
# Installation MINIMALISTE - Juste le NDK pour compiler Stockfish
# Pas d'émulateur, pas de SDK complet - juste ce qu'il faut !

set -e

echo "🚀 Installation MINIMALISTE d'Android NDK"
echo "=========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Répertoire de travail
NDK_DIR="$HOME/Android/ndk"
mkdir -p "$NDK_DIR"

echo -e "${BLUE}📥 Téléchargement d'Android NDK r26c (standalone, ~700MB)...${NC}"
echo -e "${YELLOW}⏳ Cela peut prendre 2-5 minutes selon ta connexion${NC}"

NDK_VERSION="r26c"
NDK_ZIP="android-ndk-${NDK_VERSION}-linux.zip"
NDK_URL="https://dl.google.com/android/repository/${NDK_ZIP}"

cd /tmp

if [ ! -f "$NDK_ZIP" ]; then
    wget --progress=bar:force "$NDK_URL" -O "$NDK_ZIP"
else
    echo -e "${GREEN}✅ NDK déjà téléchargé${NC}"
fi

echo -e "${BLUE}📦 Extraction du NDK (1-2 min)...${NC}"

if [ ! -d "$NDK_DIR/android-ndk-${NDK_VERSION}" ]; then
    unzip -q "$NDK_ZIP" -d "$NDK_DIR"
    echo -e "${GREEN}✅ NDK extrait${NC}"
else
    echo -e "${GREEN}✅ NDK déjà extrait${NC}"
fi

# Créer un lien symbolique
ln -sf "$NDK_DIR/android-ndk-${NDK_VERSION}" "$NDK_DIR/current"

# Configurer les variables d'environnement
SHELL_RC="$HOME/.zshrc"
if [ ! -f "$SHELL_RC" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q "ANDROID_NDK" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'EOF'

# Android NDK (pour compilation Stockfish)
export ANDROID_NDK="$HOME/Android/ndk/current"
export PATH="$PATH:$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
EOF
    echo -e "${GREEN}✅ Variables ajoutées à $SHELL_RC${NC}"
else
    echo -e "${GREEN}✅ Variables déjà configurées${NC}"
fi

# Export pour cette session
export ANDROID_NDK="$NDK_DIR/current"
export PATH="$PATH:$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

# Vérifier que le NDK fonctionne
if [ -f "$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang" ]; then
    echo -e "${GREEN}✅ NDK installé et fonctionnel !${NC}"
else
    echo -e "${RED}❌ Problème avec l'installation du NDK${NC}"
    exit 1
fi

# Nettoyer
rm -f "/tmp/$NDK_ZIP"

echo ""
echo -e "${GREEN}🎉 Installation terminée !${NC}"
echo ""
echo -e "${YELLOW}📋 Prochaine étape :${NC}"
echo -e "  ${BLUE}1.${NC} Compiler Stockfish : ${GREEN}bash setup_stockfish_android.sh${NC}"
echo ""
echo -e "${BLUE}📍 NDK installé :${NC}"
echo -e "  $ANDROID_NDK"
echo ""
echo -e "${YELLOW}💡 Pour l'émulateur :${NC}"
echo -e "  Tu peux l'installer plus tard avec Android Studio si tu veux tester l'APK"
echo -e "  Pour l'instant, on va compiler Stockfish et créer l'APK"
echo ""
