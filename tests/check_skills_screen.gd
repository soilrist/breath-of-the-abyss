extends Node
## K로 스킬 설명 화면이 열리고, 아이콘·이름·설명이 실제로 보이고, 다시 닫히는지 확인한다.
## K 키(스킬 재사용)와 겹쳐서 창을 열 때마다 스킬이 같이 나가던 버그가 있었다 -
## 그게 다시 생기지 않는지도 같이 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.level = 20
	var player := main.get_node("Player")
	player.mana = player.max_mana
	var ok := true

	var mana_before: int = player.mana
	var motion_before: String = player.motion
	_send_key(main, KEY_K)
	ok = _check("K로 열림", main.skills_open and main.get_node("HUD/Skills").visible) and ok
	ok = _check("K로 열 때 스킬이 같이 나가지 않음(마력 그대로)", player.mana == mana_before) and ok
	ok = _check("K로 열 때 스킬 모션이 걸리지 않음", player.motion != "skill" or motion_before == "skill") and ok

	for index in GameState.SKILLS.size():
		var skill: Dictionary = GameState.SKILLS[index]
		var row := main.get_node("HUD/Skills/Row%d" % index)
		var icon_ok: bool = row.get_node("Icon").texture != null
		var text: String = row.get_node("Text").text
		ok = _check("%s 아이콘 표시" % skill["name"], icon_ok) and ok
		ok = _check("%s 이름 표시" % skill["name"], text.contains(str(skill["name"]))) and ok
		ok = _check("%s 설명 표시" % skill["name"], text.contains(str(skill["desc"]))) and ok

	_send_key(main, KEY_K)
	ok = _check("K로 다시 닫힘", not main.skills_open and not main.get_node("HUD/Skills").visible) and ok

	# X 버튼으로도 닫히는지, 이번엔 mobile close 경로로 확인.
	_send_key(main, KEY_K)
	main.get_node("HUD/MobileControls")._close_modal()
	await get_tree().process_frame
	ok = _check("X 버튼으로도 닫힘", not main.skills_open) and ok

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
