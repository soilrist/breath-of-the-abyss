extends Node
## 대장간(강화/제작) 화면 Info 라벨(폭 150px, 폰트 9)에 가장 긴 장비 이름
## (+강화 수치)이 들어간 목록 줄이 패널 폭을 넘는지(가로 유출) 측정한다.
## check_storage_clip.gd(폭 210px, 폰트 7 - 여유 확인됨)와 짝이지만 이
## 화면은 더 큰 폰트+더 좁은 폭이라 별도로 검증한 적이 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name

	GameState.inventory.clear()
	GameState.level = 99
	GameState.add_item(longest)
	GameState.equip(longest)
	GameState.enhance_levels[GameState.item_uid[0]] = 10

	main._toggle_forge()
	main.forge_index = 0
	main._refresh_forge()
	await get_tree().process_frame

	var info: Label = main.get_node("HUD/Forge/Info")
	var font := info.get_theme_default_font()
	var font_size := info.get_theme_font_size("font_size")
	var panel_width: float = info.size.x
	var max_width := 0.0
	var widest_line := ""
	for line in info.text.split("\n"):
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > max_width:
			max_width = w
			widest_line = line
	print("가장 긴 항목: ", longest)
	print("패널 폭(px): ", panel_width)
	print("가장 넓은 줄: '", widest_line, "' 너비(px): ", max_width)
	var ok := max_width <= panel_width
	print("가로 유출 없음(=", ok, ")")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
