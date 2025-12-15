extends Node

class_name PieceAnimations

## Système d'animations spéciales pour les pièces d'échecs
## Basé sur l'analyse de la vidéo de référence

# ============================================================================
# TYPES D'ANIMATIONS
# ============================================================================

enum AnimationType {
	JUMP_DROP,          # Tour : Saut vertical + atterrissage brusque
	KNIGHT_ROTATION,    # Cavalier : Rotation pendant arc
	PENDULUM,           # Toutes : Oscillation à l'arrivée
	SQUASH_STRETCH,     # Pion : Écrasement/étirement
	ARC_TRAJECTORY,     # Toutes : Trajectoire parabolique
	SPIN_360,           # Captures : Rotation complète
	ELASTIC_BOUNCE,     # Petites pièces : Rebonds élastiques
	SHAKE,              # Impact : Micro-vibrations
	STANDARD            # Déplacement standard avec arc simple
}

# ============================================================================
# CONSTANTES DE CONFIGURATION
# ============================================================================

# Multiplicateurs globaux (ajustables facilement)
const ANIMATION_SPEED_MULTIPLIER = 1.0
const ARC_HEIGHT_MULTIPLIER = 1.0
const ENABLE_FANCY_ANIMATIONS = true

# Timings standard (secondes)
const SPEED_FAST = 0.25
const SPEED_NORMAL = 0.4
const SPEED_SLOW = 0.6
const ANTICIPATION_TIME = 0.1
const SETTLE_TIME = 0.2

# Hauteurs d'arc (multiplier de la hauteur d'une case)
const ARC_HEIGHT_LOW = 0.5
const ARC_HEIGHT_MEDIUM = 1.0
const ARC_HEIGHT_HIGH = 1.5

# Facteurs physiques
const BOUNCE_FACTOR = 0.4
const DAMPING_RATIO = 0.65
const ELASTIC_OVERSHOOT = 1.3
const SHAKE_AMPLITUDE = 0.05

# ============================================================================
# FONCTION PRINCIPALE
# ============================================================================

## Joue une animation sur une pièce 3D
## @param piece: Node3D - La pièce à animer
## @param type: AnimationType - Le type d'animation
## @param params: Dictionary - Paramètres { from: Vector3, to: Vector3, distance: float, ... }
## @return Tween - Le tween créé pour cette animation
static func play_animation(piece: Node3D, type: AnimationType, params: Dictionary) -> Tween:
	if not ENABLE_FANCY_ANIMATIONS and type != AnimationType.STANDARD:
		type = AnimationType.ARC_TRAJECTORY  # Fallback vers arc simple
	
	var tween = piece.create_tween()
	tween.set_parallel(false)  # Séquentiel par défaut
	
	match type:
		AnimationType.JUMP_DROP:
			return _animate_jump_drop(piece, tween, params)
		AnimationType.KNIGHT_ROTATION:
			return _animate_knight_rotation(piece, tween, params)
		AnimationType.PENDULUM:
			return _animate_pendulum(piece, tween, params)
		AnimationType.SQUASH_STRETCH:
			return _animate_squash_stretch(piece, tween, params)
		AnimationType.ARC_TRAJECTORY:
			return _animate_arc_trajectory(piece, tween, params)
		AnimationType.SPIN_360:
			return _animate_spin_360(piece, tween, params)
		AnimationType.ELASTIC_BOUNCE:
			return _animate_elastic_bounce(piece, tween, params)
		AnimationType.SHAKE:
			return _animate_shake(piece, tween, params)
		AnimationType.STANDARD:
			return _animate_standard(piece, tween, params)
		_:
			return _animate_standard(piece, tween, params)

# ============================================================================
# ANIMATIONS INDIVIDUELLES
# ============================================================================

## Animation 1: JUMP DROP (Tour)
## Saut vertical avec atterrissage brusque
static func _animate_jump_drop(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var jump_height = params.get("jump_height", 100.0) * ARC_HEIGHT_MULTIPLIER
	
	# Sauvegarde de l'échelle d'origine
	var original_scale = piece.scale
	
	# Phase 1: Squash d'anticipation (0.1s)
	tween.tween_property(piece, "scale", Vector3(1.1, 0.85, 1.1) * original_scale, ANTICIPATION_TIME * 0.5)
	tween.set_ease(Tween.EASE_IN)
	
	# Phase 2: Retour à la normale + début montée (0.05s)
	tween.tween_property(piece, "scale", original_scale, ANTICIPATION_TIME * 0.5)
	
	# Phase 3: Montée rapide (0.2s)
	var peak_pos = Vector3(from_pos.x, from_pos.y + jump_height, from_pos.z)
	tween.set_parallel(true)
	tween.tween_property(piece, "position:y", peak_pos.y, 0.2 * ANIMATION_SPEED_MULTIPLIER)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Déplacement horizontal pendant la montée
	tween.tween_property(piece, "position:x", to_pos.x, 0.35 * ANIMATION_SPEED_MULTIPLIER)
	tween.tween_property(piece, "position:z", to_pos.z, 0.35 * ANIMATION_SPEED_MULTIPLIER)
	
	# Phase 4: Pause au sommet (0.05s)
	tween.set_parallel(false)
	tween.tween_interval(0.05)
	
	# Phase 5: Chute brusque (0.15s)
	tween.tween_property(piece, "position:y", to_pos.y, 0.15 * ANIMATION_SPEED_MULTIPLIER)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# IMPACT TRIGGER
	tween.tween_callback(func(): 
		if params.has("on_impact"): params["on_impact"].call()
	)
	
	# Phase 6: Impact - squash à l'atterrissage
	tween.set_parallel(true)
	tween.tween_property(piece, "scale", Vector3(1.15, 0.85, 1.15) * original_scale, 0.05)
	
	# Phase 7: Rebond léger et retour normal
	tween.set_parallel(false)
	tween.tween_property(piece, "position:y", to_pos.y + 5, 0.08)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position:y", to_pos.y, 0.08)
	tween.set_ease(Tween.EASE_IN)
	
	# Retour échelle normale
	tween.tween_property(piece, "scale", original_scale, 0.1)
	tween.set_ease(Tween.EASE_OUT)
	
	return tween

## Animation 2: KNIGHT ROTATION (Cavalier)
## Rotation pendant déplacement en arc
static func _animate_knight_rotation(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var arc_height = params.get("arc_height", 70.0) * ARC_HEIGHT_MULTIPLIER
	var rotation_angle = params.get("rotation_angle", 60.0)  # degrés
	
	var original_rotation = piece.rotation
	var duration = 0.45 * ANIMATION_SPEED_MULTIPLIER
	
	# Anticipation : légère rotation inverse
	tween.tween_property(piece, "rotation:y", original_rotation.y - deg_to_rad(10), 0.05)
	tween.set_ease(Tween.EASE_IN)
	
	# Déplacement avec arc parabolique + rotation
	tween.set_parallel(true)
	
	# Rotation progressive
	tween.tween_property(piece, "rotation:y", original_rotation.y + deg_to_rad(rotation_angle), duration * 0.6)
	tween.set_ease(Tween.EASE_OUT)
	
	# Arc parabolique via callback
	# Arc parabolique via callback basé sur la valeur du tween
	var arc_callback = func(t: float):
		# t va de 0.0 à 1.0
		var height_offset = 4.0 * arc_height * t * (1.0 - t)
		var current_pos = from_pos.lerp(to_pos, t)
		piece.position = Vector3(current_pos.x, current_pos.y + height_offset, current_pos.z)
	
	tween.tween_method(arc_callback, 0.0, 1.0, duration)
	
	# SNAP FINAL: Assurer la position exacte à la fin
	tween.tween_callback(func(): piece.position = to_pos)
	
	# Phase finale : retour rotation normale + pendule
	tween.set_parallel(false)
	tween.tween_property(piece, "rotation:y", original_rotation.y, 0.15)
	tween.set_ease(Tween.EASE_OUT)
	
	# Effet pendule léger
	_add_pendulum_effect(tween, piece, original_rotation, 0.2)
	
	return tween

## Animation 3: PENDULUM (Toutes pièces)
## Oscillation à l'arrivée sur la case
static func _animate_pendulum(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var _from_pos = params.get("from", piece.position)
	var _to_pos = params.get("to", piece.position)
	var _duration = params.get("duration", SPEED_NORMAL) * ANIMATION_SPEED_MULTIPLIER
	
	# D'abord déplacement standard avec arc
	_animate_arc_trajectory(piece, tween, params)
	
	# Puis effet pendule
	var original_rotation = piece.rotation
	_add_pendulum_effect(tween, piece, original_rotation, 0.3)
	
	return tween

## Helper: Ajoute un effet pendule (oscillations amorties)
static func _add_pendulum_effect(tween: Tween, piece: Node3D, original_rotation: Vector3, total_duration: float):
	var amplitude1 = deg_to_rad(8.0)
	var amplitude2 = deg_to_rad(4.0)
	var amplitude3 = deg_to_rad(1.5)
	
	var osc_time = total_duration / 3.0
	
	# Oscillation 1
	tween.tween_property(piece, "rotation:z", original_rotation.z + amplitude1, osc_time * 0.5)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "rotation:z", original_rotation.z - amplitude2, osc_time)
	
	# Oscillation 2
	tween.tween_property(piece, "rotation:z", original_rotation.z + amplitude3, osc_time)
	
	# Retour repos
	tween.tween_property(piece, "rotation:z", original_rotation.z, osc_time * 0.5)
	tween.set_ease(Tween.EASE_OUT)

## Helper: Ajoute un effet d'inclinaison (Tilt) dans la direction du mouvement
static func _apply_tilt(piece: Node3D, tween: Tween, from: Vector3, to: Vector3, duration: float):
	if not ENABLE_FANCY_ANIMATIONS: return
	
	var dir = (to - from).normalized()
	if dir.length_squared() < 0.001: return
	
	# Calculer l'axe de rotation (produit vectoriel direction x UP)
	# On veut pencher vers l'avant, donc rotation autour de l'axe perpendiculaire
	var tilt_axis = dir.cross(Vector3.UP).normalized()
	
	# Angle d'inclinaison (ex: 15 degrés)
	var tilt_angle = deg_to_rad(15.0)
	
	# On ne peut pas facilement tween une rotation autour d'un axe arbitraire avec propriété simple.
	# On va tweener une propriété fictive via méthode ou modifier rotation.
	# Simplification: tweener 'rotation' est risqué si on modifie Y en même temps.
	# Si la pièce ne tourne pas sur Y (Arc Trajectory), on peut tween X et Z.
	
	# Pour simplifier et éviter conflits avec Knight Rotation:
	# On n'applique le tilt QUE si pas de rotation Y active significative, ou on le compose.
	# Ici, faisons simple: Tilt avant (début) -> Tilt arrière (freinage) -> Repos.
	
	# On utilise une méthode pour appliquer la rotation additive ? Trop complexe pour statique.
	# On va juste modifier la rotation X locale (Pitch) si la pièce est orientée vers cible.
	# Mais les pièces regardent toujours -Z ou +Z...
	
	# Alternative visuelle : Utiliser rotation:x (Pitch) et rotation:z (Roll) basés sur la direction.
	# target_tilt = Basis.looking_at(dir) ... non.
	
	# Approche la plus robuste pour Godot Tween : Basculer "x" et "z" par petits montants.
	var forward_tilt = tilt_axis * tilt_angle # Vector3(pitch, yaw, roll) representation approx
	
	# Phase 1: Pencher en avant (Accélération)
	tween.parallel().tween_property(piece, "rotation:x", piece.rotation.x + forward_tilt.x, duration * 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(piece, "rotation:z", piece.rotation.z + forward_tilt.z, duration * 0.2).set_ease(Tween.EASE_OUT)
	
	# Phase 2: Maintenir ou réduire
	
	# Phase 3: Redresser (Freinage/Arrivée)
	# On planifie le redressement vers la fin
	tween.parallel().tween_property(piece, "rotation:x", piece.rotation.x, duration * 0.3).set_delay(duration * 0.7)
	tween.parallel().tween_property(piece, "rotation:z", piece.rotation.z, duration * 0.3).set_delay(duration * 0.7)

## Animation 4: SQUASH & STRETCH (Pion)
## Écrasement et étirement pendant mouvement
static func _animate_squash_stretch(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var duration = params.get("duration", SPEED_NORMAL) * ANIMATION_SPEED_MULTIPLIER
	
	var original_scale = piece.scale
	
	# Phase 1: Squash (anticipation)
	tween.tween_property(piece, "scale", Vector3(1.1, 0.85, 1.1) * original_scale, 0.1)
	tween.set_ease(Tween.EASE_IN)
	
	# Phase 2: Stretch pendant mouvement
	tween.set_parallel(true)
	tween.tween_property(piece, "scale", Vector3(0.9, 1.15, 0.9) * original_scale, duration * 0.3)
	tween.set_ease(Tween.EASE_OUT)
	
	# Déplacement avec arc
	# Déplacement avec arc (utilisation directe de t)
	var arc_height = 30.0 * ARC_HEIGHT_MULTIPLIER
	var arc_callback = func(t: float):
		var height_offset = 4.0 * arc_height * t * (1.0 - t)
		var current_pos = from_pos.lerp(to_pos, t)
		piece.position = Vector3(current_pos.x, current_pos.y + height_offset, current_pos.z)
	
	tween.tween_method(arc_callback, 0.0, 1.0, duration)
	
	# SNAP FINAL
	tween.tween_callback(func(): piece.position = to_pos)
	
	# Phase 3: Retour normal
	tween.set_parallel(false)
	tween.tween_property(piece, "scale", original_scale, 0.1)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	return tween

## Animation 5: ARC TRAJECTORY (Standard avec arc)
## Trajectoire parabolique simple
static func _animate_arc_trajectory(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var distance = params.get("distance", from_pos.distance_to(to_pos))
	var duration = params.get("duration", SPEED_NORMAL) * ANIMATION_SPEED_MULTIPLIER
	
	# Calcul hauteur d'arc basée sur distance
	var arc_height = ARC_HEIGHT_LOW * 50.0  # Base
	if distance > 200:
		arc_height = ARC_HEIGHT_HIGH * 50.0
	elif distance > 100:
		arc_height = ARC_HEIGHT_MEDIUM * 50.0
	
	arc_height *= ARC_HEIGHT_MULTIPLIER
	
	# Animation de l'arc via callback interpolé (utilisation directe de t)
	var arc_callback = func(t: float):
		# Formule parabolique: height = 4 * h * t * (1-t)
		var height_offset = 4.0 * arc_height * t * (1.0 - t)
		var current_pos = from_pos.lerp(to_pos, t)
		piece.position = Vector3(current_pos.x, current_pos.y + height_offset, current_pos.z)
	
	tween.tween_method(arc_callback, 0.0, 1.0, duration)
	
	# Tilt dynamique
	_apply_tilt(piece, tween, from_pos, to_pos, duration)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# SNAP FINAL pour centrage parfait
	tween.tween_callback(func(): piece.position = to_pos)
	
	return tween

## Animation 6: SPIN 360 (Captures)
## Rotation complète pendant déplacement
static func _animate_spin_360(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var duration = params.get("duration", SPEED_SLOW) * ANIMATION_SPEED_MULTIPLIER
	var spin_count = params.get("spin_count", 1)  # Nombre de rotations
	
	var original_rotation = piece.rotation
	var arc_height = 80.0 * ARC_HEIGHT_MULTIPLIER
	
	tween.set_parallel(true)
	
	# Rotation 360° (ou multiple)
	var target_rotation_y = original_rotation.y + (TAU * spin_count)
	tween.tween_property(piece, "rotation:y", target_rotation_y, duration)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Optionnel: rotation X pour effet acrobatique
	if params.get("fancy_spin", false):
		tween.tween_property(piece, "rotation:x", original_rotation.x + PI, duration)
	
	# Déplacement en arc haut
	# Déplacement en arc haut avec t direct
	var arc_callback = func(t: float):
		var height_offset = 4.0 * arc_height * t * (1.0 - t)
		var current_pos = from_pos.lerp(to_pos, t)
		piece.position = Vector3(current_pos.x, current_pos.y + height_offset, current_pos.z)
	
	tween.tween_method(arc_callback, 0.0, 1.0, duration)
	
	# SNAP FINAL
	tween.tween_callback(func(): piece.position = to_pos)
	
	# Retour rotation normale
	tween.set_parallel(false)
	tween.tween_property(piece, "rotation", original_rotation, 0.1)
	tween.set_ease(Tween.EASE_OUT)
	
	return tween

## Animation 7: ELASTIC BOUNCE (Petites pièces)
## Rebonds élastiques à l'atterrissage
static func _animate_elastic_bounce(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var _from_pos = params.get("from", piece.position)
	var to_pos = params.get("to", piece.position)
	var _duration = params.get("duration", SPEED_NORMAL) * ANIMATION_SPEED_MULTIPLIER
	
	# D'abord arc standard
	_animate_arc_trajectory(piece, tween, params)
	
	# Puis rebonds
	var bounce_height_1 = 20.0 * BOUNCE_FACTOR
	var bounce_height_2 = 10.0 * BOUNCE_FACTOR
	var bounce_height_3 = 3.0 * BOUNCE_FACTOR
	
	# Rebond 1
	tween.tween_property(piece, "position:y", to_pos.y + bounce_height_1, 0.08)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position:y", to_pos.y, 0.08)
	tween.set_ease(Tween.EASE_IN)
	
	# Rebond 2
	tween.tween_property(piece, "position:y", to_pos.y + bounce_height_2, 0.06)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position:y", to_pos.y, 0.06)
	tween.set_ease(Tween.EASE_IN)
	
	# Rebond 3 (minimal)
	tween.tween_property(piece, "position:y", to_pos.y + bounce_height_3, 0.04)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position:y", to_pos.y, 0.04)
	tween.set_ease(Tween.EASE_IN)
	
	return tween

## Animation 8: SHAKE (Impact)
## Micro-vibrations après impact
static func _animate_shake(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var duration = params.get("duration", 0.2)
	var amplitude = params.get("amplitude", SHAKE_AMPLITUDE)
	var original_pos = piece.position
	
	# Plusieurs micro-déplacements aléatoires
	var shake_count = 8
	var shake_time = duration / shake_count
	
	for i in shake_count:
		var decay = 1.0 - (float(i) / shake_count)  # Décroissance
		var offset = Vector3(
			randf_range(-amplitude, amplitude) * decay,
			0,
			randf_range(-amplitude, amplitude) * decay
		)
		tween.tween_property(piece, "position", original_pos + offset, shake_time)
	
	# Retour position exacte
	tween.tween_property(piece, "position", original_pos, shake_time)
	
	return tween

## Animation Standard (fallback)
## Déplacement simple avec ease
static func _animate_standard(piece: Node3D, tween: Tween, params: Dictionary) -> Tween:
	var to_pos = params.get("to", piece.position)
	var duration = params.get("duration", SPEED_NORMAL) * ANIMATION_SPEED_MULTIPLIER
	
	tween.tween_property(piece, "position", to_pos, duration)
	
	# Tilt dynamique
	_apply_tilt(piece, tween, piece.position, to_pos, duration)
	
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	return tween

# ============================================================================
# HELPERS - SÉLECTION AUTOMATIQUE D'ANIMATION
# ============================================================================

## Sélectionne l'animation appropriée selon le type de pièce et contexte
## @param piece_type: String - Type de pièce (P, N, B, R, Q, K)
## @param move_context: Dictionary - { is_capture: bool, is_promotion: bool, distance: float }
## @return AnimationType
static func get_animation_for_piece(piece_type: String, move_context: Dictionary) -> AnimationType:
	var is_capture = move_context.get("is_capture", false)
	var is_promotion = move_context.get("is_promotion", false)
	var distance = move_context.get("distance", 0.0)
	
	# Promotions -> effet brillant
	if is_promotion:
		return AnimationType.SPIN_360
	
	# Captures -> animations spectaculaires
	if is_capture:
		match piece_type:
			"Q": return AnimationType.SPIN_360
			"R": return AnimationType.JUMP_DROP
			"N": return AnimationType.KNIGHT_ROTATION
			_: return AnimationType.ARC_TRAJECTORY
	
	# Mouvements normaux selon type de pièce
	match piece_type:
		"P":
			return AnimationType.SQUASH_STRETCH if distance < 100 else AnimationType.ELASTIC_BOUNCE
		"N":
			return AnimationType.KNIGHT_ROTATION
		"R":
			return AnimationType.JUMP_DROP if distance > 150 else AnimationType.ARC_TRAJECTORY
		"B", "Q":
			return AnimationType.ARC_TRAJECTORY
		"K":
			return AnimationType.PENDULUM
		_:
			return AnimationType.STANDARD

## Génère les paramètres pour une animation
static func get_animation_params(from: Vector3, to: Vector3, piece_type: String, move_context: Dictionary) -> Dictionary:
	var distance = from.distance_to(to)
	var is_capture = move_context.get("is_capture", false)
	
	var params = {
		"from": from,
		"to": to,
		"distance": distance
	}
	
	# Ajustements selon type de pièce
	match piece_type:
		"N":
			params["arc_height"] = 70.0
			params["rotation_angle"] = 60.0
		"R":
			params["jump_height"] = 120.0
		"P":
			params["duration"] = 0.35
		"Q":
			params["duration"] = 0.5 if distance > 200 else 0.4
	
	# Captures -> plus spectaculaires
	if is_capture:
		params["spin_count"] = 1
		params["fancy_spin"] = piece_type == "Q"
	
	return params
