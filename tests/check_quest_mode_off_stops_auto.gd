extends Node
## 결함(감독, 2026-09-07): 퀘스트모드를 한 번 더 눌러 껐는데도 캐릭터가 계속
## 자동으로 걷고 싸웠다. 원인: _toggle_quest_mode() OFF 경로가 틱이 켜 둔
## Player.auto_hunt/auto_walk_active를 끄지 않았다. 세 OFF 경로(코드 호출,
## Y 키, 모바일 Quest 버튼 재탭)가 전부 오토를 함께 끄는지 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = center
		ev.global_position = center
		button.get_viewport().push_input(ev, true)
		await get_tree().process_frame


## 퀘스트모드를 켜고 틱을 돌려 오토(walk 또는 hunt)가 실제로 켜진 main을 만든다.
func _arm() -> Node:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	GameState.current_map = "village"
	GameState.quest_stage = 1
	GameState.kills = 6
	main._toggle_quest_mode()
	for i in 5:
		main._quest_mode_tick()
		while main.dialogue_open: main._advance_dialogue()
	return main


func _assert_off(main: Node, how: String, ok: bool) -> bool:
	var player: Node = main.get_node("Player")
	var mobile: Node = main.get_node("HUD/MobileControls")
	ok = _check(how + ": quest_mode 꺼짐", not main.quest_mode) and ok
	ok = _check(how + ": auto_hunt 꺼짐", not player.auto_hunt) and ok
	ok = _check(how + ": auto_walk 꺼짐", not player.auto_walk_active) and ok
	ok = _check(how + ": Quest 버튼 해제", not mobile.get_node("Quest").button_pressed) and ok
	ok = _check(how + ": Auto 버튼 해제", not mobile.get_node("Auto").button_pressed) and ok
	return ok


func _ready() -> void:
	var ok := true
	# ① 코드 호출
	var main := await _arm()
	var player: Node = main.get_node("Player")
	ok = _check("준비: 틱이 오토를 켬", player.auto_walk_active or player.auto_hunt) and ok
	main._toggle_quest_mode()
	ok = _assert_off(main, "코드 토글", ok)
	main.queue_free()

	# ② 데스크톱 Y 키(project.godot quest_mode 액션)
	main = await _arm()
	_send_key(main, KEY_Y)
	await get_tree().process_frame
	ok = _assert_off(main, "Y 키", ok)
	main.queue_free()

	# ③ 모바일 Quest 버튼 재탭
	main = await _arm()
	var mobile: Node = main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame
	ok = _check("재탭 전 Quest 버튼 눌림 표시", mobile.get_node("Quest").button_pressed) and ok
	await _click(mobile.get_node("Quest"))
	ok = _assert_off(main, "모바일 재탭", ok)
	main.queue_free()

	get_tree().paused = false
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
