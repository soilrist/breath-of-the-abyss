extends Node
## AUTOHUNT_DESIGN.md §8 두 번째 체크박스: 모바일 Auto 버튼과 모달 강제 OFF.
## check_mobile_button_click.gd와 같은 패턴(진짜 InputEventMouseButton을
## Viewport에 push_input)으로 실제 클릭 경로를 태운다. Auto는 Pause/Close처럼
## 클릭 한 번(pressed 신호)으로 토글되는 버튼이라 그 패턴을 그대로 쓴다.

func _click_down(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame


func _click_up(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _click(button: Button) -> void:
	await _click_down(button)
	await _click_up(button)


func _ready() -> void:
	var ok := true
	var game := get_parent().get_node("Main")
	await get_tree().process_frame
	skip_dialogue(game)

	var mobile := game.get_node("HUD/MobileControls")
	var player := game.get_node("Player")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var auto_button: Button = mobile.get_node("Auto")
	ok = _check("플레이 중에는 Auto 버튼이 보인다", auto_button.visible) and ok
	ok = _check("시작 시 auto_hunt는 꺼져 있다", not player.auto_hunt) and ok

	await _click(auto_button)
	ok = _check("진짜 마우스 클릭으로 Auto 버튼이 player.auto_hunt를 켠다",
		player.auto_hunt) and ok
	ok = _check("켜지면 Auto 버튼이 눌린 상태(button_pressed)로 표시된다",
		auto_button.button_pressed) and ok

	# §6 안전장치: 모달(여기서는 일시정지)이 열리면 그 프레임에 강제 OFF.
	var pause_button: Button = mobile.get_node("Pause")
	await _click(pause_button)
	ok = _check("일시정지를 열면 켜져 있던 auto_hunt가 강제로 꺼진다",
		not player.auto_hunt) and ok
	ok = _check("모달이 열리면 Auto 버튼 자체가 보이지 않는다",
		not auto_button.visible) and ok

	var close_button: Button = mobile.get_node("Close")
	await _click(close_button)
	mobile.set_modal_mode("")
	await get_tree().process_frame

	# 껐다 켰다 왕복도 확인 - 토글이 한쪽으로만 도는 회귀를 잡는다.
	await _click(auto_button)
	ok = _check("일시정지 닫힌 뒤 다시 클릭하면 auto_hunt가 켜진다",
		player.auto_hunt) and ok
	await _click(auto_button)
	ok = _check("한 번 더 클릭하면 auto_hunt가 꺼진다",
		not player.auto_hunt) and ok
	ok = _check("꺼지면 Auto 버튼도 눌리지 않은 상태로 돌아온다",
		not auto_button.button_pressed) and ok

	# 데스크톱 T키 토글(main.gd:_toggle_auto_hunt)로 켜도 모바일 버튼 표시가 맞는지.
	game._toggle_auto_hunt()
	ok = _check("T키 토글(main.gd:_toggle_auto_hunt)로 켜도 Auto 버튼 표시가 맞춰진다",
		auto_button.button_pressed) and ok
	game._toggle_auto_hunt()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func skip_dialogue(game: Node) -> void:
	var guard := 0
	while game.dialogue_open and guard < 40:
		game._advance_dialogue()
		guard += 1


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
