extends Node
## 인벤토리 창 터치 선택(§ INBOX 2026-09-05 아이폰 실기 지시) GUI 확인용.
## 두 번째 줄을 탭해서 선택이 옮겨간 화면 1장, 같은 줄을 다시 탭해
## 착용까지 확정된 화면 1장을 찍어 사람이 직접 눈으로 본다(⑥ 규칙).

func _row_center(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Inventory/Info")
	var rect := info.get_global_rect()
	var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
	var y := rect.position.y + (3 + row) * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


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
	GameState.level = 20
	GameState.inventory = ["철검", "정령의 부적", "구리 반지", "용린 갑주"]
	main._toggle_inventory()
	await get_tree().process_frame

	await _click(main, _row_center(main, 2))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://inventory_touch_select.png")
	print("SHOT inventory_touch_select selected_index=", main.inventory_index)

	await _click(main, _row_center(main, 2))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://inventory_touch_confirm.png")
	print("SHOT inventory_touch_confirm equipped=", GameState.is_equipped_at(2), " notice=", main.get_node("HUD/Inventory/Notice").text)

	get_tree().quit()
