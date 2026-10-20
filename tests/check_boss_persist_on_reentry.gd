## (감독 2026-09-08, 10장 탐침 2장 성채 110분 보스 미처치) 회귀 검사.
## 장 보스가 살아있는 채로 방을 나갔다 오면 `_spawn_area_enemies()`가 치우고
## `_spawn_boss()`가 풀피로 다시 만들어, 퀘스트모드가 넉백·물약 귀환으로
## 1.5분마다 방을 드나들 때마다 보스 체력이 5400으로 되돌아가 영원히 못
## 잡았다. 중간보스(check_midboss_persist_on_reentry)와 같은 방식으로
## 살아있는 보스는 인스턴스·체력 그대로 보존되고 겹쳐 스폰되지 않는지,
## 죽은 보스는 여전히 재입장 시 새로 스폰되는지(check_boss_respawn 규칙)
## 확인한다.
extends Node

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _bosses_in(map_name: String) -> Array:
	var found: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss and enemy.area_id == map_name:
			found.append(enemy)
	return found


func _ready() -> void:
	seed(1)
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.unlock_map("cave_deep")
	var ok := true

	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var before: Array = _bosses_in("cave_deep")
	ok = _check("① 최초 진입 시 보스 1마리", before.size() == 1) and ok
	if before.is_empty():
		print("RESULT FAIL(보스 없음)")
		get_tree().quit(1)
		return
	var boss: Node = before[0]
	var boss_id := boss.get_instance_id()
	boss.take_damage(int(boss.max_health * 0.3), Vector2.ZERO, false)
	var hp_after_hit: int = boss.health
	ok = _check("데미지 적용됨", hp_after_hit < boss.max_health) and ok

	# 서쪽 옆 지역으로 나갔다가(퀘스트모드 넉백 이탈과 같은 경로) 마을까지
	# 거쳐 돌아온다 - 물약 귀환 경로도 같이 덮는다.
	main._change_map("dungeon", false)
	await get_tree().process_frame
	ok = _check("② 옆 지역에는 보스가 없음", _bosses_in("cave_deep").is_empty()
		and main.boss_spawned == false) and ok
	main._change_map("village", false)
	await get_tree().process_frame
	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var after: Array = _bosses_in("cave_deep")
	ok = _check("③ 재입장 후 보스 1마리(겹침 스폰 없음)", after.size() == 1) and ok
	var survivor: Node = null
	for e in after:
		if e.get_instance_id() == boss_id:
			survivor = e
	ok = _check("④ 같은 인스턴스가 보존됨", survivor != null) and ok
	if survivor != null:
		ok = _check("⑤ 체력이 리셋되지 않음(%d)" % hp_after_hit, survivor.health == hp_after_hit) and ok
		ok = _check("⑥ 보스가 보이고 움직임", survivor.visible
			and survivor.process_mode == Node.PROCESS_MODE_INHERIT) and ok
		ok = _check("⑦ boss_spawned 플래그 복원", main.boss_spawned) and ok
		# 죽이면 재입장 시 새 풀피 보스(check_boss_respawn 규칙 유지).
		survivor.take_damage(survivor.health + 99999, Vector2.ZERO, false)
		await get_tree().process_frame
		await get_tree().process_frame
	main._change_map("village", false)
	await get_tree().process_frame
	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var revived: Array = _bosses_in("cave_deep")
	ok = _check("⑧ 처치 후 재입장 시 새 보스 1마리", revived.size() == 1) and ok
	if not revived.is_empty():
		ok = _check("⑨ 새 보스는 풀피", revived[0].health == revived[0].max_health
			and revived[0].get_instance_id() != boss_id) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
