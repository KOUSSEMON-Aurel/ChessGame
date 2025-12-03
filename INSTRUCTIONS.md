# Chess Game - Cross-Platform Adaptation

## ✅ PROJET ADAPTÉ AVEC SUCCÈS!

Votre jeu d'échecs Godot est maintenant compatible avec **Linux**, **Windows** et **macOS**.

## 🚀 Démarrage Rapide

### Sur Linux (actuellement configuré):
```bash
# Si pas encore fait, exécuter le setup:
./setup.sh

# Lancer le jeu dans Godot:
./launch.sh
# OU manuellement:
cd src && godot4 project.godot
```

### Sur Windows:
1. Copier le dossier du projet sur votre machine Windows
2. Exécuter `setup.bat`
3. Ouvrir `src/project.godot` dans Godot 4
4. Appuyer sur F5 pour lancer

## 📁 Structure Créée

```
ChessGame/
├── bin/
│   ├── linux/          ✅ Binaires compilés (7.3MB)
│   │   ├── iopiper
│   │   ├── sampler
│   │   └── ping-server
│   └── windows/        ✅ Binaires compilés (7.6MB)
│       ├── iopiper.exe
│       ├── sampler.exe
│       └── ping-server.exe
├── engine/
│   └── stockfish-linux-x64  ✅ Téléchargé (66MB)
├── Makefile            ✅ Build system multi-plateformes
├── setup.sh            ✅ Setup automatique Linux/macOS
├── setup.bat           ✅ Setup automatique Windows
├── launch.sh           ✅ Lanceur rapide
└── README.md           ✅ Documentation complète
```

## 🎯 Ce Qui A Été Fait

1. ✅ **Installation de Go** sur Linux (~/go/)
2. ✅ **Makefile multi-plateformes** créé
3. ✅ **Scripts de setup automatiques** (setup.sh, setup.bat)
4. ✅ **Compilation des binaires Go**:
   - Linux: iopiper, sampler, ping-server
   - Windows: iopiper.exe, sampler.exe, ping-server.exe
5. ✅ **Téléchargement automatique de Stockfish** pour Linux
6. ✅ **Modification de Engine.gd** avec détection de plateforme
7. ✅ **Documentation complète** (README.md)

## 🔧 Commandes Utiles

```bash
# Build
make              # Compiler pour la plateforme actuelle
make build-all    # Compiler pour toutes les plateformes
make clean        # Nettoyer les binaires

# Setup
./setup.sh        # Linux/macOS
setup.bat         # Windows

# Lancer
./launch.sh       # Ouvrir dans Godot (Linux)
```

## 📖 Documentation

- **README.md** - Guide complet avec instructions détaillées
- **walkthrough.md** (artifacts) - Documentation technique des modifications
- **implementation_plan.md** (artifacts) - Plan d'implémentation

## ⚠️ Notes Importantes

### Go PATH
Si vous fermez votre terminal, ajoutez Go au PATH de manière permanente:
```bash
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### Windows
Sur Windows, vous devrez:
1. Avoir Go installé (déjà le cas selon vos dires)
2. Exécuter `setup.bat` pour télécharger Stockfish

### macOS (non testé)
Le support macOS est inclus dans le code mais n'a pas été testé.
Vous pouvez utiliser `setup.sh` sur macOS.

## 🎮 Fonctionnalités du Jeu

- **3 Modes de jeu**: Joueur vs IA, Joueur vs Joueur, IA vs IA
- **10 Niveaux d'IA**: Du débutant au maître
- **2 Conditions de victoire**: Mat/Pat classique ou Élimination totale
- **Historique des coups**: Visualiser et naviguer
- **Sauvegarde/Chargement**: Sauvegarder votre progression

## ✨ Prochaines Étapes

1. **Tester sur Linux**: Ouvrir dans Godot et jouer une partie
2. **Tester sur Windows**: Copier le projet et exécuter setup.bat
3. **Exporter le jeu**: Utiliser Project → Export dans Godot
4. **Distribuer**: Les exports incluent automatiquement les bons binaires

## 🐛 En Cas de Problème

**"Missing iopiper"**: Exécuter le script setup pour votre plateforme
**"Missing chess engine"**: Vérifier que Stockfish est dans engine/
**Go non trouvé**: S'assurer que Go est dans le PATH

Consultez la section Troubleshooting du README.md

---

**Tout est prêt! Lancez le jeu et amusez-vous! 🎯♟️**
