extends Node
## 대장간 창 터치 선택(터치 지시 2/3) GUI 확인용. 두 번째 줄을 탭해서 선택이
## 옮겨간 화면 1장, 같은 줄을 다시 탭해 강화 시도까지 확정된 화면 1장을
## 찍어 사람이 직접 눈으로 본다(⑥ 규칙, shot_inventory_touch_select.gd와 동일 패턴).

## check_forge_touch_select.gd와 같은 이유로 복사하지 않고 프리로드로 읽는다.
const _Main := preload("res://scripts/main.gd")
const FORGE_LIST_START_LINE := _Main.FORGE_LIST_START_LINE


func _row_center(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Forge/Info")
	var rect := info.get_global_rect()
	var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
	var y := rect.position.y + (FORGE_LIST_START_LINE + row) * line_height + line_height / 2.0
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
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	GameState.inventory = ["철검", "구리 반지", "정령의 부적"]
	main._toggle_forge()
	await get_tree().process_frame

	await _click(main, _row_center(main, 2))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://forge_touch_select.png")
	print("SHOT forge_touch_select selected_index=", main.forge_index)

	await _click(main, _row_center(main, 2))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://forge_touch_confirm.png")
	print("SHOT forge_touch_confirm stones=", GameState.materials[GameState.MATERIAL], " gold=", GameState.gold)

	get_tree().quit()
