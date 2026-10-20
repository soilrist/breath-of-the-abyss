extends Node
## 확정 강화(Z키, 실패·파괴 없이 강화석 배수로 무조건 성공)를 확인한다.
## "강화가 너무 어렵다, 확률 강화 말고 강화석을 더 내면 무조건 되는
## 방법도 있어야겠다"는 사용자 요청으로 추가된 기능(INBOX 신규 지시).

func _ready() -> void:
	GameState.reset()
	var ok := true

	GameState.level = 20
	GameState.inventory = ["철검"]
	GameState.materials[GameState.MATERIAL] = 999999
	GameState.gold = 999999999

	var uid := GameState.uid_of("철검")

	# 안전 구간(+0->+1): 확정 강화는 항상 성공하고, 비용은 확률 강화의
	# ENHANCE_GUARANTEED_MULT배여야 한다.
	var normal_cost := GameState.enhance_cost("철검", uid)
	var guaranteed_cost := GameState.enhance_guaranteed_cost("철검", uid)
	ok = _check("안전 구간 확정 강화 비용은 확률 강화의 %d배" % GameState.ENHANCE_GUARANTEED_MULT,
		int(guaranteed_cost["stones"]) == int(normal_cost["stones"]) * GameState.ENHANCE_GUARANTEED_MULT) and ok

	var before_stones: int = GameState.materials[GameState.MATERIAL]
	var result := GameState.enhance_guaranteed("철검", uid)
	ok = _check("확정 강화는 항상 success", result == "success") and ok
	ok = _check("확정 강화로 실제 한 단계 오름", GameState.enhance_of("철검", uid) == 1) and ok
	ok = _check("확정 강화 비용만큼 강화석 소모", GameState.materials[GameState.MATERIAL] == before_stones - int(guaranteed_cost["stones"])) and ok

	# 위험 구간(+5 이상)에서도 실패 없이 항상 성공해야 하고, 비용이 더 비싸야 한다.
	GameState.enhance_levels[uid] = GameState.ENHANCE_RISK_STEP
	var risky_normal_cost := GameState.enhance_cost("철검", uid)
	var risky_guaranteed_cost := GameState.enhance_guaranteed_cost("철검", uid)
	ok = _check("위험 구간 확정 강화 비용은 %d배" % (GameState.ENHANCE_GUARANTEED_MULT * GameState.ENHANCE_GUARANTEED_RISK_MULT),
		int(risky_guaranteed_cost["stones"]) == int(risky_normal_cost["stones"]) * GameState.ENHANCE_GUARANTEED_MULT * GameState.ENHANCE_GUARANTEED_RISK_MULT) and ok

	var destroyed_seen := false
	for i in 500:
		if not GameState.inventory.has("철검"):
			GameState.inventory.append("철검")
			uid = GameState.item_uid[GameState.inventory.find("철검")]
		GameState.enhance_levels[uid] = GameState.ENHANCE_RISK_STEP
		var r := GameState.enhance_guaranteed("철검", uid)
		if r != "success":
			destroyed_seen = true
			break
		if not GameState.inventory.has("철검"):
			destroyed_seen = true
			break
	ok = _check("위험 구간 확정 강화 500회 반복해도 파괴·실패 없음", not destroyed_seen) and ok
	ok = _check("500회 반복 후에도 아이템은 그대로", GameState.inventory.has("철검")) and ok

	# 최대 단계에서는 blocked.
	GameState.enhance_levels[uid] = GameState.MAX_ENHANCE
	ok = _check("최대 단계에서는 확정 강화도 blocked", GameState.enhance_guaranteed("철검", uid) == "blocked") and ok

	# 재료 부족이면 blocked(강화 안 되고 아이템도 그대로).
	GameState.enhance_levels[uid] = 0
	GameState.materials[GameState.MATERIAL] = 0
	ok = _check("강화석 부족이면 확정 강화도 blocked", GameState.enhance_guaranteed("철검", uid) == "blocked") and ok
	ok = _check("blocked면 단계 그대로", GameState.enhance_of("철검", uid) == 0) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
