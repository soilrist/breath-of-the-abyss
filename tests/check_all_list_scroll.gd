extends Node
## 창고·상점(구매/판매)·대장간(강화/제작) 목록도 인벤토리와 같은 원리다.
## 각각 항목을 window 크기보다 많이 채우고 커서를 끝까지 내리며 마커가
## 항상 정확히 1개만, 그리고 마지막 항목에서도 보이는지 검사한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.gold = 999999999
	GameState.chapter = 3
	var ok := true

	# --- 창고 ---
	GameState.inventory.clear()
	GameState.storage.clear()
	for i in 12:
		GameState.inventory.append("회복약")
	main._toggle_storage()
	for step in GameState.inventory.size():
		main.storage_index = step
		main._refresh_storage()
		var text: String = main.get_node("HUD/Storage/Info").text
		ok = _check("창고 idx=%d 마커 1개" % step, text.count("▶") == 1) and ok
	main._toggle_storage()

	# --- 상점: 구매 ---
	main.shop_mode = "buy"
	var buy_count: int = main._shop_goods().size()
	main.shop_open = true
	for step in buy_count:
		main.shop_index = step
		main._refresh_shop()
		var text: String = main.get_node("HUD/Shop/Info").text
		ok = _check("상점(구매) idx=%d/%d 마커 1개" % [step, buy_count], text.count("▶") == 1) and ok

	# --- 상점: 판매 ---
	main.shop_mode = "sell"
	GameState.inventory.clear()
	for i in 8:
		GameState.inventory.append("가죽 갑옷")
	for step in GameState.inventory.size():
		main.shop_index = step
		main._refresh_shop()
		var text: String = main.get_node("HUD/Shop/Info").text
		ok = _check("상점(판매) idx=%d 마커 1개" % step, text.count("▶") == 1) and ok
	main.shop_open = false

	# --- 대장간: 강화 ---
	GameState.inventory.clear()
	for i in 9:
		GameState.inventory.append("철검")
	main.forge_open = true
	main.forge_mode = "enhance"
	var forge_items: Array = main._forge_items()
	for step in forge_items.size():
		main.forge_index = step
		main._refresh_forge()
		var text: String = main.get_node("HUD/Forge/Info").text
		ok = _check("대장간(강화) idx=%d 마커 1개" % step, text.count("▶") == 1) and ok

	# --- 대장간: 제작 ---
	main.forge_mode = "craft"
	var recipes: Array = main._craft_recipe_list()
	for step in mini(recipes.size(), 12):
		main.craft_index = step
		main._refresh_forge_craft()
		var text: String = main.get_node("HUD/Forge/Info").text
		ok = _check("대장간(제작) idx=%d 마커 1개" % step, text.count("▶") == 1) and ok
	main.forge_open = false

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
