extends Node
## 메뉴 탭(감독 2026-09-10) 눈 검수용: 필드 HUD + 7개 탭 창을 스킬 배율 1.0/1.1로 찍는다.
## 실행: godot --resolution 640x480 --path . res://tests/shot_menu_tabs.tscn → user://menu_tabs_*.png

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 40
	GameState.gold = 640
	GameState.inventory = ["철검", "강철 대검", "가죽 갑옷", "사슬 갑옷", "철 투구", "정령의 부적"]
	GameState.stat_points = 5
	GameState.unlocked_maps = ["village","hill","hill_ridge","forest_w","glade","dungeon","cave_deep","harbor","shore","marsh","marsh_deep","ruins_w","tower"]
	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	for scale in [1.0, 1.1]:
		main.hud_skill_scale = scale
		main.hud_stat_scale = 0.7 if scale == 1.1 else 1.0
		main._apply_hud_scale()
		mobile.set_modal_mode("")
		await _shot("menu_tabs_field_%s" % scale)
		for tab in main.MENU_TABS:
			main._menu_open_tab(tab)
			await _shot("menu_tabs_%s_%s" % [tab, scale])
			main._menu_close_current()
			await get_tree().process_frame
	print("SHOT menu_tabs done")
	get_tree().quit()


func _shot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % label)
