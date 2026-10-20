extends Node
## 상점 구매 목록이 5개 창을 넘는 항목에서 실제로 스크롤되는지 확인한다.
## main.tscn 을 띄우고 실제 입력 경로(_unhandled_input)로 커서를 움직인다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var goods: Array = main._shop_goods()
	ok = _check("구매 목록이 창(5개)보다 많다", goods.size() > 5) and ok

	main._open_shop()
	var info: Label = main.get_node("HUD/Shop/Info")
	ok = _check("초기 목록에 6번째 이후 항목은 안 보임", not info.text.contains(str(goods[5]["item"]))) and ok

	for i in range(5):
		_send_key(main, KEY_S)
	ok = _check("아래로 5번 이동 후 인덱스 5", main.shop_index == 5) and ok
	ok = _check("스크롤되어 6번째 항목이 보임", info.text.contains(str(goods[5]["item"]))) and ok

	for i in range(goods.size() - 5):
		_send_key(main, KEY_S)
	ok = _check("끝까지 내린 뒤 한 번 더 내리면 처음으로 순환", main.shop_index == 0) and ok
	ok = _check("순환 후 첫 항목이 다시 보임", info.text.contains(str(goods[0]["item"]))) and ok

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
