extends Node
## STATUS.md "다음에 할 것" 106번: check_unequip.gd:56은 InputEventAction을
## 직접 만들어("interact") main._unhandled_input()에 넣어 물리 키코드→액션
## 매핑(project.godot의 InputMap)을 건너뛴다. check_job_change_key_input.gd와
## 같은 패턴으로 실제 InputEventKey(I=인벤토리 열기 → E=착용/해제 토글 →
## I=닫기)를 태운다. project.godot 확인: inventory=physical_keycode 73(I),
## interact=physical_keycode 69(E).

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["철검", "가죽 갑옷"]

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키 입력만으로 인벤토리 열림", main.menu_open) and ok

	main.inventory_index = main._inventory_order().find(GameState.inventory.find("철검"))

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키(interact 액션)로 실제 착용됨", GameState.equipped["weapon"] == "철검") and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("같은 칸에서 E 키를 다시 누르면 벗겨짐(토글)", GameState.equipped["weapon"] != "철검") and ok
	ok = _check("벗은 철검은 여전히 인벤토리에 있음", GameState.inventory.has("철검")) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키로 인벤토리 닫힘", not main.menu_open) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
