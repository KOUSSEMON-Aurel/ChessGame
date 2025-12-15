extends Camera3D
class_name ChessCameraController

## Contrôleur de caméra dynamique pour ChessGame
## Adapté pour respecter la vue Orthogonale d'origine tout en ajoutant des effets.

# ========================================
# PARAMÈTRES
# ========================================
@export var zoom_speed: float = 3.0
@export var pan_speed: float = 3.0 # Vitesse de lerp pour le pan (similaire au zoom)

# Valeurs de référence (capturées au démarrage)
var initial_transform: Transform3D
var initial_size: float
var initial_fov: float
var initial_center_on_ground: Vector3

# Valeurs cibles pour l'interpolation
var target_size: float
var target_fov: float
var target_offset: Vector3 = Vector3.ZERO

# Valeurs courantes
var current_offset: Vector3 = Vector3.ZERO
var current_size: float
var current_fov: float

# État
var is_orthogonal: bool = true

# ========================================
# SHAKE
# ========================================
var is_shaking: bool = false
var shake_intensity: float = 0.0
var shake_time_remaining: float = 0.0

# ========================================
# INITIALISATION
# ========================================
func _ready():
	# Capturer l'état initial défini dans l'éditeur (la "base")
	initial_transform = transform
	initial_size = size
	initial_fov = fov
	
	current_size = initial_size
	target_size = initial_size
	
	current_fov = initial_fov
	target_fov = initial_fov
	
	is_orthogonal = (projection == PROJECTION_ORTHOGONAL)
	
	# Calculer où la caméra regarde au sol (plan Y=0)
	initial_center_on_ground = _get_ground_intersection(initial_transform)
	
	print("🎥 Camera Controller Ready. Orthogonal: ", is_orthogonal, " Center: ", initial_center_on_ground)

func _process(delta):
	# 1. Gestion du Zoom
	if is_orthogonal:
		# En Orthogonal, on change la taille (size)
		current_size = lerp(current_size, target_size, delta * zoom_speed)
		size = current_size
	else:
		# En Perspective (si jamais changé)
		current_fov = lerp(current_fov, target_fov, delta * zoom_speed)
		fov = current_fov
	
	# 2. Gestion du Panoramique (Offset)
	current_offset = current_offset.lerp(target_offset, delta * pan_speed)
	
	# 3. Gestion du Shake
	var shake_offset = Vector3.ZERO
	if is_shaking:
		shake_time_remaining -= delta
		if shake_time_remaining <= 0:
			is_shaking = false
			shake_intensity = 0.0
		else:
			shake_offset = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			) * shake_intensity * 50.0

	# 4. Application de la Transform
	# On part de la transform initiale (rotation/pos de base) et on ajoute l'offset et le shake
	transform.origin = initial_transform.origin + current_offset + shake_offset

# ========================================
# ACTIONS DE ZOOM
# ========================================

func dynamic_zoom(event_type: String, target_pos_world: Vector3):
	# Calculer l'offset pour centrer la caméra sur la cible
	# Offset = Cible - CentreInitial
	# On peut appliquer un facteur (< 1.0) pour ne pas centrer trop agressivement
	var tracking_factor = 1.0 # 1.0 = Centrer parfaitement
	var desired_offset = (target_pos_world - initial_center_on_ground) * tracking_factor
	desired_offset.y = 0 # On ne change pas la hauteur de la caméra, juste X/Z
	
	match event_type:
		"capture", "capture_major":
			target_size = initial_size * 0.7
			target_offset = desired_offset
			
		"check", "checkmate":
			target_size = initial_size * 0.6
			add_camera_shake(0.15, 0.4)
			target_offset = desired_offset
			
		"normal":
			target_size = initial_size * 0.9
			# Sur un coup normal, on suit un peu moins agressivement ou on reste global
			# Ici on suit le mouvement pour garder la dynamique
			target_offset = desired_offset * 0.5 
			
		"promotion":
			target_size = initial_size * 0.8
			target_offset = desired_offset
			
		"castle":
			target_size = initial_size 
			target_offset = Vector3.ZERO # Vue globale

func reset_camera(_duration: float = 1.0):
	target_size = initial_size
	target_fov = initial_fov
	target_offset = Vector3.ZERO

func checkmate_sequence(target_pos: Vector3):
	# Centrer sur le roi
	var desired_offset = (target_pos - initial_center_on_ground)
	desired_offset.y = 0
	target_offset = desired_offset
	
	target_size = initial_size * 0.6
	add_camera_shake(0.2, 0.8)
	await get_tree().create_timer(1.5).timeout
	target_size = initial_size * 1.1 
	await get_tree().create_timer(1.0).timeout
	reset_camera()

# ========================================
# OUTILS
# ========================================
func add_camera_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_time_remaining = duration
	is_shaking = true

func _get_ground_intersection(t: Transform3D) -> Vector3:
	var origin = t.origin
	var forward = -t.basis.z # Vecteur Forward (négatif Z local)
	
	# Rayon: P = Origin + t * Forward
	# On cherche l'intersection avec le plan Y = 0 => Origin.y + t * Forward.y = 0
	# t = -Origin.y / Forward.y
	
	if abs(forward.y) < 0.001:
		return Vector3(origin.x, 0, origin.z) # Évite division par zéro (caméra à l'horizontale)
		
	var dist = -origin.y / forward.y
	return origin + forward * dist
