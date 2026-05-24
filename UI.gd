extends CanvasLayer

@onready var hp_fill: ColorRect = $TopBar/HPBarBg/HPFill
@onready var special_fill: ColorRect = $TopBar/SpecialBarBg/SpecialFill
@onready var special_label: Label = $TopBar/SpecialLabel
@onready var point_label: Label = $TopBar/PointLabel
@onready var gameover_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/VBox/RestartButton

var hp_bar_max_width: float = 200.0
var special_bar_max_width: float = 200.0

func _ready() -> void:
	gameover_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	hp_fill.size.x = hp_bar_max_width
	special_fill.size.x = 0.0

func update_health(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maximum)
	hp_fill.size.x = hp_bar_max_width * ratio

func update_special(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maximum)
	special_fill.size.x = special_bar_max_width * ratio
	if current >= maximum:
		special_label.text = "필살기 [C]"
		special_label.modulate = Color.YELLOW
	else:
		special_label.text = "필살기"
		special_label.modulate = Color.WHITE

func update_points(points: int) -> void:
	point_label.text = "포인트: %d" % points

func show_gameover(points: int) -> void:
	gameover_panel.visible = true
	final_score_label.text = "최종 포인트: %d" % points

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
