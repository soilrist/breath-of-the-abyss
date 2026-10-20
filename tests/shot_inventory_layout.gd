extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Inventory 최악
## 데이터(장비 61종 전부, 마지막 항목은 천공의 인장 3소켓 채움) 데스크톱/모바일
## 각 1장. check_inventory_layout.gd과 같은 최악 데이터를 씀.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.gold = 999999
	GameState.materials[GameState.MATERIAL] = 999
	GameState.materials[GameState.BOSS_FRAGMENT] = 999
	GameState.enhance_wards = 9
	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	GameState.sync_uids()
	var sky_seal_uid: int = GameState.uid_of("천공의 인장")
	GameState.socketed[sky_seal_uid] = ["홍옥", "벽옥", "황옥"]

	main._toggle_inventory()
	main.inventory_index = equipment_names.find("천공의 인장")
	main._refresh_inventory()
	await get_tree().process_frame

	var mc := main.get_node("HUD/MobileControls")
	mc._toggle_controls()
	mc.set_modal_mode("inventory")
	main._refresh_inventory()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://inventory_layout_desktop.png")
	print("SHOT inventory_layout_desktop controls_hidden=", mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("inventory")
	main._refresh_inventory()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://inventory_layout_mobile.png")
	print("SHOT inventory_layout_mobile controls_hidden=", mc.controls_hidden)

	get_tree().quit()
