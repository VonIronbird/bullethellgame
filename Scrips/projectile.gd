extends Area2D

@export var speed: float = 400.0
@export var direction: Vector2 = Vector2.DOWN
@export var lifetime: float = 10.0
@export var acceleration: float = 0.0
@export var max_speed: float = 999.0

@export var curve_speed_deg: float = 0.0
@export var curve_delay: float = 0.0

@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _life_time: float = 0.0
var _blocked: bool = false

func _ready() -> void:
	direction = direction.normalized()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	_life_time += delta

	speed += acceleration * delta
	speed = clamp(speed, 0.0, max_speed)

	if curve_speed_deg != 0.0 and _life_time >= curve_delay:
		direction = direction.rotated(deg_to_rad(curve_speed_deg) * delta)

	global_position += direction * speed * delta

	if _life_time >= lifetime:
		queue_free()

func _on_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	if _blocked:
		return
	if body.is_in_group("player"):
		if body.has_method("take_hit"):
			body.take_hit()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _blocked:
		return
	if area.is_in_group("shield") and area.has_method("try_block"):
		if area.try_block(self):
			_blocked = true
			queue_free()
