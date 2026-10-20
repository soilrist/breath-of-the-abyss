extends Node
## 상점 판매 목록이 5개 창을 넘는 항목에서 실제로 스크롤되는지 확인한다.
## main.tscn 을 띄우고 실제 입력 경로(_unhandled_input)로 탭 전환·커서 이동한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var stock_items := ["철검", "가죽 갑옷", "가죽 모자", "구리 반지", "사냥꾼의 활",
		"사슬 갑옷", "철 투구", "수정 목걸이"]
	for item in stock_items:
		GameState.add_item(item)
	main._open_shop()
	_send_key(main, KEY_D)
	ok = _check("D 키로 판매 탭 전환", main.shop_mode == "sell") and ok

	var sell_list: Array = main._shop_sell_list()
	ok = _check("판매 목록이 창(5개)보다 많다", sell_list.size() > 5) and ok

	var info: Label = main.get_node("HUD/Shop/Info")
	ok = _check("판매 탭 표시됨", info.text.contains("[판매]")) and ok
	ok = _check("초기 목록에 6번째 이후 항목은 안 보임", not info.text.contains(str(sell_list[5]))) and ok

	for i in range(5):
		_send_key(main, KEY_S)
	ok = _check("아래로 5번 이동 후 인덱스 5", main.shop_index == 5) and ok
	ok = _check("스크롤되어 6번째 항목이 보임", info.text.contains(str(sell_list[5]))) and ok

	for i in range(sell_list.size() - 5):
		_send_key(main, KEY_S)
	ok = _check("끝까지 내린 뒤 한 번 더 내리면 처음으로 순환", main.shop_index == 0) and ok
	ok = _check("순환 후 첫 항목이 다시 보임", info.text.contains(str(sell_list[0]))) and ok

	_send_key(main, KEY_A)
	ok = _check("A 키로 구매 탭으로 복귀", main.shop_mode == "buy") and ok

	main._close_shop()
	ok = _check("닫으면 상점 안 보임", not main.shop_open and not main.get_node("HUD/Shop").visible) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _send_key(main: Node, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	main._unhandled_input(ev)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
