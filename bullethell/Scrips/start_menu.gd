extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var difficulty_select: OptionButton = $CenterContainer/VBoxContainer/DifficultyRow/DifficultySelect
@onready var menu_container: VBoxContainer = $CenterContainer/VBoxContainer
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var settings_back_button: Button = $SettingsOverlay/SettingsCenter/SettingsPanel/SettingsVBox/BackButton
@onready var settings_volume_slider: HSlider = $SettingsOverlay/SettingsCenter/SettingsPanel/SettingsVBox/VolumeRow/VolumeSlider

func _ready() -> void:
	get_tree().paused = false
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_difficulty_select()
	_setup_settings()
	start_button.grab_focus()

func _on_start_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	menu_container.visible = false
	settings_overlay.visible = true
	settings_volume_slider.grab_focus()

func _on_settings_back() -> void:
	settings_overlay.visible = false
	menu_container.visible = true
	settings_button.grab_focus()

func _setup_difficulty_select() -> void:
	if difficulty_select == null:
		return
	difficulty_select.clear()
	difficulty_select.add_item("Easy", GameManager.Difficulty.EASY)
	difficulty_select.add_item("Normal", GameManager.Difficulty.NORMAL)
	difficulty_select.add_item("Hard", GameManager.Difficulty.HARD)
	difficulty_select.selected = difficulty_select.get_item_index(GameManager.difficulty)
	difficulty_select.item_selected.connect(_on_difficulty_selected)

func _on_difficulty_selected(index: int) -> void:
	var id := difficulty_select.get_item_id(index)
	GameManager.set_difficulty(id)

func _setup_settings() -> void:
	settings_overlay.visible = false
	settings_back_button.pressed.connect(_on_settings_back)
	settings_volume_slider.value = GameManager.master_volume_linear
	settings_volume_slider.value_changed.connect(_on_volume_changed)
	GameManager.volume_changed.connect(_on_volume_updated)

func _on_volume_changed(value: float) -> void:
	GameManager.set_master_volume(value)

func _on_volume_updated(value: float) -> void:
	settings_volume_slider.set_value_no_signal(value)
