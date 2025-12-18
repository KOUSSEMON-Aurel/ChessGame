#!/bin/bash
# Script de test de Stockfish sur émulateur Android
# Vérifie que le binaire fonctionne correctement

set -e

echo "🧪 Test de Stockfish sur émulateur Android"
echo "==========================================="

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Vérifier que le binaire existe
STOCKFISH_BIN="./engine/stockfish-android-armv7"

if [ ! -f "$STOCKFISH_BIN" ]; then
    echo -e "${RED}❌ Binaire Stockfish non trouvé : $STOCKFISH_BIN${NC}"
    echo -e "${YELLOW}💡 Exécutez d'abord : bash setup_stockfish_android.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Binaire trouvé : $STOCKFISH_BIN${NC}"

# Vérifier qu'adb est disponible
if ! command -v adb &> /dev/null; then
    echo -e "${RED}❌ adb non trouvé${NC}"
    exit 1
fi

# Vérifier qu'un device est connecté
echo -e "${BLUE}📱 Recherche d'un émulateur ou appareil Android...${NC}"

adb devices -l

DEVICE_COUNT=$(adb devices | grep -c "device$" || true)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Aucun appareil détecté${NC}"
    echo -e "${BLUE}🚀 Démarrage de l'émulateur ChessGame_Test...${NC}"
    
    # Vérifier si l'émulateur existe
    if ! "$ANDROID_HOME/emulator/emulator" -list-avds | grep -q "ChessGame_Test"; then
        echo -e "${RED}❌ Émulateur ChessGame_Test non trouvé${NC}"
        echo -e "${YELLOW}💡 Exécutez d'abord : bash setup_android_env.sh${NC}"
        exit 1
    fi
    
    # Lancer l'émulateur en arrière-plan
    "$ANDROID_HOME/emulator/emulator" -avd ChessGame_Test -no-audio -no-boot-anim &> /tmp/emulator.log &
    EMULATOR_PID=$!
    
    echo -e "${BLUE}⏳ Attente du démarrage de l'émulateur...${NC}"
    
    # Attendre que l'émulateur soit prêt (max 60 secondes)
    TIMEOUT=60
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if adb devices | grep -q "device$"; then
            echo -e "${GREEN}✅ Émulateur démarré${NC}"
            sleep 5  # Attendre un peu plus pour être sûr
            break
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        echo -n "."
    done
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "${RED}❌ Timeout lors du démarrage de l'émulateur${NC}"
        kill $EMULATOR_PID 2>/dev/null || true
        exit 1
    fi
fi

echo -e "${GREEN}✅ Appareil Android prêt${NC}"

# Copier Stockfish sur l'appareil
echo -e "${BLUE}📤 Transfert de Stockfish vers l'appareil...${NC}"

adb push "$STOCKFISH_BIN" /data/local/tmp/stockfish

# Rendre le binaire exécutable
echo -e "${BLUE}🔧 Configuration des permissions...${NC}"
adb shell "chmod +x /data/local/tmp/stockfish"

# Tester que Stockfish démarre et répond
echo -e "${BLUE}🎯 Test de Stockfish...${NC}"

TEST_OUTPUT=$(adb shell "echo 'uci' | /data/local/tmp/stockfish" 2>&1)

echo "$TEST_OUTPUT"

# Vérifier la présence de "uciok"
if echo "$TEST_OUTPUT" | grep -q "uciok"; then
    echo -e "${GREEN}✅ Stockfish fonctionne correctement !${NC}"
    echo -e "${GREEN}✅ Réponse UCI reçue : uciok${NC}"
else
    echo -e "${RED}❌ Stockfish ne répond pas correctement${NC}"
    echo -e "${YELLOW}🔍 Sortie complète :${NC}"
    echo "$TEST_OUTPUT"
    exit 1
fi

# Test d'un coup simple
echo -e "${BLUE}♟️  Test d'analyse d'une position...${NC}"

POSITION_TEST=$(adb shell "cat <<'EOF' | /data/local/tmp/stockfish
uci
isready
position startpos
go movetime 1000
quit
EOF" 2>&1)

echo "$POSITION_TEST"

if echo "$POSITION_TEST" | grep -q "bestmove"; then
    BEST_MOVE=$(echo "$POSITION_TEST" | grep "bestmove" | head -1 | awk '{print $2}')
    echo -e "${GREEN}✅ Analyse réussie !${NC}"
    echo -e "${GREEN}✅ Meilleur coup : $BEST_MOVE${NC}"
else
    echo -e "${YELLOW}⚠️  Pas de bestmove reçu${NC}"
fi

# Vérifier les logs système pour détecter d'éventuelles erreurs
echo -e "${BLUE}📋 Vérification des logs système...${NC}"

adb logcat -d | grep -i "stockfish\|illegal\|sigsegv\|fatal" | tail -20 || true

echo ""
echo -e "${GREEN}🎉 Test terminé avec succès !${NC}"
echo ""
echo -e "${YELLOW}📋 Prochaines étapes :${NC}"
echo -e "  1. Adapter Engine.gd pour utiliser ce binaire sur Android"
echo -e "  2. Configurer l'export Android dans Godot"
echo -e "  3. Compiler et tester l'APK"
echo ""
