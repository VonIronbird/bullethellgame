extends CanvasLayer

signal shop_closed

const SHIELD_COST: int = 1
const SHIELD_DURABILITY: int = 8
const LIFE_COST: int = 1
const POWER_COST: int = 1
const LASER_COST: int = 1
const LASER_MAX: int = 3
const MISSILE_COST: int = 1
const MISSILE_MAX: int = 3

@onready var continue_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/ContinueButton
@onready var shield_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/ShieldButton
@onready var life_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/LifeButton
@onready var power_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/PowerButton
@onready var laser_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/LaserButton
@onready var missile_button: Button = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/MissileButton
@onready var score_label: Label = $ShopRoot/CenterContainer/PanelContainer/VBoxContainer/ScoreLabel

var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")

	continue_button.pressed.connect(_on_continue_pressed)
	shield_button.pressed.connect(_on_shield_pressed)
	life_button.pressed.connect(_on_life_pressed)
	power_button.pressed.connect(_on_power_pressed)
	laser_button.pressed.connect(_on_laser_pressed)
	missile_button.pressed.connect(_on_missile_pressed)
	GameManager.score_changed.connect(_update_score)

	_update_score(GameManager.score)
	_update_buttons()
	continue_button.grab_focus()

func _update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value
	_update_buttons()

func _can_afford(cost: int) -> bool:
	return GameManager.score >= cost

func _update_buttons() -> void:
	shield_button.disabled = not _can_afford(SHIELD_COST)
	life_button.disabled = not _can_afford(LIFE_COST)
	var can_power := _can_afford(POWER_COST) and _can_power_purchase()
	power_button.disabled = not can_power
	laser_button.disabled = not (_can_afford(LASER_COST) and _can_laser_purchase())
	missile_button.disabled = not (_can_afford(MISSILE_COST) and _can_missile_purchase())
	_update_power_label()
	_update_laser_label()
	_update_missile_label()

func _update_power_label() -> void:
	if player == null:
		return
	if player.has_method("can_unlock_triple_shot") and player.can_unlock_triple_shot():
		power_button.text = "Unlock 3 Shot - %d" % POWER_COST
	elif player.has_method("can_upgrade_power") and player.can_upgrade_power():
		var max_upgrades: int = 3
		var max_prop = player.get("max_power_upgrades")
		if max_prop != null:
			max_upgrades = int(max_prop)
		var current: int = 0
		var current_prop = player.get("power_upgrade_level")
		if current_prop != null:
			current = int(current_prop)
		power_button.text = "Power Shots (%d/%d) - %d" % [current, max_upgrades, POWER_COST]
	else:
		power_button.text = "Power Shots (MAX)"

func _on_shield_pressed() -> void:
	if not _spend(SHIELD_COST):
		return
	if player and player.has_method("add_shield"):
		player.add_shield(SHIELD_DURABILITY)

func _on_life_pressed() -> void:
	if not _spend(LIFE_COST):
		return
	if player and player.has_method("add_life"):
		player.add_life(1)

func _on_power_pressed() -> void:
	if not _spend(POWER_COST):
		return
	if player == null:
		return
	if player.has_method("can_unlock_triple_shot") and player.can_unlock_triple_shot():
		if player.has_method("unlock_triple_shot"):
			player.unlock_triple_shot()
	elif player.has_method("upgrade_shot") and player.has_method("can_upgrade_power"):
		if player.can_upgrade_power():
			player.upgrade_shot(1)
	_update_buttons()

func _on_laser_pressed() -> void:
	if not _spend(LASER_COST):
		return
	if player and player.has_method("unlock_laser_shot"):
		player.unlock_laser_shot()
	_update_buttons()

func _on_missile_pressed() -> void:
	if not _spend(MISSILE_COST):
		return
	if player and player.has_method("unlock_homing_missile"):
		player.unlock_homing_missile()
	_update_buttons()

func _spend(cost: int) -> bool:
	var ok := GameManager.spend_score(cost)
	_update_buttons()
	return ok

func _can_power_purchase() -> bool:
	if player == null:
		return false
	if player.has_method("can_unlock_triple_shot") and player.can_unlock_triple_shot():
		return true
	if player.has_method("can_upgrade_power") and player.can_upgrade_power():
		return true
	return false

func _can_laser_purchase() -> bool:
	if player == null:
		return false
	if player.has_method("laser_level"):
		return player.laser_level < LASER_MAX
	if player.has_method("has_laser_shot") and player.has_laser_shot():
		return false
	return true

func _update_laser_label() -> void:
	if player:
		var current := 0
		var level_prop = player.get("laser_level")
		if level_prop != null:
			current = int(level_prop)
		laser_button.text = "Laser Shot (%d/%d) - %d" % [current, LASER_MAX, LASER_COST]
	else:
		laser_button.text = "Laser Shot - %d" % LASER_COST

func _can_missile_purchase() -> bool:
	if player == null:
		return false
	var level_prop = player.get("missile_level")
	if level_prop != null:
		return int(level_prop) < MISSILE_MAX
	if player.has_method("has_homing_missile") and player.has_homing_missile():
		return false
	return true

func _update_missile_label() -> void:
	if player:
		var current := 0
		var level_prop = player.get("missile_level")
		if level_prop != null:
			current = int(level_prop)
		missile_button.text = "Homing Missile (%d/%d) - %d" % [current, MISSILE_MAX, MISSILE_COST]
	else:
		missile_button.text = "Homing Missile - %d" % MISSILE_COST

func _on_continue_pressed() -> void:
	shop_closed.emit()
