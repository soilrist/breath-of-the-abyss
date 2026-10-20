extends Node
## ending.gd:_unhandled_input()은 ui_accept/attack 액션이 오면
## _return_to_title()을 부르는데, 기존 check_ending_touchreturn_click.gd는
## TouchReturn 버튼의 pressed 연결만 확인했을 뿐(터치 전용 경로), 키보드로
## 엔딩 화면을 벗어나는 실제 입력 경로(J 키, project.godot의 "attack" 액션
## 물리 키코드 74)는 InputEventKey로 태운 적이 없었다.
## _return_to_title()이 get_tree().change_scene_to_file()로 검사 트리 자체를
## 갈아치우므로, check_ending_touchreturn_click.gd와 같이 클릭(키 입력) 전에
## RESULT를 먼저 찍고 키 입력은 마지막 동작으로만 둔다.

func _ready() -> void:
	var ending: Node = preload("res://scenes/ending.tscn").instantiate()
	add_child(ending)
	await get_tree().process_frame

	var summary: Label = ending.get_node("Summary")
	var ok: bool = summary.text.contains("최종 기록")
	print("엔딩 화면이 정상 로드되어 최종 기록 표시됨", " ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.pressed = true
	ending._unhandled_input(ev)

	(Engine.get_main_loop() as SceneTree).quit()
