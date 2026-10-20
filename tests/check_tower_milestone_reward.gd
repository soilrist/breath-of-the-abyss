extends Node
## 탑 10/25층 단위 마일스톤 보상(TOWER_DESIGN.md 13절 "탑 콘텐츠 손보기"
## 요청으로 추가). 10/25/50/75층 몬스터는 이미 미니보스·보스급으로
## 세지는데(tower_floor_stats) 그 층을 클리어해도 몬스터 개별 처치
## 보상뿐이라 체감이 약했다 - 그 난이도 전용 결정을 추가로 지급한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	# 순수 함수: 25배수는 3개, 10배수(25 아님)는 1개, 그 외는 0.
	ok = _check("10층은 마일스톤 1개", GameState.tower_milestone_material(10) == 1) and ok
	ok = _check("25층은 마일스톤 3개(더 셈)", GameState.tower_milestone_material(25) == 3) and ok
	ok = _check("50층은 마일스톤 3개", GameState.tower_milestone_material(50) == 3) and ok
	ok = _check("11층은 마일스톤 없음", GameState.tower_milestone_material(11) == 0) and ok
	ok = _check("1층은 마일스톤 없음", GameState.tower_milestone_material(1) == 0) and ok

	# 실제 씬에서 10층 클리어 시 그 난이도 결정이 실제로 쌓이는지 확인.
	GameState.game_cleared = true
	GameState.tower_active = true
	GameState.tower_difficulty = "easy"
	GameState.tower_floor = 10
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var before: int = GameState.tower_material_counts["easy"]
	main._advance_tower_floor()
	var after: int = GameState.tower_material_counts["easy"]
	ok = _check("10층 클리어하면 실제로 결정이 쌓임", after == before + 1) and ok

	# 25층은 3개.
	GameState.tower_floor = 25
	var before2: int = GameState.tower_material_counts["easy"]
	main._advance_tower_floor()
	var after2: int = GameState.tower_material_counts["easy"]
	ok = _check("25층 클리어하면 3개 쌓임", after2 == before2 + 3) and ok

	# 마일스톤이 아닌 층(11)은 추가 지급 없음.
	GameState.tower_floor = 11
	var before3: int = GameState.tower_material_counts["easy"]
	main._advance_tower_floor()
	var after3: int = GameState.tower_material_counts["easy"]
	ok = _check("마일스톤 아닌 층은 추가 지급 없음", after3 == before3) and ok

	# 실제 화면 메시지: _advance_tower_floor 직후 _spawn_tower_floor가
	# "탑 N층" 안내로 곧바로 덮어써서 마일스톤 획득 메시지가 안 보이던
	# 문제가 있었다(스크린샷으로 실제 확인) - 이제 두 안내가 합쳐져야 한다.
	GameState.tower_floor = 25
	main._advance_tower_floor()
	var merged_msg: String = main.get_node("HUD/Message").text
	ok = _check("마일스톤 층 클리어 메시지가 다음 층 안내에 묻히지 않고 합쳐짐(실제: %s)" % merged_msg,
		merged_msg.contains("개 획득") and merged_msg.contains("26층")) and ok

	# 100층(마일스톤이자 마지막 층)은 _spawn_tower_floor를 안 부르고
	# 100층 클리어 메시지로 바로 끝나는 경로라, 마일스톤 재료 지급이
	# "100층 클리어!" 메시지에 덮이지 않고 조용히 함께 들어가는지도 확인.
	GameState.tower_floor = GameState.TOWER_FLOOR_COUNT
	var before5: int = GameState.tower_material_counts["easy"]
	main._advance_tower_floor()
	var after5: int = GameState.tower_material_counts["easy"]
	ok = _check("100층 클리어해도 마일스톤 재료가 쌓임", after5 == before5 + 3) and ok
	ok = _check("100층 클리어 메시지는 그대로 유지",
		main.get_node("HUD/Message").text.contains("100층 클리어")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
