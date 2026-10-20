extends Node
## (감독 2026-09-08) 전직의 돌 3종을 상점(4장부터, 개당 100G)에서 산다.
## 살 때마다 materials 가 1 오르고 골드가 빠지며, 상한(JOB_STONE_CAP)에서는
## "더 못 가진다."로 거절돼야 한다(골드만 빠지던 회복약 회귀와 같은 결).

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _stock_index(main: Node, item: String, qty: int = 1) -> int:
	var goods: Array = main._shop_goods()
	for i in goods.size():
		if str(goods[i]["item"]) == item and int(goods[i].get("qty", 1)) == qty:
			return i
	return -1


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	var ok := true

	GameState.chapter = GameState.SECOND_JOB_UNLOCK_CHAPTER - 1
	for stone in GameState.JOB_STONES:
		ok = _check("2차 전직 열리기 전(%d장)엔 %s 미판매" % [GameState.chapter, stone], _stock_index(main, stone) < 0) and ok

	GameState.chapter = GameState.SECOND_JOB_UNLOCK_CHAPTER
	main._open_shop()
	await get_tree().process_frame
	var notice: Label = main.get_node("HUD/Shop/Notice")
	var detail: Label = main.get_node("HUD/Shop/Detail")
	for stone in GameState.JOB_STONES:
		var idx := _stock_index(main, stone)
		ok = _check("%d장부터 %s 판매" % [GameState.chapter, stone], idx >= 0) and ok
		if idx < 0:
			continue
		var price: int = int(main._shop_goods()[idx]["price"])
		ok = _check("%s 가격 100G" % stone, price == 100) and ok
		GameState.gold = price * 2
		GameState.materials[stone] = 0
		main.shop_index = idx
		main._refresh_shop()
		ok = _check("%s Detail에 보유/필요 표시" % stone, detail.text.contains("보유 0") and detail.text.contains(str(GameState.SECOND_JOB_STONE_COST))) and ok
		ok = _check("%s 아이콘 숨김" % stone, not main.get_node("HUD/Shop/Icon").visible) and ok
		main._buy_shop_item(idx)
		ok = _check("%s 구매 → 보유 1" % stone, int(GameState.materials.get(stone, 0)) == 1) and ok
		ok = _check("%s 구매 → 골드 %d" % [stone, price], GameState.gold == price) and ok
		ok = _check("%s 구매 완료 안내" % stone, notice.text.contains("구매 완료")) and ok
		GameState.gold = 0
		main._buy_shop_item(idx)
		ok = _check("%s 골드 부족 거절" % stone, notice.text == "골드가 부족하다." and int(GameState.materials.get(stone, 0)) == 1) and ok
		GameState.gold = price
		GameState.materials[stone] = GameState.JOB_STONE_CAP
		main._buy_shop_item(idx)
		ok = _check("%s 상한 거절 - 골드 안 빠짐" % stone, notice.text == "더 못 가진다." and GameState.gold == price) and ok
		# 묶음 ×100 (감독: "묶음구매있게해야지")
		var idx10 := _stock_index(main, stone, 100)
		ok = _check("%s ×100 묶음 판매" % stone, idx10 >= 0) and ok
		if idx10 < 0:
			continue
		var price10: int = int(main._shop_goods()[idx10]["price"])
		ok = _check("%s ×100 가격 10000G" % stone, price10 == 10000) and ok
		main.shop_index = idx10
		main._refresh_shop()
		var info: Label = main.get_node("HUD/Shop/Info")
		ok = _check("%s ×100 목록 표시" % stone, info.text.contains("%s×100  1만G" % stone)) and ok
		# 선택 표시(▶)+"(부족)"까지 붙은 가장 긴 줄이 한 줄에 들어가야 한다(감독 스크린샷 검증).
		GameState.gold = 0
		main._refresh_shop()
		await get_tree().process_frame
		ok = _check("%s ×100 줄 안 접힘(%d줄)" % [stone, info.get_line_count()], info.get_line_count() == info.text.split("\n").size()) and ok
		ok = _check("%s ×100 Detail 보유/필요" % stone, detail.text.contains("보유") and detail.text.contains(str(GameState.SECOND_JOB_STONE_COST))) and ok
		GameState.gold = price10
		GameState.materials[stone] = 5
		main._buy_shop_item(idx10)
		ok = _check("%s ×100 구매 → 보유 105, 골드 0" % stone, int(GameState.materials.get(stone, 0)) == 105 and GameState.gold == 0 and notice.text == "%s×100 구매 완료" % stone) and ok
		GameState.gold = price10
		GameState.materials[stone] = GameState.JOB_STONE_CAP - 5
		main._buy_shop_item(idx10)
		ok = _check("%s ×100 상한 넘김 거절 - 골드 안 빠짐" % stone, notice.text == "더 못 가진다." and GameState.gold == price10 and int(GameState.materials.get(stone, 0)) == GameState.JOB_STONE_CAP - 5) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
