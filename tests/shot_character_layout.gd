extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Character 최악
## 데이터(전직 탭, 2차 전직까지 해금돼 목록이 가장 긴 상태) 데스크톱/모바일 각 1장.
## check_character_layout.gd과 같은 최악 데이터를 씀.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.level = GameState.SECOND_JOB_UNLOCK_LEVEL
	GameState.chapter = GameState.SECOND_JOB_UNLOCK_CHAPTER
	GameState.job = "warrior"
	GameState.second_job = ""
	GameState.perk_picks = 12

	main._toggle_character()
	main.character_mode = "job"
	main.job_index = GameState.JOB_NAMES.size() + GameState.SECOND_JOB_BRANCHES.get(GameState.job, []).size() - 1
	main._refresh_character()
	await get_tree().process_frame

	var mc := main.get_node("HUD/MobileControls")
	mc._toggle_controls()
	mc.set_modal_mode("character")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://character_layout_desktop.png")
	print("SHOT character_layout_desktop controls_hidden=", mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("character")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://character_layout_mobile.png")
	print("SHOT character_layout_mobile controls_hidden=", mc.controls_hidden)

	get_tree().quit()
