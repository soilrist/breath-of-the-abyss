extends Node
## INBOX 지시(HUD 창 13개 전수 점검) — Dialogue 창. Character/Forge/Inventory와
## 같은 패턴: (1) Text/Speaker/Choices/More가 StatBar와 안 겹침 (2) 서로 안
## 겹침 (3) Story의 모든 대사(INTRO/CHAPTERS/BOSS_MEET/BOSS_FALL(_BY_CHOICE)/
## TOWN_VOICE)를 실제로 띄워 봐도 안 잘림 (4) 선택지 최대치(3개, 전직 선택)에서
## Choices/More가 안 잘리고 안 겹침 (5) 창 열림 시 HUD/Area·Message·SkillBar 숨김.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _dialogue_rects(main: Node) -> Dictionary:
	var rects := {}
	for n in ["Face", "Speaker", "Text", "Choices", "More"]:
		rects[n] = main.get_node("HUD/Dialogue/%s" % n).get_global_rect()
	return rects


func _check_no_overlap(main: Node) -> bool:
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect()
	var rects := _dialogue_rects(main)
	var ok := true
	for n in rects:
		var visible: bool = main.get_node("HUD/Dialogue/%s" % n).visible
		if not visible:
			continue
		ok = _check("(1) HUD/Dialogue/%s 가 StatBar와 4px 여백 없이 안 겹침" % n,
			not rects[n].grow(4).intersects(statbar_rect)) and ok
	return ok


func _check_rects_disjoint(main: Node) -> bool:
	var rects := _dialogue_rects(main)
	var keys: Array = rects.keys()
	var ok := true
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = keys[i]
			var b: String = keys[j]
			if not main.get_node("HUD/Dialogue/%s" % a).visible:
				continue
			if not main.get_node("HUD/Dialogue/%s" % b).visible:
				continue
			ok = _check("(2) %s ∩ %s = 4px 여백 없이 무교집합" % [a, b],
				not rects[a].grow(4).intersects(rects[b])) and ok
	return ok


## 캐릭터 모드에서 실제로 보이는 모바일 버튼(Interact)과 안 겹치는지 확인.
func _check_no_overlap_mobile(main: Node) -> bool:
	var interact: Control = main.get_node("HUD/MobileControls/Interact")
	var ok := true
	if interact.visible:
		var btn_rect: Rect2 = interact.get_global_rect()
		var rects := _dialogue_rects(main)
		for n in rects:
			if not main.get_node("HUD/Dialogue/%s" % n).visible:
				continue
			ok = _check("(c) HUD/Dialogue/%s 가 MobileControls/Interact 와 4px 여백 없이 안 겹침" % n,
				not rects[n].grow(4).intersects(btn_rect)) and ok
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


## 한 페이지를 띄우고 겹침·잘림을 전부 확인한 뒤 닫는다.
func _check_one_page(main: Node, tag: String) -> bool:
	var ok := true
	ok = _check_label_fits(main.get_node("HUD/Dialogue/Text"), "%s Text" % tag) and ok
	ok = _check_label_fits(main.get_node("HUD/Dialogue/Speaker"), "%s Speaker" % tag) and ok
	ok = _check_label_fits(main.get_node("HUD/Dialogue/Choices"), "%s Choices" % tag) and ok
	ok = _check_no_overlap(main) and ok
	ok = _check_rects_disjoint(main) and ok
	ok = _check_no_overlap_mobile(main) and ok
	return ok


## Story의 모든 대사 뭉치를 실제로 띄워 잘림·겹침을 확인한다. 선택지가 있는
## 페이지(흑기사단장/서리군주 대면, 전직, 부활)도 그 안에 섞여 있어 최대
## 선택지 수(3, 전직)까지 자연히 포함된다.
func _check_all_story_pages(main: Node) -> bool:
	var ok := true
	var bundles: Array = [["INTRO", Story.INTRO]]
	for key in Story.CHAPTERS:
		bundles.append(["CHAPTERS[%s]" % key, Story.CHAPTERS[key]])
	for key in Story.BOSS_MEET:
		bundles.append(["BOSS_MEET[%s]" % key, Story.BOSS_MEET[key]])
	for key in Story.BOSS_FALL:
		bundles.append(["BOSS_FALL[%s]" % key, Story.BOSS_FALL[key]])
	for key in Story.BOSS_FALL_BY_CHOICE:
		bundles.append(["BOSS_FALL_BY_CHOICE[%s]" % key, Story.BOSS_FALL_BY_CHOICE[key]])

	for bundle in bundles:
		var tag: String = bundle[0]
		var pages: Array = bundle[1]
		main._play_dialogue(pages)
		for i in pages.size():
			ok = _check_one_page(main, "%s[%d]" % [tag, i]) and ok
			if main.dialogue_open:
				main._advance_dialogue()
	return ok


## 마을 사람 잡담(TOWN_VOICE) 6명 × filler/class_change, 그리고 전직 3선택지
## 장면을 명시적으로. 의뢰 완료(bounty_done)는 가장 긴 라벨·보상으로 채운다.
func _check_town_voice(main: Node) -> bool:
	var ok := true
	var longest_label := ""
	var longest_item := ""
	for b in GameState.BOUNTIES:
		if str(b["label"]).length() > longest_label.length():
			longest_label = str(b["label"])
		if str(b["item"]).length() > longest_item.length():
			longest_item = str(b["item"])

	for who in main.TOWN_VOICE:
		var voice: Dictionary = main.TOWN_VOICE[who]
		main._play_dialogue([[who, str(voice["filler"])]])
		ok = _check_one_page(main, "TOWN_VOICE[%s].filler" % who) and ok
		main._close_dialogue()

		main._play_dialogue([[who, str(voice["bounty_done"]) % [longest_label, 99999, longest_item]]])
		ok = _check_one_page(main, "TOWN_VOICE[%s].bounty_done(최장)" % who) and ok
		main._close_dialogue()

		# 전직 3선택지 - DIALOGUE_CHOICE_WINDOW(3)이 꽉 차는 실제 장면.
		main._play_dialogue([
			[who, str(voice["class_change"]), [
				["전사 - 강인한 근접 전투", "job_warrior"],
				["마법사 - 강력한 원소 마법", "job_mage"],
				["도적 - 빠른 연속 공격", "job_rogue"],
			]],
		])
		ok = _check_one_page(main, "TOWN_VOICE[%s].class_change(3선택지)" % who) and ok
		main._close_dialogue()
	return ok


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(4) 대화 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(4) 대화 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(4) 대화 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## 결함 회귀 방지: set_modal_mode("dialogue")를 실기처럼(_toggle_controls()
## 등) 한 번 더 불러도 확인 버튼 라벨이 "대화"로 유지돼야 한다.
func _check_interact_label(main: Node) -> bool:
	var mc: Control = main.get_node("HUD/MobileControls")
	var interact: Button = mc.get_node("Interact")
	var ok := true
	main._play_dialogue([["elder", "테스트"]])
	ok = _check("(e) 대화 중 Interact 라벨 = 대화", interact.text == "대화") and ok
	mc.set_modal_mode("dialogue")
	ok = _check("(e) 대화 중 Interact 라벨 = 대화(재호출 후)", interact.text == "대화") and ok
	main._close_dialogue()
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var ok := true
	ok = _check_all_story_pages(main) and ok
	ok = _check_town_voice(main) and ok
	main._play_dialogue([["elder", "창 상태 확인용"]])
	ok = _check_area_message_hidden(main) and ok
	main._close_dialogue()
	ok = _check_interact_label(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
