extends Node
## 강화 수치는 이름이 아니라 칸(고유 번호)별로 따로 관리돼야 한다. 같은
## 이름 여분 장비가 있을 때 하나만 강화/파괴해도 나머지 사본은 그대로여야
## 한다("1개 강화하는데 동일 아이템이 같이 강화되는 버그" 재발 방지).

func _ready() -> void:
	GameState.reset()
	var ok := true

	GameState.level = 20
	GameState.inventory = ["철검", "철검"]
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999

	var uid_a := GameState.uid_of("철검")
	var uid_b := GameState.item_uid[1]
	ok = _check("두 사본은 서로 다른 번호를 가진다", uid_a != uid_b) and ok

	GameState.enhance("철검", uid_a)
	ok = _check("강화한 사본만 단계가 오른다", GameState.enhance_of("철검", uid_a) == 1) and ok
	ok = _check("남은 사본은 강화 안 됨", GameState.enhance_of("철검", uid_b) == 0) and ok

	var destroyed := false
	for i in 2000:
		GameState.enhance_levels[uid_a] = GameState.ENHANCE_RISK_STEP
		GameState.enhance_wards = 0
		if GameState.enhance("철검", uid_a) == "destroyed":
			destroyed = true
			break
	ok = _check("위험 구간에서 파괴 사례를 관측함", destroyed) and ok
	ok = _check("파괴된 건 그 사본 하나뿐", GameState.inventory.size() == 1) and ok
	ok = _check("남은 사본의 강화 수치는 그대로 유지된다", GameState.enhance_of("철검", uid_b) == 0) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
