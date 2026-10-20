extends Node
## 감독 결함(2026-09-08): 대장간 강화 탭의 확정 강화가 Z키뿐이라 폰에 버튼이
## 없었고, 소켓 탭 마법돌도 숫자키뿐이라 폰에서 박을 길이 없었다.
## 아이폰 실기 순서(에뮬 마우스 → ScreenTouch)의 손가락 탭으로
## ① 강화 탭에서만 보이는 "확정" 버튼이 확정 강화를 한 번 하고
## ② 소켓 탭 Detail 의 돌 줄을 탭하면 그 번호의 돌이 박히는지 확인한다.
## 강화 탭/소켓 탭 화면 두 장을 user:// 에 남겨 글자가 칸에 드는지 눈으로 본다.


func _tap_at(viewport: Viewport, pos: Vector2) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.device = InputEvent.DEVICE_ID_EMULATION
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		viewport.push_input(mb, true)
		var st := InputEventScreenTouch.new()
		st.index = 0
		st.pressed = pressed
		st.position = pos
		viewport.push_input(st, true)
		await get_tree().process_frame
	await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return  # 그림이 없어 frame_post_draw 가 안 온다 - 창 모드로 돌릴 때만 저장.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % name)


func _ready() -> void:
	var ok := true
	var game := get_parent().get_node("Main")
	await get_tree().process_frame
	var guard := 0
	while game.dialogue_open and guard < 40:
		game._advance_dialogue()
		guard += 1
	var mobile := game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	var guaranteed: Button = mobile.get_node("Guaranteed")

	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["강철 대검"]
	GameState.gold = 999999
	GameState.materials[GameState.MATERIAL] = 999
	GameState.add_stone("홍옥", 1)
	GameState.add_stone("벽옥", 1)
	game._toggle_forge()
	await get_tree().process_frame
	ok = _check("강화 탭에서 확정 버튼 보임", guaranteed.visible) and ok
	ok = _check("확정 버튼 글자가 칸 안에 듦", guaranteed.get_minimum_size().x <= guaranteed.size.x) and ok
	ok = _check("Detail 에 Z 키 문구 없음", not game.get_node("HUD/Forge/Detail").text.contains("Z ")) and ok
	await _shot("forge_mobile_enhance")

	var uid: int = GameState.item_uid[0]
	var before: int = GameState.enhance_of("강철 대검", uid)
	var stones_before: int = GameState.materials[GameState.MATERIAL]
	await _tap_at(game.get_viewport(), guaranteed.get_global_rect().get_center())
	ok = _check("확정 버튼 손가락 탭 → 딱 한 단계 강화", GameState.enhance_of("강철 대검", uid) == before + 1) and ok
	ok = _check("강화석 소모됨", GameState.materials[GameState.MATERIAL] < stones_before) and ok

	for mode in ["socket", "craft", "reroll"]:
		game.forge_mode = mode
		game._refresh_forge()
		await get_tree().process_frame
		ok = _check("%s 탭에서는 확정 버튼 숨김" % mode, not guaranteed.visible) and ok

	game.forge_mode = "socket"
	game._refresh_forge()
	await get_tree().process_frame
	var detail: Label = game.get_node("HUD/Forge/Detail")
	ok = _check("소켓 안내문에 줄 탭 문구", detail.text.contains("줄 탭")) and ok
	await _shot("forge_mobile_socket")
	var line_height: float = detail.get_line_height() + detail.get_theme_constant("line_spacing")
	var rect := detail.get_global_rect()
	# 돌 줄은 라벨의 마지막 2줄(1. 홍옥, 2. 벽옥). 2번째 돌(벽옥) 줄 가운데를 탭.
	var stone2_line := detail.get_line_count() - 1
	var pos := Vector2(rect.position.x + 20.0, rect.position.y + (stone2_line + 0.5) * line_height)
	await _tap_at(game.get_viewport(), pos)
	ok = _check("소켓 탭 2번째 돌 줄 탭 → 벽옥이 박힘", GameState.sockets_used("강철 대검", uid) == 1
		and int(GameState.stone_inventory.get("벽옥", 0)) == 0
		and int(GameState.stone_inventory.get("홍옥", 0)) == 1) and ok
	# 돌 줄이 아닌 첫 줄(장비 요약)을 탭해도 아무것도 안 박힌다.
	await _tap_at(game.get_viewport(), Vector2(rect.position.x + 20.0, rect.position.y + 0.5 * line_height))
	ok = _check("요약 줄 탭은 무시", GameState.sockets_used("강철 대검", uid) == 1) and ok

	game._toggle_forge()
	await get_tree().process_frame
	ok = _check("대장간 닫으면 확정 버튼 숨김", not guaranteed.visible) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, ": ", "OK" if cond else "FAIL")
	return cond
