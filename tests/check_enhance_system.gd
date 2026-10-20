extends Node
## 한국 MMORPG식 확률 강화(성공률 표, +6부터 파괴 위험, 부적으로 파괴 방지)를 확인한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	# 확률표 자체.
	ok = _check("+0->+1 은 100%", GameState.ENHANCE_RATES[0] == 1.0) and ok
	ok = _check("갈수록 확률이 떨어진다", GameState.ENHANCE_RATES[9] < GameState.ENHANCE_RATES[0]) and ok
	ok = _check("+5 미만은 위험 구간이 아님", not GameState.enhance_is_risky("철검")) and ok

	GameState.inventory = ["철검"]
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999

	# 강화 단계는 이름이 아니라 이 칸의 고유 번호(uid)로 저장된다 - 같은
	# 이름 여분 장비끼리 강화 수치가 섞이지 않게 하려고 바꿨다.
	# 안전 구간: 파괴 없이 하락만 있어야 한다. 여러 번 돌려서 fail 이 나오면
	# 아이템이 여전히 인벤토리에 남아 있는지 확인한다.
	var saw_fail := false
	for i in 300:
		GameState.enhance_levels[GameState.uid_of("철검")] = 2
		var r: String = GameState.enhance("철검")
		if r == "fail":
			saw_fail = true
			ok = _check("안전 구간 실패는 하락만(파괴 없음)", GameState.inventory.has("철검")) and ok
			break
	ok = _check("안전 구간에서 실패 사례를 관측함", saw_fail) and ok

	# 위험 구간: +5 이상이면 risky, 부적 없으면 파괴가 나올 수 있어야 한다.
	GameState.enhance_levels[GameState.uid_of("철검")] = 5
	ok = _check("+5는 위험 구간", GameState.enhance_is_risky("철검")) and ok

	var saw_destroy := false
	for i in 2000:
		if not GameState.inventory.has("철검"):
			GameState.inventory.append("철검")
		GameState.enhance_levels[GameState.uid_of("철검")] = 5
		GameState.enhance_wards = 0
		var r2: String = GameState.enhance("철검")
		if r2 == "destroyed":
			saw_destroy = true
			ok = _check("파괴되면 인벤토리에서 사라짐", not GameState.inventory.has("철검")) and ok
			break
	ok = _check("위험 구간에서 파괴 사례를 관측함", saw_destroy) and ok

	# 부적: 위험 구간에서 실패해도 부적이 있으면 파괴 대신 하락.
	GameState.inventory.append("철검")
	var warded_seen := false
	for i in 500:
		GameState.enhance_levels[GameState.uid_of("철검")] = 5
		GameState.enhance_wards = 1
		var r3: String = GameState.enhance("철검")
		if r3 == "warded":
			warded_seen = true
			ok = _check("부적 사용 시 아이템은 남아 있음", GameState.inventory.has("철검")) and ok
			ok = _check("부적 하나 소모됨", GameState.enhance_wards == 0) and ok
			break
		elif r3 == "success":
			continue
	ok = _check("부적으로 파괴를 막는 사례를 관측함", warded_seen) and ok

	# 착용 중 파괴되면 장비 칸이 빈다.
	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["철검"]
	GameState.equip("철검")
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	var unequipped := false
	for i in 2000:
		GameState.enhance_levels[GameState.uid_of("철검")] = 5
		GameState.enhance_wards = 0
		var r4: String = GameState.enhance("철검")
		if r4 == "destroyed":
			unequipped = str(GameState.equipped.get("weapon", "")) != "철검"
			break
		if not GameState.is_equipped("철검"):
			GameState.inventory.append("철검")
			GameState.equip("철검")
	ok = _check("착용 중이던 장비가 파괴되면 슬롯이 빈다", unequipped) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
