extends CharacterBody2D

signal enemy_died(enemy)

# ── 상수 ─────────────────────────────────────────────────────────────────────
const BASE_SPEED       := 80.0
const ATTACK_RANGE     := 62.0
const ATTACK_DAMAGE    := 15
const ATTACK_DURATION  := 0.25
const ATTACK_COOLDOWN  := 1.05
const MAX_HEALTH       := 50
const GRAVITY          := 900.0
const KB_FRICTION      := 950.0   # 넉백 감속도

# 색상
const C_BODY := Color(0.82, 0.18, 0.18, 1.0)
const C_DARK := Color(0.58, 0.10, 0.10, 1.0)
const C_HEAD := Color(0.92, 0.68, 0.60, 1.0)

enum State { MOVING, ATTACKING, COOLDOWN }

# ── 상태 ─────────────────────────────────────────────────────────────────────
var health:       int   = MAX_HEALTH
var speed:        float = BASE_SPEED
var state:        State = State.MOVING
var state_timer:  float = 0.0
var is_dead:      bool  = false
var is_knockback: bool  = false
var kb_timer:     float = 0.0
var player:       Node2D = null
var facing_dir:   int   = 1
var walk_phase:   float = 0.0

# ── 비주얼 노드 ──────────────────────────────────────────────────────────────
var _head:  Polygon2D
var _torso: Polygon2D
var _arm_l: Line2D
var _arm_r: Line2D
var _leg_l: Line2D
var _leg_r: Line2D

@onready var body_node: Node2D    = $Body
@onready var hp_fill:   ColorRect = $HPBar/HPFill

# ── 초기화 ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	_build_character()

func _build_character() -> void:
	_leg_l = _make_limb(4.5, C_DARK)
	_leg_r = _make_limb(4.5, C_DARK)
	_arm_l = _make_limb(3.5, C_DARK)
	_arm_r = _make_limb(3.5, C_DARK)

	_torso = Polygon2D.new()
	_torso.color   = C_BODY
	_torso.polygon = PackedVector2Array([
		Vector2(-9, -66), Vector2(9, -66),
		Vector2(7,  -36), Vector2(-7, -36)
	])
	body_node.add_child(_torso)

	_head = Polygon2D.new()
	_head.color   = C_HEAD
	_head.polygon = _circle_poly(0.0, -78.0, 12.0, 12)
	body_node.add_child(_head)

func init(p_player: Node2D, p_speed_multiplier: float) -> void:
	player = p_player
	speed  = BASE_SPEED * p_speed_multiplier
	if player != null:
		facing_dir = 1 if player.global_position.x > global_position.x else -1

# ── 물리 루프 ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return

	# 중력 적용
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 넉백 중에는 AI 대신 감속만 처리
	if is_knockback:
		kb_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, KB_FRICTION * delta)
		if kb_timer <= 0.0:
			is_knockback = false
	else:
		match state:
			State.MOVING:    _state_moving()
			State.ATTACKING: _state_attacking(delta)
			State.COOLDOWN:  _state_cooldown(delta)

	move_and_slide()
	_update_visuals(delta)

# ── 상태 머신 ────────────────────────────────────────────────────────────────
func _state_moving() -> void:
	var dx   := player.global_position.x - global_position.x
	var dist := global_position.distance_to(player.global_position)

	if dist <= ATTACK_RANGE:
		velocity.x = 0.0
		_enter_attack()
	else:
		facing_dir = 1 if dx > 0.0 else -1
		velocity.x = facing_dir * speed

func _enter_attack() -> void:
	state       = State.ATTACKING
	state_timer = ATTACK_DURATION
	_do_attack()

func _state_attacking(delta: float) -> void:
	velocity.x   = 0.0
	state_timer -= delta
	if state_timer <= 0.0:
		state       = State.COOLDOWN
		state_timer = ATTACK_COOLDOWN

func _state_cooldown(delta: float) -> void:
	velocity.x   = 0.0
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.MOVING

# ── 공격 ─────────────────────────────────────────────────────────────────────
func _do_attack() -> void:
	if is_dead:
		return
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE, global_position)

	var eff_dir := 1 if (player.global_position.x - global_position.x) >= 0.0 else -1
	Effects.spawn_enemy_slash(
		global_position + Vector2(eff_dir * 26.0, -42.0), eff_dir)

	body_node.modulate = Color(1.6, 0.4, 0.4, 1.0)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and not is_dead:
		body_node.modulate = Color.WHITE

# ── 피격 / 넉백 ──────────────────────────────────────────────────────────────
func take_damage(amount: int, knockback_force: float = 0.0, knockback_dir: int = 0) -> void:
	if is_dead:
		return
	health -= amount
	health  = max(health, 0)
	_update_hp_bar()

	if knockback_force > 0.0:
		apply_knockback(knockback_force, knockback_dir)

	body_node.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.10).timeout
	if is_instance_valid(self) and not is_dead:
		body_node.modulate = Color.WHITE

	if health <= 0:
		_die()

func apply_knockback(force: float, dir: int) -> void:
	velocity.x   = dir * force
	velocity.y   = -100.0
	is_knockback = true
	kb_timer     = 0.30
	# 넉백 동안 쿨다운 상태로 전환 (공격 불가)
	state        = State.COOLDOWN
	state_timer  = 0.30

func _update_hp_bar() -> void:
	hp_fill.size.x = 40.0 * (float(health) / float(MAX_HEALTH))

# ── 사망 ─────────────────────────────────────────────────────────────────────
func _die() -> void:
	is_dead = true
	body_node.modulate = Color(0.5, 0.5, 0.5, 0.65)
	emit_signal("enemy_died", self)
	await get_tree().create_timer(0.30).timeout
	if is_instance_valid(self):
		queue_free()

# ── 비주얼 업데이트 ───────────────────────────────────────────────────────────
func _update_visuals(delta: float) -> void:
	# 걷기 위상
	if state == State.MOVING and abs(velocity.x) > 10.0 and is_on_floor():
		walk_phase += delta * 7.5
	else:
		walk_phase = move_toward(walk_phase, 0.0, delta * 14.0)
	var sw := sin(walk_phase) * 0.44

	# 플레이어 방향 갱신 (넉백 중 제외)
	if player != null and not is_knockback:
		var dx := player.global_position.x - global_position.x
		if abs(dx) > 5.0:
			facing_dir = 1 if dx > 0.0 else -1

	# 팔
	const ARM_ROOT := Vector2(0.0, -60.0)
	const ARM_LEN  := 24.0
	if state == State.ATTACKING:
		var lead := deg_to_rad(78.0)
		if facing_dir > 0:
			_set_limb(_arm_r, ARM_ROOT,  lead,  ARM_LEN)
			_set_limb(_arm_l, ARM_ROOT, -0.28,  ARM_LEN)
		else:
			_set_limb(_arm_r, ARM_ROOT,  0.28,  ARM_LEN)
			_set_limb(_arm_l, ARM_ROOT, -lead,  ARM_LEN)
	else:
		_set_limb(_arm_r, ARM_ROOT,  0.50 + sw, ARM_LEN)
		_set_limb(_arm_l, ARM_ROOT, -0.50 - sw, ARM_LEN)

	# 다리
	const LEG_ROOT := Vector2(0.0, -36.0)
	const LEG_LEN  := 36.0
	if not is_on_floor():
		_set_limb(_leg_r, LEG_ROOT,  0.35, LEG_LEN)
		_set_limb(_leg_l, LEG_ROOT, -0.35, LEG_LEN)
	else:
		_set_limb(_leg_r, LEG_ROOT,  0.22 - sw, LEG_LEN)
		_set_limb(_leg_l, LEG_ROOT, -0.22 + sw, LEG_LEN)

# ── 유틸 ─────────────────────────────────────────────────────────────────────
func _circle_poly(cx: float, cy: float, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / float(n)
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts

func _make_limb(w: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width          = w
	line.default_color  = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	line.points         = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	body_node.add_child(line)
	return line

func _set_limb(line: Line2D, root: Vector2, angle: float, length: float) -> void:
	line.set_point_position(0, root)
	line.set_point_position(1, root + Vector2(sin(angle), cos(angle)) * length)
