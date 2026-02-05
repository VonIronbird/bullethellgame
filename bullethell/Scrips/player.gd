extends CharacterBody2D

signal lives_changed(current_lives: int)



@export var move_speed: float = 300.0
@export var focus_speed: float = 120.0
@export var invincibility_time: float = 1.5

@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D

@export var max_lives: int = 3
@export var respawn_position: Vector2 = Vector2(640, 600)

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.15
@export var bullet_offset: Vector2 = Vector2(0, -20)

var fire_cooldown: float = 0.0
var lives: int
var invincible: bool = false
var blink_tween: Tween


func _ready() -> void:
	add_to_group("player")

	lives = max_lives
	lives_changed.emit(lives)

	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = invincibility_time
	invincibility_timer.timeout.connect(_end_invincibility)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	fire_cooldown -= delta

	if Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		_shoot()

func _shoot() -> void:
	if bullet_scene == null:
		push_error("Player bullet scene not assigned")
		return

	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position + bullet_offset
	get_tree().current_scene.add_child(bullet)

	fire_cooldown = fire_rate

func _handle_movement(_delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var speed := focus_speed if Input.is_action_pressed("focus") else move_speed
	velocity = input_vector * speed
	move_and_slide()

func take_hit() -> void:
	if invincible:
		return

	lives -= 1
	lives_changed.emit(lives)

	if lives <= 0:
		_die()
		GameManager.trigger_game_over()
		return

	_respawn()


func _end_invincibility() -> void:
	invincible = false
	collider.disabled = false

	if blink_tween:
		blink_tween.kill()

	sprite.visible = true

func _start_blink() -> void:
	if blink_tween and blink_tween.is_running():
		blink_tween.kill()

	blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(sprite, "visible", false, 0.1)
	blink_tween.tween_property(sprite, "visible", true, 0.1)

func _respawn() -> void:
	global_position = respawn_position
	invincible = true
	collider.disabled = true

	invincibility_timer.start()
	_start_blink()

func _die() -> void:
	print("GAME OVER")
	queue_free()
