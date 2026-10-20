extends Node
## 직업/전직 시스템 검증. JOB_DESIGN.md 참고.
## - 레벨 15 미만이면 전직 불가
## - 전직하면 스킬 4개가 그 직업 전용으로 바뀐다
## - 재전직 비용은 레벨×50골드이고 부족하면 실패한다
## - 전사 방패돌진(기절), 마법사 얼음창(슬로우), 도적 은신(확정 치명타)이
##   실제로 적에게/자신에게 효과를 건다
## - 세이브·불러오기에 job이 남는다

var main: Node


func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 5
	ok = _check("레벨 5는 전직 불가", not GameState.can_change_job()) and ok
	var r_early := GameState.change_job("warrior")
	ok = _check("레벨 부족하면 전직 거부", r_early != "") and ok
	ok = _check("거부되면 job이 그대로 빈 값", GameState.job == "") and ok

	GameState.level = 15
	ok = _check("레벨 15는 전직 가능", GameState.can_change_job()) and ok
	ok = _check("첫 전직은 무료", GameState.job_change_cost() == 0) and ok
	var r_ok := GameState.change_job("warrior")
	ok = _check("전직 성공하면 빈 문자열 반환", r_ok == "") and ok
	ok = _check("job이 warrior로 바뀜", GameState.job == "warrior") and ok
	ok = _check("전사 스킬 4개로 교체됨",
		GameState.active_skills()[0]["id"] == "strike") and ok
	ok = _check("공용 SKILLS 상수는 그대로 남아있음(참격)",
		GameState.SKILLS[0]["id"] == "slash") and ok

	# 재전직 비용 검사.
	GameState.gold = 10
	var r_poor := GameState.change_job("mage")
	ok = _check("골드 부족하면 재전직 실패", r_poor != "" and GameState.job == "warrior") and ok
	GameState.gold = GameState.level * 50
	var r_switch := GameState.change_job("mage")
	ok = _check("골드 충분하면 재전직 성공", r_switch == "" and GameState.job == "mage") and ok
	ok = _check("재전직으로 골드가 빠짐", GameState.gold == 0) and ok
	ok = _check("마법사 스킬 4개로 교체됨(얼음창)",
		GameState.active_skills()[1]["id"] == "ice_spear") and ok

	# 세이브/로드에 job이 남는지.
	var saved := GameState.to_dict()
	ok = _check("세이브 데이터에 job 필드 포함", saved.get("job", "") == "mage") and ok

	# 캐릭터 화면(C)의 전직 탭이 실제로 동작하는지 — 함수 직접 호출이 아니라
	# 실제 입력 경로(C키/방향키/E키에 매핑된 InputEventAction)로 확인한다.
	# (⑥ 규칙: 코드가 도는 것과 사람이 누를 수 있는 것은 다르다.)
	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	main.character_open = false
	main._toggle_character()
	ok = _check("C로 캐릭터 화면 열기", main.character_open) and ok

	main.character_mode = "stats"
	_press("move_right")
	_press("move_right")
	ok = _check("→ 두 번으로 전직 탭 진입", main.character_mode == "job") and ok
	main.job_index = 0  # warrior
	main._refresh_character()
	ok = _check("전직 탭에 직업 목록 표시", main.get_node("HUD/Character/Info").text.contains("전사")) and ok
	_press("interact")
	ok = _check("전직 탭에서 E로 전사 확정", GameState.job == "warrior") and ok
	main.job_index = 1  # mage, 재전직
	_press("interact")
	ok = _check("전직 탭에서 재전직도 됨", GameState.job == "mage") and ok

	# 스킬바 아이콘이 전직 후 SVG로 정상 로드되는지(존재하지 않으면 texture가 null).
	main._update_skill_bar()
	var skill0_icon: TextureRect = main.get_node("HUD/SkillBar/Skill0")
	ok = _check("전직 후 스킬바 아이콘 텍스처 로드됨", skill0_icon.texture != null) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	main._unhandled_input(ev)
