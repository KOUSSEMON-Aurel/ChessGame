extends Camera3D

# Paramètres de tremblement
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var rng = RandomNumberGenerator.new()

# Paramètres de mouvement
var target_position: Vector3
var initial_position: Vector3
var initial_rotation: Vector3

func _ready():
	rng.randomize()
	initial_position = position
	initial_rotation = rotation_degrees
	target_position = position

func _process(delta):
	# Gestion du tremblement (Screen Shake)
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# Appliquer un offset aléatoire
		var offset = Vector3(
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength)
		)
		
		# Appliquer à la position (en gardant la position cible comme base)
		position = target_position + offset
		
		# Arrêter si très faible
		if shake_strength < 0.01:
			shake_strength = 0
			position = target_position
	
	# Ici on pourrait ajouter du lissage de mouvement ou du zoom dynamique

# Fonction publique pour déclencher un tremblement
func apply_shake(strength: float = 0.5):
	shake_strength = strength

# Fonction pour déplacer la caméra (ex: zoom ou changement d'angle)
func move_to(new_position: Vector3, duration: float = 1.0):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "target_position", new_position, duration)
	# Note: _process mettra à jour 'position' basé sur 'target_position'
