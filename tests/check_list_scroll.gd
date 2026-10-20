extends Node
## "아이템 내려다볼때(목록에서 커서를 아래로 내릴 때) 3개만 보이고
## 2개만 보이고 고정되어 있다"는 신고 재현: 인벤토리·상점·창고·대장간에서
## 아이템을 window 크기보다 많이 채운 뒤 커서를 끝까지 내리면서
## 화면에 실제로 표시되는 항목 수와 스크롤(마지막 항목이 보이는지)을 검사한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	# 인벤토리에 10개 채운다.
	GameState.inventory.clear()
	for i in 10:
		GameState.inventory.append("회복약")
	GameState.gold = 999999

	var ok := true

	# 인벤토리 열기
	main._toggle_inventory()
	for step in 9:
		main.inventory_index = step
		main._refresh_inventory()
		var text: String = main.get_node("HUD/Inventory/Info").text
		var shown_markers := text.count("▶")
		ok = _check("인벤토리 idx=%d 선택 마커 1개 표시" % step, shown_markers == 1) and ok
	# 맨 끝(9번째, 마지막 아이템)으로 이동했을 때 그 항목이 실제로 텍스트에
	# 포함되는지(창이 따라 스크롤됐는지) 확인 - 안 따라가면 "고정" 버그다.
	main.inventory_index = 9
	main._refresh_inventory()
	var last_text: String = main.get_node("HUD/Inventory/Info").text
	ok = _check("인벤토리 마지막 항목으로 이동 시 ▶ 마커 표시", last_text.count("▶") == 1) and ok
	main._toggle_inventory()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
