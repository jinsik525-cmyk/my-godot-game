extends Node2D

const SCREEN_WIDTH := 1280
const SCREEN_HEIGHT := 720
const GROUND_Y := 500.0
const PLAYER_X := 640.0

const SPAWN_INTERVAL_BASE := 2.5
const SPAWN_INTERVAL_MIN := 0.6
const DIFFICULTY_RAMP := 0.05       # 적 처치마다 스폰 간격 감소
const SPEED_RAMP := 0.04            # 적 처치마다 속도 배율 증가

var points := 0
var kills := 0
var spawn_timer := 0.0
var spawn_interval := SPAWN_INTERVAL_BASE
var enemy_speed_mult := 1.0
var game_active := true

@onready var player: CharacterBody2D = $Player
@onready var ui: CanvasLayer = $UI
@onready var enemy_container: Node2D = $EnemyContainer

var enemy_scene: PackedScene

func _ready() -> void:
	enemy_scene = load("res://Enemy.tscn")

	# 플레이어 위치 설정 및 시그널 연결
	player.global_position = Vector2(PLAYER_X, GROUND_Y)
	player.health_changed.connect(ui.update_health)
	player.special_gauge_changed.connect(ui.update_special)
	player.player_died.connect(_on_player_died)

	ui.update_points(points)
	spawn_timer = 1.0   # 첫 스폰까지 1초 대기

func _process(delta: float) -> void:
	if not game_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval

func _spawn_enemy() -> void:
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy_container.add_child(enemy)

	# 좌우 랜덤 스폰
	var side := 1 if randf() > 0.5 else -1
	var spawn_x: float
	if side == 1:
		spawn_x = SCREEN_WIDTH + 40.0
	else:
		spawn_x = -40.0

	enemy.global_position = Vector2(spawn_x, GROUND_Y)
	enemy.init(player, enemy_speed_mult)
	enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node) -> void:
	kills += 1
	points += 10 + kills

	# 난이도 상승
	spawn_interval = max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_BASE - kills * DIFFICULTY_RAMP)
	enemy_speed_mult = 1.0 + kills * SPEED_RAMP

	# 플레이어 필살기 게이지 증가
	if player.has_method("add_special_on_kill"):
		player.add_special_on_kill()

	ui.update_points(points)

func _on_player_died() -> void:
	game_active = false
	# 남아 있는 적 멈추기
	for e in enemy_container.get_children():
		if e.has_method("set"):
			e.set("is_dead", true)
	await get_tree().create_timer(0.8).timeout
	ui.show_gameover(points)
