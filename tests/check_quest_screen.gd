extends Node
## B로 퀘스트 현황 화면이 열리고, 이야기 진행과 의뢰 상태가 실제로 보이는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	# 아직 의뢰를 안 받은 상태.
	_send_key(main, KEY_B)
	ok = _check("B로 열림", main.quest_open and main.get_node("HUD/Quest").visible) and ok
	var text: String = main.get_node("HUD/Quest/Info").text
	ok = _check("이야기 진행 문구 표시", text.contains(main._mob(main._quest_stage_text()))) and ok
	ok = _check("아직 안 받은 의뢰 안내 표시", text.contains(str(GameState.current_bounty()["label"]))) and ok
	_send_key(main, KEY_B)
	ok = _check("B로 다시 닫힘", not main.quest_open) and ok

	# 의뢰를 받은 뒤 진행도가 반영되는지.
	GameState.take_bounty()
	main._toggle_quest()
	var text2: String = main.get_node("HUD/Quest/Info").text
	ok = _check("받은 의뢰 진행도 표시", text2.contains(GameState.bounty_progress_text())) and ok
	main.get_node("HUD/MobileControls")._close_modal()
	await get_tree().process_frame
	ok = _check("X 버튼으로도 닫힘", not main.quest_open) and ok

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
