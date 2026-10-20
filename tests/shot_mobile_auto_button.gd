extends Node
## AUTOHUNT_DESIGN.md §8 "실제 게임 실행(GUI) 스크린샷" 확인용 - 모바일
## Auto 버튼이 다른 버튼과 안 겹치고 화면에 잘 보이는지, 눌렀을 때
## button_pressed 표시가 실제로 바뀌는지 눈으로 확인한다.

func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://mobile_auto_button_off.png")

	var auto_button: Button = mobile.get_node("Auto")
	await _click(auto_button)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://mobile_auto_button_on.png")

	print("SHOT mobile_auto_button auto_hunt=", main.get_node("Player").auto_hunt,
		" button_pressed=", auto_button.button_pressed, " visible=", auto_button.visible)
	get_tree().quit()
