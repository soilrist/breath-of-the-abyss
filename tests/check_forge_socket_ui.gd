extends Node
## 대장간 화면에서 실제로 좌우로 강화/소켓 탭을 바꾸고, 숫자키로 돌을 박거나
## Z로 확정 강화를 쓸 수 있는지 확인한다. main.tscn 을 띄워 실제 입력 경로를
## 그대로 탄다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.level = 20
	GameState.inventory = ["강철 대검"]
	GameState.add_stone("홍옥", 1)
	GameState.gold = 999999
	GameState.materials[GameState.MATERIAL] = 99
	var ok := true

	main._toggle_forge()
	ok = _check("대장간 열림", main.forge_open) and ok
	ok = _check("기본 모드는 강화", main.forge_mode == "enhance") and ok

	var uid: int = GameState.item_uid[0]
	var before_enhance: int = GameState.enhance_of("강철 대검", uid)
	_send_key(main, KEY_Z)
	ok = _check("Z 실제 키 입력으로 확정 강화 성공", GameState.enhance_of("강철 대검", uid) == before_enhance + 1) and ok

	_send_key(main, KEY_D)
	ok = _check("D로 소켓 탭 전환", main.forge_mode == "socket") and ok
	ok = _check("소켓 탭 안내문에 숫자키 문구 표시", main.get_node("HUD/Forge/Detail").text.contains("숫자키")) and ok

	_send_key(main, KEY_1)
	ok = _check("숫자 1로 소켓 성공", GameState.sockets_used("강철 대검") == 1) and ok
	ok = _check("돌 재고 차감됨", int(GameState.stone_inventory.get("홍옥", 0)) == 0) and ok

	_send_key(main, KEY_A)
	ok = _check("A로 다시 강화 탭 전환", main.forge_mode == "enhance") and ok

	main._toggle_forge()
	ok = _check("닫힘", not main.forge_open) and ok

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
