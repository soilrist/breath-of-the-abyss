extends Node
## 탑 난이도 선택 화면(HUD/TowerSelect)을 실제로 열어 스크린샷으로 확인한다.
## check_tower_select.gd는 Info.text에 "[잠김]" 문자열이 들어있는지만 보고
## 실제 렌더링은 본 적이 없었다. Help 라벨은 Info와 달리 autowrap_mode가
## 없어(scenes/main.tscn) 긴 문구가 박스(284x12px, 폰트 8) 밖으로 잘릴
## 위험이 있다 - 그 중 가장 긴 조합(헬 잠김, 요구 난이도 이름 "어려움")과
## 진행도 두 자리 층수 표시를 각각 스크린샷으로 남긴다.
## --headless로는 frame_post_draw가 안 돌아 무한 대기하니 반드시 일반
## 실행(창 모드)으로 띄워야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.game_cleared = true
	GameState.unlock_map("tower")
	GameState.tower_progress = {"easy": 100, "normal": 87, "hard": 0, "hell": 0, "abyss": 0}
	main._toggle_tower_select()

	# 가장 긴 잠김 문구: 헬(요구 난이도 "어려움")
	main.tower_select_index = GameState.TOWER_TIERS.keys().find("hell")
	main._refresh_tower_select()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://tower_select_locked_hell.png")
	print("SHOT tower_select_locked_hell")

	# 두 자리 층수 진행도 표시(보통 87/100층)
	main.tower_select_index = GameState.TOWER_TIERS.keys().find("normal")
	main._refresh_tower_select()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://tower_select_progress.png")
	print("SHOT tower_select_progress")

	get_tree().quit()
