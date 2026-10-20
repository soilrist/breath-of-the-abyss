extends Node
## HUD/MobileControls의 Title 버튼은 check_mobile_button_click.gd가 일부러
## 빼뒀다(get_tree().change_scene_to_file()로 검사 트리 자체를 갈아치우므로
## 그때까지 쓰던 "한 트리에서 여러 버튼을 순서대로 클릭" 패턴을 못 쓴다,
## docs/STATUS.md 참고). 여기서는 Title 클릭을 마지막 동작으로만 두고,
## 클릭 *전에* 모든 사전조건(pause_open, 버튼 가시성)을 확인해 RESULT를
## 먼저 찍은 뒤 클릭한다 — 클릭 이후 이 스크립트가 계속 산다는 보장이 없다
## (change_scene_to_file이 이 검사 트리 자체를 replace한다). 화면 전환
## 자체(title.tscn 로드)는 check_touch_button_input.gd류가 이미 title.tscn
## 쪽에서 확인한다.

func _click_down(button: Button) -> void:
	# check_mobile_button_click.gd와 동일한 이유로 get_viewport().push_input()을
	# 쓴다: project.godot의 window/stretch/mode="canvas_items"가 320x240
	# 논리 뷰포트를 확대하므로 Input.parse_input_event()로는 stretch 변환을
	# 안 타 좌표가 어긋난다.
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame


func _click_up(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


## Button.pressed는 push_input() 호출 자체 안에서 동기적으로 발생한다(다음
## 프레임까지 기다릴 필요가 없다) — Pause/Close 같은 비파괴적 버튼은 실제
## 사람 클릭에 더 가깝게 down/up 사이에 프레임을 끼워 넣지만, 트리를 죽이는
## 버튼은 그 프레임 경계를 넘기지 않고 바로 결과를 확인해야 한다(아래 참고).
func _click_now(button: Button) -> void:
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
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	while game.dialogue_open: game._advance_dialogue()
	await get_tree().process_frame

	var mobile := game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var pause_button: Button = mobile.get_node("Pause")
	await _click_down(pause_button)
	await _click_up(pause_button)
	var ok := _check("Pause 클릭으로 일시정지가 열림", game.pause_open and get_tree().paused)

	var title_button: Button = mobile.get_node("Title")
	ok = _check("Title 버튼이 일시정지 화면에서 보임", title_button.visible) and ok
	print("RESULT ", "PASS" if ok else "FAIL")

	# 실측(2026-09-04): push_input()으로 Title을 누르면 change_scene_to_file()
	# 이 이 검사 트리(=현재 씬)를 push_input() 리턴 전에 이미 갈아치운다 —
	# 그 다음 줄에서 self.get_tree()를 부르면 "Parameter data.tree is null"
	# 로 죽는다(이 노드가 이미 트리에서 빠짐). 그래서 클릭 뒤에는 self로
	# 아무 상태도 확인하지 않는다 — 클릭까지 도달했다는 것 자체가 검증이다
	# (docs/STATUS.md "클릭하면 정말 그 함수가 불렸다까지만 확인" 참고).
	_click_now(title_button)

	# title.tscn이 이제 정상적으로 켜져 헤드리스 프로세스가 끝없이 돌게 된다
	# — self는 이미 트리 밖이라 get_tree()를 못 쓰므로 전역 MainLoop로 끝낸다.
	# 실측: 여기서 한 프레임(await process_frame)을 더 기다리면 이 코루틴이
	# 다시는 재개되지 않고 그대로 멈춘다(트리 밖으로 밀려난 노드는 프레임
	# 신호로 깨어나지 못하는 것으로 보임) — 그래서 기다리지 않고 바로 끝낸다.
	# 종료 시 리소스 누수 경고가 몇 줄 남지만 run_validation.sh가 보는
	# "SCRIPT ERROR|Parse Error|Assertion failed|Failed to load script"
	# 패턴에는 안 걸린다.
	(Engine.get_main_loop() as SceneTree).quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
