extends Area2D

@export var damage_per_second: float = 6.0
@export var beam_length: float = 2000.0
@export var beam_width: float = 16.0
@export var beam_color: Color = Color(1, 0.2, 0.2, 0.6)
@export var duration: float = 0.6
@export var auto_aim: bool = true

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var player: Node2D = get_parent() as Node2D

var _targets: Array[Area2D] = []
var _damage_accum: Dictionary = {}
var _base_length: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_base_length = beam_length
	_sync_shape()
	rotation = -PI * 0.5
	queue_redraw()
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		queue_free()

func configure(new_damage_per_second: float, new_length: float, new_width: float) -> void:
	damage_per_second = new_damage_per_second
	beam_length = new_length
	beam_width = new_width
	_sync_shape()
	queue_redraw()

func set_direction(angle: float) -> void:
	rotation = angle

func set_length(new_length: float) -> void:
	beam_length = max(8.0, new_length)
	_sync_shape()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if auto_aim:
		_update_auto_aim()
	if _targets.is_empty():
		return

	var damage_step: float = damage_per_second * delta
	var to_remove: Array[Area2D] = []

	for target in _targets:
		if target == null or not is_instance_valid(target):
			to_remove.append(target)
			continue
		var prev: float = float(_damage_accum.get(target, 0.0))
		var total: float = prev + damage_step
		var hits: int = int(floor(total))
		if hits > 0 and target.has_method("take_hit"):
			for _i in range(hits):
				target.take_hit(1)
		total -= float(hits)
		_damage_accum[target] = total

	for target in to_remove:
		_targets.erase(target)
		_damage_accum.erase(target)

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return
	if _targets.has(area):
		return
	_targets.append(area)
	_damage_accum[area] = 0.0

func _on_area_exited(area: Area2D) -> void:
	_targets.erase(area)
	_damage_accum.erase(area)

func _sync_shape() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(beam_length, beam_width)
			collision_shape.position = Vector2(beam_length * 0.5, 0.0)
	_update_sprite()

func _update_sprite() -> void:
	if sprite == null or sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	sprite.rotation = 0.0
	sprite.position = Vector2(beam_length * 0.5, 0.0)
	sprite.scale = Vector2(beam_length / tex_size.x, beam_width / tex_size.y)

func _update_auto_aim() -> void:
	var target := _get_nearest_enemy()
	if target:
		var dir: Vector2 = (target.global_position - global_position)
		if dir.length() > 0.001:
			rotation = dir.angle()
			set_length(dir.length())
	else:
		rotation = -PI * 0.5
		set_length(_base_length)

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

func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(beam_length, 0.0), beam_color, beam_width, true)
