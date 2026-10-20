extends Node
## 탑 Phase 4 - "초월" 등급, 탑 전용 장비 20종, 제작 잠금 사슬을 확인한다.
## 자세한 설계: TOWER_DESIGN.md 6~7절.

func _ready() -> void:
	GameState.reset()
	var ok := true

	# 등급 시스템 확장.
	ok = _check("초월 등급 색이 있음", GameState.RARITY_COLORS.has("초월")) and ok
	ok = _check("초월은 신화 다음 순서", GameState.RARITY_ORDER.find("초월") == GameState.RARITY_ORDER.find("신화") + 1) and ok
	ok = _check("초월 등급 소켓 3개", GameState.SOCKETS_BY_RARITY.get("초월", 0) == 3) and ok

	# 20종(5난이도 x 4슬롯) 데이터 확인.
	var tower_items: Array[String] = []
	for item in GameState.EQUIPMENT:
		if str(GameState.EQUIPMENT[item].get("rarity", "")) == "초월" \
				and str(GameState.EQUIPMENT[item].get("set", "")).begins_with("tower_"):
			tower_items.append(item)
	ok = _check("탑 전용 장비가 정확히 20종(5난이도 x 4슬롯)", tower_items.size() == 20) and ok
	var slots: Array[String] = []
	for item in tower_items:
		slots.append(str(GameState.EQUIPMENT[item]["slot"]))
	var slot_counts := {"weapon": 0, "armor": 0, "helmet": 0, "trinket": 0}
	for s in slots:
		slot_counts[s] = slot_counts.get(s, 0) + 1
	ok = _check("슬롯 4종이 5개씩 고르게 있음",
		slot_counts.get("weapon", 0) == 5 and slot_counts.get("armor", 0) == 5
		and slot_counts.get("helmet", 0) == 5 and slot_counts.get("trinket", 0) == 5) and ok

	# 난이도가 오를수록 확실히 세짐(심연 검 vs 쉬움 검, 신화 용아 대검과도 비교).
	var easy_atk := int(GameState.EQUIPMENT["파수꾼의 검"]["atk"])
	var abyss_atk := int(GameState.EQUIPMENT["천공의 검"]["atk"])
	var mythic_atk := int(GameState.EQUIPMENT["용아 대검"]["atk"])
	ok = _check("심연 탑템이 쉬움 탑템보다 확실히 셈", abyss_atk > easy_atk * 2.0) and ok
	ok = _check("심연 탑템(초월)이 용기사 세트(신화)보다도 셈", abyss_atk > mythic_atk) and ok

	# 아이콘 - 61종 전용 아이콘 매핑(2026-09-04 아트 교체)이 탑 전용 무기에도
	# 적용됐는지. icon_tower_*.png 폴백은 ITEM_ICONS 표에 없는 장비용 안전망일
	# 뿐, 이미 표에 있는 탑 전용 5종은 각자 다른 전용 파일을 쓴다.
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	ok = _check("탑 전용 무기는 전용 아이콘",
		main._item_icon("파수꾼의 검").resource_path == "res://assets/items/icon_weapon_sentinel.png") and ok
	ok = _check("탑 전용 갑주 아이콘이 일반 갑옷과 다름",
		main._item_icon("파수꾼의 갑주").resource_path != main._item_icon("가죽 갑옷").resource_path) and ok

	# 제작 잠금 사슬.
	GameState.reset()
	ok = _check("스토리 클리어 전엔 쉬움 세트도 제작 불가", not GameState.can_craft("파수꾼의 검")) and ok
	GameState.game_cleared = true
	GameState.tower_material_counts["easy"] = 6
	GameState.materials[GameState.MATERIAL] = 6
	GameState.gold = 1300
	ok = _check("스토리 클리어 + 재료 다 채우면 쉬움 세트 제작 가능", GameState.can_craft("파수꾼의 검")) and ok

	GameState.tower_material_counts["easy"] = 999
	GameState.tower_material_counts["normal"] = 999
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	ok = _check("쉬움 탑 클리어 전엔 재료 넘쳐도 보통 세트 제작 불가",
		not GameState.can_craft("심판자의 검")) and ok
	GameState.tower_progress["easy"] = GameState.TOWER_FLOOR_COUNT
	ok = _check("쉬움 탑 100층 클리어하면 보통 세트 제작 가능", GameState.can_craft("심판자의 검")) and ok

	# "제작이 너무 쉽다" 피드백으로 상위 난이도 제작은 그 아래 난이도
	# 결정도 같이 요구하게 바꿨다(심판자=쉬움3+보통6). 하나라도 모자라면 막힌다.
	GameState.tower_material_counts["easy"] = 2
	ok = _check("아래 난이도(쉬움) 결정이 모자라면 제작 불가", not GameState.can_craft("심판자의 검")) and ok
	GameState.tower_material_counts["easy"] = 999

	var gold_before := GameState.gold
	ok = _check("보통 세트 제작 성공", GameState.craft("심판자의 검")) and ok
	ok = _check("제작하면 인벤토리에 들어감", GameState.inventory.has("심판자의 검")) and ok
	ok = _check("아래 난이도(쉬움) 결정도 소모됨", GameState.tower_material_counts["easy"] == 999 - 3) and ok
	ok = _check("그 난이도(보통) 결정 소모됨", GameState.tower_material_counts["normal"] == 999 - 6) and ok
	ok = _check("강화석 소모됨", GameState.materials[GameState.MATERIAL] == 999 - 7) and ok
	ok = _check("골드 소모됨", GameState.gold == gold_before - 1700) and ok

	# 결정 카운터.
	GameState.tower_material_counts["easy"] = 0
	GameState.add_tower_material("easy")
	GameState.add_tower_material("easy", 5)
	ok = _check("결정을 주우면 쌓임", GameState.tower_material_counts["easy"] == 6) and ok
	GameState.add_tower_material("easy", 999)
	ok = _check("결정도 상한(99)이 있음", GameState.tower_material_counts["easy"] == 99) and ok

	# 대장간 제작 탭 목록에 48개(기존 4 + 5~10장 세트 24 + 탑 20) 다 나오는지.
	var recipes: Array = main._craft_recipe_list()
	ok = _check("제작 탭에 기존 4종 + 5~10장 24종 + 탑 20종 = 48개", recipes.size() == 48) and ok
	main.forge_mode = "craft"
	main.craft_index = recipes.find("파수꾼의 검")
	main._refresh_forge_craft()
	ok = _check("탑템 상세에 필요 재료가 뜸", main.get_node("HUD/Forge/Detail").text.contains(GameState.tower_material_name("easy"))) and ok

	# 몬스터 드랍 - 확률이라 여러 번 시도해서 최소 한 번은 나오는지 확인.
	GameState.reset()
	GameState.game_cleared = true
	GameState.tower_difficulty = "easy"
	var probe_parent := Node2D.new()
	add_child(probe_parent)
	# GDScript 람다는 지역 변수를 값으로 캡처하므로, 클로저 안에서 대입해도
	# 바깥 bool엔 안 남는다. 배열(참조 타입)에 담아 요소를 바꾼다.
	var got_drop := [false]
	for i in 200:
		var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
		probe_parent.add_child(enemy)
		enemy.area_id = "tower"
		enemy.max_health = 10
		enemy.health = 10
		enemy.dropped.connect(func(data: Dictionary, _at: Vector2) -> void:
			if str(data.get("kind", "")) == "tower_material":
				got_drop[0] = true)
		enemy.take_damage(20, Vector2.ZERO)
	ok = _check("탑 몬스터가 결정을 떨어뜨림(200회 시도)", got_drop[0]) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
