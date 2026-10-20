extends Node
## 탑 전용 장비 5계열이 진짜 세트로 동작하는지 확인한다.
## "천공 세트 입었는데 효과가 없다, 최강 세트여야 하는데" 피드백으로
## GameState.SETS에 tower_*_set 5개를 추가했다 - 그 전엔 "set" 키 자체가
## 없어서 4개를 다 껴도 아무 보너스가 없었다.

func _ready() -> void:
	var ok := true

	# 1) 세트 데이터 자체가 5개 다 있고 각각 4피스인지.
	var tiers := ["easy", "normal", "hard", "hell", "abyss"]
	for tier in tiers:
		var set_id := "tower_%s_set" % tier
		ok = _check("%s 세트 데이터 존재" % set_id, GameState.SETS.has(set_id)) and ok
		if GameState.SETS.has(set_id):
			var pieces: Array = GameState.SETS[set_id]["pieces"]
			ok = _check("%s 4피스" % set_id, pieces.size() == 4) and ok
			for piece in pieces:
				ok = _check("%s 조각 %s 가 실제 장비고 같은 set을 가리킴" % [set_id, piece],
					GameState.EQUIPMENT.has(piece) and str(GameState.EQUIPMENT[piece].get("set", "")) == set_id) and ok

	# 2) 실제로 4피스를 다 끼면 4조각 보너스가 능력치에 반영되는지 (천공 세트로 확인).
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	GameState.level = 30
	var pieces := ["천공의 검", "천공의 갑주", "천공의 투구", "천공의 인장"]
	for piece in pieces:
		GameState.inventory.append(piece)
		GameState.equip(piece)
	var counts := GameState._equipped_set_counts()
	ok = _check("천공 세트 4피스 장착 인식", int(counts.get("tower_abyss_set", 0)) == 4) and ok
	ok = _check("천공 세트 4조각 공격력 보너스(+66) 반영",
		GameState.set_bonus("atk") >= 66.0) and ok
	ok = _check("천공 세트 완성시 특수효과 skyward_grace 활성화",
		GameState.active_set_special() == "skyward_grace") and ok

	# 3) 위기 상황(체력 30% 이하)에서 실제로 피해가 25% 더 줄어드는지.
	var player: Node = main.get_node("Player")
	player.max_health = 1000
	player.health = 250  # 25% -> 위기 발동 구간
	player.invulnerability_time = 0.0
	player.take_damage(100, Vector2.ZERO)
	var taken_in_crisis: int = 250 - int(player.health)
	player.health = 1000
	player.invulnerability_time = 0.0
	player.take_damage(100, Vector2.ZERO)
	var taken_normal: int = 1000 - int(player.health)
	ok = _check("위기 상황 피해(%d)가 평상시 피해(%d)보다 적음" % [taken_in_crisis, taken_normal],
		taken_in_crisis < taken_normal) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
