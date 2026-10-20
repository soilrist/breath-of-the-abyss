extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Perk 최악 데이터
## 데스크톱/모바일 각 1장. check_perk_layout.gd과 같은 최악 데이터(이름·설명이
## 가장 긴 특성 둘 포함 + 셋 다 보유 스택 표기)를 찍는다.
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("perk")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://perk_layout_%s_desktop.png" % tag)
	print("SHOT perk_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("perk")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://perk_layout_%s_mobile.png" % tag)
	print("SHOT perk_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	GameState.perks.clear()
	for key in ["font", "focus", "guard"]:
		GameState.perks[key] = 9
	GameState.perk_offer = ["font", "focus", "guard"]
	GameState.perk_picks = 1
	main.perk_index = 0
	main._open_perk_choice()
	await get_tree().process_frame
	await _shot(mc, "full")

	get_tree().quit()
