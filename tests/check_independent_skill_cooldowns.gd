extends Node
## 스킬 하나를 쓰면 그 스킬만 쿨타임에 들어가고, 나머지 셋은 바로 쓸 수
## 있어야 한다. 예전엔 쿨타임을 공유해서 하나 쓰면 넷 다 막혔었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.level = 20
	# player.max_mana 는 GameState.level 을 바꾼다고 저절로 안 따라온다
	# (_apply_equipment_to_player 를 거쳐야 함) - 넉넉히 999로 고정한다.
	player.max_mana = 999
	player.mana = 999
	for i in player.skill_cooldowns.size():
		player.skill_cooldowns[i] = 0.0

	ok = _check("0번 스킬 처음엔 준비됨", player.skill_cooldowns[0] == 0.0) and ok
	var r0: String = player.cast_skill(0)
	ok = _check("0번 스킬 시전 성공", not r0.contains("준비 중") and not r0.contains("배우지") and not r0.contains("마력")) and ok
	ok = _check("0번은 이제 쿨타임 중", player.skill_cooldowns[0] > 0.0) and ok

	for other in [1, 2, 3]:
		var r: String = player.cast_skill(other)
		ok = _check("%d번 스킬은 0번과 무관하게 바로 시전됨" % other,
			not r.contains("준비 중") and not r.contains("배우지") and not r.contains("마력")) and ok
		ok = _check("%d번도 자기 쿨타임엔 들어감" % other, player.skill_cooldowns[other] > 0.0) and ok

	ok = _check("서로 다른 스킬 쿨타임 값이 독립적", player.skill_cooldowns[0] != player.skill_cooldowns[2]
		or GameState.SKILLS[0]["cooldown"] == GameState.SKILLS[2]["cooldown"]) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
