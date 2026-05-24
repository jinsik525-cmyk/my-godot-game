extends CharacterBody2D

signal health_changed(current, maximum)
signal special_gauge_changed(current, maximum)
signal player_died

# ── 게임플레이 상수 ───────────────────────────────────────────────────────────
const MAX_HEALTH       := 100
const MAX_SPECIAL      := 100
const MOVE_SPEED       := 200.0
const ATTACK_DAMAGE    := 25
const SPECIAL_DAMAGE   := 40
const PARRY_WINDOW     := 0.25
const PARRY_GAIN       := 30
const ATTACK_COOLDOWN  := 0.40
const SPECIAL_PER_KILL := 8
const GRAVITY          := 900.0
const JUMP_VELOCITY    := -480.0
const KB_FORCE_RECV    := 260.0   # 피격 시 받는 넉백 힘
const KB_DURATION      := 0.20    # 넉백 지속 시간(초)

# ── 색상 ─────────────────────────────────────────────────────────────────────
const C_BODY   := Color(0.22, 0.44, 0.90, 1.0)
const C_DARK   := Color(0.14, 0.28, 0.72, 1.0)
const C_HEAD   := Color(0.92, 0.80, 0.66, 1.0)
const C_SHIELD := Color(0.28, 0.55, 1.00, 0.72)

# ── 게임플레이 상태 ───────────────────────────────────────────────────────────
var health: int     = MAX_HEALTH
var special_gauge   := 0
var is_attacking    := false
var is_guarding     := false
var is_parrying     := false
var is_dead         := false
var is_knockback    := false
var attack_timer    := 0.0
var parry_timer     := 0.0
var kb_timer        := 0.0
var facing_dir: int = 1         # 1 = 오른쪽, -1 = 왼쪽

# ── 애니메이션 ───────────────────────────────────────────────────────────────
var walk_phase := 0.0

# ── 비주얼 노드 (코드로 생성) ──────────────────────────────────────────────────
var _head:   Polygon2D
var _torso:  Polygon2D
var _arm_l:  Line2D
var _arm_r:  Line2D
var _leg_l:  Line2D
var _leg_r:  Line2D
var _shield: Polygon2D

@onready var body_node:   Node2D = $Body
@onready var attack_area: Area2D = $AttackArea
@onready var hitbox:      Area2D = $Hitbox

# ── 초기화 ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_character()
	emit_signal("health_changed",        health,        MAX_HEALTH)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

func _build_character() -> void:
	# 뒤 레이어: 다리 → 팔 순서
	_leg_l = _make_limb(5.0, C_DARK)
	_leg_r = _make_limb(5.0, C_DARK)
	_arm_l = _make_limb(4.0, C_DARK)
	_arm_r = _make_limb(4.0, C_DARK)

	# 몸통 (사다리꼴)
	_torso = Polygon2D.new()
	_torso.color   = C_BODY
	_torso.polygon = PackedVector2Array([
		Vector2(-11, -75), Vector2(11, -75),
		Vector2( 8,  -40), Vector2(-8, -40)
	])
	body_node.add_child(_torso)

	# 머리 (원형)
	_head = Polygon2D.new()
	_head.color   = C_HEAD
	_head.polygon = _circle_poly(0.0, -88.0, 13.0, 12)
	body_node.add_child(_head)

	# 방패 (기본 숨김)
	_shield = Polygon2D.new()
	_shield.color   = C_SHIELD
	_shield.polygon = PackedVector2Array([
		Vector2(-2, -28), Vector2(14, -20),
		Vector2(18,  -6), Vector2(18,  10),
		Vector2( 0,  26), Vector2(-18, 10),
		Vector2(-18, -6), Vector2(-14, -20)
	])
	_shield.visible = false
	body_node.add_child(_shield)

# ── 물리 루프 ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_tick_timers(delta)
	_handle_input()
	move_and_slide()
	_update_visuals(delta)

# ── 타이머 ───────────────────────────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false

	if parry_timer > 0.0:
		parry_timer -= delta
		if parry_timer <= 0.0:
			is_parrying = false

	if is_knockback:
		kb_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
		if kb_timer <= 0.0:
			is_knockback = false

# ── 입력 ─────────────────────────────────────────────────────────────────────
func _handle_input() -> void:
	# 수평 이동 (넉백 중에는 AI에 맡김)
	if not is_knockback:
		var dir := Input.get_axis("move_left", "move_right")
		velocity.x = dir * MOVE_SPEED
		if dir != 0.0:
			facing_dir = 1 if dir > 0.0 else -1

	# 점프
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 공격 (넉백/이미 공격 중이면 불가)
	if Input.is_action_just_pressed("attack") \
			and not is_attacking and attack_timer <= 0.0 \
			and not is_knockback:
		_do_attack()

	# 방어/패링
	if Input.is_action_just_pressed("guard"):
		is_guarding = true
		is_parrying = true
		parry_timer = PARRY_WINDOW
	if Input.is_action_just_released("guard"):
		is_guarding = false
		is_parrying = false
		parry_timer = 0.0

	# 필살기
	if Input.is_action_just_pressed("special") and special_gauge >= MAX_SPECIAL:
		_do_special()

# ── 공격 ─────────────────────────────────────────────────────────────────────
func _do_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN

	Effects.spawn_slash(
		global_position + Vector2(facing_dir * 22.0, -58.0), facing_dir)

	# 가장 가까운 적 타격
	var closest: Node2D = null
	var closest_dist    := INF
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("enemies"):
			var d := global_position.distance_to(b.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = b
	if closest and closest.has_method("take_damage"):
		var kb_dir := 1 if closest.global_position.x > global_position.x else -1
		closest.take_damage(ATTACK_DAMAGE, 290.0, kb_dir)

# ── 필살기 ───────────────────────────────────────────────────────────────────
func _do_special() -> void:
	special_gauge = 0
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

	Effects.spawn_special_wave(global_position + Vector2(0.0, -58.0))

	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var kb_dir := 1 if e.global_position.x > global_position.x else -1
			e.take_damage(SPECIAL_DAMAGE, 450.0, kb_dir)

	body_node.modulate = Color(1.3, 1.3, 0.5, 1.0)
	await get_tree().create_timer(0.30).timeout
	if not is_dead:
		body_node.modulate = Color.WHITE

# ── 피격 ─────────────────────────────────────────────────────────────────────
func take_damage(amount: int, attacker_pos: Vector2) -> void:
	if is_dead:
		return
	if is_parrying:
		_on_parry_success(attacker_pos)
		return
	if is_guarding:
		amount = int(amount * 0.3)

	health -= amount
	health  = max(health, 0)
	emit_signal("health_changed", health, MAX_HEALTH)

	# 넉백
	var kb_dir := 1 if global_position.x > attacker_pos.x else -1
	_apply_knockback(kb_dir, KB_FORCE_RECV)

	body_node.modulate = Color(1.6, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.15).timeout
	if not is_dead:
		body_node.modulate = Color.WHITE

	if health <= 0:
		_die()

func _apply_knockback(dir: int, force: float) -> void:
	velocity.x   = dir * force
	velocity.y   = -130.0
	is_knockback = true
	kb_timer     = KB_DURATION

# ── 패링 성공 ─────────────────────────────────────────────────────────────────
func _on_parry_success(attacker_pos: Vector2) -> void:
	special_gauge = min(special_gauge + PARRY_GAIN, MAX_SPECIAL)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

	Effects.spawn_parry_flash(global_position + Vector2(0.0, -58.0))

	# 공격자(가까운 적) 강한 넉백
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(attacker_pos) < 95.0 \
				and e.has_method("apply_knockback"):
			var kb_dir := 1 if e.global_position.x > global_position.x else -1
			e.apply_knockback(520.0, kb_dir)

	# 방패 번쩍임
	_shield.color      = Color(1.0, 1.0, 0.4, 1.0)
	body_node.modulate = Color(0.75, 1.0, 1.3, 1.0)
	await get_tree().create_timer(0.22).timeout
	if not is_dead:
		_shield.color      = C_SHIELD
		body_node.modulate = Color.WHITE

func add_special_on_kill() -> void:
	special_gauge = min(special_gauge + SPECIAL_PER_KILL, MAX_SPECIAL)
	emit_signal("special_gauge_changed", special_gauge, MAX_SPECIAL)

func _die() -> void:
	is_dead = true
	body_node.modulate = Color(0.5, 0.5, 0.5, 0.65)
	emit_signal("player_died")

# ── 비주얼 업데이트 ───────────────────────────────────────────────────────────
func _update_visuals(delta: float) -> void:
	# 걷기 위상 (이동 중엔 증가, 정지 중엔 0으로 감소)
	if abs(velocity.x) > 15.0 and is_on_floor():
		walk_phase += delta * 8.5
	else:
		walk_phase = move_toward(walk_phase, 0.0, delta * 16.0)
	var sw := sin(walk_phase) * 0.48

	# 팔 업데이트
	const ARM_ROOT := Vector2(0.0, -68.0)
	const ARM_LEN  := 27.0
	if is_attacking:
		# 공격 방향 팔을 앞으로, 반대 팔을 뒤로
		if facing_dir > 0:
			_set_limb(_arm_r, ARM_ROOT,  deg_to_rad(82.0), ARM_LEN)
			_set_limb(_arm_l, ARM_ROOT, -deg_to_rad(30.0), ARM_LEN)
		else:
			_set_limb(_arm_r, ARM_ROOT,  deg_to_rad(30.0), ARM_LEN)
			_set_limb(_arm_l, ARM_ROOT, -deg_to_rad(82.0), ARM_LEN)
	else:
		_set_limb(_arm_r, ARM_ROOT,  0.55 + sw, ARM_LEN)
		_set_limb(_arm_l, ARM_ROOT, -0.55 - sw, ARM_LEN)

	# 다리 업데이트
	const LEG_ROOT := Vector2(0.0, -40.0)
	const LEG_LEN  := 40.0
	if not is_on_floor():
		# 점프 시 다리 벌림
		_set_limb(_leg_r, LEG_ROOT,  0.40, LEG_LEN)
		_set_limb(_leg_l, LEG_ROOT, -0.40, LEG_LEN)
	else:
		_set_limb(_leg_r, LEG_ROOT,  0.24 - sw, LEG_LEN)
		_set_limb(_leg_l, LEG_ROOT, -0.24 + sw, LEG_LEN)

	# 방패
	_shield.visible = is_guarding and not is_dead
	if is_guarding:
		_shield.position = Vector2(facing_dir * 24.0, -54.0)
		_shield.scale.x  = float(facing_dir)
		_shield.color    = (Color(1.0, 1.0, 0.5, 0.95)
				if is_parrying else C_SHIELD)

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
	# angle=0 → 아래, angle=π/2 → 오른쪽, angle=-π/2 → 왼쪽
	line.set_point_position(0, root)
	line.set_point_position(1, root + Vector2(sin(angle), cos(angle)) * length)
