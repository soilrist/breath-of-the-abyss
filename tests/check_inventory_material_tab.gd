extends Node
## (감독 2026-09-10) 인벤토리 [재료] 탭: 강화석·파편·부적·전직의 돌·탑 결정·마법돌·
## 지역 제작 아이템이 그림+개수로 보이고, ←→/탭 버튼/탭 줄 터치로 전환되는지.
## 창 없이 돌리면 PNG는 건너뛰고 판정만 본다.
var ok := true


func _check(label: String, cond: bool) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", label])
	ok = ok and cond


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open:
		main._advance_dialogue()
	GameState.gold = 12345
	GameState.materials[GameState.MATERIAL] = 99999
	GameState.materials[GameState.BOSS_FRAGMENT] = 77
	GameState.enhance_wards = 5
	GameState.materials[GameState.JOB_STONE_MAGE] = 3
	GameState.tower_material_counts["hell"] = 42
	GameState.stone_inventory["용의눈"] = 9
	GameState.add_item("용의 비늘")
	GameState.add_item("용의 비늘")
	var mob: Node = main.get_node("HUD/MobileControls")
	mob.force_visible = true
	mob.visible = true
	main._toggle_inventory()
	await get_tree().process_frame
	var info: Label = main.get_node("HUD/Inventory/Info")
	_check("처음엔 [장비] 탭", main.inventory_tab == "items" and info.text.contains("[장비]"))
	_check("모바일 탭 버튼이 인벤토리에서 보임", mob.get_node("Sell").visible)
	await _shot("user://shot_inventory_items_tab.png")

	# 모바일 탭 버튼 → 재료 탭
	mob._toggle_shop_tab()
	await get_tree().process_frame
	_check("탭 버튼으로 [재료] 탭 전환", main.inventory_tab == "materials" and info.text.contains("[재료]"))
	_check("강화석 99999개 표시", info.text.contains("강화석  99999개"))
	_check("착용 버튼 숨김", not mob.get_node("Interact").visible)
	var icon: TextureRect = main.get_node("HUD/Inventory/Icon")
	_check("재료 아이콘 있음", icon.visible and icon.texture != null and icon.texture.resource_path.ends_with("mat_enhance.png"))
	_check("상세에 보유 개수", main.get_node("HUD/Inventory/Detail").text.contains("보유 99999개"))
	_check("Info 줄바꿈 없음(헤더 3줄+목록 4줄+더 1줄=8줄)", info.get_line_count() == 8)
	await _shot("user://shot_inventory_material_tab.png")

	# 전체 줄 순회: 개수·아이콘 전부 확인
	var rows: Array = main._material_rows()
	_check("재료 줄 28개(3+3+5+7+6+4)", rows.size() == 28)
	var expect := {"보스의 파편": 77, "파괴 방지 부적": 5, "전직의 돌(마법사)": 3, "겁화의 결정": 42, "용의눈": 9, "용의 비늘": 2}
	var icons := {}
	for i in rows.size():
		main.material_index = i
		main._refresh_inventory()
		var row: Dictionary = rows[i]
		if expect.has(row["name"]):
			_check("%s %d개" % [row["name"], expect[row["name"]]], row["count"] == expect[row["name"]]
				and info.text.contains("▶ %s  %d개" % [row["name"], expect[row["name"]]]))
		if icon.texture == null:
			_check("%s 아이콘 없음" % row["name"], false)
		else:
			icons[icon.texture.resource_path] = true
		if info.get_line_count() > 8:
			_check("%s 줄에서 줄바꿈 발생" % row["name"], false)
	_check("아이콘 28개 전부 서로 다름", icons.size() == 28)
	main.material_index = 20
	main._refresh_inventory()
	await _shot("user://shot_inventory_material_tab_job.png")

	# 탭 줄 터치 → 장비 탭으로 복귀
	var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
	var tab_pos := Vector2(info.position.x + 10.0, info.position.y + line_height * 1.5)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = tab_pos
	touch.index = 0
	main._on_inventory_gui_input(touch)
	await get_tree().process_frame
	_check("탭 줄 터치로 [장비] 탭 복귀", main.inventory_tab == "items" and info.text.contains("[장비]"))
	_check("착용 버튼 다시 보임", mob.get_node("Interact").visible)

	# 키보드 ←→ 전환 + ↑↓ 이동
	main._switch_inventory_tab()
	main.material_index = 0
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	main._unhandled_input(down)
	_check("↓로 재료 선택 이동", main.material_index == 1)
	# 4번째 줄(전직의 돌(전사)) 터치 선택
	main.material_index = 0
	main._refresh_inventory()
	touch.position = Vector2(tab_pos.x, info.position.y + line_height * 6.5)
	main._on_inventory_gui_input(touch)
	_check("재료 줄 터치 선택(4번째 = 전직의 돌(전사))", main.material_index == 3 and rows[3]["name"] == GameState.JOB_STONE_WARRIOR)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _shot(path: String) -> void:
	# headless에선 frame_post_draw가 안 와서 영원히 멈춘다 → 판정만 보고 PNG 건너뜀.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("SHOT ", ProjectSettings.globalize_path(path))
