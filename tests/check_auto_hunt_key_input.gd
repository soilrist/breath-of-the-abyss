extends Node
## AUTOHUNT_DESIGN.md §5 데스크톱 토글 키(T, project.godot의 "auto_hunt"
## 액션) 검사. check_potion_key_input.gd와 동일하게 main._unhandled_input()에
## 진짜 InputEventKey를 넣어 키 입력 -> Player.auto_hunt 전체 경로를 태운다
## (⑥ 규칙: 함수 직접 호출이 아니라 실제 입력 경로로).

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


## §6 안전장치 검사(사람 입력 감지 시 강제 OFF)는 main._unhandled_input()을
## 직접 부르는 _send_key()로는 못 태운다 - player.gd의 이동/공격/대시 감지는
## Input.is_action_just_pressed() 폴링이라 실제 Input 싱글톤을 거쳐야 한다
## (check_attack_dash_key_input.gd와 동일한 이유, 동일한 패턴).
func _tap_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().physics_frame


func _ready() -> void:
	var ok := true
	ok = (await _check_toggle_on_off()) and ok
	ok = (await _check_blocked_while_modal_open()) and ok
	ok = (await _check_forced_off_by_move_key()) and ok
	ok = (await _check_forced_off_by_attack_key()) and ok
	ok = (await _check_forced_off_by_skill_key()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_toggle_on_off() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.auto_hunt = false

	_send_key(main, KEY_T)
	var ok := _check("T 키 입력만으로 오토사냥 켜짐", player.auto_hunt == true)
	ok = _check("켜짐 안내 메시지 표시", main.get_node("HUD/Message").text == "자동사냥 켜짐") and ok
	ok = _check("HUD AUTO 라벨 표시", main.get_node("HUD/AutoLabel").visible == true) and ok

	_send_key(main, KEY_T)
	ok = _check("T 키 다시 입력하면 오토사냥 꺼짐", player.auto_hunt == false) and ok
	ok = _check("꺼짐 안내 메시지 표시", main.get_node("HUD/Message").text == "자동사냥 꺼짐") and ok
	ok = _check("HUD AUTO 라벨 숨김", main.get_node("HUD/AutoLabel").visible == false) and ok

	main.queue_free()
	return ok


func _check_blocked_while_modal_open() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.auto_hunt = false
	main._toggle_inventory()

	_send_key(main, KEY_T)
	var ok := _check("인벤토리 열려 있으면 T 키가 오토사냥을 켜지 않음", player.auto_hunt == false)

	main.queue_free()
	return ok


func _check_forced_off_by_move_key() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.auto_hunt = true

	await _tap_key(KEY_W)
	var ok := _check("W 키(이동) 실제 입력으로 오토사냥 강제 꺼짐", player.auto_hunt == false)
	ok = _check("꺼짐 안내 메시지 표시", main.get_node("HUD/Message").text == "자동사냥 꺼짐") and ok

	main.queue_free()
	return ok


func _check_forced_off_by_attack_key() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.auto_hunt = true

	await _tap_key(KEY_J)
	var ok := _check("J 키(공격) 실제 입력으로 오토사냥 강제 꺼짐", player.auto_hunt == false)

	main.queue_free()
	return ok


func _check_forced_off_by_skill_key() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.auto_hunt = true

	_send_key(main, KEY_1)
	var ok := _check("1 키(스킬) 실제 입력으로 오토사냥 강제 꺼짐", player.auto_hunt == false)

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
