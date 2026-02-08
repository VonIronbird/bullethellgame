extends Node

signal score_changed(new_score: int)
signal game_over
signal difficulty_changed(new_difficulty: int)
signal volume_changed(new_volume: float)

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

var score: int = 0
var is_game_over: bool = false
var difficulty: Difficulty = Difficulty.NORMAL
var master_volume_linear: float = 1.0
var slow_time_scale: float = 0.5
var _slow_time_active: bool = false

func _ready() -> void:
	_apply_master_volume()

func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	score_changed.emit(score)

func spend_score(amount: int) -> bool:
	if is_game_over:
		return false
	if amount <= 0:
		return true
	if score < amount:
		return false
	score -= amount
	score_changed.emit(score)
	return true

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()

func reset() -> void:
	score = 0
	is_game_over = false
	score_changed.emit(score)
	set_slow_time(false)

func set_difficulty(value: int) -> void:
	var new_value: int = clamp(value, Difficulty.EASY, Difficulty.HARD)
	if new_value == difficulty:
		return
	difficulty = new_value as Difficulty
	difficulty_changed.emit(difficulty)

func set_master_volume(value: float) -> void:
	var clamped: float = clamp(value, 0.0, 1.0)
	if is_equal_approx(clamped, master_volume_linear):
		return
	master_volume_linear = clamped
	_apply_master_volume()
	volume_changed.emit(master_volume_linear)

func set_slow_time(active: bool) -> void:
	if active == _slow_time_active:
		return
	_slow_time_active = active
	Engine.time_scale = slow_time_scale if active else 1.0

func _apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var linear_value: float = maxf(master_volume_linear, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))
