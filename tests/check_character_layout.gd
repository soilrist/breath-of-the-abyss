extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Character 창.
## check_forge_layout.gd/check_inventory_layout.gd과 같은 패턴: (1) Info/Detail/Help가
## StatBar와 안 겹침 (2) 셋이 서로 안 겹침 (3) 능력치/특성/전직 세 탭 각각 최악
## 데이터에서도 안 잘림 (4) 창 열림 시 HUD/Area·Message 숨김.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	# 메뉴 탭 창이 열리면 StatBar는 숨겨진다(main.gd _sync_modal_hud_visibility).
	if not main.get_node("HUD/StatBar").visible:
		return _check("(1) 캐릭터 창 열림 - StatBar 숨김(겹침 검사 생략)", true)
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect()
	var ok := true
	for child_name in ["Info", "Detail", "Help"]:
		var rect: Rect2 = main.get_node("HUD/Character/%s" % child_name).get_global_rect()
		ok = _check("(1) HUD/Character/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name,
			not rect.grow(4).intersects(statbar_rect)) and ok
	return ok


func _check_three_rects_disjoint(main: Node) -> bool:
	var names := ["Info", "Detail", "Help"]
	var rects := {}
	for n in names:
		rects[n] = main.get_node("HUD/Character/%s" % n).get_global_rect()
	var ok := true
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			ok = _check("(b) %s ∩ %s = 4px 여백 없이 무교집합" % [a, b],
				not rects[a].grow(4).intersects(rects[b])) and ok
	return ok


func _check_label_fits(label: Label, tag: String) -> bool:
	if label.text == "":
		return true
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


## 능력치 탭: STAT_KEYS 4개를 순회하며 커서를 옮겨도 안 잘리는지 확인.
func _check_stats_tab(main: Node) -> bool:
	main.character_mode = "stats"
	var info: Label = main.get_node("HUD/Character/Info")
	var detail: Label = main.get_node("HUD/Character/Detail")
	var ok := true
	for i in GameState.STAT_KEYS.size():
		main.stat_index = i
		main._refresh_character()
		ok = _check_label_fits(info, "능력치[%d] Info" % i) and ok
		ok = _check_label_fits(detail, "능력치[%d] Detail" % i) and ok
	return ok


## 특성 탭: 선택권이 있는 최악 상태(제안 4개 전부)로 커서를 옮긴다.
func _check_perks_tab(main: Node) -> bool:
	main.character_mode = "perks"
	GameState.perk_picks = 9
	GameState.perk_offer = []
	var info: Label = main.get_node("HUD/Character/Info")
	var detail: Label = main.get_node("HUD/Character/Detail")
	main._refresh_character()
	var ok := true
	for i in GameState.perk_offer.size():
		main.perk_index = i
		main._refresh_character()
		ok = _check_label_fits(info, "특성[%d] Info" % i) and ok
		ok = _check_label_fits(detail, "특성[%d] Detail" % i) and ok
	return ok


## 전직 탭: 2차 전직까지 해금된 최악(1차 3개 + "2차 전직" 표시줄 + 갈래 2개 =
## 목록 9줄)으로 커서를 목록 전체에 옮긴다.
func _check_job_tab(main: Node) -> bool:
	main.character_mode = "job"
	GameState.level = GameState.SECOND_JOB_UNLOCK_LEVEL
	GameState.chapter = GameState.SECOND_JOB_UNLOCK_CHAPTER
	GameState.job = "warrior"
	GameState.second_job = ""
	var info: Label = main.get_node("HUD/Character/Info")
	var detail: Label = main.get_node("HUD/Character/Detail")
	var jobs_count: int = GameState.JOB_NAMES.size()
	var second_count: int = GameState.SECOND_JOB_BRANCHES.get(GameState.job, []).size()
	var ok := true
	for i in jobs_count + second_count:
		main.job_index = i
		main._refresh_character()
		ok = _check_label_fits(info, "전직[%d] Info" % i) and ok
		ok = _check_label_fits(detail, "전직[%d] Detail" % i) and ok
	return ok


## 캐릭터 모드에서 실제로 보이는 모바일 버튼(Interact)과 안 겹치는지 확인 -
## Close는 패널 자기 모서리에 붙는 게 정상이라 제외.
func _check_no_overlap_mobile(main: Node) -> bool:
	var interact: Control = main.get_node("HUD/MobileControls/Interact")
	var ok := true
	if interact.visible:
		var btn_rect: Rect2 = interact.get_global_rect()
		for child_name in ["Info", "Detail", "Help"]:
			var rect: Rect2 = main.get_node("HUD/Character/%s" % child_name).get_global_rect()
			ok = _check("(c) HUD/Character/%s 가 MobileControls/Interact 와 4px 여백 없이 안 겹침" % child_name,
				not rect.grow(4).intersects(btn_rect)) and ok
	return ok


## 결함(2026-09-06 05:30): 제목 줄("캐릭터   [탭들]")이 폭에 안 맞아 둘째
## 줄로 접혀 내려가면 안 된다. Label.autowrap_mode 로 실제 접히는지는
## get_string_size로 폭을 재서 판정한다(줄바꿈 전 원문 첫 줄 기준).
func _check_title_one_line(main: Node, tag: String) -> bool:
	var info: Label = main.get_node("HUD/Character/Info")
	var first_line: String = info.text.split("\n")[0]
	var font: Font = info.get_theme_font("font")
	var font_size: int = info.get_theme_font_size("font_size")
	var width: float = font.get_string_size(first_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(d) %s 제목 줄 한 줄에 맞음(%dpx/%dpx) [%s]" %
		[tag, int(width), int(info.size.x), first_line], width <= info.size.x)


## 특성(12)처럼 두 자리 숫자가 되는 최악값으로 세 탭 모두의 제목 줄을 잰다.
func _check_titles_worst_case(main: Node) -> bool:
	GameState.perk_picks = 12
	var ok := true
	main.character_mode = "stats"
	main._refresh_character()
	ok = _check_title_one_line(main, "능력치") and ok
	main.character_mode = "perks"
	main._refresh_character()
	ok = _check_title_one_line(main, "특성(선택권 있음)") and ok
	GameState.perk_picks = 0
	main._refresh_character()
	ok = _check_title_one_line(main, "특성(선택권 없음)") and ok
	GameState.perk_picks = 12
	main.character_mode = "job"
	main._refresh_character()
	ok = _check_title_one_line(main, "전직(해금)") and ok
	GameState.level = 1
	main._refresh_character()
	ok = _check_title_one_line(main, "전직(잠김)") and ok
	return ok


## 결함(2026-09-06 05:30/05:45): character 모드에서 모바일 확인 버튼이
## "대화"로 남아 있으면 안 된다 - 탭마다 그 탭의 확정 동작을 말해야 한다.
## 05:45: set_modal_mode("character")를 실기처럼(_toggle_controls() 등) 한
## 번 더 불러도 라벨이 "대화"로 되돌아가지 않는지까지 재확인한다 - 처음
## 고칠 때는 _refresh_character() 직후만 봐서 이 회귀를 못 잡았다.
func _check_interact_label(main: Node) -> bool:
	var mc: Control = main.get_node("HUD/MobileControls")
	var interact: Button = mc.get_node("Interact")
	var ok := true
	GameState.level = GameState.SECOND_JOB_UNLOCK_LEVEL
	GameState.perk_picks = 12
	main.character_mode = "stats"
	main._refresh_character()
	ok = _check("(e) 능력치 탭 Interact 라벨 = 투자", interact.text == "투자") and ok
	mc.set_modal_mode("character")
	ok = _check("(e) 능력치 탭 Interact 라벨 = 투자(재호출 후)", interact.text == "투자") and ok
	main.character_mode = "perks"
	main._refresh_character()
	ok = _check("(e) 특성 탭(선택권 있음) Interact 라벨 = 선택", interact.text == "선택") and ok
	mc.set_modal_mode("character")
	ok = _check("(e) 특성 탭(선택권 있음) Interact 라벨 = 선택(재호출 후)", interact.text == "선택") and ok
	GameState.perk_picks = 0
	main._refresh_character()
	ok = _check("(e) 특성 탭(선택권 없음) Interact 숨김", not interact.visible) and ok
	GameState.perk_picks = 12
	main.character_mode = "job"
	main._refresh_character()
	ok = _check("(e) 전직 탭(해금) Interact 라벨 = 전직", interact.text == "전직") and ok
	mc.set_modal_mode("character")
	ok = _check("(e) 전직 탭(해금) Interact 라벨 = 전직(재호출 후)", interact.text == "전직") and ok
	GameState.level = 1
	main._refresh_character()
	ok = _check("(e) 전직 탭(잠김) Interact 숨김", not interact.visible) and ok
	return ok


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 캐릭터 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 캐릭터 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	# 결함(2026-09-06 05:45): 캐릭터 창 뒤로 HUD/SkillBar가 흐릿하게 비치고
	# 4번 칸이 패널 밖으로 삐져나왔다 - 모달 중엔 예외 없이 숨어야 한다.
	ok = _check("(3) 캐릭터 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	main._toggle_character()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_three_rects_disjoint(main) and ok
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_stats_tab(main) and ok
	ok = _check_perks_tab(main) and ok
	ok = _check_job_tab(main) and ok
	ok = _check_titles_worst_case(main) and ok
	ok = _check_interact_label(main) and ok
	ok = _check_area_message_hidden(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
