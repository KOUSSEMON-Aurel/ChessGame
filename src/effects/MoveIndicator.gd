extends Node2D

class_name MoveIndicator

enum Type { BRILLIANT, EXCELLENT, BEST, GOOD, INACCURACY, BLUNDER, INFO }

# Sprites dynamiques (chargés depuis assets/indicators/)
var sprites = {
	Type.BRILLIANT: "res://assets/indicators/brilliant.png",
	Type.EXCELLENT: "res://assets/indicators/excellent.png",
	Type.BEST: "res://assets/indicators/best.png",
	Type.GOOD: "res://assets/indicators/good.png",
	Type.INACCURACY: "res://assets/indicators/inaccuracy.png",
	Type.BLUNDER: "res://assets/indicators/blunder.png",
	Type.INFO: "res://assets/indicators/best.png" # Fallback
}

func _ready():
	# Configurer le z-index pour être au-dessus des pièces
	z_index = 20

# Variante où l'appelant donne la position globale (centre de la case)
# offset_corner: Vecteur vers le coin de la case.
func spawn_indicator_at_pos(pixel_pos: Vector2, type: Type, duration: float = 1.0, offset_corner: Vector2 = Vector2(35, 35)):
	var indicator = Sprite2D.new()
	indicator.z_index = 101
	
	if sprites.has(type):
		var path = sprites[type]
		var img = Image.new()
		# Convertir en chemin absolu pour éviter le warning et assurer le chargement en runtime/export
		var global_path = ProjectSettings.globalize_path(path)
		
		if FileAccess.file_exists(path): # Check existe sur res:// (plus fiable dans l'éditeur)
			var err = img.load(global_path)
			if err == OK:
				var tex = ImageTexture.create_from_image(img)
				indicator.texture = tex
			else:
				push_warning("Failed to load image texture from " + global_path + ": " + str(err))
				return
		else:
			push_warning("Image file missing: " + path)
			return
	
	# Positionnement : Centre + Offset vers coin Haut-Droite
	# offset_corner est (w/2, h/2). On veut aller à (x+w/2, y-h/2)
	var final_offset = Vector2(offset_corner.x, -offset_corner.y)
	indicator.position = pixel_pos + final_offset
	
	# Echelle initiale (plus petite pour être discrète au début)
	indicator.scale = Vector2(0.0, 0.0)
	
	add_child(indicator)
	
	# Animation Rapide & Snappy
	indicator.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Pop In (0.0 -> 0.12) en 0.2s - Minuscule (car images sources HD)
	var target_scale = Vector2(0.12, 0.12) 
	tween.tween_property(indicator, "scale", target_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(indicator, "modulate:a", 1.0, 0.1) # Fade in très vite
	# Montée très légère (-5px) pour rester précis
	tween.tween_property(indicator, "position:y", indicator.position.y - 5, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. Stay & Fade Out
	tween.set_parallel(false)
	var stay_duration = duration - 0.4 # Reste du temps
	if stay_duration < 0: stay_duration = 0.1
	tween.tween_interval(stay_duration)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.2) # Fade out rapide à la fin
	tween.tween_callback(indicator.queue_free)
