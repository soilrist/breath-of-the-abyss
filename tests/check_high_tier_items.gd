extends Node
## 5~10장 상위 장비(감독 2026-09-10, "레벨 53인데 아이템 너무 부족" 피드백).
## 장마다 정수(잡몹 확률·보스 확정 드랍) → 대장간에서 초월 세트 4종 제작,
## 필드 잡몹은 전설 등급 장비 2종씩 떨어뜨린다. 표 데이터·드랍·제작·
## 인벤 재료 탭까지 한 번에 확인한다.

func _ready() -> void:
	var ok := true
	GameState.reset()

	# 정수 6종: 5~10장 하나씩, 저장 dict 에 처음부터 들어 있음.
	ok = _check("정수 6종(5~10장)", GameState.CHAPTER_ESSENCES.size() == 6) and ok
	for ch in range(5, 11):
		var ess := GameState.chapter_essence(ch)
		ok = _check("%d장 정수 이름 있음" % ch, ess != "" and GameState.materials.has(ess)) and ok
	ok = _check("4장 이하엔 정수 없음", GameState.chapter_essence(4) == "" and GameState.chapter_essence(1) == "") and ok
	GameState.add_essence("없는 정수", 5)
	ok = _check("모르는 정수는 무시", not GameState.materials.has("없는 정수")) and ok
	GameState.add_essence("태초의 정수", 5000)
	ok = _check("정수 상한 %d" % GameState.ESSENCE_CAP, GameState.materials["태초의 정수"] == GameState.ESSENCE_CAP) and ok

	# 세트 24종(6장 x 4슬롯) + 레시피 + 보스 드랍 연결.
	ok = _check("장 세트 레시피 24개", GameState.CHAPTER_CRAFT_RECIPES.size() == 24) and ok
	var prev_atk := int(GameState.EQUIPMENT["천공의 검"]["atk"])
	for ch in range(5, 11):
		var boss_key := str(GameState.BOSS_KEYS[ch])
		var sword := str(GameState.BOSS_DROPS.get(boss_key, ""))
		var helmet := GameState.boss_drop_extra(boss_key)
		ok = _check("%d장 보스가 세트 검+투구를 떨어뜨림" % ch,
			sword.ends_with("의 검") and helmet.ends_with("의 투구")) and ok
		var set_id := str(GameState.EQUIPMENT[sword].get("set", ""))
		ok = _check("%d장 세트 보너스 2/3/4 있음" % ch,
			GameState.SETS.has(set_id) and GameState.SETS[set_id]["bonuses"].has(4)) and ok
		var slots := {}
		for item in GameState.CHAPTER_CRAFT_RECIPES:
			var cost: Dictionary = GameState.CHAPTER_CRAFT_RECIPES[item]
			if int(cost["chapter"]) != ch:
				continue
			var data: Dictionary = GameState.EQUIPMENT[item]
			slots[str(data["slot"])] = true
			ok = _check("%s: 초월 등급 + 같은 세트" % item,
				str(data["rarity"]) == "초월" and str(data.get("set", "")) == set_id) and ok
		ok = _check("%d장 세트 4슬롯 전부 제작 가능" % ch, slots.size() == 4) and ok
		var atk := int(GameState.EQUIPMENT[sword]["atk"])
		ok = _check("%d장 검(atk %d)이 이전 단계(%d)보다 셈" % [ch, atk, prev_atk], atk > prev_atk) and ok
		prev_atk = atk

	# 필드 전설 12종: 장마다 2개, 표에 있고 전설 등급.
	for ch in range(5, 11):
		var pool: Array = GameState.CHAPTER_ITEM_DROPS.get(ch, [])
		ok = _check("%d장 필드 드랍 2종" % ch, pool.size() == 2) and ok
		for item in pool:
			ok = _check("%s: 전설 등급 장비" % item,
				GameState.EQUIPMENT.has(item) and str(GameState.EQUIPMENT[item]["rarity"]) == "전설") and ok
		GameState.chapter = ch
		ok = _check("%d장 roll_chapter_item 이 그 장 목록에서 나옴" % ch, pool.has(GameState.roll_chapter_item())) and ok
	GameState.chapter = 1

	# 제작: 정수·파편·강화석·골드 다 있어야 하고, 만들면 바로 장착.
	GameState.reset()
	var cost: Dictionary = GameState.CHAPTER_CRAFT_RECIPES["근원의 검"]
	GameState.materials[GameState.BOSS_FRAGMENT] = 999
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 99999
	GameState.level = 40  # 근원 세트 착용 레벨. 제작 후 자동 장착 확인용.
	ok = _check("정수 없으면 제작 불가", not GameState.can_craft("근원의 검")) and ok
	GameState.add_essence("근원의 정수", int(cost["essence"]) - 1)
	ok = _check("정수 1개 모자라면 불가", not GameState.can_craft("근원의 검")) and ok
	GameState.add_essence("근원의 정수", 1)
	ok = _check("재료 채우면 제작 가능", GameState.can_craft("근원의 검")) and ok
	var gold_before := GameState.gold
	ok = _check("제작 성공", GameState.craft("근원의 검")) and ok
	ok = _check("정수 소모", GameState.materials["근원의 정수"] == 0) and ok
	ok = _check("파편 소모", GameState.materials[GameState.BOSS_FRAGMENT] == 999 - int(cost["fragments"])) and ok
	ok = _check("강화석 소모", GameState.materials[GameState.MATERIAL] == 999 - int(cost["stones"])) and ok
	ok = _check("골드 소모", GameState.gold == gold_before - int(cost["gold"])) and ok
	ok = _check("제작하면 바로 장착", GameState.equipped["weapon"] == "근원의 검") and ok
	ok = _check("정수 다 쓰면 다시 불가", not GameState.can_craft("근원의 검")) and ok

	# 드랍 → 줍기 → 인벤 재료 탭 + 대장간 상세.
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	# 저장/불러오기에 정수가 남는지(슬롯 4 = 테스트 전용, 끝나면 지움).
	GameState.reset()
	GameState.slot = 4
	GameState.add_essence("심해의 정수", 7)
	ok = _check("저장 성공", GameState.save_game(player)) and ok
	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("정수 저장/불러오기", GameState.materials["심해의 정수"] == 7) and ok
	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)
	GameState.reset()
	main._on_enemy_dropped({"kind": "essence", "essence": "성광의 정수"}, player.global_position)
	var pickups: Array = get_tree().get_nodes_in_group("pickups")
	ok = _check("정수 pickup 생성", pickups.size() == 1 and pickups[0].kind == "essence") and ok
	pickups[0]._on_body_entered(player)
	main._on_pickup_collected(pickups[0])
	ok = _check("주우면 정수 +1", GameState.materials["성광의 정수"] == 1) and ok
	ok = _check("줍기 메시지", main.get_node("HUD/Message").text.contains("성광의 정수")) and ok

	var rows: Array = main._material_rows()
	var names: Array[String] = []
	for row in rows:
		names.append(str(row["name"]))
		if GameState.CHAPTER_ESSENCES.values().has(row["name"]):
			ok = _check("재료 탭 %s 아이콘 있음" % row["name"], row["icon"] != null) and ok
	for ess in GameState.CHAPTER_ESSENCES.values():
		ok = _check("재료 탭에 %s 줄 있음" % ess, names.has(ess)) and ok

	var recipes: Array = main._craft_recipe_list()
	ok = _check("대장간 제작 목록에 근원의 검 있음", recipes.has("근원의 검")) and ok
	main.forge_mode = "craft"
	main.craft_index = recipes.find("근원의 검")
	main._refresh_forge_craft()
	var detail: String = main.get_node("HUD/Forge/Detail").text
	ok = _check("제작 상세에 정수 필요량 표시", detail.contains("근원의 정수 0/%d" % int(cost["essence"]))) and ok

	# 아이콘·손그림 파일이 실제로 있는지(ITEM_ICONS 표 + hand 키).
	for item in GameState.CHAPTER_CRAFT_RECIPES:
		ok = _check("%s 아이콘 파일" % item, ResourceLoader.exists("res://assets/items/%s.png" % GameState.ITEM_ICONS[item])) and ok
	for ch in range(5, 11):
		for item in GameState.CHAPTER_ITEM_DROPS[ch]:
			ok = _check("%s 아이콘 파일" % item, ResourceLoader.exists("res://assets/items/%s.png" % GameState.ITEM_ICONS[item])) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
