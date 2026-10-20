extends Node
## save0 세이브 검증(사용자 지시): 레벨60·장비4종+악세사리2·재화 10000/10000000이
## 실제 GameState.load_game() 경로로 정확히 복원되는지 확인하는 1회성 스모크
## 검사. tests/run_validation.sh에는 등록하지 않는다(이 세이브는 매번 값이
## 바뀌는 테스트용 데이터라 회귀 게이트로 쓰면 안 됨).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.slot = 0
	var loaded := GameState.load_game(main.get_node("Player"))
	ok = _check("save0 로드 성공", loaded) and ok
	ok = _check("레벨 60 (실제 %d)" % GameState.level, GameState.level == 60) and ok
	ok = _check("골드 10000000 (실제 %d)" % GameState.gold, GameState.gold == 10000000) and ok
	ok = _check("강화석 10000 (실제 %d)" % int(GameState.materials[GameState.MATERIAL]),
		int(GameState.materials[GameState.MATERIAL]) == 10000) and ok
	ok = _check("보스의 파편 10000 (실제 %d)" % int(GameState.materials[GameState.BOSS_FRAGMENT]),
		int(GameState.materials[GameState.BOSS_FRAGMENT]) == 10000) and ok
	ok = _check("파괴 방지 부적 10000 (실제 %d)" % GameState.enhance_wards,
		GameState.enhance_wards == 10000) and ok
	for stone in GameState.JOB_STONES:
		ok = _check("%s 10000 (실제 %d)" % [stone, int(GameState.materials[stone])],
			int(GameState.materials[stone]) == 10000) and ok
	ok = _check("무기=천공의 검", GameState.equipped["weapon"] == "천공의 검") and ok
	ok = _check("갑옷=천공의 갑주", GameState.equipped["armor"] == "천공의 갑주") and ok
	ok = _check("투구=천공의 투구", GameState.equipped["helmet"] == "천공의 투구") and ok
	ok = _check("장신구1=천공의 인장", GameState.equipped["trinket"] == "천공의 인장") and ok
	ok = _check("장신구2=용의 인장", GameState.equipped["trinket2"] == "용의 인장") and ok
	ok = _check("정령인장=불꽃의 정령 인장", GameState.equipped["spirit"] == "불꽃의 정령 인장") and ok
	ok = _check("천공 세트 4/4 완성(active_set_special)",
		GameState.active_set_special() == "skyward_grace") and ok
	ok = _check("job=warrior", GameState.job == "warrior") and ok
	ok = _check("second_job=guardian", GameState.second_job == "guardian") and ok
	ok = _check("stat_points > 0 (레벨업 보너스 스탯, 실제 %d)" % GameState.stat_points,
		GameState.stat_points > 0) and ok
	ok = _check("max_health > 0 (실제 %d)" % main.get_node("Player").max_health,
		main.get_node("Player").max_health > 0) and ok

	print("SAVE0_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("RESULT %s - %s" % ["PASS" if cond else "FAIL", label])
	return cond
