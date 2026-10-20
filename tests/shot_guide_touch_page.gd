extends Node
## 가이드 쪽넘김 터치 고침(INBOX 결함 08:40) GUI 확인용. 오른쪽 탭으로
## 다음 쪽(2/11)까지 넘어간 화면을 데스크톱·모바일 각 1장 찍어 사람이
## 직접 눈으로 겹침/잘림/자리표시를 확인한다(shot_forge_touch_select.gd 패턴).

func _click(main: Node, pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	main.get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	main.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	main._toggle_guide()
	await get_tree().process_frame

	var panel: Control = main.get_node("HUD/Guide")
	var right_pos := panel.get_global_rect().position + Vector2(panel.size.x * 0.75, panel.size.y * 0.5)
	await _click(main, right_pos)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://guide_touch_page_desktop.png")
	print("SHOT guide_touch_page_desktop guide_page=", main.guide_page)

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("guide")
	await get_tree().process_frame

	await _click(main, right_pos)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://guide_touch_page_mobile.png")
	print("SHOT guide_touch_page_mobile guide_page=", main.guide_page)

	get_tree().quit()
