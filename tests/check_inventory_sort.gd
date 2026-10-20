extends Node
## 가방은 열자마자 항상 희귀도 높은 것부터 보여준다(감독 2026-09-10 "누르는 거
## 만들지 말고 인벤토리 들어가면 무조건 희귀순"). 같은 등급은 주운 순서를
## 지키고, 실제 배열 순서는 안 바꾸며(뷰만 정렬), X를 눌러도 순서가 안 바뀐다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.level = 20
	# 일반, 레어, 에픽, 전설, 일반 순서가 뒤섞이게 넣는다.
	GameState.inventory = ["철검", "정령의 부적", "구리 반지", "용린 갑주", "가죽 갑옷"]
	ok = _check("등급이 실제로 섞여 있다", GameState.rarity_rank("용린 갑주") > GameState.rarity_rank("철검")) and ok

	main._toggle_inventory()
	ok = _check("열자마자 희귀도순", _sorted_desc(main._inventory_order())) and ok
	var order: Array[int] = main._inventory_order()
	ok = _check("같은 등급끼리는 주운 순서(철검→가죽 갑옷)", order.find(0) < order.find(4)) and ok
	ok = _check("실제 배열 순서는 안 바뀜(뷰만 정렬)", GameState.inventory[0] == "철검") and ok
	ok = _check("탭 줄에 정렬 표시 없음", not main._inventory_tab_line().contains("희귀도순")) and ok

	var ev := InputEventAction.new()
	ev.action = "sell_item"
	ev.pressed = true
	main._unhandled_input(ev)
	ok = _check("X를 눌러도 여전히 희귀도순", main._inventory_order() == order) and ok
	ev.action = "move_right"
	main._unhandled_input(ev)
	ok = _check("→는 재료 탭 전환", main.inventory_tab == "materials") and ok
	ev.action = "move_left"
	main._unhandled_input(ev)
	ok = _check("← 로 장비 탭 복귀, 여전히 희귀도순", main.inventory_tab == "items" and main._inventory_order() == order) and ok

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
