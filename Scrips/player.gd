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
@export var charge_shot_scene: PackedScene
@export var charge_shot_min_time: float = 0.4
@export var charge_shot_max_time: float = 1.2
@export var charge_shot_cooldown: float = 0.6
@export var charge_shot_max_damage: int = 6
@export var charge_shot_speed: float = 1000.0
@export var charge_shot_scale: float = 2.0
@export var base_bullet_damage: int = 1
@export var player_bullet_texture: Texture2D
@export var shield_arc_deg: float = 35.0
@export var shield_radius: float = 64.0
@export var shield_refill_delay: float = 1.5
@export var shield_refill_rate: float = 1.0
@export var max_power_upgrades: int = 3
@export var triple_shot_spread_deg: float = 12.0
@export var laser_scene: PackedScene
@export var laser_damage_per_second: float = 6.0
@export var laser_length: float = 2000.0
@export var laser_width: float = 16.0
@export var laser_cooldown: float = 3.0
@export var laser_duration: float = 0.6
@export var missile_scene: PackedScene
@export var missile_cooldown: float = 2.5
@export var missile_speed: float = 420.0
@export var missile_turn_rate_deg: float = 240.0
@export var missile_damage: int = 6
@export var missile_explosion_damage: int = 4
@export var missile_explosion_radius: float = 80.0
@export var missile_lifetime: float = 6.0

var fire_cooldown: float = 0.0
var charge_cooldown: float = 0.0
var charge_time: float = 0.0
var charging: bool = false
var lives: int
var invincible: bool = false
var blink_tween: Tween
var shield_durability: int = 0
var shield_max_durability: int = 0
var shield_refill_timer: float = 0.0
var power_upgrade_level: int = 0
var triple_shot_unlocked: bool = false
var laser_level: int = 0
var _laser_timer: float = 0.0
var missile_level: int = 0
var _missile_timer: float = 0.0

@onready var aim_cursor: Sprite2D = $AimCursor
@onready var shield: Node = $Shield

func _ready() -> void:
	add_to_group("player")

	_apply_difficulty()
	lives = max_lives
	lives_changed.emit(lives)

	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = invincibility_time
	invincibility_timer.timeout.connect(_end_invincibility)

	if charge_shot_scene == null:
		charge_shot_scene = bullet_scene
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)
	if shield and shield.has_method("configure"):
		shield.configure(shield_arc_deg, shield_radius)

func _apply_difficulty() -> void:
	match GameManager.difficulty:
		GameManager.Difficulty.EASY:
			max_lives = 5
		GameManager.Difficulty.HARD:
			max_lives = 1
		_:
			max_lives = 3

func _on_difficulty_changed(_value: int) -> void:
	var previous_max := max_lives
	_apply_difficulty()
	if lives > max_lives or max_lives > previous_max:
		lives = max_lives
		lives_changed.emit(lives)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	fire_cooldown -= delta
	charge_cooldown -= delta
	_update_aim_cursor()
	_update_shield_refill(delta)
	_update_time_slow()
	_laser_timer = maxf(0.0, _laser_timer - delta)
	_missile_timer = maxf(0.0, _missile_timer - delta)

	if Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		_shoot()
	if laser_level > 0 and Input.is_action_pressed("shoot"):
		_try_fire_lasers()
	if missile_level > 0 and Input.is_action_pressed("shoot"):
		_try_fire_missiles()

	if Input.is_action_pressed("charge_shot") and charge_cooldown <= 0.0:
		charging = true
		charge_time = min(charge_time + delta, charge_shot_max_time)

	if charging and Input.is_action_just_released("charge_shot"):
		_release_charge_shot()

func _update_time_slow() -> void:
	var slow_active := Input.is_action_pressed("slow_time")
	GameManager.set_slow_time(slow_active)

func _shoot() -> void:
	if bullet_scene == null:
		push_error("Player bullet scene not assigned")
		return

	if triple_shot_unlocked:
		for angle in _get_triple_shot_angles():
			_spawn_player_bullet(bullet_offset, angle)
	else:
		_spawn_player_bullet(bullet_offset, 0.0)

	fire_cooldown = fire_rate

func _release_charge_shot() -> void:
	if charge_time < charge_shot_min_time:
		charging = false
		charge_time = 0.0
		return

	if charge_shot_scene == null:
		push_error("Charge shot scene not assigned")
		charging = false
		charge_time = 0.0
		return

	var t: float = clamp(charge_time / charge_shot_max_time, 0.0, 1.0)
	var damage: int = int(lerp(1.0, float(charge_shot_max_damage + get_power_bonus()), t))
	var speed: float = lerp(800.0, charge_shot_speed, t)
	var dir: Vector2 = (get_global_mouse_position() - global_position).normalized()

	var bullet: Node2D = charge_shot_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.speed = speed
	var has_damage := false
	for prop in bullet.get_property_list():
		if prop.get("name") == "damage":
			has_damage = true
			break
	if has_damage:
		bullet.damage = damage
	if bullet.has_node("Sprite2D"):
		var bullet_sprite: Sprite2D = bullet.get_node("Sprite2D")
		bullet_sprite.scale *= lerp(1.0, charge_shot_scale, t)
		if player_bullet_texture:
			bullet_sprite.texture = player_bullet_texture
	bullet.rotation = dir.angle()
	get_tree().current_scene.add_child(bullet)

	charge_cooldown = charge_shot_cooldown
	charging = false
	charge_time = 0.0

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

func _update_aim_cursor() -> void:
	if aim_cursor == null:
		return
	aim_cursor.global_position = get_global_mouse_position()
	var t: float = clamp(charge_time / charge_shot_max_time, 0.0, 1.0)
	var cursor_scale: float = lerp(0.6, 1.2, t)
	aim_cursor.scale = Vector2.ONE * cursor_scale

func get_charge_ratio() -> float:
	return clamp(charge_time / charge_shot_max_time, 0.0, 1.0)

func is_charging() -> bool:
	return charging

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
	collider.set_deferred("disabled", false)

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
	collider.set_deferred("disabled", true)

	invincibility_timer.start()
	_start_blink()

func _die() -> void:
	print("GAME OVER")
	queue_free()

func add_shield(durability: int = 1) -> void:
	shield_max_durability = max(0, shield_max_durability + durability)
	shield_durability = max(0, shield_durability + durability)
	shield_refill_timer = 0.0

func add_life(amount: int = 1) -> void:
	lives = max(0, lives + amount)
	lives_changed.emit(lives)

func upgrade_shot(amount: int = 1) -> void:
	if power_upgrade_level >= max_power_upgrades:
		return
	power_upgrade_level = clamp(power_upgrade_level + amount, 0, max_power_upgrades)

func unlock_triple_shot() -> void:
	triple_shot_unlocked = true

func can_upgrade_power() -> bool:
	return power_upgrade_level < max_power_upgrades

func can_unlock_triple_shot() -> bool:
	return power_upgrade_level >= max_power_upgrades and not triple_shot_unlocked

func get_power_bonus() -> int:
	var bonus_steps := [4, 12, 24]
	var bonus := 0
	for i in range(min(power_upgrade_level, bonus_steps.size())):
		bonus += bonus_steps[i]
	return bonus

func unlock_laser_shot() -> void:
	if laser_level >= 3:
		return
	laser_level += 1

func has_laser_shot() -> bool:
	return laser_level > 0

func unlock_homing_missile() -> void:
	if missile_level >= 3:
		return
	missile_level += 1

func has_homing_missile() -> bool:
	return missile_level > 0

func _spawn_player_bullet(offset: Vector2, angle_offset: float) -> void:
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position + offset
	var has_damage := false
	var has_direction := false
	for prop in bullet.get_property_list():
		if prop.get("name") == "damage":
			has_damage = true
		elif prop.get("name") == "direction":
			has_direction = true
	if has_damage:
		bullet.damage = base_bullet_damage + get_power_bonus()
	if player_bullet_texture and bullet.has_node("Sprite2D"):
		var bullet_sprite: Sprite2D = bullet.get_node("Sprite2D")
		bullet_sprite.texture = player_bullet_texture
	if angle_offset != 0.0:
		if has_direction:
			bullet.direction = Vector2.UP.rotated(deg_to_rad(angle_offset))
	get_tree().current_scene.add_child(bullet)

func _get_triple_shot_angles() -> Array[float]:
	var half := triple_shot_spread_deg
	return [-half, 0.0, half]

func _try_fire_lasers() -> void:
	if _laser_timer > 0.0:
		return
	_laser_timer = laser_cooldown
	for i in range(laser_level):
		_spawn_laser(i)

func _spawn_laser(_index: int) -> void:
	if laser_scene == null:
		return
	var laser := laser_scene.instantiate()
	if laser.has_method("configure"):
		laser.configure(laser_damage_per_second, laser_length, laser_width)
	if laser.has_method("set_length"):
		laser.set_length(laser_length)
	if laser.has_method("set_direction"):
		var target := _get_nearest_enemy()
		if target:
			var dir := (target.global_position - global_position)
			if dir.length() > 0.001:
				laser.set_direction(dir.angle())
				if laser.has_method("set_length"):
					laser.set_length(dir.length())
		else:
			laser.set_direction(-PI * 0.5)
	if "duration" in laser:
		laser.duration = laser_duration
	add_child(laser)
	laser.position = Vector2.ZERO

func _try_fire_missiles() -> void:
	if _missile_timer > 0.0:
		return
	_missile_timer = missile_cooldown
	for i in range(missile_level):
		_spawn_missile(i)

func _spawn_missile(_index: int) -> void:
	if missile_scene == null:
		return
	var missile := missile_scene.instantiate()
	if missile.has_method("configure"):
		missile.configure(missile_damage, missile_explosion_damage, missile_explosion_radius, missile_speed, missile_turn_rate_deg, missile_lifetime)
	add_child(missile)
	missile.global_position = global_position

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

func _flash_shield() -> void:
	sprite.modulate = Color(0.4, 0.8, 1.0)
	await get_tree().create_timer(0.06).timeout
	sprite.modulate = Color.WHITE

func consume_shield(amount: int = 1) -> bool:
	if shield_durability <= 0:
		return false
	shield_durability = max(0, shield_durability - amount)
	_flash_shield()
	if shield_durability <= 0:
		shield_refill_timer = 0.0
	return true

func get_shield_durability() -> int:
	return shield_durability

func get_shield_max_durability() -> int:
	return shield_max_durability

func _update_shield_refill(delta: float) -> void:
	if shield_max_durability <= 0:
		return
	if shield_durability > 0:
		shield_refill_timer = 0.0
		return

	shield_refill_timer += delta
	if shield_refill_timer < shield_refill_delay:
		return

	var refill_amount := int(floor((shield_refill_timer - shield_refill_delay) * shield_refill_rate))
	if refill_amount <= 0:
		return

	shield_durability = clamp(shield_durability + refill_amount, 0, shield_max_durability)
	shield_refill_timer = shield_refill_delay
