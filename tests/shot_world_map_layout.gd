extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — WorldMap 최악 데이터
## 데스크톱/모바일 각 1장. check_world_map_layout.gd과 같은 최악 데이터(지역이
## 가장 많은 챕터, 커서를 목록 가운데로 두어 "더보기" 줄까지 나오게 함).
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("map")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://world_map_layout_%s_desktop.png" % tag)
	print("SHOT world_map_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("map")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://world_map_layout_%s_mobile.png" % tag)
	print("SHOT world_map_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	for k in World.AREAS.keys():
		GameState.unlock_map(str(k))
	var mc := main.get_node("HUD/MobileControls")
	mc.force_visible = true

	main._toggle_world_map()
	await get_tree().process_frame
	var graph = main.get_node("HUD/WorldMap/Graph")
	# 최악 데이터: 지역이 가장 많은 챕터, 커서를 가운데로 둬 "더보기" 줄까지 나오게.
	var best_ch := 1
	var best_n := 0
	for ch in range(1, graph.max_chapter() + 1):
		var n = graph.order_for_chapter(ch).size()
		if n > best_n:
			best_n = n
			best_ch = ch
	var list: Array = graph.order_for_chapter(best_ch)
	GameState.current_map = list[1]
	graph.chapter = best_ch
	graph.cursor = 1
	graph._refresh()
	await get_tree().process_frame
	await _shot(main, mc, "worst")
	main._toggle_world_map()

	get_tree().quit()
