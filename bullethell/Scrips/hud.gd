extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var lives_label: Label = $LivesLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var restart_label: Label = $RestartLabel
@onready var boss_bar: TextureProgressBar = $BossHealthBar/TextureProgressBar
@onready var boss_label: Label = $BossHealthBar/Label

var boss: Node = null

func _ready() -> void:
	_update_score(GameManager.score)
	GameManager.score_changed.connect(_update_score)

	game_over_label.visible = false
	restart_label.visible = false

	boss_bar.visible = false
	boss_label.visible = false

	GameManager.game_over.connect(_on_game_over)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		_update_lives(player.lives)
		player.lives_changed.connect(_update_lives)
	else:
		push_error("Player not found for Lives UI")

	# Boss connections
	boss = get_tree().get_first_node_in_group("boss")
	if boss:
		boss.health_changed.connect(_update_boss_health)
		boss.boss_died.connect(_hide_boss_bar)
	else:
		push_error("Boss not found for BossHealth UI")


func _update_boss_health(value: int, max_value: int) -> void:
	boss_bar.max_value = max_value
	boss_bar.value = value
	boss_bar.visible = true
	boss_label.visible = true


func _show_boss_bar(max_hp: int) -> void:
	boss_bar.visible = true
	boss_label.visible = true
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp


func _update_boss_bar(hp: int) -> void:
	boss_bar.value = hp


func _hide_boss_bar() -> void:
	boss_bar.visible = false
	boss_label.visible = false


func _on_game_over() -> void:
	game_over_label.visible = true
	restart_label.visible = true
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_over:
		return

	if event.is_action_pressed("ui_accept"):
		_restart_game()


func _restart_game() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().reload_current_scene()


func _update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value


func _update_lives(value: int) -> void:
	lives_label.text = "LIVES: %d" % value
