extends Node
## 사냥터에 맞춰 늘린 의뢰 4개(b10~b13)가 실제로 완료까지 되는지 확인한다.
## 기존 9개 순서를 그대로 두고 뒤에 붙였으니 인덱스 밀림도 같이 본다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	ok = _check("의뢰가 13개로 늘어남", GameState.BOUNTIES.size() == 13) and ok
	ok = _check("기존 9번째 의뢰 그대로(b9)", str(GameState.BOUNTIES[8]["id"]) == "b9") and ok
	for i in range(9, 13):
		var b: Dictionary = GameState.BOUNTIES[i]
		ok = _check("%s 보상 아이템이 실제 EQUIPMENT 표에 있음" % b["id"], GameState.EQUIPMENT.has(b["item"])) and ok

	# b10 을 실제로 완료까지 진행해 본다.
	GameState.bounty_index = 9
	ok = _check("b10 부터 시작", GameState.current_bounty()["id"] == "b10") and ok
	ok = _check("의뢰 받기", GameState.take_bounty()) and ok
	for i in 6:
		GameState.record_kill("beast")
	ok = _check("사냥 6마리 채우면 완료", GameState.bounty_done()) and ok
	var gold_before := GameState.gold
	var claimed := GameState.claim_bounty()
	ok = _check("보상 수령", not claimed.is_empty() and GameState.gold > gold_before) and ok
	ok = _check("다음 의뢰(b11)로 넘어감", GameState.current_bounty()["id"] == "b11") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
