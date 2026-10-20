extends Node
## 투사체 스킬(shuriken·poison_dart, projectile: true)이 몸에서만 번쩍이고
## 끝나지 않고, 실제로 날아가 맞은 적에게 박히는지 검증한다
## (INBOX 2026-10-20 17:45 "스킬이 적에게 날아가 맞아야 한다" ① 단계 +
## 2026-10-20 21:55 "큰 별 그림 빼고 박혀서 도는 걸로" 결함 수정).
## ① 시전 FX는 작게(size_up <= 0.4)만 남아야 몸에서 번쩍이는 것으로 안 보인다.
## ③ arrow가 적에게 닿으면(body_entered) 큰 SkillFx(64px 별) 대신 arrow
## 자신이 적 global_position 16px 안에 박혀서 남는다(embed=true).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	GameState.change_job("rogue")
	player.max_mana = 999
	player.mana = 999
	player.health = player.max_health
	player.facing = Vector2.RIGHT
	player.global_position = Vector2(100, 100)

	var skills: Array = GameState.active_skills()
	var shuriken_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "shuriken":
			shuriken_idx = i
	ok = _check("shuriken 슬롯 존재", shuriken_idx >= 0) and ok

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(60, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = enemy.health
	player.cast_skill(shuriken_idx)

	var cast_fx := _find_last_skill_fx(main)
	ok = _check("시전 FX가 뜸(몸에서 짧은 빛)", cast_fx != null) and ok
	if cast_fx != null:
		ok = _check("시전 FX가 큰 몸 폭발이 아니라 작은 번쩍임(scale 목표 <= 0.4)",
			cast_fx.get("frames") == 1) and ok
		cast_fx.queue_free()

	var hit := false
	var embedded_arrow: Node = null
	for _tick in 90:
		await get_tree().physics_frame
		if enemy.health < hp_before:
			hit = true
			embedded_arrow = _find_arrow_near(main, enemy.global_position)
			if embedded_arrow != null:
				break
	ok = _check("표창이 날아가 적을 맞춤(적 HP 감소)", hit) and ok
	ok = _check("맞은 적 위치 16px 안에 표창이 박혀 남음(몸이 아니라 적 위)", embedded_arrow != null) and ok
	ok = _check("큰 착탄 SkillFx(64px 별)는 더는 안 뜸", _find_fx_near(main, enemy.global_position) == null) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _find_last_skill_fx(main: Node) -> Node:
	var found: Node = null
	for child in main.get_children():
		if child is SkillFx:
			found = child
	return found


func _find_fx_near(main: Node, pos: Vector2) -> Node:
	for child in main.get_children():
		if child is SkillFx and child.global_position.distance_to(pos) <= 16.0:
			return child
	return null


func _find_arrow_near(main: Node, pos: Vector2) -> Node:
	for arrow in main.get_tree().get_nodes_in_group("arrows"):
		if arrow.global_position.distance_to(pos) <= 16.0:
			return arrow
	return null


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
