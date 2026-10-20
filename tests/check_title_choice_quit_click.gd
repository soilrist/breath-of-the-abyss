extends Node
## title.gd TouchMenu/Choice3("종료") 실제 클릭 경로 검사. _activate()의
## case 3은 get_tree().quit()으로 프로세스 자체를 끝낸다 — 다른 Choice
## 검사들처럼 "한 트리에서 여러 버튼을 순서대로 클릭"하는 패턴을 못 쓴다
## (docs/STATUS.md, check_mobile_quit_click.gd와 동일한 이유). RESULT는
## 클릭 전에 이미 찍어 둔다. 클릭 뒤 프로세스가 종료 코드 0으로 끝나는 것
## 자체가 "_activate()의 case 3이 정말 호출됐다"는 증거다 — 혹시 버튼이
## 씹혀 quit()이 안 불렸다면(회귀) 몇 프레임 뒤 워치독이 FAIL로 강제 종료해
## run_validation.sh가 무한 대기하지 않게 한다.

func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)


func _ready() -> void:
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	var touch_menu: Control = title.get_node("TouchMenu")
	touch_menu.visible = true
	var choice3: Button = touch_menu.get_node("Choice3")

	var ok := choice3.visible
	print("Choice3(종료) 버튼이 보임", " ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	_click(choice3)

	# 여기 도달했다는 건 get_tree().quit()이 이번 프레임 안에 안 불렸다는 뜻
	# (정상이라면 프로세스가 위 클릭 처리 도중 종료를 예약하고 곧 죽는다) —
	# 워치독으로 FAIL 처리하고 직접 끝내 무한 대기를 막는다.
	for i in range(5):
		await get_tree().process_frame
	print("RESULT FAIL - Choice3 클릭 후에도 프로세스가 종료되지 않음(워치독)")
	get_tree().quit(1)
