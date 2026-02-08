extends Area2D

signal enemy_died

enum Pattern {
	SPREAD,
	RING,
	SPIRAL,
	AIMED
}

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.6
@export var fire_speed: float = 300.0
@export var max_hp: int = 6
@export var spread_angle: float = 30.0
@export var spread_count: int = 4
@export var ring_count: int = 10
@export var spiral_step_deg: float = 18.0
@export var pattern: Pattern = Pattern.SPREAD
@export var move_enabled: bool = false
@export var move_speed: float = 80.0
@export var move_bounds_padding: Vector2 = Vector2(60, 60)
@export var separation_strength: float = 220.0
@export var top_half_only: bool = true
@export var safe_gap_enabled: bool = true
@export var safe_gap_deg: float = 35.0
@export var enemy_bullet_texture: Texture2D

@onready var fire_timer: Timer = $FireTimer
@onready var sprite: Sprite2D = $Sprite2D

var hp: int
var spiral_angle: float = 0.0
var spread_rotation: float = 0.0
var player: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _move_bounds: Rect2

func _ready() -> void:
	add_to_group("enemy")
	_apply_difficulty()
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	_setup_movement()

	fire_timer.stop()
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = false
	fire_timer.timeout.connect(_fire)
	fire_timer.start()

func _apply_difficulty() -> void:
	match GameManager.difficulty:
		GameManager.Difficulty.EASY:
			fire_rate *= 1.2
			fire_speed *= 0.9
		GameManager.Difficulty.HARD:
			fire_rate *= 0.8
			fire_speed *= 1.1
			spread_count += 2
			ring_count += 6
			spiral_step_deg = max(8.0, spiral_step_deg * 0.7)
			if pattern == Pattern.SPREAD and randi() % 2 == 0:
				pattern = Pattern.AIMED
		_:
			pass

func _physics_process(delta: float) -> void:
	if not move_enabled:
		return

	if _velocity == Vector2.ZERO:
		_velocity = Vector2.RIGHT.rotated(randf() * TAU) * move_speed

	global_position += _velocity * delta
	_bounce_in_bounds()
	_resolve_enemy_overlap(delta)
func _fire() -> void:
	if projectile_scene == null:
		return

	match pattern:
		Pattern.SPREAD:
			_fire_spread()
		Pattern.RING:
			_fire_ring()
		Pattern.SPIRAL:
			_fire_spiral()
		Pattern.AIMED:
			_fire_aimed()

func _spawn_bullet(direction: Vector2, speed_override: float = -1.0) -> void:
	var bullet := projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = direction.normalized()
	bullet.speed = fire_speed if speed_override < 0.0 else speed_override
	bullet.acceleration = 0.0
	bullet.curve_speed_deg = 0.0
	bullet.curve_delay = 0.0
	_apply_bullet_texture(bullet)
	get_tree().current_scene.add_child(bullet)

func _apply_bullet_texture(bullet: Node) -> void:
	if enemy_bullet_texture == null:
		return
	if bullet.has_node("Sprite2D"):
		var sprite_node: Sprite2D = bullet.get_node("Sprite2D")
		sprite_node.texture = enemy_bullet_texture

func _fire_spread() -> void:
	var base_dir := Vector2.DOWN.rotated(spread_rotation)
	var half: float = spread_angle * 0.5
	var gap_angle := _get_safe_gap_angle()
	var gap_half := deg_to_rad(safe_gap_deg * 0.5)

	for i in range(spread_count):
		var t := float(i) / float(max(spread_count - 1, 1))
		var angle_rad := deg_to_rad(lerp(-half, half, t))
		var dir := base_dir.rotated(angle_rad)
		if _is_in_safe_gap(dir.angle(), gap_angle, gap_half):
			continue
		_spawn_bullet(dir)

	spread_rotation += deg_to_rad(6.0)

func _fire_ring() -> void:
	var gap_angle := _get_safe_gap_angle()
	var gap_half := deg_to_rad(safe_gap_deg * 0.5)
	for i in range(ring_count):
		var angle := TAU * float(i) / float(ring_count)
		if _is_in_safe_gap(angle, gap_angle, gap_half):
			continue
		_spawn_bullet(Vector2.RIGHT.rotated(angle), fire_speed * 0.8)

func _fire_spiral() -> void:
	_spawn_bullet(Vector2.RIGHT.rotated(spiral_angle))
	spiral_angle += deg_to_rad(spiral_step_deg)

func _fire_aimed() -> void:
	var dir := Vector2.DOWN
	if player:
		dir = (player.global_position - global_position).normalized()
	_spawn_bullet(dir)

func _get_safe_gap_angle() -> float:
	if not safe_gap_enabled or player == null:
		return 0.0
	var dir := (player.global_position - global_position)
	if dir.length() < 0.001:
		return 0.0
	return dir.angle()

func _is_in_safe_gap(angle: float, gap_angle: float, gap_half: float) -> bool:
	if not safe_gap_enabled:
		return false
	var diff := absf(wrapf(angle - gap_angle, -PI, PI))
	return diff <= gap_half

func _setup_movement() -> void:
	var view_rect := get_viewport_rect()
	var min_pos := view_rect.position + move_bounds_padding
	var max_pos := view_rect.position + view_rect.size - move_bounds_padding
	if top_half_only:
		max_pos.y = view_rect.position.y + (view_rect.size.y * 0.5) - move_bounds_padding.y
	_move_bounds = Rect2(min_pos, max_pos - min_pos)
	if move_enabled:
		_velocity = Vector2.RIGHT.rotated(randf() * TAU) * move_speed

func _bounce_in_bounds() -> void:
	if _move_bounds.size == Vector2.ZERO:
		return
	var min_x := _move_bounds.position.x
	var max_x := _move_bounds.position.x + _move_bounds.size.x
	var min_y := _move_bounds.position.y
	var max_y := _move_bounds.position.y + _move_bounds.size.y

	if global_position.x < min_x:
		global_position.x = min_x
		_velocity.x = abs(_velocity.x)
	elif global_position.x > max_x:
		global_position.x = max_x
		_velocity.x = -abs(_velocity.x)

	if global_position.y < min_y:
		global_position.y = min_y
		_velocity.y = abs(_velocity.y)
	elif global_position.y > max_y:
		global_position.y = max_y
		_velocity.y = -abs(_velocity.y)

func _resolve_enemy_overlap(delta: float) -> void:
	var overlaps := get_overlapping_areas()
	for area in overlaps:
		if area == self:
			continue
		if not area.is_in_group("enemy"):
			continue
		if not (area is Node2D):
			continue
		var other := area as Node2D
		var dir := global_position - other.global_position
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		else:
			dir = dir.normalized()
		global_position += dir * separation_strength * delta

func take_hit(damage: int = 1) -> void:
	hp -= damage
	_flash()

	if hp <= 0:
		emit_signal("enemy_died")
		_die()

func _flash() -> void:
	sprite.modulate = Color(1, 0.6, 0.6)
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _die() -> void:
	GameManager.add_score(25)
	queue_free()
