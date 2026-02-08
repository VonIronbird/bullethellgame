extends Area2D

@export var speed: float = 800.0
@export var direction: Vector2 = Vector2.UP
@export var damage: int = 1

@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	direction = direction.normalized()
	area_entered.connect(_on_area_entered)
	notifier.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		queue_free()
		if area.has_method("take_hit"):
			area.take_hit(damage)
