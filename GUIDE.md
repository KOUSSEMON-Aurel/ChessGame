# 🎯 Guide Rapide - Jeu d'Échecs

## ✅ Ce qui fonctionne maintenant

### Pièces sur le Plateau
- ✅ Toutes les pièces sont automatiquement placées
- ✅ 6 pions blancs sur la ligne 2, 6 pions noirs sur la ligne 7
- ✅ Pièces majeures (sans cavaliers) sur les lignes 1 et 8
- ✅ Matériaux blancs/noirs appliqués automatiquement
- ✅ Orientation correcte (rotation -90°)

### Interaction
- ✅ Cliquez sur une pièce pour la sélectionner
- ✅ Les cases adjacentes s'illuminent en vert (surlignage émissif)
- ✅ Messages dans la console affichent la pièce sélectionnée

### Visuel
- ✅ Plateau damier **6x8** (6 colonnes, 8 lignes)
- ✅ Couleurs : vert foncé / gris clair
- ✅ Caméra orthogonale vue de haut
- ✅ Éclairage directionnel avec ombres
- ✅ SSAO pour profondeur visuelle

## 🎮 Comment Tester

1. **Lancer le jeu** : Appuyez sur `F5` dans Godot
2. **Vérifier les pièces** : Vous devriez voir toutes les 32 pièces sur le plateau
3. **Cliquer sur une pièce** : Elle sera sélectionnée et des highlights verts apparaîtront
4. **Regarder la console** : Les messages indiquent quelle pièce est sélectionnée

## 🔍 Déboguer

### Les pièces n'apparaissent pas ?
Vérifiez la console pour les erreurs de chargement :
- Assurez-vous que tous les `.glb` sont dans `Assets/`
- Les messages "Placement des pièces..." et "Toutes les pièces placées!" doivent s'afficher

### Les clics ne fonctionnent pas ?
- Vérifiez que le `StaticBody3D` du plateau a bien une `CollisionShape3D`
- Les messages "Pièce sélectionnée:" ou "Aucune pièce..." doivent apparaître

### Les pièces sont mal orientées ?
- La rotation de -90° est appliquée automatiquement
- Modifiez `piece.rotation_degrees.y` dans `create_piece()` si nécessaire

## 🎨 Personnalisation Express

### Changer les couleurs du damier
Dans `main_game.tscn`, modifiez les paramètres du ShaderMaterial :
- `dark_color` : Couleur cases foncées
- `light_color` : Couleur cases claires

### Changer les couleurs des pièces
Éditez les fichiers :
- `materials/piece_white.tres`
- `materials/piece_black.tres`

### Changer la couleur des highlights
Dans `scripts/highlight.gd`, ligne 4 :
```gdscript
var highlight_color: Color = Color.GREEN  # Changez ici
```

## 📊 Structure des Données

### board_pieces (Dictionnaire)
Chaque pièce est stockée avec :
```gdscript
{
    "node": référence au Node3D,
    "type": "pawn" | "rook" | "knight" | "bishop" | "queen" | "king",
    "color": "white" | "black",
    "position": Vector2i(x, y)  # 0-7
}
```

### Coordonnées du Plateau
- **Notation** : Vector2i(colonne, ligne)
- **Dimensions** : 6 colonnes (0-5) x 8 lignes (0-7)
- **Blancs** : Ligne 0 (pièces) et ligne 1 (pions)
- **Noirs** : Ligne 7 (pièces) et ligne 6 (pions)
- **Conversion** : `board_to_world_position()` et `world_to_board_position()`

## 🚀 Prochaines Améliorations

1. **Déplacements réels** : Implémenter la logique de mouvement complète
2. **Règles d'échecs** : Ajouter les règles de chaque pièce
3. **Capture** : Permettre la prise de pièces adverses
4. **Animations** : Tweens pour déplacements fluides
5. **UI** : Indicateur de tour, historique, minuteur

---

**Bon développement ! 🎉**
