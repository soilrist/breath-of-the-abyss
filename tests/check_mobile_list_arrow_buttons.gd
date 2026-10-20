extends Node
## 감독 지시(2026-09-08): 상점/대장간/창고 목록을 손가락 탭만으로 고르기
## 불편하다 - 오른쪽 열에 ▲/▼ 버튼과 확인(구매/강화/옮기기) 버튼을 둔다.
## check_mobile_button_click.gd와 같은 진짜 Viewport GUI 클릭 경로로
## ▲/▼가 각 창의 선택 줄을 실제로 옮기고, Interact 버튼이 창마다 맞는
## 라벨로 보이며 눌렀을 때 실제 동작(구매)까지 닿는지 확인한다.


func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


## 아이폰 실기와 같은 순서로 손가락 탭 하나를 흉내 낸다 - 엔진(Input)은 터치
## 하나에 에뮬레이션 마우스(DEVICE_ID_EMULATION)를 먼저, ScreenTouch 를 그
## 다음에 보낸다. 감독 결함(2026-09-08): 이 조합에서 ▲/▼가 두 칸씩 움직였다.
func _touch(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.device = InputEvent.DEVICE_ID_EMULATION
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = center
		mb.global_position = center
		button.get_viewport().push_input(mb, true)
		var st := InputEventScreenTouch.new()
		st.index = 0
		st.pressed = pressed
		st.position = center
		button.get_viewport().push_input(st, true)
		await get_tree().process_frame
	await get_tree().process_frame


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
	var up: Button = mobile.get_node("Up")
	var down: Button = mobile.get_node("Down")
	var interact: Button = mobile.get_node("Interact")
	mobile.set_modal_mode("")
	await get_tree().process_frame
	ok = _check("필드에서는 ▲/▼ 버튼이 숨김", not up.visible and not down.visible) and ok

	# 상점: ▼로 선택이 내려가고 ▲로 돌아오며, 구매 버튼이 실제 구매까지 닿는다.
	GameState.reset()
	GameState.gold = 999999
	game._open_shop()
	await get_tree().process_frame
	ok = _check("상점 ▲/▼ 버튼 보임", up.visible and down.visible) and ok
	ok = _check("상점 구매 버튼 보임(라벨 '구매')", interact.visible and interact.text == "구매") and ok
	for button in [up, down, interact]:
		ok = _check("상점 %s 버튼이 상점 패널과 안 겹침" % button.name,
			not button.get_global_rect().intersects(game.get_node("HUD/Shop").get_global_rect())) and ok
	await _click(down)
	ok = _check("상점 ▼ 클릭 → 선택 0→1", game.shop_index == 1) and ok
	await _click(down)
	ok = _check("상점 ▼ 클릭 → 선택 1→2", game.shop_index == 2) and ok
	await _click(up)
	ok = _check("상점 ▲ 클릭 → 선택 2→1", game.shop_index == 1) and ok
	await _touch(down)
	ok = _check("상점 ▼ 손가락 탭(터치+에뮬 마우스) → 정확히 한 칸 1→2", game.shop_index == 2) and ok
	await _touch(down)
	ok = _check("상점 ▼ 손가락 탭 두 번째 → 2→3", game.shop_index == 3) and ok
	await _touch(up)
	ok = _check("상점 ▲ 손가락 탭 → 3→2", game.shop_index == 2) and ok
	await _touch(up)
	ok = _check("상점 ▲ 손가락 탭 → 2→1", game.shop_index == 1) and ok
	var gold_before: int = GameState.gold
	var price: int = int(game._shop_goods()[1]["price"])
	await _click(interact)
	ok = _check("상점 구매 버튼 클릭 → 골드 %d 차감" % price, GameState.gold == gold_before - price) and ok
	mobile._toggle_shop_tab()
	await get_tree().process_frame
	ok = _check("판매 탭에서는 라벨 '판매'", interact.visible and interact.text == "판매") and ok
	game._close_shop()
	await get_tree().process_frame

	# 창고: 가방에 3개 두고 ▼/▲, 옮기기 버튼이 실제로 옮긴다.
	GameState.reset()
	GameState.inventory = ["회복약", "철검", "가죽 갑옷"] as Array[String]
	GameState.sync_uids()
	game._toggle_storage()
	await get_tree().process_frame
	ok = _check("창고 ▲/▼ 버튼 보임", up.visible and down.visible) and ok
	ok = _check("창고 넣기 버튼 보임(라벨 '넣기')", interact.visible and interact.text == "넣기") and ok
	await _click(down)
	ok = _check("창고 ▼ 클릭 → 선택 0→1", game.storage_index == 1) and ok
	await _click(up)
	ok = _check("창고 ▲ 클릭 → 선택 1→0", game.storage_index == 0) and ok
	await _touch(down)
	ok = _check("창고 ▼ 손가락 탭 → 정확히 한 칸 0→1", game.storage_index == 1) and ok
	await _touch(up)
	ok = _check("창고 ▲ 손가락 탭 → 1→0", game.storage_index == 0) and ok
	await _click(interact)
	ok = _check("창고 옮기기 버튼 클릭 → 가방 2개·창고 1개",
		GameState.inventory.size() == 2 and GameState.storage.size() == 1) and ok
	game._toggle_storage()
	await get_tree().process_frame

	# 대장간: 강화 탭 목록에서 ▼/▲.
	GameState.reset()
	GameState.inventory = ["철검", "가죽 갑옷"] as Array[String]
	GameState.sync_uids()
	game._toggle_forge()
	await get_tree().process_frame
	ok = _check("대장간 ▲/▼ 버튼 보임", up.visible and down.visible) and ok
	var forge_before: int = game.forge_index
	await _click(down)
	ok = _check("대장간 ▼ 클릭 → 선택 내려감", game.forge_index == forge_before + 1) and ok
	await _click(up)
	ok = _check("대장간 ▲ 클릭 → 선택 되돌아옴", game.forge_index == forge_before) and ok
	await _touch(down)
	ok = _check("대장간 ▼ 손가락 탭 → 정확히 한 칸", game.forge_index == forge_before + 1) and ok
	await _touch(up)
	ok = _check("대장간 ▲ 손가락 탭 → 되돌아옴", game.forge_index == forge_before) and ok
	game._toggle_forge()
	await get_tree().process_frame
	ok = _check("닫으면 ▲/▼ 버튼 숨김", not up.visible and not down.visible) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
