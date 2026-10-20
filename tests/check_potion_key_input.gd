extends Node
## STATUS.md "다음 후보"가 남긴 것: 스킬 숫자키는 실제 입력 경로 검사가
## 갖춰졌지만 포션 단축키(L, project.godot의 "potion" 액션,
## main.gd:_unhandled_input -> player.try_use_potion())는 기존 검사
## (check_save_load_stats.gd 등)가 전부 player.try_use_potion()을 코드로
## 직접 호출할 뿐 실제 키 입력 경로를 태운 적이 없었다(⑥ 규칙이 경고하는
## "함수는 돌지만 사람이 누르면 반응 안 함" 패턴과 같은 부류의 미검증 지대).
## check_skill_key_input.gd와 동일하게 main._unhandled_input()에 진짜
## InputEventKey를 넣어 키 입력 -> try_use_potion() 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_heals_and_consumes()) and ok
	ok = (await _check_no_potion_message()) and ok
	ok = (await _check_full_health_message()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_heals_and_consumes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.max_health = 200
	player.health = 50
	player.potions = 3
	GameState.potions = 3

	_send_key(main, KEY_L)
	var ok := _check("L 키 입력만으로 체력 회복(35%)", player.health > 50)
	ok = _check("L 키 입력만으로 물약 개수 감소(3->2)", player.potions == 2) and ok

	main.queue_free()
	return ok


func _check_no_potion_message() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.max_health = 200
	player.health = 50
	player.potions = 0
	GameState.potions = 0

	_send_key(main, KEY_L)
	var ok := _check("물약 0개일 때 L 키 입력은 회복 없음", player.health == 50)
	ok = _check("물약 0개 안내 메시지 표시", main.get_node("HUD/Message").text == "회복약이 없다.") and ok

	main.queue_free()
	return ok


func _check_full_health_message() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	player.max_health = 200
	player.health = 200
	player.potions = 3
	GameState.potions = 3

	_send_key(main, KEY_L)
	var ok := _check("체력 만땅일 때 L 키 입력은 물약 소모 없음", player.potions == 3)
	ok = _check("체력 만땅 안내 메시지 표시", main.get_node("HUD/Message").text == "HP가 가득 찼다.") and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
