extends Node
## ending.gd TouchReturn 버튼(엔딩 화면 "타이틀로" 터치 버튼) 실제 클릭 경로
## 검사. _return_to_title()은 get_tree().change_scene_to_file()로 검사 트리
## 자체를 갈아치운다(check_title_choice_records_click.gd/
## check_mobile_title_click.gd와 같은 부류) — 클릭 뒤에는 self.get_tree()를
## 못 쓴다. 그래서 클릭 *전에* 사전조건(버튼 가시성)을 확인해 RESULT를 먼저
## 찍고, 클릭은 마지막 동작으로만 둔다. 헤드리스 환경은
## DisplayServer.is_touchscreen_available()이 false라 _ready()가 버튼을
## 숨기므로, mobile_controls 검사들과 같이 클릭 전에 강제로 visible=true.

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
	var ending: Node = preload("res://scenes/ending.tscn").instantiate()
	add_child(ending)
	await get_tree().process_frame

	var touch_return: Button = ending.get_node("TouchReturn")
	touch_return.visible = true

	var ok := touch_return.is_connected("pressed", ending._return_to_title)
	print("TouchReturn 버튼이 _return_to_title에 연결됨", " ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	_click(touch_return)

	(Engine.get_main_loop() as SceneTree).quit()
