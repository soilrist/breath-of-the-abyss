extends Control

## 상점 품목 수. main.gd 의 goods 목록과 개수를 맞춘다.
const SHOP_SLOTS := 5

## 씬에 있는 SkillTouch 버튼 총수(전직으로 6칸까지 늘어난다). 활성 스킬
## 수(GameState.active_skills().size())보다 씬 버튼 수가 항상 많거나 같아야
## 하므로, 두 곳(연결·표시)이 이 값을 같이 써서 어긋나지 않게 한다.
const SKILL_TOUCH_COUNT := 6

@export var force_visible := false
var controls_hidden := false

const ACTIONS := {
	"Attack": "attack", "Dodge": "dash", "Potion": "potion",
	"Interact": "interact", "Inventory": "inventory", "Scroll": "world_map",
	# 상점/대장간/창고 목록을 손가락으로만 고르기 불편하다는 감독 지시(2026-09-08):
	# 화살표 버튼이 키보드 ↑↓와 같은 액션을 보내 각 창의 _unhandled_input을 탄다.
	"Up": "ui_up", "Down": "ui_down",
}

const MENU_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "interact", "inventory", "ui_cancel"]

## 화면마다 패널 크기가 달라서 X 버튼을 고정된 자리에 두면 좁은 패널에서는
## 살짝 떨어져 뜨고, WorldMap 처럼 넓은 패널에서는 안쪽 내용과 겹쳤다.
## 열려 있는 패널의 오른쪽 위 모서리에 맞춰 매번 다시 놓는다.
const MODE_PANEL := {
	"inventory": "Inventory", "shop": "Shop", "pause": "Pause", "storage": "Storage",
	"forge": "Forge", "character": "Character", "map": "WorldMap", "dialogue": "Dialogue",
	"skills": "Skills", "quest": "Quest", "guide": "Guide", "tower_select": "TowerSelect",
}
const CLOSE_SIZE := 22.0
## ▲▼ 버튼을 보이는 창. 대화는 선택지가 있을 때만이라 set_modal_mode에서 따로 본다.
const ARROW_MODES := ["shop", "storage", "forge", "inventory", "character", "perk", "tower_select", "map"]
const ARROW_TOP := 46.0
const CLOSE_MARGIN := 3.0
## 메뉴 탭 창(main.gd MENU_TABS)은 한 틀이라 X를 탭줄 오른쪽 끝(288,2) 고정 자리에 둔다.
const TAB_MODES := ["character", "inventory", "skills", "quest", "map", "guide", "pause"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = force_visible or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	# 터치 버튼이 키 포커스를 잡으면 (1) 뒤이은 키보드 ui_* 를 Viewport 가
	# 포커스 이동으로 먹고 (2) 포커스를 풀려다 button_up/button_down 이 한 번
	# 더 나서 ▲/▼가 두 칸씩 움직였다(감독 2026-09-08). 손가락 버튼은 포커스가
	# 필요 없으니 전부 안 잡게 한다.
	for child in get_children():
		if child is BaseButton:
			child.focus_mode = Control.FOCUS_NONE
	for button_name in ACTIONS:
		var button := get_node(button_name) as Button
		button.button_down.connect(_press.bind(ACTIONS[button_name]))
		button.button_up.connect(_release.bind(ACTIONS[button_name]))
	for index in SHOP_SLOTS:
		get_node("Buy%d" % (index + 1)).pressed.connect(_buy.bind(index))
	# 스킬 칸은 각각 그 스킬을 바로 쓴다. 2차 전직 전에는 4칸만 쓰이지만
	# 나중에 전직으로 늘어날 수 있으니 씬에 있는 6칸을 전부 미리 연결해
	# 둔다(연결을 활성 스킬 수만큼만 하면 전직 후 5·6번째 칸이 안 눌린다).
	for index in SKILL_TOUCH_COUNT:
		get_node("SkillTouch%d" % index).pressed.connect(_cast_skill.bind(index))
	# 확정 강화는 Z키뿐이라 폰에서 못 썼다(감독 2026-09-08). 강화 탭에서만 보인다.
	$Guaranteed.pressed.connect(func() -> void: get_parent().get_parent()._do_enhance_guaranteed())
	$Save.pressed.connect(_pause_save)
	$Title.pressed.connect(_pause_title)
	$ToggleControls.pressed.connect(_toggle_controls)
	$MusicMute.pressed.connect(_pause_toggle_music)
	$SfxMute.pressed.connect(_pause_toggle_sfx)
	$Quit.pressed.connect(_pause_quit)
	$Pause.pressed.connect(_toggle_pause)
	$Sell.pressed.connect(_toggle_shop_tab)
	$Close.pressed.connect(_close_modal)
	$Auto.pressed.connect(_toggle_auto_hunt)
	$Quest.pressed.connect(_toggle_quest_mode)
	$Character.pressed.connect(_toggle_character)
	set_modal_mode("")


func _exit_tree() -> void:
	for action in ACTIONS.values():
		Input.action_release(action)
	for action in MENU_ACTIONS:
		Input.action_release(action)


## ui_* 화살표는 엔진 입력 큐를 거치지 않고 main.gd 의 _unhandled_input 을
## 직접 한 번 부른다. 아이폰 실기(감독 2026-09-08)에서 ▲/▼ 한 번에 두 칸씩
## 움직인 원인: 손가락 터치 하나가 에뮬레이션 마우스 → ScreenTouch 두 이벤트로
## 들어오는데, 예전 코드가 button_down 안에서 gui_release_focus()를 불러
## 버튼이 FOCUS_EXIT 로 눌림 상태를 잃고(button_up) 뒤따라온 ScreenTouch 가
## button_down 을 한 번 더 냈다. 지금은 버튼이 아예 포커스를 안 잡으므로
## (_ready 의 FOCUS_NONE) 포커스를 풀 일이 없고, 한 번 누르면 정확히 한 칸.
## 나머지 액션(attack/dash/potion 등)은 폴링(Input.is_action_pressed)이 필요해
## Input 경로 그대로.
func _press(action: String) -> void:
	if action.begins_with("ui_"):
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		get_parent().get_parent()._unhandled_input(ev)
		return
	Input.action_press(action)
	_feed_action_event(action, true)


func _release(action: String) -> void:
	if action.begins_with("ui_"):
		return
	Input.action_release(action)
	_feed_action_event(action, false)


func _feed_action_event(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tap(action: String) -> void:
	_press(action)
	await get_tree().process_frame
	_release(action)


## 상점(구매/판매)·캐릭터(능력치/특성/전직)·강화(강화/소켓/제작) 탭을
## 오간다. 데스크톱 ←→ 키만 있던 탭 전환을 이 버튼 하나로 모바일에서도
## 쓸 수 있게 했다(2026-09-06 INBOX 결함).
func _toggle_shop_tab() -> void:
	var game := get_parent().get_parent()
	if game.shop_open:
		game._switch_shop_tab("sell" if game.shop_mode == "buy" else "buy")
	elif game.character_open:
		game._cycle_character_mode(1)
	elif game.forge_open:
		game._cycle_forge_mode(1)
	elif game.skills_open:
		game._skills_to_character(1)
	elif game.storage_open:
		game._switch_storage_side("box" if game.storage_side == "bag" else "bag")
	elif game.menu_open:
		game._switch_inventory_tab()


func _cast_skill(index: int) -> void:
	var game := get_parent().get_parent()
	var note: String = game.get_node("Player").cast_skill(index)
	if note != "":
		game.get_node("HUD/Message").text = note


## 이 버튼들은 화면에 보이는 상점 목록 줄 위에 얹혀 있다. 예전에는 눌린
## 줄을 곧바로 사고/팔았는데, 커서(shop_index)는 그대로 두고 조용히
## 골드·인벤토리만 바뀌어 사람 눈에는 "눌러도 아무 반응이 없다"로 보였다
## (INBOX 2026-09-05 실기 아이폰 지시). 인벤토리/강화 창과 같은 원칙
## (game._activate_selected_shop_item()) - 첫 탭은 선택만, 이미 선택된
## 줄을 다시 탭해야 확정(구매/판매)한다.
func _buy(index: int) -> void:
	var game := get_parent().get_parent()
	if not game.shop_open:
		return
	var row: int = game._shop_visible_index(index)
	var count: int = game._shop_goods().size() if game.shop_mode == "buy" else game._shop_sell_list().size()
	if row < 0 or row >= count:
		return
	if row == game.shop_index:
		game._activate_selected_shop_item()
	else:
		game.shop_index = row
		Audio.play_sfx("cancel")
		game._refresh_shop()


func _pause_save() -> void:
	var game := get_parent().get_parent()
	if game.pause_open:
		GameState.save_game(game.get_node("Player"))
		game.get_node("HUD/Pause/Info").text = "일시정지\n저장 완료"


func _pause_title() -> void:
	var game := get_parent().get_parent()
	if game.pause_open:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _toggle_controls() -> void:
	controls_hidden = not controls_hidden
	$ToggleControls.text = "조작 UI 켜기" if controls_hidden else "조작 UI 끄기"
	set_modal_mode("pause")


func _pause_toggle_music() -> void:
	var game := get_parent().get_parent()
	if game.pause_open:
		game._toggle_audio_mute("music")


func _pause_toggle_sfx() -> void:
	var game := get_parent().get_parent()
	if game.pause_open:
		game._toggle_audio_mute("sfx")


func _pause_quit() -> void:
	var game := get_parent().get_parent()
	if game.pause_open:
		get_tree().quit()


## 데스크톱 T키 토글과 같은 함수(main.gd:_toggle_auto_hunt)를 그대로 불러
## 새 오토사냥 로직을 만들지 않는다. 그 함수가 끝에서 sync_auto_button()을
## 불러 버튼 표시를 맞추므로 여기서 따로 맞출 필요 없다.
func _toggle_auto_hunt() -> void:
	get_parent().get_parent()._toggle_auto_hunt()


## 오토사냥이 키보드(T)/모바일 버튼 어느 쪽으로 켜지고 꺼져도 버튼의 눌린
## 상태 표시가 항상 실제 상태(Player.auto_hunt)와 일치하도록 맞춘다.
## HUD의 AutoLabel도 여기서 같이 맞춰(단일 지점) 데스크톱에서도(버튼이
## 없어도) 오토 상태가 화면에 보이게 한다.
func sync_auto_button() -> void:
	var on: bool = get_parent().get_parent().get_node("Player").auto_hunt
	$Auto.button_pressed = on
	get_parent().get_node("AutoLabel").visible = on


## AUTOHUNT_DESIGN.md §10.4. 데스크톱 Y키·모바일 Quest 버튼이 여기로 모인다
## (Auto 버튼과 같은 패턴).
func _toggle_quest_mode() -> void:
	get_parent().get_parent()._toggle_quest_mode()


## 인벤토리 버튼("가방")과 같은 방식 - 필드에서만 열 수 있고 여는 함수가
## 이미 다시 누르면 닫히는 토글이라 별도 close 분기가 필요 없다.
func _toggle_character() -> void:
	get_parent().get_parent()._toggle_character()


func sync_quest_button() -> void:
	var on: bool = get_parent().get_parent().quest_mode
	$Quest.button_pressed = on
	get_parent().get_node("QuestLabel").visible = on


## 일시정지 화면을 다시 열 때나 토글 직후 버튼 글자를 현재 상태로 맞춘다.
func set_pause_audio_labels(music_muted: bool, sfx_muted: bool) -> void:
	$MusicMute.text = "음악 꺼짐" if music_muted else "음악 켜짐"
	$SfxMute.text = "효과음 꺼짐" if sfx_muted else "효과음 켜짐"


func _toggle_pause() -> void:
	var game := get_parent().get_parent()
	game.set_pause_open(not game.pause_open)


## 화면마다 닫는 함수 이름이 다 달라서 하나라도 빠지면 그 화면은 X를 눌러도
## 반응이 없다. 열리는 화면(_open 변수)을 전부 여기서 확인한다.
## 특성 고르기(perk)는 원래도 골라야만 넘어가는 화면이라 넣지 않는다.
func _close_modal() -> void:
	var game := get_parent().get_parent()
	if game.dialogue_open:
		if not game.dialogue_choices.is_empty():
			return
		game._close_dialogue()
	elif game.menu_open:
		game._toggle_inventory()
	elif game.shop_open:
		game._close_shop()
	elif game.world_map_open:
		game._toggle_world_map()
	elif game.character_open:
		game._toggle_character()
	elif game.forge_open:
		game._toggle_forge()
	elif game.storage_open:
		game._toggle_storage()
	elif game.skills_open:
		game._toggle_skills()
	elif game.quest_open:
		game._toggle_quest()
	elif game.guide_open:
		game._toggle_guide()
	elif game.tower_select_open:
		game._toggle_tower_select()
	elif game.pause_open:
		game.set_pause_open(false)


## 지금 열린 패널의 오른쪽 위 모서리 안쪽에 X 버튼을 놓는다. 모르는 모드거나
## 패널이 없으면(예: perk, 애초에 안 보임) 손대지 않는다.
func _place_close_button(mode: String) -> void:
	if not MODE_PANEL.has(mode):
		return
	if mode in TAB_MODES:
		$Close.offset_left = 288.0
		$Close.offset_top = 2.0
		$Close.offset_right = 312.0
		$Close.offset_bottom = 24.0
		return
	var panel := get_parent().get_node(MODE_PANEL[mode]) as Control
	if panel == null:
		return
	$Close.offset_left = panel.offset_right - CLOSE_SIZE - CLOSE_MARGIN
	$Close.offset_top = panel.offset_top + CLOSE_MARGIN
	$Close.offset_right = panel.offset_right - CLOSE_MARGIN
	$Close.offset_bottom = panel.offset_top + CLOSE_MARGIN + CLOSE_SIZE


## ▲/▼/확인(Interact) 세로 줄 위치. 기본은 씬 값(y46/78/138), 지도만 아래로.
func _place_arrow_buttons(_mode: String) -> void:
	# 지도도 다른 창과 같은 자리(감독 2026-09-10 "메인화면처럼 화살표") - mode는 안 쓴다.
	for pair in [[$Up, ARROW_TOP], [$Down, ARROW_TOP + 32.0], [$Interact, 138.0]]:
		var button: Control = pair[0]
		button.offset_top = pair[1]
		button.offset_bottom = pair[1] + 24.0


func set_inventory_mode(open: bool) -> void:
	$Joystick.visible = not open


func set_forge_guaranteed_visible(is_visible: bool) -> void:
	$Guaranteed.visible = is_visible and not controls_hidden


func set_interact_label(text: String, is_visible: bool = true) -> void:
	$Interact.text = text
	$Interact.visible = is_visible and not controls_hidden


func set_modal_mode(mode: String) -> void:
	var playing := mode == ""
	var show_controls := not controls_hidden
	# 모달(대화/상점/인벤토리 등)이 열리는 모든 경로가 결국 이 함수를 거치므로
	# AUTOHUNT_DESIGN.md §6의 "모달 열림 시 오토 강제 해제"를 여기 한 곳에서 처리한다.
	if mode != "":
		var game := get_parent().get_parent()
		if game.get_node("Player").auto_hunt:
			game._toggle_auto_hunt()
		# §10.5: 퀘스트모드 자신이 여는 대화(마을 NPC)는 예외 - 그 외 모달만 강제 OFF.
		if mode != "dialogue" and game.quest_mode:
			game._toggle_quest_mode()
	sync_auto_button()
	sync_quest_button()
	$Auto.visible = playing and show_controls
	$Quest.visible = playing and show_controls
	# 캐릭/가방 버튼은 메뉴 탭(☰ → 탭줄)으로 대체돼 안 쓴다(감독 2026-09-10).
	$Character.visible = false
	$Joystick.visible = playing and show_controls
	$Attack.visible = playing and show_controls
	# 결함(2026-09-06, Perk 창 전수 점검): 활성 스킬 수만큼만 표시를 갱신하면
	# 그 뒤 칸(예: 2차 전직 전 SkillTouch4/5)은 씬 기본값(visible=true)에
	# 그대로 남아 모드와 무관하게 항상 보이고 눌렸다 - 6칸 전부를 활성
	# 스킬 수와 비교해 매번 다시 정한다.
	var skill_count := GameState.active_skills().size()
	for index in SKILL_TOUCH_COUNT:
		get_node("SkillTouch%d" % index).visible = index < skill_count and playing and show_controls
	$Dodge.visible = playing and show_controls
	$Potion.visible = playing and show_controls
	$Interact.visible = (playing or mode == "dialogue" or mode == "inventory" or mode == "shop" or mode == "storage" or mode == "forge" or mode == "character" or mode == "perk" or mode == "tower_select" or mode == "map") and show_controls
	# 목록이 있는 창은 전부 ▲▼ - 대화는 선택지가 있을 때만(감독 2026-09-09).
	var dialogue_choosing: bool = mode == "dialogue" and not get_parent().get_parent().dialogue_choices.is_empty()
	$Up.visible = (mode in ARROW_MODES or dialogue_choosing) and show_controls
	$Down.visible = $Up.visible
	_place_arrow_buttons(mode)
	set_forge_guaranteed_visible(mode == "forge" and get_parent().get_parent().forge_mode == "enhance")
	# 필드로 돌아올 때만 기본 라벨로 되돌린다 - 모달 중에는 그 창의
	# _refresh_*()가 이미 자기 라벨(투자/선택/전직/착용/강화 등)을 정했으므로
	# 여기서 건드리면 그 뒤에 이 함수가 다시 불릴 때(예: _toggle_controls())
	# 라벨이 지워진다(결함 2026-09-06 05:45).
	if mode == "":
		$Interact.text = "대화"
	$Inventory.visible = false
	$Scroll.visible = playing and show_controls
	$Sell.visible = (mode == "shop" or mode == "character" or mode == "forge" or mode == "skills" or mode == "storage" or mode == "inventory") and show_controls
	$Pause.visible = playing
	# 특성 고르기·선택지 대화는 골라야만 넘어가는 화면이라 X로 그냥 닫을 수 없다
	# (키보드도 Esc가 안 먹는다). 대화 X 자리가 ▲▼와 겹치기도 한다.
	$Close.visible = mode != "" and mode != "perk" and not dialogue_choosing
	_place_close_button(mode)
	$Save.visible = mode == "pause"
	$Title.visible = mode == "pause"
	$ToggleControls.visible = mode == "pause"
	$MusicMute.visible = mode == "pause"
	$SfxMute.visible = mode == "pause"
	$Quit.visible = mode == "pause"
	for index in SHOP_SLOTS:
		get_node("Buy%d" % (index + 1)).visible = mode == "shop" and show_controls
	if mode == "shop":
		_place_buy_buttons(get_parent().get_parent())


## Buy1~5는 화면에 보이는 상점 목록 줄 위에 얹히는 투명 터치 버튼이라
## 실제 줄 위치(글꼴 높이 + line_spacing)와 어긋나면 한 줄 밀려 눌린다
## (INBOX 2026-09-05 결함과 같은 원인 - Info가 그리는 줄 간격을 그대로 써야 한다).
func _place_buy_buttons(game: Node) -> void:
	var info: Label = game.get_node("HUD/Shop/Info")
	var rect := info.get_global_rect()
	var line_height: float = info.get_line_height() + info.get_theme_constant("line_spacing")
	var list_top: float = rect.position.y + game.SHOP_LIST_START_LINE * line_height
	for index in SHOP_SLOTS:
		var button := get_node("Buy%d" % (index + 1))
		button.position = Vector2(rect.position.x, list_top + index * line_height)
		button.size = Vector2(rect.size.x, line_height)
