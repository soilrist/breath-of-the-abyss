extends Node
## 장신구 슬롯이 2개(trinket/trinket2)로 늘어난 걸 확인한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	GameState.level = 20
	GameState.inventory = ["구리 반지", "수정 목걸이", "정령의 부적"]

	ok = _check("첫 장신구는 trinket 자리로", GameState.equip("구리 반지") and GameState.equipped["trinket"] == "구리 반지") and ok
	ok = _check("두 번째 장신구는 trinket2 자리로", GameState.equip("수정 목걸이") and GameState.equipped["trinket2"] == "수정 목걸이") and ok
	ok = _check("두 장신구 모두 착용 판정", GameState.is_equipped("구리 반지") and GameState.is_equipped("수정 목걸이")) and ok

	var atk_before := GameState.attack_bonus
	ok = _check("두 장신구 공격력 합산됨(2+4=6 이상)", atk_before >= 6) and ok

	ok = _check("세 번째는 trinket 자리를 새 걸로 교체", GameState.equip("정령의 부적") and GameState.equipped["trinket"] == "정령의 부적") and ok
	ok = _check("trinket2는 그대로 유지", GameState.equipped["trinket2"] == "수정 목걸이") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
