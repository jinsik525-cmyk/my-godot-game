extends CanvasLayer

@onready var hp_fill:          ColorRect = $TopBar/HPBarBg/HPFill
@onready var special_fill:     ColorRect = $TopBar/SpecialBarBg/SpecialFill
@onready var special_label:    Label     = $TopBar/SpecialLabel
@onready var point_label:      Label     = $TopBar/PointLabel
@onready var gameover_panel:   Panel     = $GameOverPanel
@onready var final_score_label:Label     = $GameOverPanel/VBox/FinalScoreLabel
@onready var restart_button:   Button    = $GameOverPanel/VBox/RestartButton
@onready var pause_panel:      ColorRect = $PausePanel
@onready var resume_button:    Button    = $PausePanel/PauseBox/VBox/ResumeButton
@onready var quit_button:      Button    = $PausePanel/PauseBox/VBox/QuitButton

const HP_BAR_W      := 200.0
const SPECIAL_BAR_W := 200.0

func _ready() -> void:
	gameover_panel.visible = false
	pause_panel.visible    = false

	restart_button.pressed.connect(_on_restart_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	hp_fill.size.x      = HP_BAR_W
	special_fill.size.x = 0.0

# ── HP / 특수 / 포인트 ────────────────────────────────────────────────────────
func update_health(current: int, maximum: int) -> void:
	hp_fill.size.x = HP_BAR_W * (float(current) / float(maximum))

func update_special(current: int, maximum: int) -> void:
	special_fill.size.x = SPECIAL_BAR_W * (float(current) / float(maximum))
	if current >= maximum:
		special_label.text     = "필살기 [C]"
		special_label.modulate = Color.YELLOW
	else:
		special_label.text     = "필살기"
		special_label.modulate = Color.WHITE

func update_points(points: int) -> void:
	point_label.text = "포인트: %d" % points

# ── 게임오버 ─────────────────────────────────────────────────────────────────
func show_gameover(points: int) -> void:
	gameover_panel.visible     = true
	final_score_label.text     = "최종 포인트: %d" % points

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ── 일시정지 ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_just_pressed("ui_cancel"):
		if gameover_panel.visible:
			return          # 게임오버 중에는 일시정지 불가
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused   = paused
	pause_panel.visible = paused
	if paused:
		resume_button.grab_focus()

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Title.tscn")
