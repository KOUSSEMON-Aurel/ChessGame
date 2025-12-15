"""
Script d'analyse des mouvements de caméra pour la vidéo d'échecs
Détecte les zooms et dézooms pour reproduire les effets dans Godot
"""

import cv2
import numpy as np
import json
import sys
from pathlib import Path

class CameraAnalyzer:
    def __init__(self, video_path):
        self.video_path = video_path
        self.cap = cv2.VideoCapture(video_path)
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)
        self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        self.duration = self.total_frames / self.fps
        
        self.camera_movements = []
        self.prev_frame = None
        
    def analyze_camera_zoom(self, frame, prev_frame, frame_num, timestamp):
        """Analyse le zoom de la caméra en comparant les frames"""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
        
        # Détection de caractéristiques pour suivre le mouvement
        # Utilise ORB (Oriented FAST and Rotated BRIEF)
        orb = cv2.ORB_create(nfeatures=100)
        
        # Détecter les points clés
        kp1, des1 = orb.detectAndCompute(prev_gray, None)
        kp2, des2 = orb.detectAndCompute(gray, None)
        
        if des1 is not None and des2 is not None and len(des1) > 10 and len(des2) > 10:
            # Matcher les caractéristiques
            bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
            matches = bf.match(des1, des2)
            
            if len(matches) > 10:
                # Calculer les distances entre points matchés
                distances = []
                for match in matches:
                    pt1 = kp1[match.queryIdx].pt
                    pt2 = kp2[match.trainIdx].pt
                    dist = np.sqrt((pt2[0] - pt1[0])**2 + (pt2[1] - pt1[1])**2)
                    distances.append(dist)
                
                avg_distance = np.mean(distances)
                
                # Flux optique pour détecter le mouvement
                flow = cv2.calcOpticalFlowFarneback(
                    prev_gray, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0
                )
                
                # Calculer la magnitude et l'angle du flux
                mag, ang = cv2.cartToPolar(flow[..., 0], flow[..., 1])
                avg_mag = np.mean(mag)
                
                # Analyser le pattern de mouvement
                # Zoom in : les points s'éloignent du centre
                # Zoom out : les points se rapprochent du centre
                
                center_x, center_y = self.width // 2, self.height // 2
                
                # Calculer le mouvement radial
                flow_x = flow[..., 0]
                flow_y = flow[..., 1]
                
                # Créer une grille de coordonnées
                y_coords, x_coords = np.mgrid[0:self.height, 0:self.width]
                
                # Vecteurs du centre vers chaque point
                to_center_x = x_coords - center_x
                to_center_y = y_coords - center_y
                
                # Normaliser
                distances_from_center = np.sqrt(to_center_x**2 + to_center_y**2)
                distances_from_center[distances_from_center == 0] = 1  # Éviter division par zéro
                
                to_center_x_norm = to_center_x / distances_from_center
                to_center_y_norm = to_center_y / distances_from_center
                
                # Produit scalaire entre flux et direction radiale
                radial_flow = flow_x * to_center_x_norm + flow_y * to_center_y_norm
                avg_radial_flow = np.mean(radial_flow)
                
                # Déterminer le type de mouvement
                movement_type = "static"
                zoom_factor = 1.0
                
                if avg_mag > 1.5:  # Mouvement significatif
                    if avg_radial_flow > 0.5:
                        # Flux s'éloigne du centre = ZOOM IN
                        movement_type = "zoom_in"
                        zoom_factor = 1.0 + (avg_mag / 20.0)
                    elif avg_radial_flow < -0.5:
                        # Flux se rapproche du centre = ZOOM OUT
                        movement_type = "zoom_out"
                        zoom_factor = 1.0 - (avg_mag / 20.0)
                    else:
                        # Mouvement panoramique
                        movement_type = "pan"
                        zoom_factor = 1.0
                
                if movement_type != "static":
                    return {
                        "frame": int(frame_num),
                        "timestamp": float(round(timestamp, 3)),
                        "type": str(movement_type),
                        "magnitude": float(round(avg_mag, 3)),
                        "radial_flow": float(round(avg_radial_flow, 3)),
                        "zoom_factor": float(round(zoom_factor, 3)),
                        "feature_matches": int(len(matches))
                    }
        
        return None
    
    def analyze(self):
        """Lance l'analyse de la vidéo"""
        print(f"🎬 Analyse de la vidéo : {self.video_path}")
        print(f"📊 Résolution : {self.width}x{self.height}")
        print(f"⏱️  Durée : {self.duration:.2f}s ({self.total_frames} frames @ {self.fps} FPS)")
        print()
        
        frame_count = 0
        
        while True:
            ret, frame = self.cap.read()
            if not ret:
                break
            
            timestamp = frame_count / self.fps
            
            # Analyser le mouvement de caméra
            if self.prev_frame is not None and frame_count % 2 == 0:  # Analyser toutes les 2 frames
                camera_move = self.analyze_camera_zoom(frame, self.prev_frame, frame_count, timestamp)
                if camera_move:
                    self.camera_movements.append(camera_move)
            
            self.prev_frame = frame.copy()
            
            # Afficher la progression
            if frame_count % 30 == 0:
                progress = (frame_count / self.total_frames) * 100
                print(f"Progression : {progress:.1f}%", end='\r')
            
            frame_count += 1
        
        self.cap.release()
        print(f"\n✅ Analyse terminée !")
        
        # Regrouper les mouvements consécutifs
        self.consolidate_movements()
        
        # Générer le rapport
        self.generate_report()
    
    def consolidate_movements(self):
        """Regroupe les mouvements consécutifs similaires"""
        if not self.camera_movements:
            return
        
        consolidated = []
        current_move = self.camera_movements[0].copy()
        current_move['start_time'] = current_move['timestamp']
        current_move['end_time'] = current_move['timestamp']
        current_move['duration'] = 0
        
        for i in range(1, len(self.camera_movements)):
            move = self.camera_movements[i]
            
            # Si même type et proche dans le temps (< 0.5s)
            if (move['type'] == current_move['type'] and 
                move['timestamp'] - current_move['end_time'] < 0.5):
                # Étendre le mouvement actuel
                current_move['end_time'] = move['timestamp']
                current_move['magnitude'] = max(current_move['magnitude'], move['magnitude'])
                current_move['zoom_factor'] = move['zoom_factor']
            else:
                # Sauvegarder le mouvement actuel
                current_move['duration'] = current_move['end_time'] - current_move['start_time']
                consolidated.append(current_move)
                
                # Commencer un nouveau mouvement
                current_move = move.copy()
                current_move['start_time'] = move['timestamp']
                current_move['end_time'] = move['timestamp']
                current_move['duration'] = 0
        
        # Ajouter le dernier mouvement
        current_move['duration'] = current_move['end_time'] - current_move['start_time']
        consolidated.append(current_move)
        
        self.consolidated_movements = consolidated
    
    def generate_report(self):
        """Génère le rapport d'analyse"""
        report = {
            "metadata": {
                "video_path": self.video_path,
                "duration": self.duration,
                "fps": self.fps,
                "resolution": f"{self.width}x{self.height}",
                "total_frames": self.total_frames
            },
            "raw_movements": self.camera_movements,
            "consolidated_movements": self.consolidated_movements if hasattr(self, 'consolidated_movements') else []
        }
        
        # Sauvegarder en JSON
        output_file = Path("camera_analysis.json")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Rapport sauvegardé : {output_file}")
        
        # Afficher le résumé
        print("\n" + "="*70)
        print("📊 RÉSUMÉ DE L'ANALYSE DES MOUVEMENTS DE CAMÉRA")
        print("="*70)
        print(f"🎥 Mouvements détectés : {len(self.camera_movements)}")
        
        if hasattr(self, 'consolidated_movements'):
            print(f"📌 Mouvements consolidés : {len(self.consolidated_movements)}\n")
            
            print("🔍 MOUVEMENTS PRINCIPAUX :")
            for i, move in enumerate(self.consolidated_movements, 1):
                print(f"\n{i}. {move['type'].upper().replace('_', ' ')}")
                print(f"   ⏱️  Début : {move['start_time']:.2f}s")
                print(f"   ⏱️  Fin : {move['end_time']:.2f}s")
                print(f"   ⌛ Durée : {move['duration']:.2f}s")
                print(f"   💪 Intensité : {move['magnitude']:.2f}")
                if 'zoom' in move['type']:
                    print(f"   🔎 Facteur de zoom : {move['zoom_factor']:.3f}")
        
        print("\n" + "="*70)
        
        # Générer le guide d'implémentation Godot
        self.generate_godot_guide()
    
    def generate_godot_guide(self):
        """Génère un guide pour implémenter ces mouvements dans Godot"""
        guide = """
# 🎮 GUIDE D'IMPLÉMENTATION GODOT - Mouvements de Caméra

## 📋 Résumé des mouvements détectés

"""
        
        if hasattr(self, 'consolidated_movements'):
            for i, move in enumerate(self.consolidated_movements, 1):
                guide += f"""
### Mouvement {i} : {move['type'].upper().replace('_', ' ')}
- **Timing** : {move['start_time']:.2f}s → {move['end_time']:.2f}s (durée: {move['duration']:.2f}s)
- **Intensité** : {move['magnitude']:.2f}
- **Facteur de zoom** : {move.get('zoom_factor', 1.0):.3f}
"""
        
        guide += """

## 🎬 Implémentation dans Godot (GDScript)

### 1. Créer un script CameraController.gd

```gdscript
extends Camera3D
class_name ChessCameraController

# Paramètres de zoom
var zoom_speed: float = 2.0
var min_zoom: float = 5.0
var max_zoom: float = 20.0
var target_zoom: float = 10.0
var current_zoom: float = 10.0

# Paramètres de mouvement
var camera_offset: Vector3 = Vector3(0, 10, 8)
var look_at_target: Vector3 = Vector3.ZERO

# Animations planifiées
var camera_animations: Array = []
var current_animation_index: int = 0
var animation_time: float = 0.0

func _ready():
    # Initialiser la position de la caméra
    position = camera_offset
    look_at(look_at_target)
    
    # Charger les animations depuis l'analyse
    load_camera_animations()

func _process(delta):
    # Traiter l'animation en cours
    if current_animation_index < camera_animations.size():
        process_camera_animation(delta)
    
    # Interpolation douce du zoom
    current_zoom = lerp(current_zoom, target_zoom, delta * zoom_speed)
    
    # Appliquer le zoom (ajuster la distance)
    var zoom_offset = camera_offset.normalized() * current_zoom
    position = lerp(position, zoom_offset, delta * 5.0)

func process_camera_animation(delta):
    var anim = camera_animations[current_animation_index]
    animation_time += delta
    
    # Vérifier si l'animation doit commencer
    if animation_time < anim.start_time:
        return
    
    # Calculer la progression de l'animation
    var duration = anim.end_time - anim.start_time
    var progress = (animation_time - anim.start_time) / duration
    
    if progress >= 1.0:
        # Animation terminée, passer à la suivante
        current_animation_index += 1
        return
    
    # Appliquer l'animation selon le type
    match anim.type:
        "zoom_in":
            animate_zoom_in(progress, anim)
        "zoom_out":
            animate_zoom_out(progress, anim)
        "pan":
            animate_pan(progress, anim)

func animate_zoom_in(progress: float, anim: Dictionary):
    # Interpolation douce avec easing
    var eased_progress = ease(progress, -2.0)  # Ease out
    
    # Calculer le zoom cible
    var start_zoom = current_zoom
    var end_zoom = start_zoom / anim.zoom_factor
    
    target_zoom = lerp(start_zoom, end_zoom, eased_progress)

func animate_zoom_out(progress: float, anim: Dictionary):
    var eased_progress = ease(progress, 2.0)  # Ease in
    
    var start_zoom = current_zoom
    var end_zoom = start_zoom * (2.0 - anim.zoom_factor)
    
    target_zoom = lerp(start_zoom, end_zoom, eased_progress)

func animate_pan(progress: float, anim: Dictionary):
    # Déplacer la caméra latéralement
    var pan_amount = anim.magnitude * 0.1
    var pan_direction = Vector3(cos(animation_time), 0, sin(animation_time))
    
    position += pan_direction * pan_amount * 0.01

func load_camera_animations():
    # Charger les animations depuis l'analyse JSON
    # Pour l'instant, voici des exemples basés sur l'analyse
    
"""
        
        # Ajouter les animations détectées
        if hasattr(self, 'consolidated_movements'):
            guide += "    # Animations détectées automatiquement :\n"
            for move in self.consolidated_movements:
                guide += f"""    camera_animations.append({{
        "type": "{move['type']}",
        "start_time": {move['start_time']:.2f},
        "end_time": {move['end_time']:.2f},
        "magnitude": {move['magnitude']:.2f},
        "zoom_factor": {move.get('zoom_factor', 1.0):.3f}
    }})
"""
        
        guide += """

### 2. Utilisation dans votre scène

```gdscript
# Dans votre script Board.gd ou Main.gd
extends Node3D

@onready var camera = $ChessCameraController

func _ready():
    # La caméra va automatiquement jouer les animations planifiées
    pass

func trigger_move_animation(from_square: Vector2i, to_square: Vector2i):
    # Quand un coup est joué, déclencher le zoom sur l'action
    var world_pos = board_to_world(to_square)
    camera.zoom_to_position(world_pos, 1.5)  # Zoom pendant 1.5s

func board_to_world(square: Vector2i) -> Vector3:
    # Convertir coordonnées échiquier en position 3D
    var x = (square.x - 3.5) * 1.0
    var z = (square.y - 3.5) * 1.0
    return Vector3(x, 0, z)
```

### 3. Amélioration : Zoom dynamique sur l'action

```gdscript
# Ajouter cette fonction à CameraController.gd

func zoom_to_position(target_pos: Vector3, duration: float = 1.0):
    # Créer une animation de zoom vers une position spécifique
    var tween = create_tween()
    
    # Calculer nouvelle position de caméra
    var direction = (position - target_pos).normalized()
    var new_pos = target_pos + direction * 5.0  # 5 unités de distance
    
    # Animer la position
    tween.tween_property(self, "position", new_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    
    # Animer le look_at
    tween.parallel().tween_method(
        func(p): look_at(target_pos),
        0.0, 1.0, duration
    )
    
    return tween

func zoom_on_piece_capture(captured_pos: Vector3):
    # Zoom rapide sur une pièce capturée
    var tween = zoom_to_position(captured_pos, 0.5)
    
    # Après le zoom, revenir à la vue normale
    await tween.finished
    await get_tree().create_timer(0.3).timeout
    
    reset_camera_view(0.8)

func reset_camera_view(duration: float = 1.0):
    # Retour à la vue normale
    var tween = create_tween()
    tween.tween_property(self, "position", camera_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.parallel().tween_method(
        func(p): look_at(look_at_target),
        0.0, 1.0, duration
    )
```

## 🎯 Points clés pour reproduire le style de la vidéo

### 1. Timing des zooms
- **Zoom IN** : Lorsqu'un coup important est joué (capture, échec, mat)
- **Zoom OUT** : Pour montrer l'ensemble du plateau
- **Durée typique** : 0.5s à 2s par mouvement

### 2. Courbes d'easing recommandées
- **Zoom IN** : `EASE_OUT` (rapide au début, ralentit à la fin)
- **Zoom OUT** : `EASE_IN_OUT` (doux aux deux extrémités)
- **Pan** : `LINEAR` ou `EASE_IN_OUT`

### 3. Déclencheurs suggérés
```gdscript
# Dans votre logique de jeu
func on_piece_moved(from: Vector2i, to: Vector2i, piece: ChessPiece):
    var move_data = analyze_move(from, to, piece)
    
    if move_data.is_capture:
        # Zoom sur la capture
        camera.zoom_to_position(board_to_world(to), 0.8)
    elif move_data.is_check:
        # Zoom sur le roi en échec
        camera.zoom_to_king(get_king_in_check(), 1.0)
    elif move_data.is_castling:
        # Zoom out pour voir le roque
        camera.zoom_out_view(1.2)
```

### 4. Effets additionnels (comme dans la vidéo)
- **Shake de caméra** lors de captures importantes
- **Rotation légère** pour dynamiser les coups
- **Ralenti (slow-motion)** pour les moments critiques

```gdscript
func add_camera_shake(intensity: float = 0.1, duration: float = 0.3):
    var original_pos = position
    var shake_timer = 0.0
    
    while shake_timer < duration:
        var shake_offset = Vector3(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        position = original_pos + shake_offset
        shake_timer += get_process_delta_time()
        await get_tree().process_frame
    
    position = original_pos
```

## 📊 Statistiques de la vidéo analysée
"""
        
        if hasattr(self, 'consolidated_movements'):
            zoom_in_count = sum(1 for m in self.consolidated_movements if m['type'] == 'zoom_in')
            zoom_out_count = sum(1 for m in self.consolidated_movements if m['type'] == 'zoom_out')
            pan_count = sum(1 for m in self.consolidated_movements if m['type'] == 'pan')
            
            guide += f"""
- **Total de mouvements** : {len(self.consolidated_movements)}
- **Zooms IN** : {zoom_in_count}
- **Zooms OUT** : {zoom_out_count}
- **Panoramiques** : {pan_count}
- **Durée moyenne** : {np.mean([m['duration'] for m in self.consolidated_movements]):.2f}s
"""
        
        guide += "\n\n---\n✨ Générée automatiquement par camera_analyzer.py\n"
        
        # Sauvegarder le guide
        guide_file = Path("GODOT_CAMERA_GUIDE.md")
        with open(guide_file, 'w', encoding='utf-8') as f:
            f.write(guide)
        
        print(f"📖 Guide Godot généré : {guide_file}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("❌ Usage: python3 analyze_camera.py <video_path>")
        sys.exit(1)
    
    video_path = sys.argv[1]
    
    if not Path(video_path).exists():
        print(f"❌ Vidéo non trouvée : {video_path}")
        sys.exit(1)
    
    analyzer = CameraAnalyzer(video_path)
    analyzer.analyze()
