extends Node
## 힘은 치명타 피해도, 민첩은 치명타 확률도 올리는지 확인한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	var chance_before := GameState.crit_chance()
	var dmg_before := GameState.crit_damage_mult()
	GameState.stats["agility"] += 4
	GameState.stats["strength"] += 4
	ok = _check("민첩이 오르면 치명타 확률도 오름", GameState.crit_chance() > chance_before) and ok
	ok = _check("힘이 오르면 치명타 피해도 오름", GameState.crit_damage_mult() > dmg_before) and ok
	ok = _check("치명타 피해 기본값 180%", abs(GameState.crit_damage_mult() - (1.8 + 4 * 0.02)) < 0.001) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
