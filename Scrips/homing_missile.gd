extends Area2D

@export var speed: float = 420.0
@export var turn_rate_deg: float = 240.0
@export var damage: int = 6
@export var explosion_radius: float = 80.0
@export var explosion_damage: int = 4
@export var lifetime: float = 6.0
@export var explosion_duration: float = 0.25
@export var explosion_scale: float = 3.0
@export var explosion_color: Color = Color(1, 0.6, 0.2, 1)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite

var _life_time: float = 0.0
var _velocity: Vector2 = Vector2.UP
var _exploding: bool = false
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_update_shape()
	if sprite:
		_base_scale = sprite.scale

func configure(new_damage: int, new_explosion_damage: int, new_explosion_radius: float, new_speed: float, new_turn_rate_deg: float, new_lifetime: float) -> void:
	damage = new_damage
	explosion_damage = new_explosion_damage
	explosion_radius = new_explosion_radius
	speed = new_speed
	turn_rate_deg = new_turn_rate_deg
	lifetime = new_lifetime
	_update_shape()

func _physics_process(delta: float) -> void:
	if _exploding:
		return
	_life_time += delta
	if _life_time >= lifetime:
		_explode()
		return

	var target := _get_nearest_enemy()
	if target:
		var desired := (target.global_position - global_position).normalized()
		if desired.length() > 0.001:
			_velocity = _velocity.rotated(_turn_toward(_velocity.angle(), desired.angle(), deg_to_rad(turn_rate_deg) * delta)).normalized()

	global_position += _velocity * speed * delta
	rotation = _velocity.angle()

func _turn_toward(from_angle: float, to_angle: float, max_delta: float) -> float:
	var delta := wrapf(to_angle - from_angle, -PI, PI)
	return clamp(delta, -max_delta, max_delta)

func _on_area_entered(area: Area2D) -> void:
	if _exploding:
		return
	if not area.is_in_group("enemy"):
		return
	if area.has_method("take_hit"):
		area.take_hit(damage)
	_explode()

func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	monitoring = false
	if collision_shape:
		collision_shape.disabled = true
	_targets.clear()
	_damage_accum.clear()

	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			if enemy.has_method("take_hit"):
				enemy.take_hit(explosion_damage)

	if explosion_sprite and explosion_sprite.sprite_frames and explosion_sprite.sprite_frames.has_animation("explode"):
		sprite.visible = false
		explosion_sprite.visible = true
		explosion_sprite.play("explode")
		await get_tree().create_timer(explosion_duration).timeout
	else:
		if sprite:
			sprite.modulate = explosion_color
			var tween := create_tween()
			tween.tween_property(sprite, "scale", _base_scale * explosion_scale, explosion_duration)
			tween.parallel().tween_property(sprite, "modulate:a", 0.0, explosion_duration)
			await tween.finished
	queue_free()

func _get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _update_shape() -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape as CircleShape2D
		if shape:
			shape.radius = max(4.0, explosion_radius * 0.25)
