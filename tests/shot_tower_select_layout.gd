extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — TowerSelect 최악
## 데이터 데스크톱/모바일 각 1장. check_tower_select_layout.gd과 같은 최악 데이터
## (전부 해금 + 마지막 칸 "[99/100층]", 그리고 hard 잠긴 채 hell 선택).
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("tower_select")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://tower_select_layout_%s_desktop.png" % tag)
	print("SHOT tower_select_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("tower_select")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://tower_select_layout_%s_mobile.png" % tag)
	print("SHOT tower_select_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	GameState.game_cleared = true
	GameState.tower_progress = {"easy": 100, "normal": 100, "hard": 100, "hell": 100, "abyss": 99}
	main.tower_select_index = 4
	main._toggle_tower_select()
	await get_tree().process_frame
	await _shot(main, mc, "unlocked")
	main._toggle_tower_select()

	GameState.tower_progress = {"easy": 100, "normal": 100, "hard": 0, "hell": 0, "abyss": 0}
	main.tower_select_index = 3
	main._toggle_tower_select()
	await get_tree().process_frame
	await _shot(main, mc, "locked")
	main._toggle_tower_select()

	get_tree().quit()
