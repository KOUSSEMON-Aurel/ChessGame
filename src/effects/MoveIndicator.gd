extends Node2D

class_name MoveIndicator

enum Type { BRILLIANT, EXCELLENT, BEST, GOOD, INACCURACY, BLUNDER, INFO }

# Configuration Couleur (Selon demande utilisateur)
var type_colors = {
	Type.BRILLIANT: Color("00bfff"), # Bleu (Deep Sky Blue)
	Type.EXCELLENT: Color("2ecc71"), # Vert
	Type.BEST:      Color("2ecc71"), # Vert
	Type.GOOD:      Color("2ecc71"), # Vert
	Type.INACCURACY:Color("f1c40f"), # Jaune
	Type.BLUNDER:   Color("e74c3c"), # Rouge
	Type.INFO:      Color.WHITE
}

var sprites = {
	Type.BRILLIANT: "res://assets/indicators/brilliant.png",
	Type.EXCELLENT: "res://assets/indicators/excellent.png",
	Type.BEST:      "res://assets/indicators/best.png",
	Type.GOOD:      "res://assets/indicators/good.png",
	Type.INACCURACY:"res://assets/indicators/inaccuracy.png",
	Type.BLUNDER:   "res://assets/indicators/blunder.png",
	Type.INFO:      "res://assets/indicators/best.png"
}

func _ready():
	z_index = 20

# Classe interne pour dessiner l'anneau (Ring)
class IndicatorRing extends Node2D:
	var color: Color
	var radius: float
	var thickness: float
	
	func _init(p_radius: float, p_color: Color, p_thickness: float):
		radius = p_radius
		color = p_color
		thickness = p_thickness
		
	func _draw():
		# Dessine un cercle vide (stroke)
		# draw_arc(center, radius, start_angle, end_angle, point_count, color, width)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, thickness)

# Fonction principale de spawn
func spawn_indicator_at_pos(pixel_pos: Vector2, type: Type, duration: float = 1.5, offset_corner: Vector2 = Vector2(35, 35)):
	# 1. Conteneur Principal (Pivot pour l'animation de sortie globale)
	var pivot = Node2D.new()
	pivot.position = pixel_pos + Vector2(offset_corner.x, -offset_corner.y)
	pivot.z_index = 101
	add_child(pivot)
	
	# Couleur de base
	var base_color = type_colors.get(type, Color.WHITE)
	
	# 2. Chargement de l'icône (Cœur)
	var sprite = Sprite2D.new()
	var tex_size = Vector2(60, 60)
	var base_scale = 0.08 # Image minuscule (0.08)
	
	if sprites.has(type):
		var path = sprites[type]
		if FileAccess.file_exists(path):
			var img = Image.new()
			# Charger l'image directement depuis le système de fichiers (plus sûr si pas importé)
			var global_path = ProjectSettings.globalize_path(path)
			var err = img.load(global_path)
			if err == OK:
				var tex = ImageTexture.create_from_image(img)
				sprite.texture = tex
				tex_size = tex.get_size()
				sprite.scale = Vector2(base_scale, base_scale)
			else:
				print("Failed to load image: ", global_path)
	
	# Rayon visuel de l'image (100%)
	var core_radius = (tex_size.x * base_scale) / 2.0
	
	# 3. Création des Anneaux
	# Anneau 1 (Satellite) : Gap quasi nul (110%) et trait épais
	var radius_satellite = core_radius * 1.10
	var ring_satellite = IndicatorRing.new(radius_satellite, base_color, 3.5) # Épaissi (était 2.0)
	ring_satellite.scale = Vector2.ZERO # Départ 0
	pivot.add_child(ring_satellite)
	
	# Anneau 2 (Pulse) : Statique à l'extérieur (170%)
	var radius_pulse = core_radius * 1.7
	var ring_pulse = IndicatorRing.new(radius_pulse, base_color, 1.5)
	ring_pulse.scale = Vector2.ONE 
	ring_pulse.modulate.a = 0.0    
	pivot.add_child(ring_pulse)
	
	# 4. Ajout du sprite (Devant les anneaux)
	sprite.scale = Vector2.ZERO
	pivot.add_child(sprite)
	
	# Lancer l'animation chorégraphiée
	_animate_pulse(pivot, sprite, ring_satellite, ring_pulse, base_scale, duration)

# Animation "Pulsation" + "Sortie Groupée"
func _animate_pulse(pivot: Node2D, sprite: Sprite2D, ring_sat: Node2D, ring_pulse: Node2D, target_sprite_scale: float, duration: float):
	var tween = create_tween()
	
	# ════════════════════════════════════════════════════════════════════════════
	# PHASE 1: L'APPARITION
	# ════════════════════════════════════════════════════════════════════════════
	
	tween.set_parallel(true)
	
	# A. Sprite (Cœur) : Pop Elastique
	tween.tween_property(sprite, "scale", Vector2(target_sprite_scale, target_sprite_scale), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# B. Anneau Satellite : Pop Elastique synchro
	tween.tween_property(ring_sat, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# C. Anneau Pulse (Extérieur) : Statique Flash
	tween.tween_property(ring_pulse, "modulate:a", 0.6, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_pulse, "modulate:a", 0.0, 0.35).set_delay(0.15).set_ease(Tween.EASE_IN)
	
	tween.set_parallel(false)
	
	# ════════════════════════════════════════════════════════════════════════════
	# PHASE 2: PAUSE
	# ════════════════════════════════════════════════════════════════════════════
	var stay_time = max(0.2, duration - 0.9) 
	tween.tween_interval(stay_time)
	
	# ════════════════════════════════════════════════════════════════════════════
	# PHASE 3: LA SORTIE GROUPÉE (3D Spin & Tilt)
	# ════════════════════════════════════════════════════════════════════════════
	
	tween.set_parallel(true)
	
	# 1. Scale Down global (Vers 0)
	tween.tween_property(pivot, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# 2. Rotation "A plat" (Spin Y simulé via scale.x)
	# On fait passer le scale X de 1 -> -1 (retournement) -> 0
	# Attention: Comme on tween déjà "scale" vers ZERO ci-dessus, on risque un conflit.
	# Solution: On tweene uniquement scale:y pour le rétrécissement, et scale:x pour le spin+rétrécissement? 
	# Non, "scale" affecte x et y.
	
	# Approche alternative : On utilise la rotation mais très légère (tilt) et on simule le spin via un skew extrême ou juste une rotation Y si c'était 3D.
	# Ici Node2D est 2D.
	
	# Si l'utilisateur veut "tourner a plat", c'est souvent une rotation Z simple (comme un disque sur une table).
	# "Un tour sur elle meme" -> 360 degres Z.
	# "Tourne juste a plat" -> Z ? 
	# "Pas comme une piece lancer" -> Une pièce lancée tourne sur X ou Y.
	# Donc l'utilisateur veut peut-être une VRAIE rotation Z (Horloge) mais "a plat" = perspective?
	
	# "Elle tourne juste a plat et un peu pencher vers la fin".
	# Cela ressemble à : Rotation Z (0 -> 360) + Tilt (Skew/ScaleY).
	
	# Essayons Rotation Z 180 degres + Tilt accentué.
	tween.tween_property(pivot, "rotation_degrees", 180.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Profondeur (Tilt arrière)
	tween.tween_property(pivot, "skew", 0.5, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(pivot, "scale:y", 0.0, 0.3) # Écrase un peu plus vite Y pour effet "couché"
	
	tween.set_parallel(false)
	tween.tween_callback(pivot.queue_free)
