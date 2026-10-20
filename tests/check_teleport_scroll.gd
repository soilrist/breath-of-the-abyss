extends Node
## (감독 2026-09-10) 지도 무료 이동 제거 → 상점 '이동주문서'(99장 상한) 소모.
## 물약 바로 오른쪽 HUD 칸(SkillBar/Scroll)과 같은 자리의 터치 버튼
## (MobileControls/Scroll), 2차 전직 스킬 5·6번 칸이 24×24로 눌리는지까지 본다.

var ok := true


func _check(label: String, cond: bool) -> bool:
	print("%s %s" % ["PASS" if cond else "FAIL", label])
	return cond


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.reset()
	GameState.current_map = "village"
	GameState.unlocked_maps = ["village", "hill"]
	GameState.gold = 100000

	# 구매·상한.
	var price := -1
	for entry in main.SHOP_STOCK:
		if entry["item"] == GameState.SCROLL_ITEM:
			price = int(entry["price"])
	ok = _check("상점 목록에 이동주문서가 있다(1장부터)", price > 0) and ok
	GameState.scrolls = 0
	ok = _check("1장 구매", GameState.buy(GameState.SCROLL_ITEM, price) and GameState.scrolls == 1) and ok
	var gold_before := GameState.gold
	GameState.scrolls = GameState.MAX_SCROLLS
	ok = _check("99장이면 구매 거절 + 골드 안 빠짐",
		not GameState.buy(GameState.SCROLL_ITEM, price) and GameState.gold == gold_before
		and GameState.scrolls == GameState.MAX_SCROLLS) and ok
	ok = _check("상한은 99", GameState.MAX_SCROLLS == 99) and ok
	var d: Dictionary = GameState.to_dict()
	ok = _check("저장에 scrolls 포함", int(d.get("scrolls", -1)) == 99) and ok

	# 0장이면 지도는 열리지만 이동은 거절.
	GameState.scrolls = 0
	var graph: Node = main.get_node("HUD/WorldMap/Graph")
	main._toggle_world_map()
	graph.chapter = World.chapter_of("hill")
	graph.cursor = graph.order_for_chapter(graph.chapter).find("hill")
	var refusal: String = graph.try_travel()
	ok = _check("0장이면 이동 거절 문구", refusal.contains("이동주문서")) and ok
	ok = _check("0장이면 제자리(지도 열린 채)", GameState.current_map == "village" and main.world_map_open) and ok
	ok = _check("지도 Info에 보유 장수 표시", str(graph.get_node("Info").text).contains("이동주문서 0장")) and ok
	main._toggle_world_map()

	# 1장 있으면 이동하고 1장 소모, HUD 칸 숫자 갱신.
	GameState.scrolls = 1
	main._update_skill_bar()
	ok = _check("HUD Scroll 칸 숫자 1", main.get_node("HUD/SkillBar/Scroll/Count").text == "1") and ok
	main._toggle_world_map()
	graph.chapter = World.chapter_of("hill")
	graph.cursor = graph.order_for_chapter(graph.chapter).find("hill")
	ok = _check("1장이면 이동 허용", graph.try_travel() == "") and ok
	ok = _check("hill로 이동 + 지도 닫힘", GameState.current_map == "hill" and not main.world_map_open) and ok
	ok = _check("이동주문서 1장 소모 → 0", GameState.scrolls == 0) and ok
	ok = _check("HUD Scroll 칸 숫자 0", main.get_node("HUD/SkillBar/Scroll/Count").text == "0") and ok
	ok = _check("이동 메시지에 남은 장수", str(main.get_node("HUD/Message").text).contains("0장 남음")) and ok
	# 탑 입장은 무료(별도 난이도 선택 화면).
	GameState.game_cleared = true
	GameState.unlock_map("tower")
	main._toggle_world_map()
	ok = _check("0장이어도 탑 선택은 허용", graph.try_travel_tower() == "") and ok
	if main.get("tower_select_open"):
		main._toggle_tower_select()
	elif main.world_map_open:
		main._toggle_world_map()

	# 레이아웃: HUD 칸 = 터치 버튼(물약 바로 오른쪽), 스킬 6칸 모두 24×24 터치 가능.
	# 칸 설계값은 배율 100% 기준. (배율별 터치 버튼 추종은 아래에서 따로 본다.)
	var saved_scale: float = main.hud_skill_scale
	main.hud_skill_scale = 1.0
	main._apply_hud_scale()
	var bar: Control = main.get_node("HUD/SkillBar")
	var mobile: Control = main.get_node("HUD/MobileControls")
	var potion: Control = bar.get_node("Potion")
	var scroll: Control = bar.get_node("Scroll")
	ok = _check("Scroll 칸이 물약 바로 오른쪽(같은 줄, 4px 간격)",
		scroll.get_global_rect().position.y == potion.get_global_rect().position.y
		and scroll.get_global_rect().position.x == potion.get_global_rect().end.x + 4.0) and ok
	ok = _check("Scroll 칸이 화면 안(≤320)", scroll.get_global_rect().end.x <= 320.0) and ok
	ok = _check("MobileControls/Scroll 버튼 = HUD Scroll 칸 자리",
		mobile.get_node("Scroll").get_global_rect() == scroll.get_global_rect()) and ok
	ok = _check("Map 버튼은 사라짐", not mobile.has_node("Map")) and ok
	for i in 6:
		var slot: Control = bar.get_node("Skill%d" % i)
		var touch: Control = mobile.get_node("SkillTouch%d" % i)
		ok = _check("Skill%d 24×24" % i, slot.size == Vector2(24, 24)) and ok
		ok = _check("SkillTouch%d 자리 = Skill%d 칸" % [i, i], touch.get_global_rect() == slot.get_global_rect()) and ok
	ok = _check("스킬 6칸이 조작 버튼 줄과 안 겹침",
		bar.get_node("Skill5").get_global_rect().end.y <= potion.get_global_rect().position.y) and ok

	# HUD 배율을 바꿔도(일시정지에서 스킬바 110%) 터치 버튼이 칸을 따라가야 한다.
	for scale_value in [1.1, 0.7, 1.0]:
		main.hud_skill_scale = scale_value
		main._apply_hud_scale()
		for i in 6:
			ok = _check("배율 %.1f: SkillTouch%d 자리 = Skill%d 칸" % [scale_value, i, i],
				mobile.get_node("SkillTouch%d" % i).get_global_rect().is_equal_approx(bar.get_node("Skill%d" % i).get_global_rect())) and ok
		for name in ["Attack", "Dodge", "Potion", "Scroll"]:
			ok = _check("배율 %.1f: 터치 %s = HUD 칸" % [scale_value, name],
				mobile.get_node(name).get_global_rect().is_equal_approx(bar.get_node(name).get_global_rect())) and ok
		ok = _check("배율 %.1f: 터치 버튼이 화면 안" % scale_value,
			mobile.get_node("Scroll").get_global_rect().end.x <= 320.0
			and mobile.get_node("SkillTouch0").get_global_rect().position.x >= 0.0) and ok
	main.hud_skill_scale = saved_scale
	main._apply_hud_scale()

	print("RESULT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
