extends Node
## 방향키 대신 넣은 동그란 조이스틱이 실제로 어떻게 보이는지 한 장 찍는다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var mc: Control = main.get_node("HUD/MobileControls")
	mc.force_visible = true
	mc.visible = true
	mc.set_modal_mode("")
	var stick: Control = mc.get_node("Joystick")
	stick._update_knob(stick.get_global_rect().get_center() + Vector2(14, 10))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://joystick_shot.png")
	print("SHOT joystick")
	get_tree().quit()
