extends Node
## STATUS.md "다음 후보"가 남긴 것: attack(J/Space)와 dash(Q)는
## main._unhandled_input() 콜백이 아니라 player.gd:_physics_process가
## 매 프레임 Input.is_action_just_pressed("attack"/"dash")로 직접
## 폴링한다(player.gd:162~165). 기존 검사(integration_test.gd)는
## player.attack()/player.try_dodge()를 코드로 직접 호출할 뿐 실제
## 물리 키 입력이 Input 싱글톤을 거쳐 폴링되는 경로를 태운 적이 없었다.
## shot_chapter1_boss.gd와 동일하게 Input.parse_input_event()로 진짜
## InputEventKey를 주입하고 physics_frame을 한 번 넘겨 결과를 확인한다.

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
	ok = (await _check_attack()) and ok
	ok = (await _check_dash()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_attack() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := _check("전투 전 공격 쿨타임 0", player.cooldown_time == 0.0)

	await _tap_key(KEY_J)
	ok = _check("J 키(attack) 실제 입력으로 공격 쿨타임 발생", player.cooldown_time > 0.0) and ok

	main.queue_free()
	return ok


func _check_dash() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := _check("구르기 전 무적시간 0", player.invulnerability_time == 0.0)
	var start_pos: Vector2 = player.global_position

	await _tap_key(KEY_Q)
	ok = _check("Q 키(dash) 실제 입력으로 무적시간 발생", player.invulnerability_time > 0.0) and ok
	ok = _check("Q 키(dash) 실제 입력으로 위치 이동", player.global_position != start_pos) and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
