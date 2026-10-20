extends Node
## STATUS.md "다음 후보" 96번(b): 사망 시 "부활의 깃털을 쓰겠습니까?" 대화
## 선택지가 지금까지 코드 직접 호출(_on_revive_choice() 등)로만 테스트됐고
## 실제 화살표(W/S)+E 키 입력 경로로 고른 적은 없었다
## (revive_potions을 쓰는 check_death_physics_*.gd 조차 revive_potions=0
## 으로 못 뜨게 해서 이 분기를 아예 건드리지 않는다).
## main.gd:_unhandled_input()이 dialogue_open일 때 move_up/move_down으로
## dialogue_choice를 옮기고 interact(E)로 확정하는 경로(check_quest_key_input.gd
## 와 동일한 실제 InputEventKey 방식)를 死 -> 선택지 -> 부활/사망처리까지
## 전부 태운다. 죽음 자체도 real take_damage()로 일으켜
## check_death_physics_callback.gd와 같은 실제 신호 경로를 쓴다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_revive_yes()) and ok
	ok = (await _check_revive_no()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _kill_player(main: Node, player: CharacterBody2D) -> void:
	player.global_position = Vector2(160, 120)
	player.max_health = 999
	player.health = 1
	player.invulnerability_time = 0.0
	player.take_damage(1, Vector2.ZERO)


func _check_revive_yes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.revive_potions = 2
	var player: CharacterBody2D = main.get_node("Player")
	_kill_player(main, player)
	await get_tree().process_frame

	var ok := _check("사망 -> 부활 선택지 대화 열림", main.dialogue_open)
	ok = _check("선택지 2개(쓴다/쓰지 않는다)", main.dialogue_choices.size() == 2) and ok
	ok = _check("시작 커서는 0번(쓴다)", main.dialogue_choice == 0) and ok

	_send_key(main, KEY_S)
	await get_tree().process_frame
	ok = _check("S 키(move_down) 실제 입력 -> 커서가 1번(쓰지 않는다)로", main.dialogue_choice == 1) and ok

	_send_key(main, KEY_W)
	await get_tree().process_frame
	ok = _check("W 키(move_up) 실제 입력 -> 커서가 0번(쓴다)으로 복귀", main.dialogue_choice == 0) and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키(interact) 실제 입력 -> 대화 닫힘", not main.dialogue_open) and ok
	ok = _check("부활의 깃털 1개 소모(2->1)", GameState.revive_potions == 1) and ok
	ok = _check("체력이 0이 아니라 되살아남(50% 이상)", player.health >= int(player.max_health * 0.5)) and ok
	ok = _check("트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_revive_no() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.revive_potions = 2
	GameState.exp = 1000
	GameState.next_exp = 1000
	var player: CharacterBody2D = main.get_node("Player")
	_kill_player(main, player)
	await get_tree().process_frame

	_send_key(main, KEY_S)
	await get_tree().process_frame
	var ok := _check("S 키 실제 입력 -> 커서가 1번(쓰지 않는다)", main.dialogue_choice == 1)

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키 실제 입력 -> 대화 닫힘", not main.dialogue_open) and ok
	ok = _check("부활의 깃털 안 씀(2 그대로)", GameState.revive_potions == 2) and ok
	ok = _check("사망 페널티 적용(경험치 감소)", GameState.exp < 1000) and ok
	ok = _check("체력은 최대로 회복(마을 복귀 처리)", player.health == player.max_health) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
