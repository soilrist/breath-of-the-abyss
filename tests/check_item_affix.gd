extends Node
## 드랍 랜덤 옵션(감독 2026-09-08). 몬스터/보스 드랍 장비에만 uid별 추가
## 능력치가 붙고, 이름 접두어·상세 줄·착용 보너스·저장/불러오기·판매 삭제가
## 그 인스턴스에만 정확히 따라가야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 2
	GameState.level = 20
	seed(7)

	GameState.add_dropped_item("철검", true)
	var uid_a: int = GameState.item_uid[0]
	var rolled: Dictionary = GameState.affix_of(uid_a)
	ok = _check("보스 드랍은 옵션 2~3줄 확정", rolled.size() >= 2 and rolled.size() <= 3) and ok
	var positive := true
	for key in rolled:
		positive = positive and GameState.AFFIX_KEYS.has(key) and int(rolled[key]) >= 1
	ok = _check("옵션 값은 전부 1 이상 정수", positive) and ok
	var expect_prefix: String = str(GameState.AFFIX_PREFIX[rolled.size()])
	ok = _check("이름 앞에 줄 수 접두어가 붙는다: " + GameState.item_label("철검", uid_a),
		GameState.item_label("철검", uid_a).begins_with(expect_prefix + " 철검")) and ok
	ok = _check("상세에 ✦ 옵션 줄이 있다", GameState.item_summary("철검", uid_a).count("✦") == rolled.size()) and ok

	GameState.add_item("철검")
	var uid_b: int = GameState.item_uid[1]
	ok = _check("상점/보상용 add_item은 옵션 없음", GameState.affix_of(uid_b).is_empty()) and ok
	ok = _check("옵션 없는 사본은 이름 그대로", GameState.item_label("철검", uid_b) == "철검") and ok

	GameState.equip("철검", uid_a)
	var base_atk := int(GameState.item_data("철검").get("atk", 0))
	ok = _check("착용하면 옵션 공격이 공격 보너스에 더해진다",
		GameState.attack_bonus == base_atk + int(rolled.get("atk", 0))) and ok
	ok = _check("HP/방어/속도 보너스도 옵션만큼",
		GameState.health_bonus == int(GameState.item_data("철검").get("hp", 0)) + int(rolled.get("hp", 0))
		and GameState.defense_bonus == int(rolled.get("def", 0))
		and GameState.speed_bonus == int(rolled.get("spd", 0))) and ok
	GameState.enhance_levels[uid_a] = 4
	GameState._recalc_bonuses()
	ok = _check("강화 배율은 기본치에만, 옵션은 그대로 더한다",
		GameState.attack_bonus == int(round(base_atk * 2.0)) + int(rolled.get("atk", 0))) and ok

	var affixed := 0
	var lines_ok := true
	for i in 300:
		GameState.add_dropped_item("가죽 갑옷", false)
		var r: Dictionary = GameState.affix_of(GameState.item_uid.back())
		if not r.is_empty():
			affixed += 1
			lines_ok = lines_ok and r.size() >= 1 and r.size() <= 3
	ok = _check("잡몹 드랍은 일부만 옵션(%d/300)" % affixed, affixed > 60 and affixed < 240 and lines_ok) and ok
	var one_line := ""
	for i in range(2, GameState.inventory.size()):
		var r2: Dictionary = GameState.affix_of(GameState.item_uid[i])
		if r2.size() == 1:
			one_line = GameState.item_label("가죽 갑옷", GameState.item_uid[i])
			ok = _check("1줄 옵션은 능력치 접두어: " + one_line,
				one_line.begins_with(str(GameState.AFFIX_PREFIX[r2.keys()[0]]) + " ")) and ok
			break

	ok = _check("저장 성공", GameState.save_game(player)) and ok
	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("옵션이 사본 A에 그대로 복원", GameState.affix_of(uid_a) == rolled) and ok
	ok = _check("사본 B는 여전히 옵션 없음", GameState.affix_of(uid_b).is_empty()) and ok
	ok = _check("착용 보너스도 복원", GameState.attack_bonus == int(round(base_atk * 2.0)) + int(rolled.get("atk", 0))) and ok

	GameState.unequip("weapon")
	var idx := GameState.item_uid.find(uid_a)
	GameState.sell_at(idx)
	ok = _check("팔면 옵션 기록도 지워진다", not GameState.affixes.has(uid_a)) and ok

	GameState.reset()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
