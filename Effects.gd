extends Node
## 모든 전투 이펙트를 Line2D / Polygon2D로 코드 생성 (외부 이미지 없음)

# ── 플레이어 공격 슬래시 ─────────────────────────────────────────────────────
func spawn_slash(world_pos: Vector2, dir: int,
		color: Color = Color(1.0, 1.0, 0.55, 1.0)) -> void:
	var node := Node2D.new()
	node.global_position = world_pos
	node.z_index = 10
	_add_to_scene(node)

	var line := Line2D.new()
	line.width = 5.0
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	line.points = _make_slash_points(dir)
	node.add_child(line)

	# 테두리(외곽선) 효과를 위한 얇은 흰색 레이어
	var outline := Line2D.new()
	outline.width = 8.0
	outline.default_color = Color(1.0, 1.0, 1.0, 0.35)
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode   = Line2D.LINE_CAP_ROUND
	outline.points = line.points
	node.add_child(outline)
	node.move_child(outline, 0)   # 아래 레이어

	_fade_and_free(node, 0.25)

func _make_slash_points(dir: int) -> PackedVector2Array:
	# 2차 베지어 곡선으로 자연스러운 호형 슬래시
	var pts := PackedVector2Array()
	var p0 := Vector2(-26.0 * dir, -68.0)
	var p1 := Vector2( 64.0 * dir, -16.0)
	var p2 := Vector2( 46.0 * dir,  54.0)
	for i in range(13):
		var t := float(i) / 12.0
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		pts.append(a.lerp(b, t))
	return pts

# ── 패링 성공 섬광 ──────────────────────────────────────────────────────────
func spawn_parry_flash(world_pos: Vector2) -> void:
	var node := Node2D.new()
	node.global_position = world_pos
	node.z_index = 10
	_add_to_scene(node)

	# 8방향 방사선
	for i in range(8):
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.5, 0.9, 1.0, 1.0)
		var ang := deg_to_rad(i * 45.0)
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		pts.append(Vector2(cos(ang), sin(ang)) * 62.0)
		line.points = pts
		node.add_child(line)

	# 중심 다이아몬드
	var poly := Polygon2D.new()
	poly.color = Color(0.85, 1.0, 1.0, 1.0)
	poly.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(15, 0), Vector2(0, 22), Vector2(-15, 0)
	])
	node.add_child(poly)

	# 외곽 링 (큰 다이아몬드)
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.7, 0.95, 1.0, 0.8)
	ring.closed = true
	ring.points = PackedVector2Array([
		Vector2(0, -32), Vector2(22, 0), Vector2(0, 32), Vector2(-22, 0)
	])
	node.add_child(ring)

	node.scale = Vector2(0.25, 0.25)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.6, 1.6), 0.12)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.30)
	tw.tween_callback(node.queue_free)

# ── 필살기 파동 (좌우 동시 발사) ──────────────────────────────────────────
func spawn_special_wave(world_pos: Vector2) -> void:
	for d in [1, -1]:
		_spawn_wave_unit(world_pos, d)

func _spawn_wave_unit(origin: Vector2, dir: int) -> void:
	var node := Node2D.new()
	node.global_position = origin
	node.z_index = 10
	_add_to_scene(node)

	# 3줄 파동선
	var offsets := [-22.0, 0.0, 22.0]
	for idx in range(offsets.size()):
		var oy: float = offsets[idx]
		var line := Line2D.new()
		line.width = 3.5 - idx * 0.5
		line.default_color = Color(0.85, 0.95, 1.0, 1.0)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode   = Line2D.LINE_CAP_ROUND
		var pts := PackedVector2Array()
		pts.append(Vector2(0.0,        oy))
		pts.append(Vector2(45.0 * dir, oy - 12.0))
		pts.append(Vector2(85.0 * dir, oy +  6.0))
		line.points = pts
		node.add_child(line)

	var target_x := node.position.x + 440.0 * dir
	var tw := node.create_tween()
	tw.tween_property(node, "position:x", target_x, 0.32)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.32)
	tw.tween_callback(node.queue_free)

# ── 적 슬래시 (주황-빨) ────────────────────────────────────────────────────
func spawn_enemy_slash(world_pos: Vector2, dir: int) -> void:
	spawn_slash(world_pos, dir, Color(1.0, 0.36, 0.16, 1.0))

# ── 유틸 ─────────────────────────────────────────────────────────────────────
func _add_to_scene(node: Node2D) -> void:
	get_tree().current_scene.add_child(node)

func _fade_and_free(node: Node2D, duration: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration)
	tw.tween_callback(node.queue_free)
