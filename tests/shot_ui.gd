extends Node
## 게임 안 UI 패널을 하나씩 열어 스크린샷을 남긴다. 눈으로 검수하기 위한 하네스다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: Node = main.get_node("Player")

	GameState.gold = 640
	GameState.level = 9
	main._apply_equipment_to_player()
	GameState.inventory = ["철검", "강철 대검", "가죽 갑옷", "사슬 갑옷", "철 투구", "정령의 부적"]
	GameState.equip("강철 대검")
	GameState.equip("가죽 갑옷")
	GameState.equip("철 투구")
	main._apply_equipment_to_player()
	GameState.unlocked_maps = ["village","hill","hill_ridge","forest_w","glade","dungeon","cave_deep","harbor","shore","marsh","marsh_deep","ruins_w"]
	GameState.current_map = "forest_w"

	GameState.stat_points = 5
	GameState.stats = {"strength": 4, "agility": 2, "vitality": 6, "will": 1}
	GameState.materials[GameState.MATERIAL] = 12
	GameState.enhance_levels = {"강철 대검": 2}
	GameState.storage = ["철검", "가죽 모자", "구리 반지"]
	await snap(main, "storage", func() -> void: main._toggle_storage())
	GameState.perk_picks = 1
	GameState.perks = {"edge": 2}
	GameState.roll_perk_offer()
	await snap(main, "perk", func() -> void: main._open_perk_choice())
	await snap(main, "forge", func() -> void: main._toggle_forge())
	await snap(main, "character", func() -> void: main._toggle_character())
	await snap(main, "map", func() -> void: main._toggle_world_map())
	await snap(main, "inventory", func() -> void: main._toggle_inventory())
	await snap(main, "shop", func() -> void:
		main.shop_open = true
		main.shop_mode = "buy"
		main.shop_index = 0
		main.get_node("HUD/Shop").visible = true
		main.get_node("HUD/MobileControls").set_modal_mode("shop")
		main._refresh_shop())
	await snap(main, "shop_sell", func() -> void:
		main.shop_open = true
		main.shop_mode = "sell"
		main.shop_index = 0
		main.get_node("HUD/Shop").visible = true
		main.get_node("HUD/MobileControls").set_modal_mode("shop")
		main._refresh_shop())
	await snap(main, "dialogue", func() -> void:
		main._play_dialogue([["elder", "숲에서 마물이 내려오고 있네.\n셋만 솎아 주면 나머지는 물러갈 걸세."]]))
	await snap(main, "dialogue_intro", func() -> void: main._play_dialogue(Story.INTRO))
	await snap(main, "dialogue_boss", func() -> void: main._play_dialogue(Story.BOSS_MEET["frost"]))
	await snap(main, "dialogue_choice", func() -> void:
		main._play_dialogue(Story.BOSS_MEET["captain"])
		main._advance_dialogue()
		main._advance_dialogue())
	await snap(main, "pause", func() -> void: main.set_pause_open(true))
	get_tree().quit()


func snap(main: Node, label: String, open: Callable) -> void:
	open.call()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % label)
	print("SHOT ", label)
	# 다음 패널을 위해 전부 닫는다.
	for panel in ["Inventory", "Shop", "Dialogue", "Pause", "WorldMap", "Character", "Forge", "Storage", "Perk"]:
		main.get_node("HUD/%s" % panel).visible = false
	main.menu_open = false
	main.shop_open = false
	main.dialogue_open = false
	main.dialogue_pages = []
	main.pause_open = false
	main.world_map_open = false
	main.character_open = false
	main.forge_open = false
	main.storage_open = false
	main.perk_open = false
	main.get_node("HUD/MobileControls").set_modal_mode("")
	get_tree().paused = false
	await get_tree().process_frame
