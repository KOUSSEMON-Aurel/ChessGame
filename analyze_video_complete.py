"""
Script d'analyse vidéo ultra-complet pour ChessGame.mp4
Détecte TOUS les éléments visuels, effets, animations, emojis, etc.
"""

import cv2
import numpy as np
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import os

class VideoAnalyzer:
    def __init__(self, video_path, output_dir="analysis_complete"):
        self.video_path = video_path
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Charger la vidéo
        self.cap = cv2.VideoCapture(video_path)
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)
        self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        self.duration = self.total_frames / self.fps
        
        # Résultats d'analyse
        self.results = {
            "metadata": {
                "video_path": video_path,
                "duration": self.duration,
                "fps": self.fps,
                "resolution": f"{self.width}x{self.height}",
                "total_frames": self.total_frames,
                "analysis_date": datetime.now().isoformat()
            },
            "emojis": [],
            "camera_movements": [],
            "board_effects": [],
            "color_themes": [],
            "particles": [],
            "ui_elements": [],
            "transitions": [],
            "timing_events": []
        }
        
        # Frame précédente pour comparaison
        self.prev_frame = None
        self.prev_gray = None
        
    def analyze_frame(self, frame_num, frame):
        """Analyse complète d'une frame"""
        timestamp = frame_num / self.fps
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # 1. Détection d'emojis/icônes
        emojis = self.detect_emojis(frame, frame_num, timestamp)
        if emojis:
            self.results["emojis"].extend(emojis)
        
        # 2. Détection de mouvement de caméra
        if self.prev_frame is not None:
            camera_move = self.detect_camera_movement(frame, self.prev_frame, frame_num, timestamp)
            if camera_move:
                self.results["camera_movements"].append(camera_move)
        
        # 3. Détection des tremblements/vagues du plateau
        if self.prev_gray is not None:
            board_effect = self.detect_board_effects(gray, self.prev_gray, frame_num, timestamp)
            if board_effect:
                self.results["board_effects"].append(board_effect)
        
        # 4. Analyse des couleurs dominantes
        if frame_num % 30 == 0:  # Tous les 30 frames
            color_theme = self.analyze_colors(frame, frame_num, timestamp)
            self.results["color_themes"].append(color_theme)
        
        # 5. Détection de particules/effets visuels
        particles = self.detect_particles(frame, frame_num, timestamp)
        if particles:
            self.results["particles"].extend(particles)
        
        # 6. Détection d'éléments UI
        ui_elements = self.detect_ui_elements(frame, frame_num, timestamp)
        if ui_elements:
            self.results["ui_elements"].extend(ui_elements)
        
        # 7. Détection de transitions
        if self.prev_frame is not None:
            transition = self.detect_transition(frame, self.prev_frame, frame_num, timestamp)
            if transition:
                self.results["transitions"].append(transition)
        
        # Sauvegarder frames
        self.prev_frame = frame.copy()
        self.prev_gray = gray.copy()
    
    def detect_emojis(self, frame, frame_num, timestamp):
        """Détecte les emojis/réactions dans la frame"""
        emojis = []
        
        # Convertir en HSV pour mieux détecter les couleurs vives
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Détection de zones circulaires colorées (emojis typiques)
        # Filtre pour couleurs vives (haute saturation)
        high_sat_mask = cv2.inRange(hsv, (0, 100, 100), (180, 255, 255))
        
        # Trouver des contours
        contours, _ = cv2.findContours(high_sat_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            area = cv2.contourArea(contour)
            if 500 < area < 10000:  # Taille typique d'un emoji
                # Calculer circularité
                perimeter = cv2.arcLength(contour, True)
                if perimeter > 0:
                    circularity = 4 * np.pi * area / (perimeter * perimeter)
                    
                    if circularity > 0.6:  # Assez circulaire
                        x, y, w, h = cv2.boundingRect(contour)
                        
                        # Extraire la région
                        emoji_region = frame[y:y+h, x:x+w]
                        
                        # Analyser la couleur dominante
                        avg_color = cv2.mean(emoji_region)[:3]
                        
                        emoji_data = {
                            "frame": frame_num,
                            "timestamp": timestamp,
                            "position": {"x": int(x), "y": int(y)},
                            "size": {"width": int(w), "height": int(h)},
                            "color": {
                                "b": int(avg_color[0]),
                                "g": int(avg_color[1]),
                                "r": int(avg_color[2])
                            },
                            "circularity": float(circularity),
                            "type": self.classify_emoji_type(avg_color)
                        }
                        
                        # Sauvegarder l'image de l'emoji
                        emoji_path = self.output_dir / f"emoji_{frame_num}_{x}_{y}.png"
                        cv2.imwrite(str(emoji_path), emoji_region)
                        emoji_data["image_path"] = str(emoji_path)
                        
                        emojis.append(emoji_data)
        
        return emojis
    
    def classify_emoji_type(self, avg_color):
        """Classifier le type d'emoji basé sur la couleur"""
        b, g, r = avg_color
        
        if r > 200 and g < 100 and b < 100:
            return "angry_red"
        elif r > 200 and g > 200 and b < 100:
            return "happy_yellow"
        elif b > 200 and g < 150 and r < 150:
            return "sad_blue"
        elif g > 200 and r < 150 and b < 150:
            return "success_green"
        else:
            return "other"
    
    def detect_camera_movement(self, frame, prev_frame, frame_num, timestamp):
        """Détecte les mouvements de caméra (zoom, pan, rotation)"""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
        
        # Calculer le flux optique
        flow = cv2.calcOpticalFlowFarneback(
            prev_gray, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0
        )
        
        # Analyser le mouvement global
        mag, ang = cv2.cartToPolar(flow[..., 0], flow[..., 1])
        
        avg_mag = np.mean(mag)
        avg_ang = np.mean(ang)
        
        # Déterminer le type de mouvement
        movement_type = "static"
        if avg_mag > 2:  # Seuil de mouvement significatif
            # Analyser la variance de l'angle pour détecter rotation vs pan
            ang_variance = np.var(ang)
            
            if ang_variance < 0.5:
                # Mouvement uniforme = pan ou zoom
                if avg_mag > 5:
                    movement_type = "zoom" if np.mean(flow[..., 0]) > 0 else "zoom_out"
                else:
                    movement_type = "pan"
            else:
                movement_type = "rotation"
            
            return {
                "frame": frame_num,
                "timestamp": timestamp,
                "type": movement_type,
                "magnitude": float(avg_mag),
                "direction": float(avg_ang)
            }
        
        return None
    
    def detect_board_effects(self, gray, prev_gray, frame_num, timestamp):
        """Détecte tremblements, vagues, distorsions du plateau"""
        # Calculer la différence absolue
        diff = cv2.absdiff(gray, prev_gray)
        
        # Calculer l'intensité du changement par région
        h, w = gray.shape
        
        # Diviser en grille 8x8 (comme un échiquier)
        grid_h = h // 8
        grid_w = w // 8
        
        shake_intensity = []
        wave_detected = False
        
        for i in range(8):
            for j in range(8):
                region = diff[i*grid_h:(i+1)*grid_h, j*grid_w:(j+1)*grid_w]
                intensity = np.mean(region)
                shake_intensity.append(intensity)
        
        # Analyser les patterns
        avg_shake = np.mean(shake_intensity)
        max_shake = np.max(shake_intensity)
        variance = np.var(shake_intensity)
        
        # Détection de vague (pattern sinusoïdal dans la grille)
        # Vague = variation progressive de l'intensité
        if variance > 100:  # Variation significative
            # Analyser si c'est un pattern ondulatoire
            shake_array = np.array(shake_intensity).reshape(8, 8)
            
            # Vérifier les patterns horizontaux et verticaux
            h_pattern = np.mean(np.abs(np.diff(shake_array, axis=1)))
            v_pattern = np.mean(np.abs(np.diff(shake_array, axis=0)))
            
            if h_pattern > 20 or v_pattern > 20:
                wave_detected = True
        
        effect_type = None
        if max_shake > 30:
            effect_type = "shake_strong"
        elif avg_shake > 10:
            effect_type = "shake_light"
        
        if wave_detected:
            effect_type = "wave" if effect_type is None else f"{effect_type}_wave"
        
        if effect_type:
            return {
                "frame": frame_num,
                "timestamp": timestamp,
                "type": effect_type,
                "intensity": float(avg_shake),
                "max_intensity": float(max_shake),
                "variance": float(variance),
                "wave": wave_detected
            }
        
        return None
    
    def analyze_colors(self, frame, frame_num, timestamp):
        """Analyse le thème de couleurs de la frame"""
        # Calculer l'histogramme de couleurs
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Trouver les couleurs dominantes
        hist_h = cv2.calcHist([hsv], [0], None, [180], [0, 180])
        hist_s = cv2.calcHist([hsv], [1], None, [256], [0, 256])
        hist_v = cv2.calcHist([hsv], [2], None, [256], [0, 256])
        
        # Teinte dominante
        dominant_hue = int(np.argmax(hist_h))
        
        # Saturation moyenne
        avg_saturation = np.mean(hsv[:, :, 1])
        
        # Valeur moyenne (brightness)
        avg_brightness = np.mean(hsv[:, :, 2])
        
        # Classifier le thème
        theme = self.classify_theme(dominant_hue, avg_saturation, avg_brightness)
        
        return {
            "frame": frame_num,
            "timestamp": timestamp,
            "dominant_hue": dominant_hue,
            "avg_saturation": float(avg_saturation),
            "avg_brightness": float(avg_brightness),
            "theme": theme
        }
    
    def classify_theme(self, hue, saturation, brightness):
        """Classifier le thème visuel"""
        if brightness < 80:
            return "dark"
        elif brightness > 200:
            return "bright"
        elif saturation < 50:
            return "grayscale"
        elif 0 <= hue < 30 or 150 <= hue < 180:
            return "warm"
        elif 30 <= hue < 150:
            return "cool"
        else:
            return "neutral"
    
    def detect_particles(self, frame, frame_num, timestamp):
        """Détecte les effets de particules (étincelles, confettis, etc.)"""
        particles = []
        
        # Convertir en HSV
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Détecter des points très lumineux (étincelles)
        bright_mask = cv2.inRange(hsv, (0, 0, 200), (180, 50, 255))
        
        # Trouver les points
        contours, _ = cv2.findContours(bright_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        small_particles = 0
        for contour in contours:
            area = cv2.contourArea(contour)
            if 5 < area < 100:  # Petites particules
                small_particles += 1
        
        if small_particles > 10:  # Beaucoup de petites particules
            particles.append({
                "frame": frame_num,
                "timestamp": timestamp,
                "type": "sparkles",
                "count": small_particles
            })
        
        # Détecter des particules colorées (confettis)
        colored_mask = cv2.inRange(hsv, (0, 150, 150), (180, 255, 255))
        contours, _ = cv2.findContours(colored_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        colored_particles = 0
        for contour in contours:
            area = cv2.contourArea(contour)
            if 20 < area < 500:
                colored_particles += 1
        
        if colored_particles > 5:
            particles.append({
                "frame": frame_num,
                "timestamp": timestamp,
                "type": "confetti",
                "count": colored_particles
            })
        
        return particles
    
    def detect_ui_elements(self, frame, frame_num, timestamp):
        """Détecte les éléments d'interface (texte, boutons, scores, etc.)"""
        ui_elements = []
        
        # Convertir en niveaux de gris
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Détection de texte (zones avec beaucoup de bords horizontaux/verticaux)
        edges = cv2.Canny(gray, 50, 150)
        
        # Trouver des régions rectangulaires (typiques des UI)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            area = cv2.contourArea(contour)
            if area > 1000:  # Assez grand pour être un élément UI
                x, y, w, h = cv2.boundingRect(contour)
                aspect_ratio = w / h if h > 0 else 0
                
                # Classifier
                ui_type = "unknown"
                if 2 < aspect_ratio < 10 and area > 2000:
                    ui_type = "text_bar"
                elif 0.8 < aspect_ratio < 1.2:
                    ui_type = "button_square"
                elif aspect_ratio > 10:
                    ui_type = "separator"
                
                ui_elements.append({
                    "frame": frame_num,
                    "timestamp": timestamp,
                    "type": ui_type,
                    "position": {"x": int(x), "y": int(y)},
                    "size": {"width": int(w), "height": int(h)},
                    "aspect_ratio": float(aspect_ratio)
                })
        
        return ui_elements
    
    def detect_transition(self, frame, prev_frame, frame_num, timestamp):
        """Détecte les transitions/effets de changement"""
        # Calculer la différence globale
        diff = cv2.absdiff(frame, prev_frame)
        total_change = np.mean(diff)
        
        # Transition détectée si changement important
        if total_change > 50:  # Changement significatif
            # Analyser le type de transition
            # Fade = changement progressif de luminosité
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
            
            brightness_change = np.mean(gray) - np.mean(prev_gray)
            
            transition_type = "cut"
            if abs(brightness_change) > 30:
                transition_type = "fade_out" if brightness_change < 0 else "fade_in"
            
            return {
                "frame": frame_num,
                "timestamp": timestamp,
                "type": transition_type,
                "intensity": float(total_change),
                "brightness_change": float(brightness_change)
            }
        
        return None
    
    def analyze(self):
        """Lance l'analyse complète"""
        print(f"🎬 Analyse de la vidéo : {self.video_path}")
        print(f"📊 Résolution : {self.width}x{self.height}")
        print(f"⏱️  Durée : {self.duration:.2f}s ({self.total_frames} frames)")
        print()
        
        frame_count = 0
        
        while True:
            ret, frame = self.cap.read()
            if not ret:
                break
            
            # Analyser cette frame
            self.analyze_frame(frame_count, frame)
            
            # Progression
            if frame_count % 30 == 0:
                progress = (frame_count / self.total_frames) * 100
                print(f"Progression : {progress:.1f}% ({frame_count}/{self.total_frames} frames)", end='\r')
            
            frame_count += 1
        
        self.cap.release()
        print(f"\n✅ Analyse terminée !")
        
        # Post-traitement : regrouper les événements similaires
        self.consolidate_events()
        
        # Générer le rapport
        self.generate_report()
    
    def consolidate_events(self):
        """Regroupe les événements similaires qui se suivent"""
        # Regrouper les emojis par proximité temporelle
        if self.results["emojis"]:
            grouped_emojis = []
            current_group = [self.results["emojis"][0]]
            
            for i in range(1, len(self.results["emojis"])):
                emoji = self.results["emojis"][i]
                prev_emoji = self.results["emojis"][i-1]
                
                # Si même position et proche dans le temps (< 1s)
                if (abs(emoji["timestamp"] - prev_emoji["timestamp"]) < 1.0 and
                    abs(emoji["position"]["x"] - prev_emoji["position"]["x"]) < 50 and
                    abs(emoji["position"]["y"] - prev_emoji["position"]["y"]) < 50):
                    current_group.append(emoji)
                else:
                    grouped_emojis.append({
                        "start_time": current_group[0]["timestamp"],
                        "end_time": current_group[-1]["timestamp"],
                        "duration": current_group[-1]["timestamp"] - current_group[0]["timestamp"],
                        "position": current_group[0]["position"],
                        "type": current_group[0]["type"],
                        "instances": len(current_group)
                    })
                    current_group = [emoji]
            
            # Ajouter le dernier groupe
            if current_group:
                grouped_emojis.append({
                    "start_time": current_group[0]["timestamp"],
                    "end_time": current_group[-1]["timestamp"],
                    "duration": current_group[-1]["timestamp"] - current_group[0]["timestamp"],
                    "position": current_group[0]["position"],
                    "type": current_group[0]["type"],
                    "instances": len(current_group)
                })
            
            self.results["emojis_grouped"] = grouped_emojis
    
    def generate_report(self):
        """Génère le rapport complet"""
        # Sauvegarder le JSON
        json_path = self.output_dir / "complete_analysis.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Rapport JSON sauvegardé : {json_path}")
        
        # Générer un rapport HTML
        self.generate_html_report()
        
        # Afficher un résumé
        print("\n" + "="*60)
        print("📊 RÉSUMÉ DE L'ANALYSE")
        print("="*60)
        print(f"🎭 Emojis détectés : {len(self.results['emojis'])}")
        if 'emojis_grouped' in self.results:
            print(f"   Groupés en {len(self.results['emojis_grouped'])} événements")
        print(f"📹 Mouvements caméra : {len(self.results['camera_movements'])}")
        print(f"🌊 Effets plateau : {len(self.results['board_effects'])}")
        print(f"✨ Particules : {len(self.results['particles'])}")
        print(f"🖼️  Éléments UI : {len(self.results['ui_elements'])}")
        print(f"🎬 Transitions : {len(self.results['transitions'])}")
        print(f"🎨 Thèmes couleur analysés : {len(self.results['color_themes'])}")
        print("="*60)
    
    def generate_html_report(self):
        """Génère un rapport HTML interactif"""
        html_content = f"""
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Analyse Vidéo Complète - ChessGame</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #1a1a1a;
            color: #e0e0e0;
            padding: 20px;
            margin: 0;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        h1 {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 30px;
            border-radius: 10px;
            text-align: center;
        }}
        .section {{
            background: #2d2d2d;
            margin: 20px 0;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }}
        h2 {{
            color: #667eea;
            margin-top: 0;
        }}
        .stat {{
            display: inline-block;
            background: #3d3d3d;
            padding: 15px 25px;
            margin: 10px;
            border-radius: 5px;
            min-width: 150px;
        }}
        .stat-value {{
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }}
        .stat-label {{
            color: #999;
            font-size: 0.9em;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #444;
        }}
        th {{
            background: #3d3d3d;
            color: #667eea;
        }}
        tr:hover {{
            background: #353535;
        }}
        .emoji-preview {{
            width: 40px;
            height: 40px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 10px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 Analyse Vidéo Complète - ChessGame.mp4</h1>
        
        <div class="section">
            <h2>📊 Statistiques Globales</h2>
            <div class="stat">
                <div class="stat-value">{len(self.results['emojis'])}</div>
                <div class="stat-label">Emojis Détectés</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(self.results['camera_movements'])}</div>
                <div class="stat-label">Mouvements Caméra</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(self.results['board_effects'])}</div>
                <div class="stat-label">Effets Plateau</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(self.results['particles'])}</div>
                <div class="stat-label">Effets de Particules</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(self.results['transitions'])}</div>
                <div class="stat-label">Transitions</div>
            </div>
        </div>
        
        <div class="section">
            <h2>🎭 Emojis/Réactions Détectés</h2>
            {self._generate_emoji_table()}
        </div>
        
        <div class="section">
            <h2>📹 Mouvements de Caméra</h2>
            {self._generate_camera_table()}
        </div>
        
        <div class="section">
            <h2>🌊 Effets du Plateau (Tremblements/Vagues)</h2>
            {self._generate_board_effects_table()}
        </div>
        
        <div class="section">
            <h2>✨ Effets de Particules</h2>
            {self._generate_particles_table()}
        </div>
        
        <div class="section">
            <h2>🎬 Transitions Détectées</h2>
            {self._generate_transitions_table()}
        </div>
    </div>
</body>
</html>
"""
        
        html_path = self.output_dir / "report_complete.html"
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"📄 Rapport HTML sauvegardé : {html_path}")
    
    def _generate_emoji_table(self):
        if not self.results.get('emojis_grouped'):
            return "<p>Aucun emoji détecté.</p>"
        
        rows = ""
        for emoji in self.results['emojis_grouped'][:50]:  # Limite à 50
            rows += f"""
            <tr>
                <td>{emoji['start_time']:.2f}s</td>
                <td>{emoji['duration']:.2f}s</td>
                <td>{emoji['type']}</td>
                <td>x:{emoji['position']['x']}, y:{emoji['position']['y']}</td>
                <td>{emoji['instances']}</td>
            </tr>
            """
        
        return f"""
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Durée</th>
                <th>Type</th>
                <th>Position</th>
                <th>Occurrences</th>
            </tr>
            {rows}
        </table>
        """
    
    def _generate_camera_table(self):
        if not self.results['camera_movements']:
            return "<p>Aucun mouvement de caméra détecté.</p>"
        
        rows = ""
        for cam in self.results['camera_movements'][:50]:
            rows += f"""
            <tr>
                <td>{cam['timestamp']:.2f}s</td>
                <td>{cam['type']}</td>
                <td>{cam['magnitude']:.2f}</td>
                <td>{cam['direction']:.2f}</td>
            </tr>
            """
        
        return f"""
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Type</th>
                <th>Magnitude</th>
                <th>Direction</th>
            </tr>
            {rows}
        </table>
        """
    
    def _generate_board_effects_table(self):
        if not self.results['board_effects']:
            return "<p>Aucun effet de plateau détecté.</p>"
        
        rows = ""
        for effect in self.results['board_effects'][:50]:
            rows += f"""
            <tr>
                <td>{effect['timestamp']:.2f}s</td>
                <td>{effect['type']}</td>
                <td>{effect['intensity']:.2f}</td>
                <td>{'Oui' if effect['wave'] else 'Non'}</td>
            </tr>
            """
        
        return f"""
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Type</th>
                <th>Intensité</th>
                <th>Vague</th>
            </tr>
            {rows}
        </table>
        """
    
    def _generate_particles_table(self):
        if not self.results['particles']:
            return "<p>Aucun effet de particules détecté.</p>"
        
        rows = ""
        for particle in self.results['particles'][:50]:
            rows += f"""
            <tr>
                <td>{particle['timestamp']:.2f}s</td>
                <td>{particle['type']}</td>
                <td>{particle['count']}</td>
            </tr>
            """
        
        return f"""
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Type</th>
                <th>Nombre</th>
            </tr>
            {rows}
        </table>
        """
    
    def _generate_transitions_table(self):
        if not self.results['transitions']:
            return "<p>Aucune transition détectée.</p>"
        
        rows = ""
        for trans in self.results['transitions'][:50]:
            rows += f"""
            <tr>
                <td>{trans['timestamp']:.2f}s</td>
                <td>{trans['type']}</td>
                <td>{trans['intensity']:.2f}</td>
            </tr>
            """
        
        return f"""
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Type</th>
                <th>Intensité</th>
            </tr>
            {rows}
        </table>
        """

if __name__ == "__main__":
    video_path = "/home/aurel/Downloads/ChessGame.mp4"
    
    if not os.path.exists(video_path):
        print(f"❌ Vidéo non trouvée : {video_path}")
        exit(1)
    
    analyzer = VideoAnalyzer(video_path)
    analyzer.analyze()
    
    print("\n✅ Analyse terminée ! Consultez les fichiers :")
    print(f"   - analysis_complete/complete_analysis.json")
    print(f"   - analysis_complete/report_complete.html")
