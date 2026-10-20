extends Node
## (감독 2026-09-10) 보스 재설계 요구 5가지를 10개 장 보스 전부에 대해 확인.
## ① HP 비율 3페이즈(0→1→2), 회복해도 역방향 없음
## ② 페이즈마다 행동 변화(쿨다운·속도·패턴 목록·색)
## ③ 돌진/범위/소환/추적 투사체 중 2가지 이상 - 그리고 실제로 실행됨
## ④ 이동은 네브메시(World.ensure_nav → NavigationAgent2D), 제어는 상태 머신(boss_state)
## ⑤ 페이즈 전환 연출(파티클 PhaseFx + 효과음)

const SPECIALS := ["dash", "aoe", "summon", "volley"]


func _ready() -> void:
	var ok := true
	# ①②③⑤ - 장별 보스를 World 없는 빈 노드에 띄워 페이즈 규칙만 본다.
	for chapter in range(1, 11):
		ok = await _check_boss_phases(chapter) and ok
	# ③④ - main 안에서 패턴 실행·네브메시.
	ok = await _check_patterns_in_main() and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check_boss_phases(chapter: int) -> bool:
	var ok := true
	GameState.reset()
	GameState.chapter = chapter
	var holder := Node.new()
	add_child(holder)
	var boss: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	boss.is_boss = true
	holder.add_child(boss)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var id: String = str(boss.kind["id"])
	var tag := "%d장 %s" % [chapter, id]
	var spec: Dictionary = GameState.BOSS_PHASES.get(id, {})
	ok = _check(tag + " BOSS_PHASES 정의", not spec.is_empty() and boss.kind.get("behavior") == "boss") and ok
	if spec.is_empty():
		holder.queue_free()
		return false
	var phases: Array = spec["phases"]
	ok = _check(tag + " 3페이즈(임계 2개, 내림차순)", phases.size() == 2
		and float(phases[0]["hp"]) > float(phases[1]["hp"])) and ok
	# ③ 특수 패턴 종류 2가지 이상(모든 페이즈 합산)
	var kinds := {}
	for p in [spec["patterns"], phases[0]["patterns"], phases[1]["patterns"]]:
		for name in p:
			if SPECIALS.has(str(name)):
				kinds[str(name)] = true
	ok = _check(tag + " 특수 패턴 2종 이상 (%s)" % [", ".join(kinds.keys())], kinds.size() >= 2) and ok
	ok = _check(tag + " 소환 잡몹 id 존재", boss.KINDS.has(str(spec.get("summon", "")))) and ok

	var base_speed: float = boss.base_speed
	var base_tint: Color = boss.kind.get("tint", Color.WHITE)
	ok = _check(tag + " HP 100%: phase 0", boss.boss_phase == 0
		and boss.get_node("Sprite").modulate.is_equal_approx(base_tint)
		and boss.boss_patterns == spec["patterns"]) and ok
	# phase 1
	boss.health = int(boss.max_health * (float(phases[0]["hp"]) - 0.05))
	await get_tree().physics_frame
	var p1: Dictionary = phases[0]
	ok = _check(tag + " phase 1: 색·쿨다운·속도·패턴 바뀜", boss.boss_phase == 1
		and boss.get_node("Sprite").modulate.is_equal_approx(p1["tint"])
		and is_equal_approx(boss.attack_cooldown_mult, float(p1["cooldown_mult"]))
		and is_equal_approx(boss.speed, base_speed * float(p1["speed_mult"]))
		and boss.boss_patterns == p1["patterns"]) and ok
	ok = _check(tag + " phase 1: 행동 변화 있음(쿨다운<1 또는 속도>1)",
		float(p1["cooldown_mult"]) < 1.0 or float(p1["speed_mult"]) > 1.0) and ok
	ok = _check(tag + " phase 1 전환 파티클(PhaseFx)", holder.get_node_or_null("PhaseFx") != null
		and holder.get_node("PhaseFx") is CPUParticles2D) and ok
	# 회복해도 안 내려감
	boss.health = boss.max_health
	await get_tree().physics_frame
	ok = _check(tag + " 회복해도 phase 1 유지(역방향 없음)", boss.boss_phase == 1
		and boss.get_node("Sprite").modulate.is_equal_approx(p1["tint"])) and ok
	# phase 2
	boss.health = int(boss.max_health * (float(phases[1]["hp"]) - 0.05))
	await get_tree().physics_frame
	var p2: Dictionary = phases[1]
	ok = _check(tag + " phase 2: 색·쿨다운·속도·패턴 바뀜", boss.boss_phase == 2
		and boss.get_node("Sprite").modulate.is_equal_approx(p2["tint"])
		and is_equal_approx(boss.attack_cooldown_mult, float(p2["cooldown_mult"]))
		and is_equal_approx(boss.speed, base_speed * float(p2["speed_mult"]))
		and boss.boss_patterns == p2["patterns"]) and ok
	ok = _check(tag + " phase 2가 phase 1보다 더 공격적", float(p2["cooldown_mult"]) < float(p1["cooldown_mult"])
		and float(p2["speed_mult"]) >= float(p1["speed_mult"])) and ok
	boss.health = boss.max_health
	await get_tree().physics_frame
	ok = _check(tag + " 회복해도 phase 2 유지", boss.boss_phase == 2) and ok
	# 색 구분(인접 단계 거리 ≥ 0.5)
	var tints: Array = [base_tint, p1["tint"], p2["tint"]]
	for i in 2:
		var d: float = Vector3(tints[i].r - tints[i + 1].r, tints[i].g - tints[i + 1].g, tints[i].b - tints[i + 1].b).length()
		ok = _check(tag + " tint %d→%d 거리 ≥ 0.5 (%.2f)" % [i, i + 1, d], d >= 0.5) and ok
	holder.queue_free()
	await get_tree().process_frame
	return ok


func _check_patterns_in_main() -> bool:
	var ok := true
	GameState.reset()
	GameState.chapter = 1
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: CharacterBody2D = main.get_node("Player")
	player.max_health = 9999
	player.health = 9999
	player.invulnerability_time = 0.0
	player.global_position = Vector2(160, 120)

	var boss: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	boss.is_boss = true
	boss.archetype = "boss"
	boss.area_id = GameState.current_map
	boss.position = Vector2(160 + 80, 120)
	boss.max_health = 4000
	boss.health = 4000
	boss.damage = 20
	main.add_child(boss)
	main._connect_enemy(boss)
	boss.attack_time = 99.0
	boss.special_time = 99.0
	await get_tree().physics_frame
	await get_tree().physics_frame

	# ④ 네브메시
	var nav := main.get_node_or_null("World/BossNav")
	ok = _check("④ World 아래 NavigationRegion2D(BossNav) 생성", nav is NavigationRegion2D
		and nav.navigation_polygon != null and nav.navigation_polygon.get_polygon_count() > 0) and ok
	ok = _check("④ 보스 NavigationAgent2D 연결(_nav_ok)", boss._nav_ok and boss.nav_agent != null) and ok
	var before_gap: float = boss.global_position.distance_to(player.global_position)
	for i in 30:
		await get_tree().physics_frame
	ok = _check("④ 감지 후 네브메시 추격으로 접근(80px→%.0fpx)" % boss.global_position.distance_to(player.global_position),
		boss.boss_aggro and boss.global_position.distance_to(player.global_position) < before_gap - 8.0) and ok

	# ④ 상태 머신이 자동으로 특수 패턴을 고른다(1장 수호자: lunge, summon)
	boss.global_position = player.global_position + Vector2(80, 0)
	boss.special_time = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _check("④ 쿨다운 0이면 상태 머신이 패턴 진입(boss_state/swing)", boss.boss_state != "" or boss.swing > 0.0) and ok
	boss._end_boss_pattern()
	boss.swing = 0.0
	boss.special_time = 99.0
	_clear_minions(main)
	await get_tree().process_frame

	# ③ 돌진
	player.health = 9999
	boss.global_position = player.global_position + Vector2(80, 0)
	boss.velocity = Vector2.ZERO
	var off: Vector2 = player.global_position - boss.global_position
	ok = _check("③ 돌진 시작(dash_windup)", boss._begin_pattern("dash", player, off, off.length())
		and boss.boss_state == "dash_windup") and ok
	var moved := false
	var dashed := false
	var start: Vector2 = boss.global_position
	for i in 80:
		await get_tree().physics_frame
		if boss.boss_state == "dash":
			dashed = true
			if boss.charging > 0.0 and boss.global_position.distance_to(start) > 20.0:
				moved = true
	ok = _check("③ 돌진: 예비동작 뒤 charging>0으로 빠르게 전진", dashed and moved) and ok
	ok = _check("③ 돌진: 플레이어 피해", player.health < 9999) and ok
	ok = _check("③ 돌진 끝나면 상태 복귀", boss.boss_state == "" and boss.modulate == Color.WHITE) and ok

	# ③ 범위 공격
	player.health = 9999
	player.invulnerability_time = 0.0
	boss.global_position = player.global_position + Vector2(40, 0)
	off = player.global_position - boss.global_position
	ok = _check("③ 범위: 멀면 시작 안 함", not boss._begin_pattern("aoe", player, off, 200.0)) and ok
	ok = _check("③ 범위 시작(aoe_windup, 예고 원)", boss._begin_pattern("aoe", player, off, off.length())
		and boss.boss_state == "aoe_windup" and boss.aoe_progress > 0.0) and ok
	var stood := true
	for i in 70:
		await get_tree().physics_frame
		if boss.boss_state == "aoe_windup" and boss.velocity != Vector2.ZERO:
			stood = false
	ok = _check("③ 범위: 예고 중 정지", stood) and ok
	ok = _check("③ 범위: 반경 안 플레이어 피해", player.health < 9999) and ok
	ok = _check("③ 범위 끝나면 상태 복귀(예고 원 사라짐)", boss.boss_state == "" and boss.aoe_progress == 0.0) and ok

	# ③ 소환
	player.health = 9999
	off = player.global_position - boss.global_position
	ok = _check("③ 소환 시작", boss._begin_pattern("summon", player, off, off.length()) and boss.boss_state == "summon") and ok
	for i in 40:
		await get_tree().physics_frame
	var minions := _minions(main)
	ok = _check("③ 소환: 잡몹 %d마리(=%d)" % [minions.size(), GameState.BOSS_SUMMON_COUNT],
		minions.size() == GameState.BOSS_SUMMON_COUNT) and ok
	if not minions.is_empty():
		var m: CharacterBody2D = minions[0]
		ok = _check("③ 소환수: 보스 소환 잡몹 종류·enemies 그룹·약한 체력", str(m.kind["id"]) == str(GameState.BOSS_PHASES["guardian"]["summon"])
			and m.is_in_group("enemies") and m.max_health < boss.max_health / 5) and ok
	boss._begin_pattern("summon", player, off, off.length())
	for i in 40:
		await get_tree().physics_frame
	ok = _check("③ 소환 상한 %d" % GameState.BOSS_SUMMON_CAP, _minions(main).size() == GameState.BOSS_SUMMON_CAP
		and not boss._begin_pattern("summon", player, off, off.length())) and ok

	# ③ 추적 투사체
	player.health = 9999
	boss.global_position = player.global_position + Vector2(100, 0)
	off = player.global_position - boss.global_position
	ok = _check("③ 투사체 시작", boss._begin_pattern("volley", player, off, off.length()) and boss.boss_state == "volley") and ok
	for i in 40:
		await get_tree().physics_frame
		if boss.boss_state == "":
			break
	var projs := get_tree().get_nodes_in_group("enemy_projectiles")
	ok = _check("③ 투사체 %d개(=%d), 전부 추적" % [projs.size(), GameState.BOSS_VOLLEY_COUNT],
		projs.size() == GameState.BOSS_VOLLEY_COUNT and projs.all(func(p): return p.homing)) and ok
	if not projs.is_empty():
		# 플레이어를 옆으로 옮기면 투사체 방향이 플레이어 쪽으로 꺾인다.
		player.global_position += Vector2(0, -60)
		var proj: Area2D = projs[0]
		var err_before: float = absf(proj.direction.angle_to(player.global_position - proj.global_position))
		for i in 15:
			await get_tree().physics_frame
		var err_after: float = absf(proj.direction.angle_to(player.global_position - proj.global_position))
		ok = _check("③ 추적: 방향 오차 줄어듦(%.2f→%.2f)" % [err_before, err_after], is_instance_valid(proj) and err_after < err_before) and ok
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		p.queue_free()

	# 보스가 죽으면 소환수도 사라진다
	player.global_position = Vector2(160, 120)
	boss.global_position = Vector2(240, 120)
	ok = _check("보스 처치 전 소환수 %d" % _minions(main).size(), _minions(main).size() > 0) and ok
	boss.take_damage(999999, Vector2.RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _check("보스 처치 시 소환수 전부 제거", _minions(main).is_empty()) and ok
	main.queue_free()
	return ok


func _minions(main: Node) -> Array:
	var out := []
	for e in main.get_children():
		if e.has_meta("summoned_by") and e.is_in_group("enemies"):
			out.append(e)
	return out


func _clear_minions(main: Node) -> void:
	for e in _minions(main):
		e.remove_from_group("enemies")
		e.queue_free()


func _check(label: String, cond: bool) -> bool:
	print(("PASS " if cond else "FAIL ") + label)
	return cond
