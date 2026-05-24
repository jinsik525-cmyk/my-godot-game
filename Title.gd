extends Node

@onready var start_button:   Button = $CenterContainer/VBox/StartButton
@onready var ranking_button: Button = $CenterContainer/VBox/RankingButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	ranking_button.pressed.connect(_on_ranking_pressed)
	start_button.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_ranking_pressed() -> void:
	get_tree().change_scene_to_file("res://RankingScene.tscn")
