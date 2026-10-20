extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Dialogue 최악
## 데이터(전직 3선택지, 그리고 9장의 줄바꿈 없는 긴 나레이션) 데스크톱/모바일 각 1장.
## check_dialogue_layout.gd과 같은 최악 데이터를 씀.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("dialogue")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://dialogue_layout_%s_desktop.png" % tag)
	print("SHOT dialogue_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("dialogue")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://dialogue_layout_%s_mobile.png" % tag)
	print("SHOT dialogue_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	main._play_dialogue([
		["elder", "이 마을에는 세 갈래의 길이 있다.", [
			["전사 - 강인한 근접 전투", "job_warrior"],
			["마법사 - 강력한 원소 마법", "job_mage"],
			["도적 - 빠른 연속 공격", "job_rogue"],
		]],
	])
	await get_tree().process_frame
	await _shot(main, mc, "choices3")

	main._play_dialogue(Story.CHAPTERS[9])
	await get_tree().process_frame
	await _shot(main, mc, "chapter9")

	get_tree().quit()
