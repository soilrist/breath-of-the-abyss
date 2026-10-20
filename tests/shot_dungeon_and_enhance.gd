extends Node
## 던전 입구 표시(HUD 지역명+안내 메시지)와 대장간 확정 강화(Z키) 안내
## 텍스트가 실제 화면에 정상 렌더링되는지 스크린샷으로 눈으로 확인한다.
## --headless로는 frame_post_draw가 안 돌아 무한 대기하니 반드시 일반
## 실행(창 모드)으로 --resolution 옵션과 함께 띄워야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.chapter = 4
	GameState.level = 20
	GameState.unlocked_maps = ["village", "dungeon"]
	GameState.opened_doors = []
	main._change_map("dungeon", true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://dungeon_entrance.png")
	print("SHOT dungeon_entrance")

	# 대장간 확정 강화(Z) 화면.
	GameState.inventory = ["철검"]
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	main._apply_equipment_to_player()
	main._toggle_forge()
	main.forge_mode = "enhance"
	main._refresh_forge()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://forge_enhance_guaranteed.png")
	print("SHOT forge_enhance_guaranteed")

	get_tree().quit()
