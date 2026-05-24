extends CharacterBody2D

signal enemy_died(enemy)

const BASE_SPEED := 80.0
const ATTACK_RANGE := 55.0
const ATTACK_DAMAGE := 15
const ATTACK_INTERVAL := 1.5
const MAX_HEALTH := 50

var health: int = MAX_HEALTH
var speed: float = BASE_SPEED
var attack_timer: float = 0.0
var is_dead := false
var player: Node2D = null

@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill

func _ready() -> void:
	add_to_group("enemies")
	attack_timer = randf_range(0.5, ATTACK_INTERVAL)

func init(p_player: Node2D, p_speed_multiplier: float) -> void:
	player = p_player
	speed = BASE_SPEED * p_speed_multiplier

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return

	var dist := global_position.distance_to(player.global_position)

	if dist > ATTACK_RANGE:
		# 플레이어 방향으로 이동
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = ATTACK_INTERVAL
			_attack_player()

func _attack_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE, global_position)
	# 공격 이펙트
	sprite.color = Color.RED
	await get_tree().create_timer(0.15).timeout
	if not is_dead:
		sprite.color = Color.ORANGE_RED

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	health = max(health, 0)
	_update_hp_bar()

	sprite.color = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.color = Color.ORANGE_RED

	if health <= 0:
		_die()

func _update_hp_bar() -> void:
	var ratio := float(health) / float(MAX_HEALTH)
	hp_fill.size.x = 40.0 * ratio

func _die() -> void:
	is_dead = true
	sprite.color = Color.GRAY
	emit_signal("enemy_died", self)
	await get_tree().create_timer(0.3).timeout
	queue_free()
