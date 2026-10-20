extends Node
## 경험치 곡선(GameState.exp_for_level): 20까지 1.30배, 그 뒤 1.06배. 예전
## 곡선(끝까지 1.30배)으로 저장된 next_exp가 add_reward에서 내려가는지도 본다.
func _ready() -> void:
	var ok := true
	ok = ok and GameState.exp_for_level(1) == 80
	ok = ok and GameState.exp_for_level(20) == int(80.0 * pow(1.30, 19))
	ok = ok and GameState.exp_for_level(21) == int(80.0 * pow(1.30, 19) * 1.06)
	ok = ok and GameState.exp_for_level(43) < 50000 and GameState.exp_for_level(60) < 130000
	GameState.reset()
	GameState.level = 43
	GameState.exp = 0
	GameState.next_exp = 4883270  # 예전 곡선 저장값
	GameState.add_reward(275, 0)
	ok = ok and GameState.level == 43 and GameState.next_exp == GameState.exp_for_level(43)
	GameState.add_reward(GameState.next_exp, 0)
	ok = ok and GameState.level == 44 and GameState.next_exp == GameState.exp_for_level(44)
	print("L20=%d L40=%d L43=%d L60=%d" % [GameState.exp_for_level(20), GameState.exp_for_level(40), GameState.exp_for_level(43), GameState.exp_for_level(60)])
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
