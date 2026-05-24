extends CharacterBody2D

signal enemy_died(enemy)

const BASE_SPEED      := 80.0
const ATTACK_RANGE    := 62.0
const ATTACK_DAMAGE   := 15
const ATTACK_DURATION := 0.25   # 공격 모션 지속 (이 시간 동안 멈춤)
const ATTACK_COOLDOWN := 1.05   # 공격 후 이동 재개까지 대기
const MAX_HEALTH      := 50
const GRAVITY         := 900.0

enum State { MOVING, ATTACKING, COOLDOWN }

var health:      int   = MAX_HEALTH
var speed:       float = BASE_SPEED
var state:       State = State.MOVING
var state_timer: float = 0.0
var is_dead:     bool  = false
var player:      Node2D = null
var facing_dir:  int   = 1      # 1 = 오른쪽, -1 = 왼쪽

@onready var sprite:   ColorRect = $Sprite
@onready var hp_fill:  ColorRect = $HPBar/HPFill

func _ready() -> void:
	add_to_group("enemies")

func init(p_player: Node2D, p_speed_multiplier: float) -> void:
	player = p_player
	speed  = BASE_SPEED * p_speed_multiplier
	# 스폰 위치로 플레이어 방향 초기 설정
	if player != null:
		facing_dir = 1 if player.global_position.x > global_position.x else -1

# ── 물리 루프 ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return

	# 중력 (낙하) 적용
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.MOVING:    _state_moving()
		State.ATTACKING: _state_attacking(delta)
		State.COOLDOWN:  _state_cooldown(delta)

	move_and_slide()

# ── 상태: 이동 ───────────────────────────────────────────────────────────────
func _state_moving() -> void:
	# 매 프레임 플레이어 방향 재계산 (X축 이동만)
	var dx   := player.global_position.x - global_position.x
	var dist := global_position.distance_to(player.global_position)

	if dist <= ATTACK_RANGE:
		# 공격 범위 진입 → 공격 상태로 전환
		velocity.x = 0.0
		_enter_attack()
	else:
		facing_dir = 1 if dx > 0.0 else -1
		velocity.x = facing_dir * speed

# ── 상태: 공격 ───────────────────────────────────────────────────────────────
func _enter_attack() -> void:
	state       = State.ATTACKING
	state_timer = ATTACK_DURATION
	_do_attack()

func _state_attacking(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta
	if state_timer <= 0.0:
		state       = State.COOLDOWN
		state_timer = ATTACK_COOLDOWN

func _do_attack() -> void:
	if is_dead:
		return
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE, global_position)

	# 슬래시 이펙트 (플레이어 방향)
	var eff_dir := 1 if (player.global_position.x - global_position.x) >= 0.0 else -1
	Effects.spawn_enemy_slash(
		global_position + Vector2(eff_dir * 28.0, -36.0),
		eff_dir
	)

	# 공격 색 플래시
	sprite.color = Color.RED
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and not is_dead:
		sprite.color = Color.ORANGE_RED

# ── 상태: 쿨타임 ─────────────────────────────────────────────────────────────
func _state_cooldown(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.MOVING

# ── 피격 ─────────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	health  = max(health, 0)
	_update_hp_bar()

	sprite.color = Color.WHITE
	await get_tree().create_timer(0.10).timeout
	if is_instance_valid(self) and not is_dead:
		sprite.color = Color.ORANGE_RED

	if health <= 0:
		_die()

func _update_hp_bar() -> void:
	hp_fill.size.x = 40.0 * (float(health) / float(MAX_HEALTH))

# ── 사망 ─────────────────────────────────────────────────────────────────────
func _die() -> void:
	is_dead    = true
	sprite.color = Color.GRAY
	emit_signal("enemy_died", self)
	await get_tree().create_timer(0.30).timeout
	if is_instance_valid(self):
		queue_free()
