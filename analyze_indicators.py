"""
Script d'analyse spécialisé pour détecter les indicateurs de qualité de coup.
Détecte : ⭐ (bon coup), 👍 (pouce), ❓ (erreur), !! (brillant), etc.
Ces icônes apparaissent au-dessus/coin des cases lors des mouvements.
"""

import cv2
import numpy as np
import json
from pathlib import Path
from datetime import datetime
import os

class MoveIndicatorAnalyzer:
    def __init__(self, video_path, output_dir="analysis_indicators"):
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
        
        # Résultats
        self.results = {
            "metadata": {
                "video_path": video_path,
                "duration": self.duration,
                "fps": self.fps,
                "resolution": f"{self.width}x{self.height}",
                "total_frames": self.total_frames,
                "analysis_date": datetime.now().isoformat()
            },
            "move_indicators": [],
            "indicator_types": {},
            "board_shake_events": [],
            "camera_movements": [],
            "visual_effects": []
        }
        
        self.prev_frame = None
        self.prev_gray = None
        
        # Zone de l'échiquier (à ajuster selon la vidéo)
        # La vidéo est en 576x720 (portrait)
        self.board_region = {
            "x": 0,
            "y": 100,  # Décalage vertical (header)
            "width": 576,
            "height": 576  # Carré pour l'échiquier
        }
        
        # Taille d'une case
        self.square_size = self.board_region["width"] // 8  # ~72px
        
    def get_square_corners(self):
        """Retourne les positions des coins supérieurs droits de chaque case"""
        corners = []
        for row in range(8):
            for col in range(8):
                x = self.board_region["x"] + (col + 1) * self.square_size - 20  # Coin droit
                y = self.board_region["y"] + row * self.square_size + 5  # Haut de la case
                corners.append({
                    "row": row,
                    "col": col,
                    "square": chr(ord('a') + col) + str(8 - row),
                    "x": x,
                    "y": y,
                    "region": (max(0, x-25), max(0, y-5), 50, 40)  # Zone de l'indicateur
                })
        return corners
    
    def analyze_frame(self, frame_num, frame):
        """Analyse une frame pour détecter les indicateurs"""
        timestamp = frame_num / self.fps
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # 1. Détecter les indicateurs au-dessus des cases
        indicators = self.detect_indicators(frame, hsv, frame_num, timestamp)
        if indicators:
            self.results["move_indicators"].extend(indicators)
        
        # 2. Détecter les tremblements/effets du plateau
        if self.prev_gray is not None:
            shake = self.detect_board_shake(gray, self.prev_gray, frame_num, timestamp)
            if shake:
                self.results["board_shake_events"].append(shake)
            
            # 3. Détecter les mouvements de caméra globaux
            camera_move = self.detect_camera_movement(gray, self.prev_gray, frame_num, timestamp)
            if camera_move:
                self.results["camera_movements"].append(camera_move)
            
            # 4. Détecter les effets visuels (flash, particules)
            effects = self.detect_visual_effects(frame, self.prev_frame, frame_num, timestamp)
            if effects:
                self.results["visual_effects"].extend(effects)
        
        self.prev_frame = frame.copy()
        self.prev_gray = gray.copy()
    
    def detect_indicators(self, frame, hsv, frame_num, timestamp):
        """Détecte les petites icônes au-dessus des cases"""
        indicators = []
        
        # Couleurs typiques des indicateurs
        # Étoile jaune/dorée
        yellow_lower = np.array([20, 100, 100])
        yellow_upper = np.array([40, 255, 255])
        
        # Vert (bon coup)
        green_lower = np.array([40, 100, 100])
        green_upper = np.array([80, 255, 255])
        
        # Rouge (erreur)
        red_lower1 = np.array([0, 100, 100])
        red_upper1 = np.array([10, 255, 255])
        red_lower2 = np.array([160, 100, 100])
        red_upper2 = np.array([180, 255, 255])
        
        # Bleu (information)
        blue_lower = np.array([100, 100, 100])
        blue_upper = np.array([130, 255, 255])
        
        # Blanc brillant (étoile, brillant)
        # Utiliser la valeur (V) très haute
        
        # Scanner les coins supérieurs droits de chaque case
        corners = self.get_square_corners()
        
        for corner in corners:
            x, y, w, h = corner["region"]
            
            # Vérifier les limites
            if x + w > self.width or y + h > self.height:
                continue
                
            region_hsv = hsv[y:y+h, x:x+w]
            region_bgr = frame[y:y+h, x:x+w]
            
            # Vérifier la présence de couleurs d'indicateurs
            indicator_type = None
            confidence = 0.0
            
            # Masque jaune (étoile)
            yellow_mask = cv2.inRange(region_hsv, yellow_lower, yellow_upper)
            yellow_ratio = np.sum(yellow_mask > 0) / (w * h)
            
            if yellow_ratio > 0.1:  # Plus de 10% de jaune
                indicator_type = "star"
                confidence = yellow_ratio
            
            # Masque vert (bon coup)
            green_mask = cv2.inRange(region_hsv, green_lower, green_upper)
            green_ratio = np.sum(green_mask > 0) / (w * h)
            
            if green_ratio > 0.1 and green_ratio > confidence:
                indicator_type = "thumbs_up"
                confidence = green_ratio
            
            # Masque rouge (erreur)
            red_mask1 = cv2.inRange(region_hsv, red_lower1, red_upper1)
            red_mask2 = cv2.inRange(region_hsv, red_lower2, red_upper2)
            red_mask = cv2.bitwise_or(red_mask1, red_mask2)
            red_ratio = np.sum(red_mask > 0) / (w * h)
            
            if red_ratio > 0.1 and red_ratio > confidence:
                indicator_type = "question_mark"
                confidence = red_ratio
            
            # Masque bleu (info)
            blue_mask = cv2.inRange(region_hsv, blue_lower, blue_upper)
            blue_ratio = np.sum(blue_mask > 0) / (w * h)
            
            if blue_ratio > 0.1 and blue_ratio > confidence:
                indicator_type = "info"
                confidence = blue_ratio
            
            # Détecter les zones très lumineuses (étoiles brillantes)
            bright_mask = cv2.inRange(region_hsv, (0, 0, 220), (180, 50, 255))
            bright_ratio = np.sum(bright_mask > 0) / (w * h)
            
            if bright_ratio > 0.15 and bright_ratio > confidence:
                indicator_type = "brilliant"
                confidence = bright_ratio
            
            if indicator_type and confidence > 0.1:
                # Sauvegarder l'image de l'indicateur
                indicator_path = self.output_dir / f"indicator_{frame_num}_{corner['square']}.png"
                cv2.imwrite(str(indicator_path), region_bgr)
                
                indicators.append({
                    "frame": frame_num,
                    "timestamp": timestamp,
                    "square": corner["square"],
                    "position": {"x": x, "y": y},
                    "type": indicator_type,
                    "confidence": float(confidence),
                    "image_path": str(indicator_path)
                })
                
                # Compter par type
                if indicator_type not in self.results["indicator_types"]:
                    self.results["indicator_types"][indicator_type] = 0
                self.results["indicator_types"][indicator_type] += 1
        
        return indicators
    
    def detect_board_shake(self, gray, prev_gray, frame_num, timestamp):
        """Détecte les tremblements du plateau"""
        # Région du plateau uniquement
        br = self.board_region
        board_gray = gray[br["y"]:br["y"]+br["height"], br["x"]:br["x"]+br["width"]]
        prev_board = prev_gray[br["y"]:br["y"]+br["height"], br["x"]:br["x"]+br["width"]]
        
        # Calculer le flux optique
        flow = cv2.calcOpticalFlowFarneback(
            prev_board, board_gray, None, 0.5, 3, 15, 3, 5, 1.2, 0
        )
        
        mag, ang = cv2.cartToPolar(flow[..., 0], flow[..., 1])
        avg_mag = np.mean(mag)
        
        # Variance de direction (tremblement = directions variées)
        ang_variance = np.var(ang)
        
        # Tremblement détecté si mouvement modéré avec variance élevée
        if avg_mag > 1.5 and ang_variance > 1.0:
            shake_type = "light"
            if avg_mag > 3.0:
                shake_type = "moderate"
            if avg_mag > 5.0:
                shake_type = "strong"
            
            return {
                "frame": frame_num,
                "timestamp": timestamp,
                "type": shake_type,
                "magnitude": float(avg_mag),
                "variance": float(ang_variance)
            }
        
        return None
    
    def detect_camera_movement(self, gray, prev_gray, frame_num, timestamp):
        """Détecte les mouvements de caméra (zoom, pan)"""
        flow = cv2.calcOpticalFlowFarneback(
            prev_gray, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0
        )
        
        mag, ang = cv2.cartToPolar(flow[..., 0], flow[..., 1])
        avg_mag = np.mean(mag)
        avg_ang = np.mean(ang)
        
        # Analyse du mouvement global
        if avg_mag > 2.0:
            # Déterminer le type
            flow_x = np.mean(flow[..., 0])
            flow_y = np.mean(flow[..., 1])
            
            if abs(flow_x) > abs(flow_y) * 2:
                move_type = "pan_horizontal"
            elif abs(flow_y) > abs(flow_x) * 2:
                move_type = "pan_vertical"
            else:
                # Vérifier zoom (flux radial depuis le centre)
                center_x, center_y = self.width // 2, self.height // 2
                is_zoom = self.check_radial_flow(flow, center_x, center_y)
                move_type = "zoom" if is_zoom else "pan"
            
            return {
                "frame": frame_num,
                "timestamp": timestamp,
                "type": move_type,
                "magnitude": float(avg_mag),
                "direction": float(avg_ang)
            }
        
        return None
    
    def check_radial_flow(self, flow, cx, cy):
        """Vérifie si le flux est radial (zoom)"""
        h, w = flow.shape[:2]
        
        # Créer une grille de points
        y_coords, x_coords = np.mgrid[0:h, 0:w]
        
        # Vecteurs du centre vers chaque point
        dx_from_center = x_coords - cx
        dy_from_center = y_coords - cy
        
        # Normaliser
        dist = np.sqrt(dx_from_center**2 + dy_from_center**2) + 1e-6
        nx = dx_from_center / dist
        ny = dy_from_center / dist
        
        # Produit scalaire avec le flux
        dot_product = flow[..., 0] * nx + flow[..., 1] * ny
        
        # Si la majorité est positive -> zoom out, négative -> zoom in
        avg_dot = np.mean(dot_product)
        
        return abs(avg_dot) > 0.5
    
    def detect_visual_effects(self, frame, prev_frame, frame_num, timestamp):
        """Détecte les effets visuels (flash, particules, etc.)"""
        effects = []
        
        # Différence de luminosité globale (flash)
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
        
        brightness_diff = np.mean(gray) - np.mean(prev_gray)
        
        if abs(brightness_diff) > 20:
            effect_type = "flash_bright" if brightness_diff > 0 else "flash_dark"
            effects.append({
                "frame": frame_num,
                "timestamp": timestamp,
                "type": effect_type,
                "intensity": float(abs(brightness_diff))
            })
        
        # Détecter les particules (petits points lumineux qui n'étaient pas là avant)
        diff = cv2.absdiff(frame, prev_frame)
        diff_gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
        
        _, thresh = cv2.threshold(diff_gray, 50, 255, cv2.THRESH_BINARY)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        small_bright_spots = 0
        for contour in contours:
            area = cv2.contourArea(contour)
            if 10 < area < 200:  # Petites particules
                small_bright_spots += 1
        
        if small_bright_spots > 20:
            effects.append({
                "frame": frame_num,
                "timestamp": timestamp,
                "type": "particles",
                "count": small_bright_spots
            })
        
        return effects
    
    def analyze(self):
        """Lance l'analyse complète"""
        print(f"🎯 Analyse des indicateurs de coup : {self.video_path}")
        print(f"📊 Résolution : {self.width}x{self.height}")
        print(f"⏱️  Durée : {self.duration:.2f}s ({self.total_frames} frames)")
        print(f"📐 Taille de case estimée : {self.square_size}px")
        print()
        
        frame_count = 0
        
        while True:
            ret, frame = self.cap.read()
            if not ret:
                break
            
            self.analyze_frame(frame_count, frame)
            
            if frame_count % 30 == 0:
                progress = (frame_count / self.total_frames) * 100
                print(f"Progression : {progress:.1f}% ({frame_count}/{self.total_frames} frames)", end='\r')
            
            frame_count += 1
        
        self.cap.release()
        print(f"\n✅ Analyse terminée !")
        
        # Post-traitement
        self.consolidate_indicators()
        self.generate_report()
    
    def consolidate_indicators(self):
        """Regroupe les indicateurs par événement"""
        if not self.results["move_indicators"]:
            return
        
        grouped = []
        current_group = None
        
        for indicator in sorted(self.results["move_indicators"], key=lambda x: x["timestamp"]):
            if current_group is None:
                current_group = {
                    "start_time": indicator["timestamp"],
                    "end_time": indicator["timestamp"],
                    "square": indicator["square"],
                    "type": indicator["type"],
                    "confidence": indicator["confidence"],
                    "frames": [indicator["frame"]]
                }
            elif (indicator["timestamp"] - current_group["end_time"] < 0.5 and 
                  indicator["square"] == current_group["square"] and
                  indicator["type"] == current_group["type"]):
                # Même événement
                current_group["end_time"] = indicator["timestamp"]
                current_group["frames"].append(indicator["frame"])
                current_group["confidence"] = max(current_group["confidence"], indicator["confidence"])
            else:
                # Nouvel événement
                current_group["duration"] = current_group["end_time"] - current_group["start_time"]
                grouped.append(current_group)
                current_group = {
                    "start_time": indicator["timestamp"],
                    "end_time": indicator["timestamp"],
                    "square": indicator["square"],
                    "type": indicator["type"],
                    "confidence": indicator["confidence"],
                    "frames": [indicator["frame"]]
                }
        
        if current_group:
            current_group["duration"] = current_group["end_time"] - current_group["start_time"]
            grouped.append(current_group)
        
        self.results["indicator_events"] = grouped
    
    def generate_report(self):
        """Génère le rapport"""
        # Sauvegarder JSON
        json_path = self.output_dir / "indicators_analysis.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Rapport JSON : {json_path}")
        
        # Résumé
        print("\n" + "="*60)
        print("📊 RÉSUMÉ DE L'ANALYSE DES INDICATEURS")
        print("="*60)
        print(f"⭐ Indicateurs détectés : {len(self.results['move_indicators'])}")
        
        if 'indicator_events' in self.results:
            print(f"📌 Événements groupés : {len(self.results['indicator_events'])}")
        
        print("\n📋 Types d'indicateurs :")
        for ind_type, count in self.results["indicator_types"].items():
            emoji = {"star": "⭐", "thumbs_up": "👍", "question_mark": "❓", 
                     "info": "ℹ️", "brilliant": "✨"}.get(ind_type, "•")
            print(f"   {emoji} {ind_type}: {count}")
        
        print(f"\n🌊 Tremblements plateau : {len(self.results['board_shake_events'])}")
        print(f"📹 Mouvements caméra : {len(self.results['camera_movements'])}")
        print(f"✨ Effets visuels : {len(self.results['visual_effects'])}")
        print("="*60)
        
        # Générer HTML
        self.generate_html_report()
    
    def generate_html_report(self):
        """Génère un rapport HTML"""
        events = self.results.get("indicator_events", [])
        
        events_html = ""
        for event in events[:100]:  # Limite à 100
            emoji = {"star": "⭐", "thumbs_up": "👍", "question_mark": "❓", 
                     "info": "ℹ️", "brilliant": "✨"}.get(event["type"], "•")
            events_html += f"""
            <tr>
                <td>{event['start_time']:.2f}s</td>
                <td>{event['duration']:.2f}s</td>
                <td>{event['square']}</td>
                <td>{emoji} {event['type']}</td>
                <td>{event['confidence']*100:.1f}%</td>
            </tr>
            """
        
        html = f"""
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Analyse des Indicateurs de Coup</title>
    <style>
        body {{ font-family: Arial, sans-serif; background: #1a1a1a; color: #e0e0e0; padding: 20px; }}
        .container {{ max-width: 1000px; margin: 0 auto; }}
        h1 {{ background: linear-gradient(135deg, #f39c12, #e74c3c); padding: 20px; border-radius: 10px; }}
        .section {{ background: #2d2d2d; margin: 20px 0; padding: 20px; border-radius: 8px; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #444; }}
        th {{ background: #3d3d3d; }}
        .stat {{ display: inline-block; background: #3d3d3d; padding: 15px 25px; margin: 10px; border-radius: 5px; }}
        .stat-value {{ font-size: 2em; font-weight: bold; color: #f39c12; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>⭐ Analyse des Indicateurs de Coup</h1>
        
        <div class="section">
            <h2>Statistiques</h2>
            <div class="stat">
                <div class="stat-value">{len(self.results['move_indicators'])}</div>
                <div>Indicateurs détectés</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(events)}</div>
                <div>Événements groupés</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(self.results['board_shake_events'])}</div>
                <div>Tremblements</div>
            </div>
        </div>
        
        <div class="section">
            <h2>Événements d'Indicateurs</h2>
            <table>
                <tr><th>Timestamp</th><th>Durée</th><th>Case</th><th>Type</th><th>Confiance</th></tr>
                {events_html}
            </table>
        </div>
    </div>
</body>
</html>
"""
        
        html_path = self.output_dir / "indicators_report.html"
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html)
        
        print(f"📄 Rapport HTML : {html_path}")

if __name__ == "__main__":
    video_path = "/home/aurel/Downloads/ChessGame.mp4"
    
    if not os.path.exists(video_path):
        print(f"❌ Vidéo non trouvée : {video_path}")
        exit(1)
    
    analyzer = MoveIndicatorAnalyzer(video_path)
    analyzer.analyze()
