extends Node
## AUTOHUNT_DESIGN.md §8 "실제 게임 실행(GUI) 스크린샷" 확인용 - 이번 바퀴는
## T키 토글 하나만 있으므로, 실제로 T를 눌렀을 때 HUD 메시지가 화면에
## 보이는지만 눈으로 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var down := InputEventKey.new()
	down.physical_keycode = KEY_T
	down.pressed = true
	main._unhandled_input(down)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_toggle.png")
	print("SHOT auto_hunt_toggle auto_hunt=", main.get_node("Player").auto_hunt, " msg=", main.get_node("HUD/Message").text)
	get_tree().quit()
