extends Node
## STATUS.md "다음 후보" 102번: 대장간(smith)/창고(keeper) 패널은
## `_interact_npc()`(main.gd:700 부근)가 가장 가까운 NPC를 골라 여는데,
## 기존 검사(check_forge_socket_ui.gd/check_storage_clip.gd/
## check_forge_info_clip.gd)는 전부 main._toggle_forge()/_toggle_storage()를
## 코드로 직접 호출할 뿐, smith/keeper 근처에서 실제 E 키를 눌러 여는 경로는
## 태운 적이 없었다(⑥ 규칙). check_interact_key_input.gd(elder 대화)와 같은
## 패턴으로 실제 InputEventKey(E)를 태워 forge_open/storage_open이 열리는지
## 확인한다. 닫기는 E(interact)가 아니라 I(inventory 액션, main.gd:2708/2731의
## `event.is_action_pressed("inventory")` 분기)라서 그 키로 닫힘도 확인한다.
## _maybe_chatter가 먼저 가로챌 수 있어 heard를 미리 채워 잡담을 건너뛴다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_forge()) and ok
	ok = (await _check_storage()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_forge() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.quest_stage = 0
	main.heard["smith:0"] = true
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position(GameState.current_map, "smith")

	_send_key(main, KEY_E)
	await get_tree().process_frame
	var ok := _check("E 키 입력만으로 대장간 열림", main.forge_open)
	ok = _check("대장간 패널 보임", main.get_node("HUD/Forge").visible) and ok
	ok = _check("대장간 여는 동안 트리 일시정지", get_tree().paused) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키(inventory 액션)로 대장간 닫힘", not main.forge_open) and ok
	ok = _check("대장간 패널 숨김", not main.get_node("HUD/Forge").visible) and ok
	ok = _check("대장간 닫히며 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_storage() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.quest_stage = 0
	main.heard["keeper:0"] = true
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position(GameState.current_map, "keeper")

	_send_key(main, KEY_E)
	await get_tree().process_frame
	var ok := _check("E 키 입력만으로 창고 열림", main.storage_open)
	ok = _check("창고 패널 보임", main.get_node("HUD/Storage").visible) and ok
	ok = _check("창고 여는 동안 트리 일시정지", get_tree().paused) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키(inventory 액션)로 창고 닫힘", not main.storage_open) and ok
	ok = _check("창고 패널 숨김", not main.get_node("HUD/Storage").visible) and ok
	ok = _check("창고 닫히며 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
