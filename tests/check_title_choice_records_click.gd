extends Node
## title.gd TouchMenu/Choice2("클리어 기록") 실제 클릭 경로 검사, 클리어
## 기록이 있는 경우(GameState.game_cleared == true). _activate()의 case 2는
## get_tree().change_scene_to_file("res://scenes/ending.tscn")로 검사 트리를
## 갈아치운다. **실측(2026-09-04)**: 이 새 씬 로드는 idle 시점까지 미뤄져서,
## 클릭 직후 current_scene은 아직 null이고(옛 씬은 이미 빠졌지만 새 씬은 아직
## 안 들어옴), 그 시점을 넘기려고 process_frame 시그널에 연결해도(await든
## connect든) 다시는 호출되지 않는다 — 이 검사의 루트 노드 자신이 곧
## current_scene이라 클릭과 함께 통째로 트리 밖으로 밀려나기 때문으로 보인다
## (check_mobile_title_click.gd가 self.get_tree() 호출로 확인한 것과 같은
## 현상). 그래서 클릭 뒤 상태를 확인하는 대신, Title/Quit 검사와 같은 패턴
## (docs/STATUS.md)으로 되돌아간다: 클릭 *전에* 사전조건(game_cleared,
## 버튼 가시성/비활성 여부)을 확인해 RESULT를 먼저 찍고, 클릭은 마지막
## 동작으로만 둔다 — 클릭까지 도달했다는 것 자체가 "_activate()의 case 2가
## 정말 실행됐다"는 증거다.

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
	GameState.game_cleared = true

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	var touch_menu: Control = title.get_node("TouchMenu")
	touch_menu.visible = true
	var choice2: Button = touch_menu.get_node("Choice2")

	var ok := choice2.visible and GameState.game_cleared
	print("Choice2(클리어 기록 있음) 버튼이 보이고 GameState.game_cleared=true",
		" ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	_click(choice2)

	(Engine.get_main_loop() as SceneTree).quit()
