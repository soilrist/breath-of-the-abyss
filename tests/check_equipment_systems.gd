extends Node
## 소켓/마법돌, 세트 효과, 보스 확정 드랍, 장별 드랍 테이블을 GameState 만 놓고 확인한다.
## main.tscn 을 안 띄우니 훨씬 빠르다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	# --- 소켓 ---
	ok = _check("일반 등급 소켓 0개", GameState.socket_count("낡은 검") == 0) and ok
	ok = _check("레어 등급 소켓 1개", GameState.socket_count("강철 대검") == 1) and ok
	ok = _check("에픽 등급 소켓 2개", GameState.socket_count("수호자의 검") == 2) and ok

	ok = _check("돌 없으면 소켓 실패", not GameState.can_socket("강철 대검", "홍옥")) and ok
	GameState.add_stone("홍옥", 2)
	ok = _check("돌 얻으면 소켓 가능", GameState.can_socket("강철 대검", "홍옥")) and ok
	# 마법돌 효과는 착용 중인 칸에만 붙는다(창고에 넣어 둔 사본까지 영구
	# 반영되던 버그를 고쳤다) - 소켓·착용 순서로 확인해야 한다.
	GameState.level = 20
	GameState.inventory = ["강철 대검"]
	GameState.equip("강철 대검")
	ok = _check("소켓 성공", GameState.insert_stone("강철 대검", "홍옥")) and ok
	ok = _check("돌 재고 차감", int(GameState.stone_inventory["홍옥"]) == 1) and ok
	ok = _check("레어는 소켓 1개라 두 번째는 실패", not GameState.insert_stone("강철 대검", "홍옥")) and ok
	ok = _check("돌 하나는 그대로 남음(실패해서 안 깎임)", int(GameState.stone_inventory["홍옥"]) == 1) and ok
	ok = _check("stone_bonus 반영", int(GameState.stone_bonus("atk")) == 3) and ok
	ok = _check("장비 보너스에 돌 효과 합산", GameState.attack_bonus >= 18 + 3) and ok

	# --- 세트 효과 ---
	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["수호자의 검"]
	GameState.equip("수호자의 검")
	var atk_one_piece := GameState.attack_bonus
	ok = _check("세트 한 조각만으로는 세트 보너스 없음", int(GameState.set_bonus("atk")) == 0) and ok
	GameState.inventory.append("숲의 심장")
	GameState.equip("숲의 심장")
	ok = _check("세트 두 조각 채우면 세트 보너스 발동", int(GameState.set_bonus("atk")) == 8) and ok
	ok = _check("장비 보너스도 세트만큼 더 늘어남", GameState.attack_bonus > atk_one_piece + 5 - 1) and ok
	var summary := GameState.active_set_summary()
	ok = _check("active_set_summary 에 세트 이름 표시", not summary.is_empty() and str(summary[0]).contains("수호자")) and ok

	# --- 보스 확정 드랍 ---
	ok = _check("guardian 드랍", GameState.boss_drop("guardian") == "숲의 심장") and ok
	ok = _check("captain 드랍", GameState.boss_drop("captain") == "단장의 견장") and ok
	ok = _check("frost 드랍", GameState.boss_drop("frost") == "서리왕관") and ok
	ok = _check("abyss 드랍", GameState.boss_drop("abyss") == "심연의 파편") and ok
	for key in ["guardian", "captain", "frost", "abyss"]:
		var item: String = GameState.boss_drop(key)
		ok = _check("%s 드랍 아이템이 실제 EQUIPMENT 표에 있음" % key, GameState.EQUIPMENT.has(item)) and ok

	# --- 장(챕터)별 드랍 테이블 ---
	for c in range(1, 5):
		GameState.chapter = c
		var item2: String = GameState.roll_chapter_item()
		var stone2: String = GameState.roll_chapter_stone()
		ok = _check("%d장 아이템 드랍 후보가 있음" % c, item2 != "" and GameState.EQUIPMENT.has(item2)) and ok
		ok = _check("%d장 마법돌 드랍 후보가 있음" % c, stone2 != "" and GameState.STONES.has(stone2)) and ok

	# --- 저장/불러오기 라운드트립 ---
	GameState.reset()
	GameState.add_stone("홍염석", 3)
	GameState.inventory = ["강철 대검"]
	GameState.insert_stone("강철 대검", "홍염석")
	var uid := GameState.uid_of("강철 대검")
	var saved := GameState.to_dict()
	var restored_json := JSON.stringify(saved)
	var restored: Dictionary = JSON.parse_string(restored_json)
	ok = _check("stone_inventory 저장됨", int(restored["stone_inventory"].get("홍염석", 0)) == 2) and ok
	# JSON은 정수 키를 문자열로 바꾸니 소켓도 같은 규칙으로 저장됐는지 본다.
	ok = _check("socketed 저장됨", (restored["socketed"].get(str(uid), []) as Array).has("홍염석")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
