extends Node
## STATUS.md "다음에 할 것" 98(a): check_title_slot_switch.gd는 슬롯을 실제
## ui_right/ui_left 로 "전환"하는 것만 확인했고, 그때 화면에 보이는 요약도
## raw JSON을 파일에 직접 써 넣어 만든 가짜 데이터였다(GameState.save_game()을
## 슬롯 1/2에서 실제로 부른 적이 없음). 여기서는 슬롯 0과 슬롯 1에 서로 다른
## 값으로 실제 GameState.save_game()을 호출해 저장한 뒤, 타이틀 화면에서 진짜
## → 키 입력(InputEventKey)으로 슬롯 1을 고르고, 그 상태에서 실제
## GameState.load_game()을 호출해 슬롯 1 데이터가 슬롯 0과 섞이지 않고 그대로
## 돌아오는지, 그리고 슬롯 0을 다시 불러와도 슬롯 1 저장으로 오염되지
## 않았는지 확인한다.

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

	# 슬롯 0: 골드 111, 레벨 2, 빈 인벤토리 - 실제 save_game() 호출.
	var main0: Node = await _new_main()
	GameState.reset()
	GameState.slot = 0
	GameState.gold = 111
	GameState.level = 2
	ok = _check("슬롯 0 실제 save_game() 성공", GameState.save_game(main0.get_node("Player"))) and ok
	main0.queue_free()

	# 슬롯 1: 골드 222, 레벨 9, 가죽 갑옷 보유 - 실제 save_game() 호출.
	var main1: Node = await _new_main()
	GameState.reset()
	GameState.slot = 1
	GameState.gold = 222
	GameState.level = 9
	GameState.inventory.append("가죽 갑옷")
	ok = _check("슬롯 1 실제 save_game() 성공", GameState.save_game(main1.get_node("Player"))) and ok
	main1.queue_free()

	# 타이틀 화면에서 실제 → 키 입력으로 슬롯 1을 고른다.
	GameState.reset()
	GameState.slot = 0
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_press_key(title, KEY_RIGHT)
	ok = _check("실제 → 키 입력 -> GameState.slot이 1로 전환", GameState.slot == 1) and ok
	ok = _check("타이틀 슬롯 목록에서 [2](슬롯 1)가 선택 표시",
		title.get_node("Slots").text.contains("[2]")) and ok
	title.queue_free()

	# GameState.slot == 1 인 채로 실제 load_game() 호출 -> 슬롯 1 데이터만 돌아오는지.
	var main2: Node = await _new_main()
	GameState.reset()
	GameState.slot = 1
	ok = _check("슬롯 1 load_game() 성공", GameState.load_game(main2.get_node("Player"))) and ok
	ok = _check("슬롯 1 골드(222)가 돌아옴 - 슬롯 0(111)과 안 섞임", GameState.gold == 222) and ok
	ok = _check("슬롯 1 레벨(9)이 돌아옴", GameState.level == 9) and ok
	ok = _check("슬롯 1 인벤토리(가죽 갑옷)가 돌아옴", GameState.inventory.has("가죽 갑옷")) and ok
	main2.queue_free()

	# 슬롯 0을 다시 불러와도 슬롯 1 저장으로 오염되지 않았는지.
	var main3: Node = await _new_main()
	GameState.reset()
	GameState.slot = 0
	ok = _check("슬롯 0 load_game() 성공", GameState.load_game(main3.get_node("Player"))) and ok
	ok = _check("슬롯 0 골드(111)는 그대로", GameState.gold == 111) and ok
	ok = _check("슬롯 0 레벨(2)은 그대로", GameState.level == 2) and ok
	ok = _check("슬롯 0 인벤토리에 가죽 갑옷 없음(슬롯 1과 안 섞임)",
		not GameState.inventory.has("가죽 갑옷")) and ok
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
