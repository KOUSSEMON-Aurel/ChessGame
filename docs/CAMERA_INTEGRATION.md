# 🎥 Guide d'Intégration - Caméra Dynamique ChessGame

## 📦 Fichiers Générés

Votre projet contient maintenant :

1. **[src/camera/ChessCameraController.gd](file:///home/aurel/ChessGame/src/camera/ChessCameraController.gd)** - Script de contrôle de caméra
2. **[GODOT_CAMERA_GUIDE.md](file:///home/aurel/ChessGame/GODOT_CAMERA_GUIDE.md)** - Guide détaillé avec tous les mouvements analysés
3. **[camera_analysis.json](file:///home/aurel/ChessGame/camera_analysis.json)** - Données brutes de l'analyse
4. **[analyze_camera.py](file:///home/aurel/ChessGame/analyze_camera.py)** - Script d'analyse réutilisable

## 🚀 Intégration en 3 Étapes

### Étape 1 : Modifier votre scène pour utiliser le nouveau script

Votre projet utilise déjà un `SubViewport` avec une `Camera3D`. Vous devez :

1. Ouvrir votre scène principale dans Godot
2. Sélectionner le nœud `Camera3D` dans `Container/SubViewportContainer/SubViewport/Camera3D`
3. **Attacher le script** : 
   - Cliquez sur l'icône de script à côté du nœud
   - Sélectionnez "Load" et choisissez `src/camera/ChessCameraController.gd`
   - OU ajoutez directement dans la scène `.tscn` :
     ```
     [node name="Camera3D" type="Camera3D"]
     script = ExtResource("path/to/src/camera/ChessCameraController.gd")
     ```

### Étape 2 : Intégrer dans Board.gd

Ajoutez ces modifications dans votre fichier `Board.gd` :

```gdscript
# ==================================================
# AJOUT 1 : Référence à la caméra (dans la section variables)
# ==================================================
var camera_controller: ChessCameraController = null

# ==================================================
# AJOUT 2 : Initialisation de la caméra (dans _ready())
# ==================================================
func _ready():
	# ... votre code existant ...
	
	# Récupérer la référence à la caméra
	var subviewport = get_node_or_null("Container/SubViewportContainer/SubViewport")
	if subviewport:
		camera_controller = subviewport.get_node_or_null("Camera3D") as ChessCameraController
		if camera_controller:
			print("✅ Contrôleur de caméra initialisé !")
		else:
			print("⚠️ Camera3D n'utilise pas le script ChessCameraController")

# ==================================================
# AJOUT 3 : Intégration dans move_piece() (lignes 646-698)
# ==================================================
func move_piece(p: Piece, _engine_turn: bool, was_capture: bool = false):
	var start_pos_idx = get_grid_index(p.pos.x, p.pos.y)
	var end_pos_idx = get_grid_index(p.new_pos.x, p.new_pos.y)
	
	var is_promotion = (p.key == "P" and (p.new_pos.y == 0 or p.new_pos.y == 7))
	var is_castling = (p.key == "K" and abs(p.new_pos.x - p.pos.x) > 1)
	
	# 🎬 NOUVEAU : Calculer la position 3D de la cible
	var target_3d_pos = get_marker_position(end_pos_idx)
	
	var indicator_type = null
	if is_promotion:
		indicator_type = MoveIndicator.Type.BRILLIANT
		play_sound("promote")
		# 🎬 NOUVEAU : Zoom dramatique sur la promotion
		if camera_controller:
			camera_controller.dynamic_zoom("promotion", target_3d_pos)
	elif is_castling:
		indicator_type = MoveIndicator.Type.EXCELLENT
		play_sound("castle")
		# 🎬 NOUVEAU : Zoom OUT pour voir le roque
		if camera_controller:
			camera_controller.dynamic_zoom("castle", target_3d_pos)
	elif grid[end_pos_idx] != null or was_capture:
		play_sound("capture")
		var r = randf()
		if r < 0.1: indicator_type = MoveIndicator.Type.BRILLIANT
		elif r < 0.4: indicator_type = MoveIndicator.Type.BEST
		else: indicator_type = MoveIndicator.Type.GOOD
		
		# 🎬 NOUVEAU : Zoom sur la capture
		if camera_controller:
			# Détecter si c'est une capture majeure (Dame, Tour)
			var captured_piece = grid[end_pos_idx]
			if captured_piece and (captured_piece.key == "Q" or captured_piece.key == "R"):
				camera_controller.dynamic_zoom("capture_major", target_3d_pos)
			else:
				camera_controller.dynamic_zoom("capture", target_3d_pos)
	else:
		play_sound("move")
		if randf() < 0.3: indicator_type = MoveIndicator.Type.GOOD
		
		# 🎬 NOUVEAU : Zoom léger sur coup normal
		if camera_controller:
			camera_controller.dynamic_zoom("normal", target_3d_pos)
	
	# ... reste du code existant ...
	
	# 🎬 BONUS : Retour à la vue normale après 2 secondes
	if camera_controller:
		await get_tree().create_timer(2.0).timeout
		camera_controller.reset_camera()

# ==================================================
# AJOUT 4 : Détection d'échec (utiliser votre fonction existante is_king_checked)
# ==================================================
# Dans votre logique de jeu (probablement dans Main.gd), après move_piece :
func check_game_state_after_move(p: Piece):
	var check_state = board.is_king_checked(p)
	
	if check_state.has("mated") and check_state.mated:
		# Échec et mat !
		var king = board.kings[check_state.side]
		var king_pos = board.get_marker_position(board.get_grid_index(king.pos.x, king.pos.y))
		
		if board.camera_controller:
			await board.camera_controller.checkmate_sequence(king_pos)
		
		# Afficher message de fin de partie
		print("🏆 ÉCHEC ET MAT ! Victoire de ", "Blancs" if check_state.side == "B" else "Noirs")
	
	elif check_state.has("checked") and check_state.checked:
		# Échec simple
		var king = board.kings[check_state.side]
		var king_pos = board.get_marker_position(board.get_grid_index(king.pos.x, king.pos.y))
		
		if board.camera_controller:
			board.camera_controller.dynamic_zoom("check", king_pos)
		
		board.play_sound("check")
		print("⚠️ ÉCHEC au Roi ", "Noir" if check_state.side == "B" else "Blanc")
```

### Étape 3 : Tester dans Godot

1. **Lancez votre jeu** dans Godot
2. **Jouez quelques coups** et observez :
   - Coup normal → Léger zoom sur la pièce
   - Capture → Zoom moyen + léger tremblement
   - Capture de Dame/Tour → Zoom fort + tremblement prononcé
   - Échec → Zoom sur le roi + décalage latéral
   - Roque → Zoom OUT pour voir les deux pièces
   - Promotion → Zoom dramatique

## 🎨 Personnalisation

Vous pouvez ajuster les paramètres directement dans l'éditeur Godot en sélectionnant la caméra :

### Paramètres de Zoom
- **Zoom Speed** : Vitesse de transition (défaut: 3.0)
- **Min Distance** : Distance minimale (zoom max IN) (défaut: 600.0)
- **Max Distance** : Distance maximale (zoom max OUT) (défaut: 1200.0)
- **Default Distance** : Distance par défaut (défaut: 1000.0)

### Paramètres de Mouvement
- **Pan Speed** : Vitesse de panoramique (défaut: 100.0)
- **Default Position** : Position de base de la caméra
- **Look At Target** : Point visé (centre du plateau)

### Paramètres FOV
- **Default FOV** : Champ de vision par défaut (défaut: 70.0)

## 🔧 Fonctions Disponibles

Voici toutes les fonctions que vous pouvez utiliser :

### Zooms Basiques
```gdscript
camera.zoom_in_to_position(target_pos, duration, zoom_factor)
camera.zoom_out(duration, zoom_factor)
camera.reset_camera(duration)
```

### Zoom Dynamique (Recommandé)
```gdscript
camera.dynamic_zoom(event_type, target_pos)
# event_type peut être:
#  - "normal"         : Coup standard
#  - "capture"        : Capture normale
#  - "capture_major"  : Capture de pièce majeure (Dame, Tour)
#  - "check"          : Échec
#  - "checkmate"      : Échec et mat
#  - "promotion"      : Promotion de pion
#  - "castle"         : Roque
```

### Effets Spéciaux
```gdscript
camera.add_camera_shake(intensity, duration)  # Tremblement
camera.pan_to_offset(offset, duration)        # Panoramique manuel
camera.pan_to_board_position(grid_pos)        # Panoramique vers une case
```

### Séquences Complètes
```gdscript
await camera.dramatic_capture_sequence(target_pos)  # Capture dramatique
await camera.checkmate_sequence(king_pos)           # Échec et mat
```

## 📊 Données d'Analyse Utilisées

L'analyse de votre vidéo a révélé **62 mouvements distincts** :

| Type | Nombre | Usage Principal |
|------|--------|-----------------|
| **ZOOM IN** | 28 | Attirer l'attention sur une action |
| **ZOOM OUT** | 9 | Montrer le contexte global |
| **PAN** | 25 | Suivre l'action, dynamisme |

### Exemples de Mouvements Réels Détectés

**Mouvement #37** (18.67s) - Le plus intense :
- Type: ZOOM IN
- Facteur: 1.628x
- Intensité: 12.56
- **Usage** : Capture ultra-importante

**Mouvement #49** (27.40s) - Zoom OUT dramatique :
- Type: ZOOM OUT
- Facteur: 0.282x (très large)
- Intensité: 14.36
- **Usage** : Retour à la vue d'ensemble après une séquence tendue

## 🎯 Conseils d'Utilisation

### ✅ À FAIRE
1. **Varier les intensités** : Tous les coups ne méritent pas un gros zoom
2. **Retour progressif** : Toujours revenir à la vue normale après 1-3s
3. **Combiner les effets** : Zoom + shake pour les moments critiques
4. **Tester les timings** : Ajuster les durées selon vos préférences

### ❌ À ÉVITER
1. **Zoom constant** : Laissez des moments calmes
2. **Transitions trop rapides** : Peut donner le mal de tête
3. **Shake excessif** : Réservez-le aux moments importants
4. **Négliger le reset** : Toujours revenir à la vue de base

## 🐛 Dépannage

### La caméra ne bouge pas
- Vérifiez que le script est bien attaché au nœud Camera3D
- Vérifiez que `camera_controller` n'est pas `null` dans Board.gd
- Ajoutez des `print()` pour debug :
  ```gdscript
  if camera_controller:
      print("🎬 Zoom sur position: ", target_pos)
      camera_controller.dynamic_zoom("capture", target_pos)
  else:
      print("❌ Caméra non initialisée !")
  ```

### Les mouvements sont trop rapides/lents
- Ajustez `zoom_speed` dans les paramètres de la caméra
- Valeurs recommandées : 1.0 (lent) à 5.0 (rapide)

### Le zoom est trop fort/faible
- Ajustez `min_distance` et `max_distance`
- Ou modifiez les `zoom_factor` dans les appels `dynamic_zoom()`

### La caméra ne revient pas à la normale
- Assurez-vous que `reset_camera()` est appelé
- Augmentez le délai avant reset :
  ```gdscript
  await get_tree().create_timer(3.0).timeout  # 3 secondes au lieu de 2
  camera_controller.reset_camera()
  ```

## 📚 Fichiers de Référence

Pour aller plus loin, consultez :

- **[GODOT_CAMERA_GUIDE.md](file:///home/aurel/ChessGame/GODOT_CAMERA_GUIDE.md)** : Guide complet avec les 62 mouvements détaillés
- **[camera_analysis.json](file:///home/aurel/ChessGame/camera_analysis.json)** : Données brutes JSON
- **[analyze_camera.py](file:///home/aurel/ChessGame/analyze_camera.py)** : Pour analyser d'autres vidéos

## 🎮 Exemple Complet

Voici un exemple d'intégration complète dans `Main.gd` ou votre gestionnaire de partie :

```gdscript
extends Node

@onready var board = $Board  # ou votre chemin vers Board

func _ready():
	# Connecter les signaux
	board.connect("unclicked", Callable(self, "_on_piece_released"))

func _on_piece_released(piece: Piece):
	# Validation du coup (votre logique existante)
	var move_info = validate_move(piece)
	
	if move_info.valid:
		# Déplacer la pièce
		var was_capture = board.grid[board.get_grid_index(piece.new_pos.x, piece.new_pos.y)] != null
		board.move_piece(piece, false, was_capture)
		
		# Vérifier l'état du jeu
		var check_state = board.is_king_checked(piece)
		
		# Gérer la caméra selon l'événement
		if check_state.has("mated") and check_state.mated:
			# Échec et mat
			var king = board.kings[check_state.side]
			var king_pos = board.get_marker_position(
				board.get_grid_index(king.pos.x, king.pos.y)
			)
			if board.camera_controller:
				await board.camera_controller.checkmate_sequence(king_pos)
			game_over(check_state.side)
```

---

**Créé automatiquement** à partir de l'analyse vidéo par l'outil `analyze_camera.py` 🎬✨

Bon développement ! 🚀
