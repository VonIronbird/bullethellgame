extends Node2D

signal stage_cleared_changed(count: int)

@export var stage_enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var shop_scene: PackedScene
@export var boss_spawn_position: Vector2 = Vector2(612, 65)
@export var spawn_positions: Array[Vector2] = [
	Vector2(320, 120),
	Vector2(640, 120),
	Vector2(960, 120),
]
@export var patterns: Array[int] = [0, 1, 2]
@export var stage_count: int = 3
@export var difficulty_stage_step: int = 2
@export var difficulty_hp_scale: float = 1.25
@export var difficulty_fire_rate_scale: float = 0.9
@export var difficulty_fire_speed_scale: float = 1.15
@export var endless_mode: bool = false
@export var max_enemies_on_screen: int = 12

var _remaining_enemies: int = 0
var _stage_index: int = 0
var _active_boss: Node = null
var _active_shop: Node = null
var _shop_open: bool = false
var _pending_spawns: Array = []

func _ready() -> void:
	add_to_group("stage_controller")
	stage_cleared_changed.emit(_stage_index)
	_spawn_stage_enemies()

func _spawn_stage_enemies() -> void:
	if stage_enemy_scene == null:
		push_error("Stage enemy scene not assigned")
		return

	_pending_spawns.clear()
	var difficulty_tier: int = int(floor(float(_stage_index) / float(max(difficulty_stage_step, 1))))
	var hp_scale: float = pow(difficulty_hp_scale, difficulty_tier)
	var fire_rate_scale: float = pow(difficulty_fire_rate_scale, difficulty_tier)
	var fire_speed_scale: float = pow(difficulty_fire_speed_scale, difficulty_tier)

	for i in range(spawn_positions.size()):
		var pattern_value := i % 4
		if i < patterns.size():
			pattern_value = patterns[i]
		_pending_spawns.append({
			"position": spawn_positions[i],
			"pattern": pattern_value,
			"hp_scale": hp_scale,
			"fire_rate_scale": fire_rate_scale,
			"fire_speed_scale": fire_speed_scale
		})

	_remaining_enemies = _pending_spawns.size()
	_spawn_pending_enemies()

	if _remaining_enemies == 0:
		_spawn_boss()

func _on_stage_enemy_died() -> void:
	_remaining_enemies -= 1
	_spawn_pending_enemies()
	if _remaining_enemies <= 0:
		_stage_index += 1
		stage_cleared_changed.emit(_stage_index)
		if endless_mode:
			var boss_interval: int = max(stage_count, 1)
			if boss_interval > 0 and (_stage_index % boss_interval) == 0:
				call_deferred("_spawn_boss")
			else:
				call_deferred("_spawn_stage_enemies")
		else:
			if _stage_index < max(stage_count, 1):
				call_deferred("_spawn_stage_enemies")
			else:
				call_deferred("_spawn_boss")

func _apply_difficulty(enemy: Node, hp_scale: float, fire_rate_scale: float, fire_speed_scale: float) -> void:
	var has_hp := false
	var has_fire_rate := false
	var has_fire_speed := false
	for prop in enemy.get_property_list():
		var prop_name: String = str(prop.get("name"))
		if prop_name == "max_hp":
			has_hp = true
		elif prop_name == "fire_rate":
			has_fire_rate = true
		elif prop_name == "fire_speed":
			has_fire_speed = true

	if has_hp:
		enemy.max_hp = int(ceil(float(enemy.max_hp) * hp_scale))
	if has_fire_rate:
		enemy.fire_rate = max(0.05, float(enemy.fire_rate) * fire_rate_scale)
	if has_fire_speed:
		enemy.fire_speed = float(enemy.fire_speed) * fire_speed_scale

func _spawn_pending_enemies() -> void:
	if _pending_spawns.is_empty():
		return
	var available := max_enemies_on_screen - _count_active_enemies()
	while available > 0 and not _pending_spawns.is_empty():
		var data: Dictionary = _pending_spawns.pop_front()
		var enemy := stage_enemy_scene.instantiate()
		enemy.global_position = data["position"]
		var has_move_enabled := false
		var has_pattern := false
		for prop in enemy.get_property_list():
			if prop.get("name") == "pattern":
				has_pattern = true
			elif prop.get("name") == "move_enabled":
				has_move_enabled = true
		if has_pattern:
			enemy.pattern = int(data["pattern"])
		if has_move_enabled:
			enemy.move_enabled = _stage_index >= 5
		_apply_difficulty(enemy, float(data["hp_scale"]), float(data["fire_rate_scale"]), float(data["fire_speed_scale"]))
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_stage_enemy_died)
		get_tree().current_scene.call_deferred("add_child", enemy)
		available -= 1

func _count_active_enemies() -> int:
	var count := 0
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group("boss"):
			continue
		count += 1
	return count

func _spawn_boss() -> void:
	if boss_scene == null:
		push_error("Boss scene not assigned")
		return

	var boss := boss_scene.instantiate()
	if boss.has_signal("boss_died"):
		if _active_boss != null and is_instance_valid(_active_boss):
			_active_boss.boss_died.disconnect(_on_boss_died)
		_active_boss = boss
		boss.boss_died.connect(_on_boss_died)
	boss.global_position = boss_spawn_position
	get_tree().current_scene.call_deferred("add_child", boss)

func _on_boss_died() -> void:
	_open_shop()

func _open_shop() -> void:
	if _shop_open:
		return
	if shop_scene == null:
		push_error("Shop scene not assigned")
		_after_shop()
		return

	_shop_open = true
	get_tree().paused = true

	var shop := shop_scene.instantiate()
	_active_shop = shop
	if shop.has_signal("shop_closed"):
		shop.shop_closed.connect(_on_shop_closed)
	get_tree().current_scene.call_deferred("add_child", shop)

func _on_shop_closed() -> void:
	if _active_shop != null and is_instance_valid(_active_shop):
		_active_shop.queue_free()
	_active_shop = null
	_shop_open = false
	get_tree().paused = false
	_after_shop()

func _after_shop() -> void:
	if endless_mode:
		call_deferred("_spawn_stage_enemies")

func get_stage_cleared() -> int:
	return _stage_index
