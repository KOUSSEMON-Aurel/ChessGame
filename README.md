# 🎮 Jeu d'Échecs Stylisé - Godot

Un jeu d'échecs 3D avec un style cartoon/mat utilisant Godot Engine et le moteur de rendu Mobile.

## 📋 Caractéristiques

✨ **Style Visuel**
- Motif damier généré par shader personnalisé
- Matériaux mats (roughness 1.0, metallic 0.0) pour un aspect cartoon
- Éclairage directionnel avec ombres douces
- Vue caméra orthogonale pour une perspective stylisée

🎯 **Effets Visuels**
- Système de surlignage émissif pour les cases valides
- Animation pulsante sur les highlights
- Couleurs configurables (vert pour mouvements valides, rouge pour danger)

🎲 **Logique de Jeu**
- Système de sélection de pièces par clic
- Conversion automatique coordonnées monde ↔ plateau
- Structure pour mouvements de toutes les pièces d'échecs

## 📁 Structure du Projet

```
chess-game/
├── project.godot              # Configuration principale
├── main_game.tscn            # Scène principale
├── default_env.tres          # Environnement (SSAO activé)
├── shaders/
│   └── board_shader.gdshader # Shader damier 8x8
├── materials/
│   ├── piece_white.tres      # Matériau pièces blanches
│   └── piece_black.tres      # Matériau pièces noires
├── scenes/
│   └── pieces/
│       └── highlight.tscn    # Surlignage émissif
├── scripts/
│   ├── main_game.gd          # Logique principale
│   ├── chess_piece.gd        # Classe de base des pièces
│   └── highlight.gd          # Script de surlignage
└── models/
    └── (vos fichiers .glb)   # Modèles 3D importés
```

## 🚀 Utilisation

### Ouvrir le Projet
1. Lancez Godot Engine (version 4.3 ou supérieure)
2. Cliquez sur "Importer"
3. Naviguez vers `chess-game/project.godot`
4. Cliquez sur "Importer et Éditer"

### Configuration du Plateau
Le shader damier est configurable via les paramètres du matériau :
- `dark_color` : Couleur des cases foncées (défaut: vert foncé)
- `light_color` : Couleur des cases claires (défaut: gris clair)
- `board_size` : Taille du plateau (défaut: 8.0)

### Ajouter des Pièces 3D
1. Placez vos fichiers `.glb` ou `.gltf` dans le dossier `models/`
2. Créez une nouvelle scène héritée du modèle importé
3. Attachez le script `chess_piece.gd`
4. Configurez `piece_type` et `piece_color` dans l'inspecteur
5. Appliquez le matériau approprié (`piece_white.tres` ou `piece_black.tres`)

### Personnaliser les Matériaux
Les matériaux sont configurés pour un aspect mat :
- **Metallic** : 0.0 (pas de reflets métalliques)
- **Roughness** : 1.0 (surface complètement diffuse)

## 🎨 Paramètres Graphiques

### Caméra
- **Projection** : Orthogonale (taille : 12.0)
- **Position** : (0, 10, 10) avec rotation vers le plateau
- **Alternative** : Changez en Perspective pour un effet différent

### Lumière Directionnelle
- **Rotation** : X: -50°, Y: -30° (approx)
- **Énergie** : 0.8
- **Ombres** : Activées

### Environnement
- **SSAO** : Activé pour ombres ambiantes douces
- **Lumière ambiante** : Énergie 0.3
- **Tonemap** : Mode 2

## 🎮 Contrôles (À Implémenter)

- **Clic gauche** : Sélectionner/déplacer une pièce
- Les cases valides s'affichent avec un surlignage vert émissif

## 🔧 Prochaines Étapes

- [ ] Implémenter la logique complète des mouvements pour chaque pièce
- [ ] Ajouter la détection d'échec et mat
- [ ] Créer des animations de déplacement fluides
- [ ] Implémenter le système de tour par tour
- [ ] Ajouter des effets sonores
- [ ] Créer un menu principal

## 📝 Notes Techniques

### Shader Damier
Le shader utilise `VERTEX.xz` pour calculer les coordonnées du monde et génère automatiquement le motif en damier en utilisant l'opération modulo sur les coordonnées de cellule.

### Système de Highlight
Les highlights sont instanciés dynamiquement et utilisent un matériau émissif non ombré (`SHADING_MODE_UNSHADED`) pour briller indépendamment de l'éclairage.

### Conversion de Coordonnées
- `world_to_board_position()` : Convertit Vector3 → Vector2i (0-7)
- `board_to_world_position()` : Convertit Vector2i → Vector3 (centré sur cases)

## 📜 Licence

Projet créé avec Godot Engine (MIT License)
