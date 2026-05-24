extends CharacterBody2D

signal health_changed(current, maximum)
signal special_gauge_changed(current, maximum)
signal player_died

const MAX_HEALTH := 100
const MAX_SPECIAL := 100
const MOVE_SPEED := 200.0
const ATTACK_RANGE := 120.0
const ATTACK_DAMAGE := 25
const SPECIAL_DAMAGE := 40
const PARRY_WINDOW := 0.25        # 패링 판정 시간(초)
const PARRY_GAIN := 30            # 패링 성공 시 게이지 증가량
const ATTACK_COOLDOWN := 0.4
const SPECIAL_PER_KILL := 8       # 적 처치 시 게이지 증가

var health: int = MAX_HEALTH
var special_gauge: int = 0
var is_attacking := false
var is_guarding := false
var is_parrying := false
var is_dead := false
var attack_timer := 0.0
var parry_timer := 0.0

@onready var sprite: ColorRect = $Sprite
@onready var attack_area: Area2D = $AttackArea
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	emit_signal("health_changed", health, MAX_HEALTH)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_handle_timers(delta)
	_handle_input()
	move_and_slide()

func _handle_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			_update_sprite_color()

	if parry_timer > 0.0:
		parry_timer -= delta
		if parry_timer <= 0.0:
			is_parrying = false
			if not is_guarding:
				_update_sprite_color()

func _handle_input() -> void:
	# 이동
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * MOVE_SPEED

	# 공격
	if Input.is_action_just_pressed("attack") and not is_attacking and attack_timer <= 0.0:
		_do_attack()

	# 방어/패링
	if Input.is_action_just_pressed("guard"):
		_start_guard()
	if Input.is_action_just_released("guard"):
		_end_guard()

	# 필살기
	if Input.is_action_just_pressed("special") and special_gauge >= MAX_SPECIAL:
		_do_special()

func _do_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	_update_sprite_color()

	# AttackArea 안의 적을 찾아 가장 가까운 적 공격
	var bodies := attack_area.get_overlapping_bodies()
	var closest: Node2D = null
	var closest_dist := INF
	for b in bodies:
		if b.is_in_group("enemies"):
			var d := global_position.distance_to(b.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = b
	if closest and closest.has_method("take_damage"):
		closest.take_damage(ATTACK_DAMAGE)

func _start_guard() -> void:
	is_guarding = true
	is_parrying = true
	parry_timer = PARRY_WINDOW
	_update_sprite_color()

func _end_guard() -> void:
	is_guarding = false
	is_parrying = false
	parry_timer = 0.0
	_update_sprite_color()

func _do_special() -> void:
	special_gauge = 0
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)
	_update_sprite_color()

	# 화면 양쪽 모든 적에게 데미지
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.has_method("take_damage"):
			e.take_damage(SPECIAL_DAMAGE)

	# 필살기 이펙트(간단히 색 변경 후 복원)
	sprite.color = Color.YELLOW
	await get_tree().create_timer(0.3).timeout
	_update_sprite_color()

func take_damage(amount: int, attacker_pos: Vector2) -> void:
	if is_dead:
		return
	if is_parrying:
		_on_parry_success()
		return
	if is_guarding:
		amount = int(amount * 0.3)

	health -= amount
	health = max(health, 0)
	emit_signal("health_changed", health, MAX_HEALTH)

	# 피격 시 빨간 깜빡임
	sprite.color = Color.RED
	await get_tree().create_timer(0.15).timeout
	_update_sprite_color()

	if health <= 0:
		_die()

func _on_parry_success() -> void:
	special_gauge = min(special_gauge + PARRY_GAIN, MAX_SPECIAL)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)
	# 패링 성공 이펙트
	sprite.color = Color.CYAN
	await get_tree().create_timer(0.2).timeout
	_update_sprite_color()

func add_special_on_kill() -> void:
	special_gauge = min(special_gauge + SPECIAL_PER_KILL, MAX_SPECIAL)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

func _die() -> void:
	is_dead = true
	sprite.color = Color.DARK_RED
	emit_signal("player_died")

func _update_sprite_color() -> void:
	if is_dead:
		sprite.color = Color.DARK_RED
	elif is_parrying:
		sprite.color = Color.CYAN
	elif is_guarding:
		sprite.color = Color.BLUE
	elif is_attacking:
		sprite.color = Color.ORANGE
	else:
		sprite.color = Color.GREEN
