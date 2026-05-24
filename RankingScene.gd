extends Node

@onready var scores_vbox: VBoxContainer = $CenterContainer/VBox/ScoresVBox
@onready var back_button: Button        = $CenterContainer/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_scores()
	back_button.grab_focus()

func _populate_scores() -> void:
	var rankings: Array = Scores.load_scores()
	for i in range(5):
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		if i < rankings.size():
			var entry = rankings[i]
			lbl.text = "%d위   %d pt   (%s)" % [i + 1, entry["score"], entry["date"]]
			lbl.self_modulate = Color(1.0, 0.88, 0.25, 1.0) if i == 0 else Color.WHITE
		else:
			lbl.text = "%d위   ---" % (i + 1)
			lbl.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
		scores_vbox.add_child(lbl)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Title.tscn")
