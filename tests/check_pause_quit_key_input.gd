extends Node
## docs/STATUS.md "다음 후보"(81번): 일시정지 화면 KEY_9(게임 종료)는 지금까지
## HUD/MobileControls의 Quit 버튼(check_mobile_quit_click.gd)만 마우스
## 클릭으로 검증됐고, main.gd:_unhandled_input의 키보드 KEY_9 분기는 실제
## InputEventKey 입력으로 검증된 적이 없었다. RESULT는 키 입력 전에 이미
## 찍어 둔다. 입력 뒤 프로세스가 종료 코드 0으로 끝나는 것 자체가
## "get_tree().quit()이 정말 호출됐다"는 증거다 — 혹시 회귀로 quit()이 안
## 불렸다면 몇 프레임 뒤 워치독이 FAIL로 강제 종료해 run_validation.sh가
## 무한 대기하지 않게 한다.

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

	_send_key(main, KEY_9)

	# 여기 도달했다는 건 get_tree().quit()이 이번 호출 안에서 안 불렸다는 뜻
	# (정상이라면 프로세스가 위 입력 처리 도중 종료를 예약하고 곧 죽는다) —
	# 워치독으로 FAIL 처리하고 직접 끝내 무한 대기를 막는다.
	for i in range(5):
		await get_tree().process_frame
	print("RESULT FAIL - KEY_9 입력 후에도 프로세스가 종료되지 않음(워치독)")
	get_tree().quit(1)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
