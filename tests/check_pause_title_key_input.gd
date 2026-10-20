extends Node
## docs/STATUS.md "다음 후보"(81번): 일시정지 화면 KEY_2(타이틀로)는 지금까지
## HUD/MobileControls의 Title 버튼(check_mobile_title_click.gd)만 마우스
## 클릭으로 검증됐고, main.gd:_unhandled_input의 키보드 KEY_2 분기는 실제
## InputEventKey 입력으로 검증된 적이 없었다. get_tree().change_scene_to_file()
## 이 검사 트리 자체를 갈아치우므로(check_mobile_title_click.gd와 동일한
## 이유) 키 입력 *전에* 모든 사전조건을 확인해 RESULT를 먼저 찍고, 키 입력은
## 마지막 동작으로만 둔다 — 입력 이후 이 스크립트가 계속 산다는 보장이 없다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main.set_pause_open(true)
	await get_tree().process_frame
	var ok := _check("일시정지 화면 열림(사전조건)", main.pause_open and get_tree().paused)
	print("RESULT ", "PASS" if ok else "FAIL")

	# 실측(check_mobile_title_click.gd와 동일): _unhandled_input() 호출
	# 안에서 change_scene_to_file()이 이 검사 트리(=현재 씬)를 이미 갈아
	# 치운다 — 그 다음 줄에서 self.get_tree()를 부르면 "Parameter data.tree
	# is null"로 죽는다(이 노드가 이미 트리에서 빠짐). 그래서 키 입력
	# 이후에는 self로 아무 상태도 확인하지 않는다 — 입력까지 도달했다는
	# 것 자체가 검증이다.
	_send_key(main, KEY_2)

	# title.tscn이 이제 정상적으로 켜져 헤드리스 프로세스가 끝없이 돌게 된다
	# — self는 이미 트리 밖이라 get_tree()를 못 쓰므로 전역 MainLoop로 끝낸다.
	# 여기서 한 프레임을 더 기다리면 이 코루틴이 다시는 재개되지 않는다
	# (check_mobile_title_click.gd 실측과 동일).
	(Engine.get_main_loop() as SceneTree).quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
