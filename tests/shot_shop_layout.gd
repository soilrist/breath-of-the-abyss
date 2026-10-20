extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Shop 최악 데이터
## 데스크톱/모바일 각 1장. check_shop_layout.gd과 같은 최악 데이터를 씀
## (구매탭: 챕터 최대·골드 0, 판매탭: 소켓 3/3 채운 "천공의 인장" 착용 중).
## 감독 보정(2026-09-06 06:55): buy_broke/sell_worn은 이름과 달리 실제
## 구매·판매를 누르지 않아 Notice 문구가 화면에 안 보였다 — 캡처 전에
## _activate_selected_shop_item()으로 실제 실패를 일으켜 Notice가 뜬
## 상태를 찍는다.

func _shot(main: Node, mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("shop")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shop_layout_%s_desktop.png" % tag)
	print("SHOT shop_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("shop")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shop_layout_%s_mobile.png" % tag)
	print("SHOT shop_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	GameState.chapter = 99
	GameState.gold = 0
	main._open_shop()
	main.shop_mode = "buy"
	main.shop_index = 0
	main._refresh_shop()
	main._activate_selected_shop_item()
	await get_tree().process_frame
	await _shot(main, mc, "buy_broke")

	GameState.gold = 999999
	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	GameState.sync_uids()
	var sky_seal_uid: int = GameState.uid_of("천공의 인장")
	GameState.socketed[sky_seal_uid] = ["홍옥", "벽옥", "황옥"]
	GameState.equipped["trinket"] = "천공의 인장"
	GameState.equipped_uid["trinket"] = sky_seal_uid
	main.shop_mode = "sell"
	main.shop_index = equipment_names.find("천공의 인장")
	main._refresh_shop()
	main._activate_selected_shop_item()
	await get_tree().process_frame
	await _shot(main, mc, "sell_worn")

	get_tree().quit()
