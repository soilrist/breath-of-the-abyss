extends Node
## 특성 선택 화면(HUD/Perk)을 실제로 열어 스크린샷으로 확인한다.
## check_safe_perk_picking.gd는 함수 호출로 perk_picks/take_perk 결과만
## 확인했지 실제 렌더링은 본 적이 없었다. Info 라벨은 autowrap_mode가
## 없어(scenes/main.tscn) 세로 108px 안에 8줄(헤더 2 + 특성 3종 x 2줄)이
## 들어가야 하고, 바로 2px 아래(offset_top=118)에 Help 라벨이 있어 여유가
## 빠듯하다 - 보유 스택 수를 두 자리로 채워 가장 긴 줄 조합을 만든다.
## --headless로는 frame_post_draw가 안 돌아 무한 대기하니 반드시 일반
## 실행(창 모드)으로 띄워야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	for key in GameState.PERKS:
		GameState.perks[key] = 99
	GameState.perk_picks = 1
	GameState.roll_perk_offer()
	main._open_perk_choice()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://perk_screen_max_stack.png")
	print("SHOT perk_screen_max_stack")

	# 비교용: 갓 시작한 캐릭터의 첫 선택(스택 접미사 없음)도 겹치는지 확인.
	GameState.reset()
	GameState.perk_picks = 1
	GameState.roll_perk_offer()
	main._open_perk_choice()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://perk_screen_fresh.png")
	print("SHOT perk_screen_fresh")

	get_tree().quit()
