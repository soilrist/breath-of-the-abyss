## INBOX 지시(2026-10-19 23:43): Lv8~40 스킬 공백 메우기.
## 직업 3종 각각 Lv12/20/30 에서 active_skills() 가 늘어나는지(5·6번
## 슬롯 채움)와 Lv30 에 인덱스 2(Lv8 스킬)가 상위판으로 바뀌는지 확인한다.
extends Node

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _ready() -> void:
	var ok := true
	for job in ["warrior", "mage", "rogue"]:
		GameState.reset()
		GameState.job = job

		GameState.level = 11
		var before_30: Dictionary = GameState.active_skills()[2]
		ok = _check("%s Lv11 스킬 수(4)" % job, GameState.active_skills().size() == 4) and ok

		GameState.level = 12
		var lv12_list: Array = GameState.active_skills()
		ok = _check("%s Lv12 스킬 수(5)" % job, lv12_list.size() == 5) and ok
		ok = _check("%s Lv12 신규 스킬 id" % job,
			str(lv12_list[4]["id"]) == str(GameState.SKILLS_LV12_BY_JOB[job]["id"])) and ok

		GameState.level = 20
		var lv20_list: Array = GameState.active_skills()
		ok = _check("%s Lv20 스킬 수(6)" % job, lv20_list.size() == 6) and ok
		ok = _check("%s Lv20 신규 스킬 id" % job,
			str(lv20_list[5]["id"]) == str(GameState.SKILLS_LV20_BY_JOB[job]["id"])) and ok

		GameState.level = 30
		var lv30_list: Array = GameState.active_skills()
		ok = _check("%s Lv30 Lv8 슬롯 상위판 교체" % job,
			str(lv30_list[2]["id"]) == str(GameState.SKILLS_LV30_UPGRADE_BY_JOB[job]["id"])
			and int(lv30_list[2]["level"]) == 30) and ok
		ok = _check("%s Lv30 전 슬롯과 다름" % job,
			lv30_list[2]["cost"] != before_30["cost"] or lv30_list[2]["id"] != before_30["id"]) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
