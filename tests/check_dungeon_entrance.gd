extends Node
## 던전 입구(dungeon/ruins_w/glacier/abyss) 표시가 실제로 뜨는지 확인한다.
## "던전 입구를 좀 만들어줘"(사람 지시, INBOX K)에 대응 - 던전 지역
## 진입 시 HUD 지역명에 "[던전]" 표시와, 처음 들어설 때 문/열쇠 위치를
## 알리는 안내 메시지가 뜨는지 검증한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.reset()
	GameState.chapter = 4  # 4개 던전 전부 도달 가능하게 진행도를 최대로.
	GameState.unlocked_maps = ["village", "dungeon", "ruins_w", "glacier", "ash_hollow"]

	for map_name in ["dungeon", "ruins_w", "glacier", "ash_hollow"]:
		GameState.opened_doors = []  # 매번 "처음 들어서는" 상태로 검사.
		main._change_map(map_name, true)
		await get_tree().process_frame
		var area_text: String = main.get_node("HUD/Area").text
		ok = _check("%s HUD 지역명에 [던전] 표시" % map_name, area_text.begins_with("[던전]")) and ok
		var msg: String = main.get_node("HUD/Message").text
		ok = _check("%s 최초 입장 시 던전 입구 안내 메시지" % map_name, msg.begins_with("던전 입구다")) and ok

	# 문을 이미 연 상태(재입장)면 평범한 도착 메시지여야 한다(같은 안내가
	# 반복되지 않게).
	GameState.opened_doors = ["dungeon_key"]
	main._change_map("dungeon", true)
	await get_tree().process_frame
	var revisit_msg: String = main.get_node("HUD/Message").text
	ok = _check("문을 이미 연 뒤 재입장하면 평범한 도착 메시지", revisit_msg.begins_with("수호자의 동굴에 도착했다")) and ok

	# 던전이 아닌 지역(마을)은 표시가 없어야 한다.
	main._change_map("village", true)
	await get_tree().process_frame
	var village_area: String = main.get_node("HUD/Area").text
	ok = _check("일반 지역엔 [던전] 표시 없음", not village_area.begins_with("[던전]")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
