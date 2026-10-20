extends Node
## 상점/인벤토리 같은 메뉴에서 화살표 대신 WASD로도 커서가 움직이는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var ok := true

	# 상점: S 로 아래, W 로 위, D 로 탭 전환(판매), A 로 되돌아온다(구매).
	main._open_shop()
	main.shop_index = 0
	_send_key(main, KEY_S)
	ok = _check("상점 S로 아래 이동 (0 -> 1)", main.shop_index == 1) and ok
	_send_key(main, KEY_W)
	ok = _check("상점 W로 위 이동 (1 -> 0)", main.shop_index == 0) and ok
	_send_key(main, KEY_D)
	ok = _check("상점 D로 판매탭", main.shop_mode == "sell") and ok
	_send_key(main, KEY_A)
	ok = _check("상점 A로 구매탭", main.shop_mode == "buy") and ok
	main._close_shop()

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
