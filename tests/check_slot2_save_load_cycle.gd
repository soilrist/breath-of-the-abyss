extends Node
## STATUS.md "다음에 할 것" 99: check_slot1_save_load_cycle.gd(193143c)가 슬롯 1을
## 실제 save_game()/load_game() 사이클로 검사했다. 슬롯 2는 슬롯 1과 같은
## save_path(index) 코드 경로(index만 다름)라 버그 발생 가능성은 낮지만,
## SLOT_COUNT(3) 전체를 실제로 확인한 적은 없었다. 이번엔 ui_left(←) 키로
## 슬롯 0에서 슬롯 2로 wrapi(-1, 0, 3) 되돌아가는 경로(슬롯1 검사는 ui_right만
## 확인했음)까지 같이 확인한다.

func _press_key(node: Node, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = true
	node._unhandled_input(ev)


func _new_main() -> Node:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	return main


func _ready() -> void:
	var ok := true
	var backups := {}
	for index in GameState.SLOT_COUNT:
		var path := GameState.save_path(index)
		if FileAccess.file_exists(path):
			backups[index] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(path)

	# 슬롯 0: 골드 333, 레벨 3, 빈 인벤토리 - 실제 save_game() 호출.
	var main0: Node = await _new_main()
	GameState.reset()
	GameState.slot = 0
	GameState.gold = 333
	GameState.level = 3
	ok = _check("슬롯 0 실제 save_game() 성공", GameState.save_game(main0.get_node("Player"))) and ok
	main0.queue_free()

	# 슬롯 2: 골드 444, 레벨 12, 강철 대검 보유 - 실제 save_game() 호출.
	var main1: Node = await _new_main()
	GameState.reset()
	GameState.slot = 2
	GameState.gold = 444
	GameState.level = 12
	GameState.inventory.append("강철 대검")
	ok = _check("슬롯 2 실제 save_game() 성공", GameState.save_game(main1.get_node("Player"))) and ok
	main1.queue_free()

	# 타이틀 화면에서 실제 ← 키 입력으로 슬롯 0 -> 슬롯 2 로 되돌아간다(wrapi).
	GameState.reset()
	GameState.slot = 0
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_press_key(title, KEY_LEFT)
	ok = _check("실제 ← 키 입력 -> GameState.slot이 2로 전환(wrapi)", GameState.slot == 2) and ok
	ok = _check("타이틀 슬롯 목록에서 [3](슬롯 2)가 선택 표시",
		title.get_node("Slots").text.contains("[3]")) and ok
	title.queue_free()

	# GameState.slot == 2 인 채로 실제 load_game() 호출 -> 슬롯 2 데이터만 돌아오는지.
	var main2: Node = await _new_main()
	GameState.reset()
	GameState.slot = 2
	ok = _check("슬롯 2 load_game() 성공", GameState.load_game(main2.get_node("Player"))) and ok
	ok = _check("슬롯 2 골드(444)가 돌아옴 - 슬롯 0(333)과 안 섞임", GameState.gold == 444) and ok
	ok = _check("슬롯 2 레벨(12)이 돌아옴", GameState.level == 12) and ok
	ok = _check("슬롯 2 인벤토리(강철 대검)가 돌아옴", GameState.inventory.has("강철 대검")) and ok
	main2.queue_free()

	# 슬롯 0을 다시 불러와도 슬롯 2 저장으로 오염되지 않았는지.
	var main3: Node = await _new_main()
	GameState.reset()
	GameState.slot = 0
	ok = _check("슬롯 0 load_game() 성공", GameState.load_game(main3.get_node("Player"))) and ok
	ok = _check("슬롯 0 골드(333)는 그대로", GameState.gold == 333) and ok
	ok = _check("슬롯 0 레벨(3)은 그대로", GameState.level == 3) and ok
	ok = _check("슬롯 0 인벤토리에 강철 대검 없음(슬롯 2와 안 섞임)",
		not GameState.inventory.has("강철 대검")) and ok
	main3.queue_free()

	for index in GameState.SLOT_COUNT:
		var path := GameState.save_path(index)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for index in backups:
		var f := FileAccess.open(GameState.save_path(index), FileAccess.WRITE)
		f.store_buffer(backups[index])
		f.close()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
