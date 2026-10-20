extends Node
## main.tscn의 HUD/MobileControls 버튼들은 지금까지
## `integration_test.gd`에서 `mobile._press("attack")`/`mobile._toggle_pause()`
## 같은 함수 직접 호출로만 검증됐다(안드로이드에서는 이게 유일한 조작
## 수단인데도). check_touch_button_input.gd가 title.tscn의 TouchMenu에
## 뚫었던 것과 같은 공백 — Godot Button이 실제로 클릭 판정을 하는 Viewport
## GUI 입력 경로(사람이 화면을 탭할 때 타는 경로)는 한 번도 탄 적이 없었다.
## 여기서는 main.tscn을 그대로 띄우고 진짜 InputEventMouseButton을
## Attack(누르고 있는 동안만 입력, button_down/up 신호)과
## Pause/Close(클릭 한 번, pressed 신호) 버튼에 주입해 확인한다.
##
## Attack/Dodge는 여기까지는 Input.is_action_pressed() 상태만 확인했었다 —
## 실제로 player.gd:_physics_process()가 매 프레임 폴링하는 건
## Input.is_action_just_pressed()이고(mobile_controls.gd:59~61 주석이 이미
## 지적한 "폴링 vs 이벤트" 차이), 그 폴링이 이 터치 경로에서 실제로
## attack()/try_dodge()까지 닿는지는 검증된 적이 없었다(check_attack_dash_key_input.gd는
## 키보드 InputEventKey 경로만 검증). physics_frame을 한 번 넘겨 확인한다.

func _click_down(button: Button) -> void:
	# check_touch_button_input.gd와 동일한 이유로 get_viewport().push_input()을
	# 쓴다: project.godot의 window/stretch/mode="canvas_items"가 320x240
	# 논리 뷰포트를 확대하므로 Input.parse_input_event()로는 stretch 변환을
	# 안 타 좌표가 어긋난다.
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame


func _click_up(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _click(button: Button) -> void:
	await _click_down(button)
	await _click_up(button)


func _ready() -> void:
	var ok := true
	var game := get_parent().get_node("Main")
	await get_tree().process_frame
	skip_dialogue(game)

	var mobile := game.get_node("HUD/MobileControls")
	var player := game.get_node("Player")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	# Attack: button_down/button_up 신호 — 누르고 있는 동안만 폴링에 잡힌다.
	var attack: Button = mobile.get_node("Attack")
	var before_attack := Input.is_action_pressed("attack")
	var cooldown_before_attack: float = player.cooldown_time
	await _click_down(attack)
	ok = _check("진짜 마우스 클릭(down)으로 Attack 버튼이 눌림",
		not before_attack and Input.is_action_pressed("attack")) and ok
	# _click_down이 이미 process_frame을 한 번 건너므로, 그 안에서 물리
	# 프레임이 몇 번 돌았는지(0번일 수도, 여러 번일 수도)는 헤드리스 실행
	# 타이밍에 따라 달라진다 - 고정된 프레임 수 대신 여유 있게 폴링해
	# cooldown_time이 실제로 오르는지 확인한다(진짜 버그라면 끝까지 0.0).
	var attack_triggered: bool = cooldown_before_attack == 0.0 and player.cooldown_time > 0.0
	var attack_guard := 0
	while not attack_triggered and attack_guard < 10:
		await get_tree().physics_frame
		attack_triggered = player.cooldown_time > cooldown_before_attack
		attack_guard += 1
	ok = _check("모바일 Attack 버튼 누름이 실제 공격까지 도달(is_action_just_pressed 폴링)",
		attack_triggered) and ok
	await _click_up(attack)
	ok = _check("마우스 클릭 해제(up)로 Attack 버튼이 풀림",
		not Input.is_action_pressed("attack")) and ok

	# Dodge/Potion: Attack과 같은 button_down/button_up 신호(ACTIONS 딕셔너리).
	var dodge: Button = mobile.get_node("Dodge")
	var invuln_before_dodge: float = player.invulnerability_time
	await _click_down(dodge)
	ok = _check("진짜 마우스 클릭(down)으로 Dodge 버튼이 눌림",
		Input.is_action_pressed("dash")) and ok
	var dodge_triggered: bool = player.invulnerability_time > invuln_before_dodge
	var dodge_guard := 0
	while not dodge_triggered and dodge_guard < 10:
		await get_tree().physics_frame
		dodge_triggered = player.invulnerability_time > invuln_before_dodge
		dodge_guard += 1
	ok = _check("모바일 Dodge 버튼 누름이 실제 구르기까지 도달(is_action_just_pressed 폴링)",
		dodge_triggered) and ok
	await _click_up(dodge)
	ok = _check("마우스 클릭 해제(up)로 Dodge 버튼이 풀림",
		not Input.is_action_pressed("dash")) and ok

	var potion: Button = mobile.get_node("Potion")
	# Attack/Dodge와 달리 potion은 main.gd:_unhandled_input의
	# event.is_action_pressed("potion")(폴링이 아니라 이벤트)로 걸린다 —
	# _press()가 흘려보내는 InputEventAction이 실제로 거기까지 닿아
	# try_use_potion()을 부르는지, 지금까지는 Input.is_action_pressed()
	# 상태만 확인하고 실제 소비(GameState.potions 감소·회복량)는 본 적이
	# 없었다. 회복이 실제로 일어나야 소비되므로 체력을 미리 깎아 둔다.
	player.health = int(player.max_health * 0.5)
	GameState.potions = 2
	player.potions = GameState.potions
	var potions_before_use: int = GameState.potions
	var health_before_use: int = player.health
	await _click_down(potion)
	ok = _check("진짜 마우스 클릭(down)으로 Potion 버튼이 눌림",
		Input.is_action_pressed("potion")) and ok
	ok = _check("모바일 Potion 버튼 클릭이 실제 try_use_potion()까지 도달(회복량 반영)",
		player.health > health_before_use) and ok
	ok = _check("Potion 버튼 클릭으로 GameState.potions가 실제로 줄어든다",
		GameState.potions == potions_before_use - 1) and ok
	await _click_up(potion)
	ok = _check("마우스 클릭 해제(up)로 Potion 버튼이 풀림",
		not Input.is_action_pressed("potion")) and ok

	# Pause: pressed 신호 — 클릭 한 번(down+up)으로 토글된다.
	var pause_button: Button = mobile.get_node("Pause")
	await _click(pause_button)
	ok = _check("진짜 마우스 클릭으로 Pause 버튼이 일시정지를 연다",
		game.pause_open and get_tree().paused) and ok
	ok = _check("일시정지가 열리면 Close 버튼이 보인다", mobile.get_node("Close").visible) and ok

	# Close: 같은 자리(Pause와 겹치는 rect)에서 pressed 신호로 닫는다.
	var close_button: Button = mobile.get_node("Close")
	await _click(close_button)
	ok = _check("진짜 마우스 클릭으로 Close 버튼이 일시정지를 닫는다",
		not game.pause_open and not get_tree().paused) and ok

	# Interact/Inventory/Map: button_down 신호가 Input.action_press +
	# _feed_action_event(실제 InputEventAction)를 함께 흘려보내
	# main._unhandled_input()의 최상위 토글 분기까지 태운다(mobile_controls.gd:62~76).
	# 세 버튼 모두 패널을 열고 닫으므로, 다음 버튼이 보이는 상태로
	# 검사 사이마다 set_modal_mode("")로 되돌린다(닫힌 패널의 버튼은
	# visible=false라 실제 마우스 클릭 경로가 못 닿는다).
	GameState.current_map = "forest_w"
	var interact: Button = mobile.get_node("Interact")
	game.get_node("HUD/Message").text = ""
	await _click(interact)
	ok = _check("진짜 마우스 클릭으로 Interact 버튼이 _interact_npc()까지 도달",
		game.get_node("HUD/Message").text == "상호작용할 대상이 없다.") and ok
	mobile.set_modal_mode("")
	await get_tree().process_frame

	# 가방 버튼은 메뉴 탭으로 대체(감독 2026-09-10): ☰ → 탭줄 '가방' → X.
	ok = _check("필드에 '가방' 버튼은 더 이상 안 보인다", not mobile.get_node("Inventory").visible) and ok
	await _click(mobile.get_node("Pause"))
	ok = _check("진짜 마우스 클릭으로 ☰ 버튼이 설정(일시정지) 탭을 연다",
		game.pause_open and game.get_node("HUD/MenuTabs").visible) and ok
	await _click(game.get_node("HUD/MenuTabs/Tab1"))
	ok = _check("탭줄 '가방' 클릭으로 인벤토리를 연다(설정 탭은 닫힘)",
		game.menu_open and not game.pause_open and game.get_node("HUD/Inventory").visible and get_tree().paused) and ok
	await _click(mobile.get_node("Close"))
	ok = _check("X 클릭으로 인벤토리가 닫힌다",
		not game.menu_open and not get_tree().paused and not game.get_node("HUD/MenuTabs").visible) and ok
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var map_button: Button = mobile.get_node("Scroll")
	await _click(map_button)
	ok = _check("진짜 마우스 클릭으로 Scroll(이동주문서) 버튼이 월드맵을 연다",
		game.world_map_open and game.get_node("HUD/WorldMap").visible and get_tree().paused) and ok
	# 지도가 열리면 set_modal_mode("map")가 Map 버튼 자체를 안 보이게
	# 만든다(playing 상태에서만 보임) — 실기기와 같은 방식(Close로 닫기)으로 닫는다.
	await _click(close_button)
	ok = _check("Close 버튼을 클릭하면 월드맵이 닫힌다",
		not game.world_map_open and not get_tree().paused) and ok
	mobile.set_modal_mode("")

	# Save/ToggleControls/MusicMute/SfxMute: 전부 pause 모드에서만 보이는
	# pressed 신호 버튼(mobile_controls.gd:232~237). Title/Quit은 각각
	# change_scene_to_file()/get_tree().quit()로 검사 트리 자체를 죽이므로
	# 여기서는 다루지 않는다(STATUS.md "조건부/보류" 참고).
	await _click(pause_button)
	ok = _check("Pause 버튼으로 다시 일시정지를 연다(Save 등 검사 준비)",
		game.pause_open and get_tree().paused) and ok

	# 이 클릭은 실제 save0.json을 만든다 — 백업 없이 그대로 두면
	# GameState.game_cleared=false인 저장 파일이 디스크에 남아, 이후 다른
	# 검사 프로세스가 title.tscn을 띄울 때 _load_clear_flag()가 그 값으로
	# GameState.game_cleared를 덮어써 버린다(실측: check_title_choice_records_click.gd가
	# 전체 스위트 안에서만 FAIL했던 원인). 백업해 뒀다가 끝나면 복원한다.
	var save_path := GameState.save_path()
	var save_backup: PackedByteArray = []
	var had_save_backup := FileAccess.file_exists(save_path)
	if had_save_backup:
		save_backup = FileAccess.get_file_as_bytes(save_path)

	var save_button: Button = mobile.get_node("Save")
	game.get_node("HUD/Pause/Info").text = ""
	await _click(save_button)
	ok = _check("진짜 마우스 클릭으로 Save 버튼이 GameState.save_game()까지 도달",
		game.get_node("HUD/Pause/Info").text == "일시정지\n저장 완료") and ok

	if had_save_backup:
		var restore_f := FileAccess.open(save_path, FileAccess.WRITE)
		restore_f.store_buffer(save_backup)
		restore_f.close()
	else:
		DirAccess.remove_absolute(save_path)

	var toggle_controls: Button = mobile.get_node("ToggleControls")
	var before_hidden: bool = mobile.controls_hidden
	await _click(toggle_controls)
	ok = _check("진짜 마우스 클릭으로 ToggleControls 버튼이 controls_hidden을 뒤집는다",
		mobile.controls_hidden == not before_hidden) and ok
	await _click(toggle_controls)
	ok = _check("다시 클릭하면 controls_hidden이 원래대로 돌아온다",
		mobile.controls_hidden == before_hidden) and ok

	var music_mute: Button = mobile.get_node("MusicMute")
	var before_music: bool = Audio.music_muted
	await _click(music_mute)
	ok = _check("진짜 마우스 클릭으로 MusicMute 버튼이 Audio.music_muted를 뒤집는다",
		Audio.music_muted == not before_music) and ok
	await _click(music_mute)
	ok = _check("다시 클릭하면 music_muted가 원래대로 돌아온다",
		Audio.music_muted == before_music) and ok

	var sfx_mute: Button = mobile.get_node("SfxMute")
	var before_sfx: bool = Audio.sfx_muted
	await _click(sfx_mute)
	ok = _check("진짜 마우스 클릭으로 SfxMute 버튼이 Audio.sfx_muted를 뒤집는다",
		Audio.sfx_muted == not before_sfx) and ok
	await _click(sfx_mute)
	ok = _check("다시 클릭하면 sfx_muted가 원래대로 돌아온다",
		Audio.sfx_muted == before_sfx) and ok

	await _click(close_button)
	mobile.set_modal_mode("")

	# Buy1~5/Sell: mode == "shop"일 때만 보인다(mobile_controls.gd:239,227).
	# _buy(index)는 game._shop_visible_index(index)로 화면에 보이는 줄을
	# 실제 상점 목록 인덱스로 바꿔 _buy_shop_item/_sell_shop_item을 부른다
	# (mobile_controls.gd:99~106). 같은 Buy1~5 버튼이 buy/sell 탭 양쪽에서
	# 쓰인다 — Sell 버튼은 물건을 파는 게 아니라 탭만 뒤집는다(_toggle_shop_tab).
	GameState.gold = 200
	GameState.add_item("가죽 갑옷")
	game._open_shop()
	await get_tree().process_frame
	ok = _check("_open_shop()으로 상점이 buy 탭으로 열린다",
		game.shop_open and game.shop_mode == "buy") and ok

	var buy1: Button = mobile.get_node("Buy1")
	var gold_before_buy: int = GameState.gold
	var potions_before: int = GameState.potions
	await _click(buy1)
	ok = _check("진짜 마우스 클릭으로 Buy1 버튼이 회복약을 구매(_buy_shop_item)",
		GameState.gold == gold_before_buy - 20 and GameState.potions == potions_before + 1) and ok

	var sell_button: Button = mobile.get_node("Sell")
	await _click(sell_button)
	ok = _check("진짜 마우스 클릭으로 Sell 버튼이 탭을 sell로 뒤집는다(_toggle_shop_tab)",
		game.shop_mode == "sell") and ok

	var gold_before_sell: int = GameState.gold
	var inventory_count_before: int = GameState.inventory.size()
	await _click(buy1)
	ok = _check("sell 탭에서 같은 Buy1 버튼이 목록 0번 물건을 판매(_sell_shop_item)",
		GameState.gold > gold_before_sell
		and GameState.inventory.size() == inventory_count_before - 1) and ok

	await _click(close_button)
	mobile.set_modal_mode("")

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func skip_dialogue(game: Node) -> void:
	var guard := 0
	while game.dialogue_open and guard < 40:
		game._advance_dialogue()
		guard += 1


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
