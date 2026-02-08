extends CanvasLayer

@onready var score_label: Label = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/ScoreLabel
@onready var lives_label: Label = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/LivesLabel
@onready var charge_container: HBoxContainer = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/ChargeContainer
@onready var charge_bar: ProgressBar = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/ChargeContainer/ChargeBar
@onready var shield_container: HBoxContainer = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/ShieldContainer
@onready var shield_bar: ProgressBar = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/ShieldContainer/ShieldBar
@onready var stage_label: Label = $HUDRoot/TopLeftPanel/MarginContainer/VBoxContainer/StageLabel
@onready var game_over_label: Label = $HUDRoot/GameOverContainer/VBoxContainer/GameOverLabel
@onready var restart_label: Label = $HUDRoot/GameOverContainer/VBoxContainer/RestartLabel
@onready var boss_panel: Control = $HUDRoot/BossHealthBar
@onready var boss_bar: ProgressBar = $HUDRoot/BossHealthBar/MarginContainer/HBoxContainer/HealthBar
@onready var boss_label: Label = $HUDRoot/BossHealthBar/MarginContainer/HBoxContainer/BossLabel
@onready var phase_label: Label = $HUDRoot/BossHealthBar/MarginContainer/HBoxContainer/PhaseLabel
@onready var pause_overlay: ColorRect = $HUDRoot/PauseOverlay
@onready var resume_button: Button = $HUDRoot/PauseOverlay/PauseCenter/PausePanel/PauseVBox/ResumeButton
@onready var settings_button: Button = $HUDRoot/PauseOverlay/PauseCenter/PausePanel/PauseVBox/SettingsButton
@onready var menu_button: Button = $HUDRoot/PauseOverlay/PauseCenter/PausePanel/PauseVBox/MenuButton
@onready var quit_button: Button = $HUDRoot/PauseOverlay/PauseCenter/PausePanel/PauseVBox/QuitButton
@onready var settings_overlay: ColorRect = $HUDRoot/SettingsOverlay
@onready var settings_back_button: Button = $HUDRoot/SettingsOverlay/SettingsCenter/SettingsPanel/SettingsVBox/BackButton
@onready var settings_volume_slider: HSlider = $HUDRoot/SettingsOverlay/SettingsCenter/SettingsPanel/SettingsVBox/VolumeRow/VolumeSlider

var boss: Node = null
var player: Node = null
var stage_controller: Node = null

func _ready() -> void:
	_update_score(GameManager.score)
	GameManager.score_changed.connect(_update_score)

	game_over_label.visible = false
	restart_label.visible = false
	pause_overlay.visible = false
	settings_overlay.visible = false

	boss_panel.visible = false
	boss_bar.visible = false
	boss_label.visible = false

	GameManager.game_over.connect(_on_game_over)

	resume_button.pressed.connect(_resume_game)
	settings_button.pressed.connect(_open_settings)
	menu_button.pressed.connect(_go_to_menu)
	quit_button.pressed.connect(_quit_game)
	settings_back_button.pressed.connect(_close_settings)
	settings_volume_slider.value = GameManager.master_volume_linear
	settings_volume_slider.value_changed.connect(_on_volume_changed)
	GameManager.volume_changed.connect(_on_volume_updated)

	player = get_tree().get_first_node_in_group("player")
	if player:
		_update_lives(player.lives)
		player.lives_changed.connect(_update_lives)
	else:
		push_error("Player not found for Lives UI")

	boss = get_tree().get_first_node_in_group("boss")
	if boss:
		boss.health_changed.connect(_update_boss_health)
		boss.boss_died.connect(_hide_boss_bar)
		boss.phase_changed.connect(_update_phase)
	else:
		get_tree().node_added.connect(_on_node_added)

	stage_controller = get_tree().get_first_node_in_group("stage_controller")
	if stage_controller:
		_stage_connect(stage_controller)
	else:
		_resolve_stage_controller()
		if stage_controller == null:
			get_tree().node_added.connect(_on_node_added)

func _process(_delta: float) -> void:
	if stage_controller == null:
		_resolve_stage_controller()
	if player == null or not is_instance_valid(player):
		return

	if not player.has_method("get_charge_ratio") or not player.has_method("is_charging"):
		charge_container.visible = false
	else:
		var is_charging: bool = player.is_charging()
		var ratio: float = player.get_charge_ratio()
		charge_container.visible = is_charging or ratio > 0.0
		charge_bar.value = ratio

	if not player.has_method("get_shield_durability") or not player.has_method("get_shield_max_durability"):
		shield_container.visible = false
		return

	var shield_max: int = player.get_shield_max_durability()
	var shield_current: int = player.get_shield_durability()
	if shield_max <= 0:
		shield_container.visible = false
		return

	shield_container.visible = true
	shield_bar.max_value = shield_max
	shield_bar.value = shield_current

func _on_node_added(node: Node) -> void:
	if boss == null and node.is_in_group("boss"):
		boss = node
		boss.health_changed.connect(_update_boss_health)
		boss.boss_died.connect(_hide_boss_bar)
		boss.phase_changed.connect(_update_phase)
		_update_boss_health(boss.hp, boss.max_hp)
	if stage_controller == null and node.is_in_group("stage_controller"):
		stage_controller = node
		_stage_connect(stage_controller)
	if boss != null and stage_controller != null:
		get_tree().node_added.disconnect(_on_node_added)

func _stage_connect(controller: Node) -> void:
	if controller.has_signal("stage_cleared_changed"):
		controller.stage_cleared_changed.connect(_update_stage_cleared)
	if controller.has_method("get_stage_cleared"):
		_update_stage_cleared(controller.get_stage_cleared())

func _resolve_stage_controller() -> void:
	if stage_controller != null:
		return
	stage_controller = get_tree().get_first_node_in_group("stage_controller")
	if stage_controller:
		_stage_connect(stage_controller)
		return
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.is_in_group("stage_controller"):
		stage_controller = current_scene
		_stage_connect(stage_controller)

func _update_stage_cleared(count: int) -> void:
	stage_label.text = "STAGES CLEARED: %d" % count
func _update_boss_health(value: int, max_value: int) -> void:
	boss_bar.max_value = max_value
	boss_bar.value = value
	boss_panel.visible = true
	boss_bar.visible = true
	boss_label.visible = true
	phase_label.visible = true

func _show_boss_bar(max_hp: int) -> void:
	boss_panel.visible = true
	boss_bar.visible = true
	boss_label.visible = true
	phase_label.visible = true
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp

func _update_boss_bar(hp: int) -> void:
	boss_bar.value = hp

func _hide_boss_bar() -> void:
	boss_panel.visible = false
	boss_bar.visible = false
	boss_label.visible = false
	phase_label.visible = false

func _update_phase(phase: int) -> void:
	phase_label.text = "PHASE %d" % (phase + 1)

func _on_game_over() -> void:
	game_over_label.visible = true
	restart_label.visible = true
	pause_overlay.visible = false
	settings_overlay.visible = false
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_over:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause()
		return

	if event.is_action_pressed("ui_accept"):
		_restart_game()

func _restart_game() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().reload_current_scene()

func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	if GameManager.is_game_over:
		return
	get_tree().paused = true
	pause_overlay.visible = true
	settings_overlay.visible = false
	resume_button.grab_focus()

func _resume_game() -> void:
	if GameManager.is_game_over:
		return
	get_tree().paused = false
	pause_overlay.visible = false
	settings_overlay.visible = false

func _open_settings() -> void:
	settings_overlay.visible = true
	pause_overlay.visible = false
	settings_volume_slider.grab_focus()

func _close_settings() -> void:
	settings_overlay.visible = false
	if get_tree().paused and not GameManager.is_game_over:
		pause_overlay.visible = true
		resume_button.grab_focus()

func _go_to_menu() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")

func _quit_game() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	GameManager.set_master_volume(value)

func _on_volume_updated(value: float) -> void:
	settings_volume_slider.set_value_no_signal(value)

func _update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value

func _update_lives(value: int) -> void:
	lives_label.text = "LIVES: %d" % value
