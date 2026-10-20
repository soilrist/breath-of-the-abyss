## AUTOHUNT_DESIGN.md §10.7(2026-09-07 5시드 프로브) 결함 회귀 검사.
## `_spawn_area_enemies()`가 `is_boss`만 재입장 시 보존하고 `is_midboss`는
## 살아있어도 매번 치우고 풀피로 다시 깠다 - 후퇴 후 복귀하면 중간보스
## 체력이 리셋돼 hill_ridge 5시드 전부 영구 정체(cell(3,7)/(4,7))를 냈다.
## 보스와 같은 방식으로 살아있는 중간보스를 보존하는지, 죽은 중간보스
## 자리는 여전히 새로 스폰되는지 확인한다.
extends Node

const MainScript := preload("res://scripts/main.gd")

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _midbosses_in(main: Node, map_name: String) -> Array:
	var found: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.area_id == map_name and enemy.is_midboss:
			found.append(enemy)
	return found


func _ready() -> void:
	seed(1)
	GameState.reset()
	var area: String = ""
	for candidate in MainScript.MIDBOSS_AREAS:
		area = candidate
		break
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.unlock_map(area)

	var ok := true

	# ① 살아있는 중간보스는 재입장해도 체력·인스턴스가 그대로 보존된다.
	main._change_map(area, false)
	await get_tree().process_frame
	var before: Array = _midbosses_in(main, area)
	var initial_count: int = before.size()
	ok = _check("① 최초 진입 시 중간보스 최소 1마리 존재", initial_count >= 1) and ok
	if before.is_empty():
		print("RESULT FAIL(중간보스 없음, 지역=", area, ")")
		get_tree().quit(1)
		return
	var mid: Node = before[0]
	var mid_id := mid.get_instance_id()
	var full_hp: int = mid.max_health
	mid.take_damage(int(full_hp * 0.3), Vector2.ZERO, false)
	var hp_after_hit: int = mid.health
	ok = _check("데미지 적용됨(hp_after_hit < full_hp)", hp_after_hit < full_hp) and ok

	main._change_map("village", false)
	await get_tree().process_frame
	main._change_map(area, false)
	await get_tree().process_frame

	var after: Array = _midbosses_in(main, area)
	for e in after:
		print("DEBUG after id=", e.get_instance_id(), " health=", e.health, " max=", e.max_health)
	print("DEBUG mid_id was ", mid_id)
	ok = _check("② 재입장 후에도 중간보스 수가 그대로(%d마리, 중복 스폰 없음)" % initial_count,
		after.size() == initial_count) and ok
	var survivor: Node = null
	for e in after:
		if e.get_instance_id() == mid_id:
			survivor = e
	ok = _check("③ 데미지 준 인스턴스가 그대로 보존됨(id 동일)", survivor != null) and ok
	if survivor != null:
		ok = _check("④ 체력이 리셋되지 않고 유지됨", survivor.health == hp_after_hit) and ok

	# ⑤ 중간보스가 죽으면(자리 비움) 재입장 시 새로 스폰된다(회귀 방지 - 죽은
	# 자리까지 영영 안 채우면 그것도 결함).
	if survivor != null:
		survivor.take_damage(survivor.health + 9999, Vector2.ZERO, false)
		await get_tree().process_frame
		await get_tree().process_frame
	main._change_map("village", false)
	await get_tree().process_frame
	main._change_map(area, false)
	await get_tree().process_frame
	var revived: Array = _midbosses_in(main, area)
	ok = _check("⑤ 처치된 자리도 재입장 시 다시 채워져 마릿수가 원래대로 돌아옴",
		revived.size() == initial_count) and ok
	var has_full_hp := false
	for e in revived:
		if e.health == e.max_health:
			has_full_hp = true
	ok = _check("⑥ 새로 스폰된 중간보스는 풀피", has_full_hp) and ok

	# ⑦ 중간보스를 죽인 '같은 프레임'에 지역을 떠나면(queue_free 대기 중, 아직
	# 그룹에 있음) 시체가 보관 목록에 들어가면 안 된다. 들어가면 재입장 때
	# 'previously freed' 접근 에러(8장 프로브 hollow_barracks↔grey_reservoir).
	var victim: Node = revived[0]
	victim.take_damage(victim.health + 9999, Vector2.ZERO, false)
	main._change_map("village", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var stash: Array = main._preserved_midbosses.get(area, [])
	var stash_valid := true
	for e in stash:
		if not is_instance_valid(e):
			stash_valid = false
	ok = _check("⑦ 같은 프레임에 죽은 중간보스는 보관 목록에 남지 않음", stash_valid) and ok
	main._change_map(area, false)
	await get_tree().process_frame
	var again: Array = _midbosses_in(main, area)
	ok = _check("⑧ 재입장 시 에러 없이 마릿수 복원", again.size() == initial_count) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
