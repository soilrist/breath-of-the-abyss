extends Node
## 감독(2026-09-10) 메뉴 탭 개편(피처폰 RPG식): 캐릭·가방·스킬·퀘스트·지도·가이드·설정
## 7개 창이 한 틀(8,26~284,232) + 위 탭줄(HUD/MenuTabs) + ✕(288,2)로 묶였다.
## 탭줄이 창마다 보이고 필드에서는 숨는지, 탭 버튼/◀▶/[ ] 로 넘어가는지,
## AUTO/QUEST가 좌상단에 나란히 있는지, 옛 캐릭/가방 버튼이 안 보이는지 본다.

const TABS := ["character", "inventory", "skills", "quest", "map", "guide", "pause"]
const OPEN_FLAGS := {
	"character": "character_open", "inventory": "menu_open", "skills": "skills_open",
	"quest": "quest_open", "map": "world_map_open", "guide": "guide_open", "pause": "pause_open",
}
const PANELS := {
	"character": "Character", "inventory": "Inventory", "skills": "Skills",
	"quest": "Quest", "map": "WorldMap", "guide": "Guide", "pause": "Pause",
}


func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _touch(main: Node, button: Control) -> void:
	var pos: Vector2 = main.get_viewport().get_final_transform() * button.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = pos
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _ready() -> void:
	var ok := true
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame
	# 스킬 6칸(최악 데이터) - 스킬 창이 제일 길어지는 경우로 겹침을 본다.
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 40
	# 테스트 HOME의 ui_settings(스킬 1.1)에 안 흔들리게 기본 배율로 고정.
	main.hud_skill_scale = 1.0
	main.hud_stat_scale = 1.0
	main._apply_hud_scale()

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var tabs: Control = main.get_node("HUD/MenuTabs")
	var auto: Control = mobile.get_node("Auto")
	var quest: Control = mobile.get_node("Quest")
	var close: Control = mobile.get_node("Close")
	ok = _check("필드: 탭줄 숨김, StatBar 보임", not tabs.visible and main.get_node("HUD/StatBar").visible) and ok
	ok = _check("필드: AUTO(4,4~40,28)·QUEST(44,4~80,28) 좌상단 나란히",
		auto.visible and quest.visible
		and auto.offset_left == 4.0 and auto.offset_top == 4.0 and auto.offset_right == 40.0 and auto.offset_bottom == 28.0
		and quest.offset_left == 44.0 and quest.offset_top == 4.0 and quest.offset_right == 80.0 and quest.offset_bottom == 28.0) and ok
	ok = _check("필드: 옛 캐릭/가방 버튼 숨김",
		not mobile.get_node("Character").visible and not mobile.get_node("Inventory").visible) and ok
	ok = _check("탭 버튼 7개 = MENU_TABS", main.MENU_TABS == TABS and tabs.get_node_or_null("Tab6") != null) and ok
	ok = _check("AUTO/QUEST 글자가 버튼 폭 안에 들어감", _text_fits(auto) and _text_fits(quest)) and ok
	ok = _check("◀▶ 글자가 버튼 폭 안에 들어감", _text_fits(tabs.get_node("Prev")) and _text_fits(tabs.get_node("Next"))) and ok

	# 탭마다 열어서 상태 확인
	for i in TABS.size():
		var tab: String = TABS[i]
		main._menu_open_tab(tab)
		await get_tree().process_frame
		ok = _check("[%s] 열림 플래그" % tab, main.get(OPEN_FLAGS[tab]) and main._menu_current_tab() == tab) and ok
		var panel: Control = main.get_node("HUD/" + PANELS[tab])
		ok = _check("[%s] 패널 보임 + 탭줄 보임 + StatBar 숨김" % tab,
			panel.visible and tabs.visible and not main.get_node("HUD/StatBar").visible) and ok
		var pressed_ok := true
		for j in TABS.size():
			pressed_ok = pressed_ok and (tabs.get_node("Tab%d" % j).button_pressed == (j == i))
		ok = _check("[%s] 눌린 탭 표시가 자기 탭뿐" % tab, pressed_ok) and ok
		ok = _check("[%s] ✕ 버튼 (288,2~312,24)" % tab,
			close.visible and close.offset_left == 288.0 and close.offset_top == 2.0
			and close.offset_right == 312.0 and close.offset_bottom == 24.0) and ok
		ok = _check("[%s] AUTO/QUEST/옛 캐릭·가방 버튼 숨김" % tab,
			not auto.visible and not quest.visible and not mobile.get_node("Character").visible
			and not mobile.get_node("Inventory").visible) and ok
		ok = _check("[%s] 탭줄이 패널(y26~) 위에 있고 ✕와 안 겹침" % tab,
			_rect(tabs).end.y <= panel.get_global_rect().position.y
			and not _rect(tabs).intersects(_rect(close))) and ok
		var overlap := false
		for name in ["Up", "Down", "Interact"]:
			var b: Control = mobile.get_node(name)
			if b.visible and _rect(b).intersects(_rect(tabs)):
				overlap = true
		ok = _check("[%s] ▲▼확인 버튼이 탭줄과 안 겹침" % tab, not overlap) and ok
		if tab == "map":
			var up: Control = mobile.get_node("Up")
			var down: Control = mobile.get_node("Down")
			ok = _check("[map] ▲▼ 위치 y46/78 + 이동 y138",
				up.visible and down.visible and up.offset_top == 46.0 and down.offset_top == 78.0
				and mobile.get_node("Interact").offset_top == 138.0) and ok
		ok = _check("[%s] 탭줄 Tab%d 텍스트가 칸 안에 들어감" % [tab, i],
			_text_fits(tabs.get_node("Tab%d" % i))) and ok
		main._menu_close_current()
		await get_tree().process_frame
		ok = _check("[%s] 닫힘 → 탭줄 숨김, StatBar 복귀, AUTO/QUEST 복귀" % tab,
			not main.get(OPEN_FLAGS[tab]) and not tabs.visible and main.get_node("HUD/StatBar").visible
			and auto.visible and quest.visible and not get_tree().paused) and ok

	# ◀▶ 터치 / [ ] 키 / 탭 터치로 넘어가기
	main._menu_open_tab("character")
	await get_tree().process_frame
	await _touch(main, tabs.get_node("Next"))
	ok = _check("▶ 터치: 캐릭 → 가방", main._menu_current_tab() == "inventory" and not main.character_open) and ok
	await _touch(main, tabs.get_node("Prev"))
	ok = _check("◀ 터치: 가방 → 캐릭", main._menu_current_tab() == "character" and not main.menu_open) and ok
	await _touch(main, tabs.get_node("Prev"))
	ok = _check("◀ 터치: 캐릭 → 설정(끝에서 감김)", main._menu_current_tab() == "pause") and ok
	_send_key(main, KEY_BRACKETRIGHT)
	await get_tree().process_frame
	ok = _check("] 키: 설정 → 캐릭(감김)", main._menu_current_tab() == "character") and ok
	_send_key(main, KEY_BRACKETLEFT)
	await get_tree().process_frame
	ok = _check("[ 키: 캐릭 → 설정", main._menu_current_tab() == "pause") and ok
	await _touch(main, tabs.get_node("Tab4"))
	ok = _check("지도 탭 터치: 설정 → 지도", main._menu_current_tab() == "map" and main.world_map_open and not main.pause_open) and ok
	await _touch(main, tabs.get_node("Tab4"))
	ok = _check("같은 탭 다시 터치해도 그대로 열려 있음", main._menu_current_tab() == "map") and ok
	ok = _check("탭 전환 중 일시정지 유지", get_tree().paused) and ok
	await _touch(main, close)
	ok = _check("✕ 터치: 지도 닫힘 + 탭줄 숨김 + 일시정지 해제",
		main._menu_current_tab() == "" and not tabs.visible and not get_tree().paused) and ok
	# 필드에서는 [ ] 가 아무 것도 안 연다
	_send_key(main, KEY_BRACKETRIGHT)
	await get_tree().process_frame
	ok = _check("필드에서 ] 키는 무시", main._menu_current_tab() == "") and ok

	# 상점(탭 창 아님)은 StatBar 유지 + 탭줄 숨김
	main.shop_open = true
	main._sync_modal_hud_visibility()
	ok = _check("상점 모달: 탭줄 숨김 + StatBar 유지",
		not tabs.visible and main.get_node("HUD/StatBar").visible) and ok
	main.shop_open = false
	main._sync_modal_hud_visibility()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## 탭 버튼 글자가 버튼 폭 안에 들어가는지(폰트 실측).
func _text_fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	var size := button.get_theme_font_size("font_size")
	var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return width <= button.size.x


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
