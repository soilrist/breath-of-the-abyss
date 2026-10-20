extends Node
## 보스의 파편을 모아 "용기사 세트"(제작 전용 전설 장비 4개)를 만드는
## 제작 시스템을 확인한다. 파편은 보스 한 마리당 확정이 아니라 10~30개
## 무작위로만 나오고, 동서남북 사냥터 전용 아이템도 하나씩 있어야 한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	ok = _check("재료 없으면 제작 불가", not GameState.can_craft("용아 대검")) and ok

	GameState.add_boss_fragments(9)
	GameState.materials[GameState.MATERIAL] = 6
	GameState.gold = 850
	ok = _check("파편이 1개 모자라면 아직 불가", not GameState.can_craft("용아 대검")) and ok

	GameState.add_boss_fragments(1)
	ok = _check("사냥터 전용 아이템이 없으면 아직 불가", not GameState.can_craft("용아 대검")) and ok

	GameState.add_item("가라앉은 목걸이")
	ok = _check("재료를 다 채우면 제작 가능", GameState.can_craft("용아 대검")) and ok

	var gold_before := GameState.gold
	ok = _check("제작 성공", GameState.craft("용아 대검")) and ok
	ok = _check("인벤토리에 들어감", GameState.inventory.has("용아 대검")) and ok
	ok = _check("제작템은 boss_set 소속(기존 4개 보스 세트와는 별개)",
		GameState.item_data("용아 대검").get("set") == "boss_set") and ok
	ok = _check("파편 10개 소모", GameState.materials[GameState.BOSS_FRAGMENT] == 0) and ok
	ok = _check("강화석 6개 소모", GameState.materials[GameState.MATERIAL] == 0) and ok
	ok = _check("골드 850 소모", GameState.gold == gold_before - 850) and ok
	ok = _check("사냥터 아이템도 소모돼 인벤에서 사라짐", not GameState.inventory.has("가라앉은 목걸이")) and ok

	ok = _check("재료 바닥나면 다시 제작 불가", not GameState.can_craft("용아 대검")) and ok

	ok = _check("레시피 네 개가 용기사 세트 조각을 다 커버함", GameState.CRAFT_RECIPES.size() == 4) and ok

	var total_fragments := 0
	for item in GameState.CRAFT_RECIPES:
		total_fragments += int(GameState.CRAFT_RECIPES[item]["fragments"])
	ok = _check("네 개를 다 만들어도 최악의 파편 운(보스 4마리 최소치)을 안 넘음",
		total_fragments <= 4 * GameState.BOSS_FRAGMENT_MIN) and ok

	# 레시피 네 개가 동서남북 사냥터 전용 아이템 네 개를 하나씩 커버해야
	# 던전을 다 돌아야 세트를 완성할 수 있다.
	var required_area_items: Array[String] = []
	for item in GameState.CRAFT_RECIPES:
		required_area_items.append(str(GameState.CRAFT_RECIPES[item].get("area_item", "")))
	required_area_items.sort()
	var area_drops: Array[String] = []
	for area in GameState.AREA_ITEM_DROPS:
		area_drops.append(str(GameState.AREA_ITEM_DROPS[area]))
	area_drops.sort()
	ok = _check("제작 레시피가 사냥터 전용 아이템 네 개를 하나씩 다 요구함",
		required_area_items == area_drops) and ok

	# 제작템 네 개가 무기/방어구/투구/장신구 슬롯을 하나씩 겹치지 않게 커버해야
	# 한다("갑주가 왜 2개냐" 피드백으로 슬롯이 안 겹치게 배치함).
	var craft_slots: Array[String] = []
	for item in GameState.CRAFT_RECIPES:
		craft_slots.append(str(GameState.item_data(item).get("slot", "")))
	craft_slots.sort()
	ok = _check("제작템 네 개가 서로 다른 슬롯(무기/방어구/투구/장신구)",
		craft_slots == ["armor", "helmet", "trinket", "weapon"]) and ok
	ok = _check("전설 등급 색이 따로 있음", GameState.RARITY_COLORS.has("전설")) and ok
	ok = _check("전설 등급 소켓 3개", GameState.SOCKETS_BY_RARITY.get("전설", 0) == 3) and ok
	ok = _check("제작템(용기사 세트)은 전설이 아니라 신화 등급",
		GameState.item_data("용아 대검").get("rarity") == "신화") and ok

	GameState.add_boss_fragments(9999)
	ok = _check("파편 상한(999)을 넘지 않음", GameState.materials[GameState.BOSS_FRAGMENT] == GameState.BOSS_FRAGMENT_CAP) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
