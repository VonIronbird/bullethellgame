extends Area2D

signal health_changed(current_hp, max_hp)
signal boss_died()
signal phase_changed(phase: int)

enum BossPhase {
	PHASE_1,
	PHASE_2,
	PHASE_3
}

@export var phase_duration: float = 4.0
@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.3
@export var fire_speed: float = 450.0
@export var spread_angle: float = 30.0
@export var spread_count: int = 5
@export var ring_count: int = 16
@export var max_hp: int = 100
@export var spiral_step_deg: float = 12.0
@export var enemy_bullet_texture: Texture2D

@onready var fire_timer: Timer = $FireTimer
@onready var sprite: Sprite2D = $Sprite2D

var current_phase: BossPhase = BossPhase.PHASE_1
var hp: int
var spiral_angle: float = 0.0
var phase_index: int = 0
var phase_time: float = 0.0
var spread_rotation: float = 0.0
var player: Node2D
var _last_phase: BossPhase = BossPhase.PHASE_1

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_apply_difficulty()
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")

	fire_timer.stop()
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = false
	fire_timer.timeout.connect(_fire)
	fire_timer.start()

	emit_signal("health_changed", hp, max_hp)
	_update_phase()
	_start_phase_timer()

func _apply_difficulty() -> void:
	match GameManager.difficulty:
		GameManager.Difficulty.EASY:
			fire_rate *= 1.2
			fire_speed *= 0.9
		GameManager.Difficulty.HARD:
			fire_rate *= 0.8
			fire_speed *= 1.15
			spread_count += 3
			ring_count += 8
			spiral_step_deg = max(8.0, spiral_step_deg * 0.7)
		_:
			pass

func _start_phase_timer() -> void:
	await get_tree().create_timer(phase_duration).timeout
	phase_time += phase_duration
	_update_phase()
	_start_phase_timer()

func _update_phase() -> void:
	var hp_ratio := float(hp) / float(max_hp)

	var hp_phase := BossPhase.PHASE_1
	if hp_ratio <= 0.33:
		hp_phase = BossPhase.PHASE_3
	elif hp_ratio <= 0.66:
		hp_phase = BossPhase.PHASE_2

	var time_phase := BossPhase.PHASE_1
	if phase_time >= phase_duration * 2:
		time_phase = BossPhase.PHASE_3
	elif phase_time >= phase_duration:
		time_phase = BossPhase.PHASE_2

	current_phase = max(hp_phase, time_phase)
	if current_phase != _last_phase:
		_last_phase = current_phase
		emit_signal("phase_changed", int(current_phase))

func _fire() -> void:
	if projectile_scene == null:
		return

	match current_phase:
		BossPhase.PHASE_1:
			_fire_ring()
		BossPhase.PHASE_2:
			_fire_spread()
			_fire_delayed_turn()
		BossPhase.PHASE_3:
			_fire_ring()
			_fire_spiral()

func _spawn_bullet(direction: Vector2) -> void:
	var bullet := projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = direction.normalized()
	bullet.speed = fire_speed
	bullet.acceleration = 0.0
	bullet.curve_speed_deg = 0.0
	bullet.curve_delay = 0.0
	_apply_bullet_texture(bullet)
	get_tree().current_scene.add_child(bullet)

func _fire_spread() -> void:
	var base_dir := Vector2.DOWN.rotated(spread_rotation)
	var half: float = spread_angle * 0.5

	for i in range(spread_count):
		var t := float(i) / float(max(spread_count - 1, 1))
		var angle_rad := deg_to_rad(lerp(-half, half, t))
		_spawn_bullet(base_dir.rotated(angle_rad))

	spread_rotation += deg_to_rad(5.0)

func _fire_ring() -> void:
	for i in range(ring_count):
		var angle := TAU * float(i) / float(ring_count)

		var bullet := projectile_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = Vector2.RIGHT.rotated(angle)
		bullet.speed = fire_speed * 0.3
		bullet.acceleration = fire_speed * 1.2
		bullet.max_speed = fire_speed
		_apply_bullet_texture(bullet)
		get_tree().current_scene.add_child(bullet)

func _fire_spiral() -> void:
	var bullet := projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = Vector2.RIGHT.rotated(spiral_angle)
	bullet.speed = fire_speed
	bullet.curve_speed_deg = 90.0
	_apply_bullet_texture(bullet)
	get_tree().current_scene.add_child(bullet)
	spiral_angle += deg_to_rad(spiral_step_deg)

func _fire_delayed_turn() -> void:
	var dir := Vector2.DOWN

	var bullet := projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.speed = fire_speed
	bullet.curve_delay = 0.4
	bullet.curve_speed_deg = 180.0
	_apply_bullet_texture(bullet)
	get_tree().current_scene.add_child(bullet)

func take_hit(damage: int = 1) -> void:
	hp -= damage
	emit_signal("health_changed", hp, max_hp)
	_flash()
	_update_phase()

	if hp <= 0:
		emit_signal("boss_died")
		_die()

func _flash() -> void:
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _die() -> void:
	GameManager.add_score(100)
	queue_free()

func _apply_bullet_texture(bullet: Node) -> void:
	if enemy_bullet_texture == null:
		return
	if bullet.has_node("Sprite2D"):
		var sprite_node: Sprite2D = bullet.get_node("Sprite2D")
		sprite_node.texture = enemy_bullet_texture
