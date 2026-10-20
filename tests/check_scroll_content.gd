extends Node
## "커서를 내려도 화면이 3개/2개로 고정되고 안 스크롤된다" 재현: 표시된
## 항목 "내용"이 커서 이동에 따라 실제로 바뀌는지(창이 따라 움직이는지)
## 검사한다. 마커 존재 여부만으론 못 잡는 결함이라 항목 개수를 window
## 크기보다 많이 넣고, 각 스텝에서 렌더된 텍스트 자체를 비교한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	# 서로 다른 아이템 12종을 넣어서 각 줄이 서로 구별되게 한다.
	var pool := ["철검", "가죽 갑옷", "가죽 모자", "구리 반지", "사냥꾼의 활",
		"사슬 갑옷", "철 투구", "수정 목걸이", "서리 단검", "낚싯대",
		"부활의 깃털", "파괴 방지 부적"]
	GameState.inventory.clear()
	for item in pool:
		GameState.inventory.append(item)
	GameState.gold = 1000

	main._toggle_inventory()
	var seen_texts := []
	for step in GameState.inventory.size():
		main.inventory_index = step
		main._refresh_inventory()
		var text: String = main.get_node("HUD/Inventory/Info").text
		seen_texts.append(text)
		print("--- idx=", step, " ---\n", text)
	main._toggle_inventory()

	# 첫 window(idx=0)와 마지막 window(idx=11)는 내용이 달라야 정상
	# (달라야 스크롤이 실제로 됐다는 뜻). 같으면 "고정" 버그 재현.
	var scrolled: bool = seen_texts[0] != seen_texts[-1]
	print("처음과 끝 window 내용이 다름(스크롤됨): ", scrolled)

	# 마지막 window에는 리스트의 마지막 아이템("파괴 방지 부적")이 있어야 한다.
	var last_has_last_item: bool = seen_texts[-1].find(pool[-1]) != -1
	print("마지막 커서 위치에서 리스트 끝 항목이 보임: ", last_has_last_item)

	var ok := scrolled and last_has_last_item
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
