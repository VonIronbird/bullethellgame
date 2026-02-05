extends Node

@export var bullet_scene: PackedScene
@export var fire_rate := 1.0
@export var bullet_speed := 300.0

var _cooldown := 0.0
var _spiral_angle := 0.0

func _process(delta: float) -> void:
	_cooldown -= delta

func fire(direction: Vector2) -> void:
	if bullet_scene == null:
		push_error("BulletEmitter: bullet_scene not assigned")
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = direction.normalized()
	bullet.speed = bullet_speed

	get_tree().current_scene.add_child(bullet)

func fire_spread(base_dir: Vector2, count: int, angle_deg: float) -> void:
	var half := angle_deg * 0.5

	for i in count:
		var t := float(i) / max(count - 1, 1)
		var angle := deg_to_rad(lerp(-half, half, t))
		fire(base_dir.rotated(angle))

func fire_ring(count: int) -> void:
	for i in count:
		var angle := TAU * float(i) / count
		fire(Vector2.RIGHT.rotated(angle))

func fire_spiral(step_deg := 10.0) -> void:
	_spiral_angle += deg_to_rad(step_deg)
	fire(Vector2.RIGHT.rotated(_spiral_angle))

func fire_at_player(count := 3, spread_deg := 10.0) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var base_dir := (player.global_position - global_position).normalized()
	fire_spread(base_dir, count, spread_deg)
