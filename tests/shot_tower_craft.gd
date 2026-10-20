extends Node
## 탑 전용 장비 제작 화면(대장간 제작 탭)에서 심연(5종 결정 요구, 가장 긴
## 필요 재료 문구) 레시피의 상세 텍스트가 Forge/Detail 박스(108x158px,
## 폰트 7)에서 잘리지 않는지 스크린샷으로 눈으로 확인한다.
## --headless로는 frame_post_draw가 안 돌아 무한 대기하니 반드시 일반
## 실행(창 모드)으로 --resolution 옵션과 함께 띄워야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.game_cleared = true
	GameState.tower_progress = {"easy": 100, "normal": 100, "hard": 100, "hell": 100, "abyss": 0}
	GameState.tower_material_counts = {"easy": 99, "normal": 99, "hard": 99, "hell": 99, "abyss": 99}
	GameState.materials[GameState.MATERIAL] = 99
	GameState.gold = 999999
	main._apply_equipment_to_player()
	main._toggle_forge()
	main.forge_mode = "craft"
	main.craft_index = main._craft_recipe_list().find("천공의 검")
	main._refresh_forge_craft()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://forge_craft_abyss.png")
	print("SHOT forge_craft_abyss")

	get_tree().quit()
