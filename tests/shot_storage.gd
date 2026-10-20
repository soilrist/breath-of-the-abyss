extends Node
## 창고 화면 스크린샷. check_storage_clip.gd(가로 폭 측정)와 같은 조건
## (가장 긴 장비 이름 + 강화 +10 + [착용])을 실제로 띄워 눈으로 확인한다.
## 주의(INBOX 기록): --headless로 돌리면 frame_post_draw에서 무한 대기한다.
## 창을 띄운 채(헤드리스 없이) 실행할 것.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name

	GameState.inventory.clear()
	GameState.level = 99
	GameState.add_item(longest)
	GameState.equip(longest)
	GameState.enhance_levels[GameState.item_uid[0]] = 10

	main._toggle_storage()
	main.storage_index = 0
	main._refresh_storage()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://storage.png")
	print("SHOT storage")
	get_tree().quit()
