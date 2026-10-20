extends Node
## JOB_DESIGN.md 4절(직업별 스킬안) 표 값과 game_state.gd SKILLS_BY_JOB 상수가
## 어긋나지 않는지 대조한다. 밸런스 숫자는 game_state.gd 한 곳에만 둔다는
## 규칙이 지켜지는지, 설계 문서와 실제 수치가 계속 같은지 잡아내는 검사.
## 마법사 4번(마나 순환)은 JOB_DESIGN.md의 "회복"을 의도적으로 대체한
## 신규 메커니즘이라(game_state.gd:376~379 주석 참고) cost는 대조하지 않는다.

func _ready() -> void:
	var ok := true
	var by_job: Dictionary = GameState.SKILLS_BY_JOB

	ok = _check_skill(by_job["warrior"][0], 20, 2.5, 2.4) and ok   # 강타
	ok = _check_skill(by_job["warrior"][1], 24, 6.0, 1.2) and ok   # 방패 돌진
	ok = _check_skill(by_job["warrior"][2], 28, 12.0, 0.0) and ok  # 전투 함성
	ok = _check_skill(by_job["warrior"][3], 34, 15.0, 0.0) and ok  # 불굴

	ok = _check_skill(by_job["mage"][0], 22, 3.0, -1.0) and ok     # 화염구 (설계엔 배수 미기재)
	ok = _check_skill(by_job["mage"][1], 26, 5.0, 3.0) and ok      # 얼음창
	ok = _check_skill(by_job["mage"][2], 36, 8.0, 1.8) and ok      # 마나 폭발
	ok = _check("마법사 4번(마나 순환) 쿨타임 9s (설계 표의 '회복'과 동일)",
		is_equal_approx(float(by_job["mage"][3]["cooldown"]), 9.0)) and ok

	ok = _check_skill(by_job["rogue"][0], 18, 2.0, 1.1) and ok     # 연속베기
	ok = _check_skill(by_job["rogue"][1], 16, 2.5, 1.6) and ok     # 표창 던지기
	ok = _check_skill(by_job["rogue"][2], 30, 14.0, 0.0) and ok    # 은신
	ok = _check_skill(by_job["rogue"][3], 20, 10.0, 0.0) and ok    # 회피 강화

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_skill(skill: Dictionary, cost: int, cooldown: float, damage: float) -> bool:
	var label: String = str(skill.get("name", "?"))
	var ok := true
	ok = _check(label + " 마력 " + str(cost), int(skill["cost"]) == cost) and ok
	ok = _check(label + " 쿨타임 " + str(cooldown) + "s", is_equal_approx(float(skill["cooldown"]), cooldown)) and ok
	if damage >= 0.0:
		ok = _check(label + " 피해배수 x" + str(damage), is_equal_approx(float(skill["damage"]), damage)) and ok
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
