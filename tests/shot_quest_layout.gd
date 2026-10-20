extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Quest 최악 데이터
## 데스크톱/모바일 각 1장. check_quest_layout.gd과 같은 최악 데이터(가장 긴 이야기
## 문구 + 가장 늦은 의뢰, 수락 전/진행 중 각각)를 찍는다.
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("quest")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://quest_layout_%s_desktop.png" % tag)
	print("SHOT quest_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("quest")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://quest_layout_%s_mobile.png" % tag)
	print("SHOT quest_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	GameState.quest_stage = 60
	GameState.bounty_index = GameState.BOUNTIES.size() - 1
	GameState.bounty_taken = false
	main._toggle_quest()
	await get_tree().process_frame
	await _shot(main, mc, "accept")

	GameState.bounty_taken = true
	GameState.bounty_progress = 0
	main._refresh_quest()
	await get_tree().process_frame
	await _shot(main, mc, "progress")

	get_tree().quit()
