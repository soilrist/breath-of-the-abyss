extends Node
## check_inventory_sort.gd는 main._toggle_inventory()를 직접 부르고 InputEventAction을
## 만들어 넣어 InputMap을 건너뛴다. 여기서는 실제 InputEventKey
## (I=인벤토리 열기 → X → D/A 탭 전환 → I=닫기)를 태워, 가방이 어떤 키를
## 거치든 항상 희귀도순으로 보이는지 확인한다(감독 2026-09-10, 정렬 토글 없음).

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.reset()
	GameState.level = 20
	# 일반, 레어, 에픽, 전설 순서가 뒤섞이게 넣는다.
	GameState.inventory = ["철검", "정령의 부적", "구리 반지", "용린 갑주"]

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키 입력만으로 인벤토리 열림", main.menu_open) and ok
	var order: Array[int] = main._inventory_order()
	ok = _check("열자마자 희귀도 높은 것부터(전설→에픽→레어→일반)", _sorted_desc(order)) and ok
	ok = _check("실제 배열 순서는 안 바뀜(뷰만 정렬)", GameState.inventory[0] == "철검") and ok

	_send_key(main, KEY_X)
	await get_tree().process_frame
	ok = _check("X 키를 눌러도 순서 그대로", main._inventory_order() == order and main.menu_open) and ok
	_send_key(main, KEY_D)
	await get_tree().process_frame
	ok = _check("D 키(move_right)는 재료 탭 전환", main.inventory_tab == "materials") and ok
	_send_key(main, KEY_A)
	await get_tree().process_frame
	ok = _check("A 키(move_left)로 장비 탭 복귀, 여전히 희귀도순", main.inventory_tab == "items" and main._inventory_order() == order) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키로 인벤토리 닫힘", not main.menu_open) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _sorted_desc(order: Array[int]) -> bool:
	for i in range(1, order.size()):
		if GameState.rarity_rank(GameState.inventory[order[i]]) > GameState.rarity_rank(GameState.inventory[order[i - 1]]):
			return false
	return true


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
