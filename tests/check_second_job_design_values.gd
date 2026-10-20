extends Node
## SECOND_JOB_DESIGN.md 1·2·5절(해금 조건, 전직의 돌 비용) 및 3절(분기 표 안의
## 구체적 수치)이 game_state.gd의 SECOND_JOB_*/SKILLS_BY_SECOND_JOB과
## 어긋나지 않는지 대조한다.
## 문서 1행은 여전히 "검토용 — 미구현"이지만 실제로는 이미 구현돼 있다
## (JOB_DESIGN.md도 같은 이유로 표기가 남아 있는 것과 같은 패턴 —
## TOWER_DESIGN.md의 관례대로 코드가 맞다).
## 2026-09-04: 사람 답변("코드가 먼저야")에 따라 3절 불일치 2건은 문서를
## 코드에 맞춰 고쳤다(연쇄 번개 설명, 철벽 태세 이동속도 문구 제거).
## 이 검사에는 원래부터 두 필드를 대조하지 않았으므로(③ 규칙 - 불일치
## 상태에서 문서/코드 어느 쪽도 이 검사가 강제로 맞추지 않는 설계였음)
## 코드 변경 없이 문서만 고쳐 대조가 자연히 일치하게 됐다.
## 2026-09-05: 7절 "가배치, 근거" 각주(분신술: 분신 스폰 대신 speed_mult
## 0.7/3초 + invuln 1.5초로 대체 구현됨)에 적힌 구체 수치를 새로 대조
## 대상에 추가했다(그 전엔 문서에 각주만 있고 대조 검사가 없었음).

func _ready() -> void:
	var ok := true

	ok = _check("SECOND_JOB_UNLOCK_LEVEL 40", GameState.SECOND_JOB_UNLOCK_LEVEL == 40) and ok
	ok = _check("SECOND_JOB_UNLOCK_CHAPTER 4", GameState.SECOND_JOB_UNLOCK_CHAPTER == 4) and ok
	ok = _check("SECOND_JOB_STONE_COST 200개(고정)", GameState.SECOND_JOB_STONE_COST == 200) and ok
	ok = _check("SECOND_JOB_GOLD_MULT 레벨x200", GameState.SECOND_JOB_GOLD_MULT == 200) and ok

	var guardian: Dictionary = GameState.SKILLS_BY_SECOND_JOB["guardian"][0]
	ok = _check("철벽 태세 받는 피해 50%감소", is_equal_approx(float(guardian["buff"]["value"]), 0.5)) and ok
	ok = _check("철벽 태세 4초 지속", is_equal_approx(float(guardian["buff"]["duration"]), 4.0)) and ok

	var assassin_pierce: Dictionary = GameState.SKILLS_BY_SECOND_JOB["assassin"][0]
	ok = _check("심장 관통 피해배수 x4.0", is_equal_approx(float(assassin_pierce["damage"]), 4.0)) and ok

	var assassin_execute: Dictionary = GameState.SKILLS_BY_SECOND_JOB["assassin"][1]
	ok = _check("처형 HP 30% 이하", is_equal_approx(float(assassin_execute["execute_pct"]), 0.3)) and ok

	# SECOND_JOB_DESIGN.md 3절 각주(최후의 일격 "가배치, 근거")와 대조 —
	# HP 0%에서 배율 3.0배(player.gd:774~776의 선형 보간 공식이 쓰는 상한값).
	var berserker_final_strike: Dictionary = GameState.SKILLS_BY_SECOND_JOB["berserker"][1]
	ok = _check("최후의 일격 low_hp_mult_max 3.0", is_equal_approx(float(berserker_final_strike["low_hp_mult_max"]), 3.0)) and ok

	# SECOND_JOB_DESIGN.md 7절 "가배치" 각주(분신술 실제 구현값)와 대조.
	var shadow_clone: Dictionary = GameState.SKILLS_BY_SECOND_JOB["shadow_dancer"][1]
	ok = _check("분신술 이동속도배율 0.7", is_equal_approx(float(shadow_clone["buff"]["value"]), 0.7)) and ok
	ok = _check("분신술 버프 3초 지속", is_equal_approx(float(shadow_clone["buff"]["duration"]), 3.0)) and ok
	ok = _check("분신술 무적 1.5초", is_equal_approx(float(shadow_clone["invuln"]), 1.5)) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
