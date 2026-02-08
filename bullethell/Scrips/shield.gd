extends Area2D

@export var arc_deg: float = 120.0
@export var radius: float = 64.0
@export var arc_color: Color = Color(0.3, 0.8, 1.0, 0.45)
@export var arc_width: float = 6.0

@onready var player: Node2D = get_parent() as Node2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _last_angle: float = 0.0

func _ready() -> void:
	add_to_group("shield")
	_sync_shape()
	_update_visibility()

func _process(_delta: float) -> void:
	if player == null:
		return
	var mouse_dir: Vector2 = (get_global_mouse_position() - player.global_position)
	if mouse_dir.length() > 0.001:
		rotation = mouse_dir.angle()
		if abs(rotation - _last_angle) > 0.01:
			_last_angle = rotation
			queue_redraw()
	_update_visibility()

func _update_visibility() -> void:
	var durability: int = _get_durability()
	visible = durability > 0
	monitoring = durability > 0

func try_block(projectile: Node2D) -> bool:
	var durability: int = _get_durability()
	if durability <= 0:
		return false
	if player == null:
		return false

	var facing: Vector2 = (get_global_mouse_position() - player.global_position).normalized()
	if facing.length() < 0.001:
		return false
	var incoming: Vector2 = (projectile.global_position - player.global_position).normalized()
	if incoming.length() < 0.001:
		return false

	var dot: float = clamp(facing.dot(incoming), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(dot))
	if angle > arc_deg * 0.5:
		return false

	if player.has_method("consume_shield"):
		return player.consume_shield(1)
	return false

func _get_durability() -> int:
	if player and player.has_method("get_shield_durability"):
		return player.get_shield_durability()
	return 0

func _draw() -> void:
	var durability: int = _get_durability()
	if durability <= 0:
		return

	var half: float = deg_to_rad(arc_deg * 0.5)
	var points: int = 24
	var start: float = -half
	var end: float = half
	for i in range(points):
		var t0: float = float(i) / float(points)
		var t1: float = float(i + 1) / float(points)
		var a0: float = lerp(start, end, t0)
		var a1: float = lerp(start, end, t1)
		var p0: Vector2 = Vector2(cos(a0), sin(a0)) * radius
		var p1: Vector2 = Vector2(cos(a1), sin(a1)) * radius
		draw_line(p0, p1, arc_color, arc_width, true)

func configure(new_arc_deg: float, new_radius: float) -> void:
	arc_deg = new_arc_deg
	radius = new_radius
	_sync_shape()
	queue_redraw()

func _sync_shape() -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape as CircleShape2D
		if shape:
			shape.radius = radius
