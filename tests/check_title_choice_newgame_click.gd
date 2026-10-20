extends Node
## title.gd TouchMenu/Choice0("새 게임") 실제 클릭 경로 검사. _activate()의
## case 0은 GameState.reset() 뒤 get_tree().change_scene_to_file()로 검사
## 트리 자체를 갈아치운다(docs/STATUS.md 80번 참고) — 그래서 클릭 뒤에는
## self.get_tree()를 쓰지 못한다(check_mobile_title_click.gd에서 이미 확인된
## 실측: "Parameter data.tree is null"). 다만 GameState는 오토로드라 트리
## 교체와 무관하게 살아 있으므로, 클릭 뒤에도 GameState 값으로 reset()이
## 정말 실행됐는지 확인할 수 있다. 끝은 Engine.get_main_loop()로 강제 종료.

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
	GameState.level = 5
	GameState.gold = 999
	GameState.pending_load = true

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	var touch_menu: Control = title.get_node("TouchMenu")
	touch_menu.visible = true
	var choice0: Button = touch_menu.get_node("Choice0")

	_click(choice0)

	var ok := GameState.level == 1 and GameState.gold == 0 and not GameState.pending_load
	print("Choice0 클릭 -> GameState.reset() 실행됨(레벨/골드 초기화, pending_load=false)",
		" ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	(Engine.get_main_loop() as SceneTree).quit()
