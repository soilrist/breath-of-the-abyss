extends Node
## 재료 개수가 커져서 요약 줄이 줄바꿈될 때, clip_text 때문에 아이템 목록
## 줄이 실제로 화면(패널 높이) 밖으로 밀려 잘리는지 측정한다.
## Label.get_line_count() 로 렌더링된 줄 수를, 패널 높이/줄높이로 보이는
## 줄 수를 계산해 비교한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.inventory.clear()
	for i in 10:
		GameState.inventory.append("회복약")
	GameState.gold = 999999999
	# 재료 숫자를 최대치 근처로 키운다 - clip 재현 조건.
	GameState.materials[GameState.MATERIAL] = 99
	GameState.materials[GameState.BOSS_FRAGMENT] = 999
	GameState.enhance_wards = 9

	main._toggle_inventory()
	main.inventory_index = 9
	main._refresh_inventory()
	await get_tree().process_frame

	var info: Label = main.get_node("HUD/Inventory/Info")
	var line_count := info.get_line_count()
	var line_height := info.get_theme_default_font().get_height(info.get_theme_font_size("font_size"))
	var panel_height: float = info.size.y
	var visible_lines := int(panel_height / line_height) if line_height > 0 else -1
	print("실제 렌더 줄 수: ", line_count)
	print("줄 높이(px): ", line_height)
	print("패널 높이(px): ", panel_height)
	print("패널에 다 들어가는 줄 수(추정): ", visible_lines)
	print("텍스트 전체:\n", info.text)
	var ok := line_count <= visible_lines
	print("클리핑 없음(=", ok, ")")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
