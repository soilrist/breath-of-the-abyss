extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Storage 최악 데이터
## 데스크톱/모바일 각 1장. check_storage_layout.gd과 같은 최악 데이터(가방·창고
## 둘 다 EQUIPMENT 최장 이름으로 6칸 채움 + 착용 표기)에 더해 실패 메시지가
## Storage/Notice에 실제로 뜬 상태(창고 가득 참)를 찍는다.
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("storage")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://storage_layout_%s_desktop.png" % tag)
	print("SHOT storage_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("storage")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://storage_layout_%s_mobile.png" % tag)
	print("SHOT storage_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name

	GameState.inventory.clear()
	GameState.storage.clear()
	GameState.level = 99
	for i in 8:
		GameState.add_item(longest)
	GameState.equip(longest)
	GameState.enhance_levels[GameState.item_uid[0]] = 10
	for i in 8:
		GameState.storage.append(longest)
	GameState.sync_uids()

	main._toggle_storage()
	main.storage_side = "bag"
	main.storage_index = 0
	main._refresh_storage()
	await get_tree().process_frame
	await _shot(main, mc, "full")

	# 창고가 가득 찬 상태에서 넣기를 시도해 실패 메시지(Notice)가 뜬 상태.
	for i in GameState.STORAGE_MAX - GameState.storage.size():
		GameState.storage.append("가죽 갑옷")
	GameState.sync_uids()
	main._refresh_storage()
	main._move_storage()
	await get_tree().process_frame
	await _shot(main, mc, "notice")

	get_tree().quit()
