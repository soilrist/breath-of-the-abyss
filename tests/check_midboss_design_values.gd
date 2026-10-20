## MAP_MOB_FX_DESIGN.md 5절(중간보스 시스템, "가배치" 각주)에 적은 실제
## 구현값과 GameState 상수·main.gd 스폰 로직이 어긋나지 않는지 대조한다.
extends Node

const MainScript := preload("res://scripts/main.gd")

func _ready() -> void:
	var ok := true

	ok = _check("MIDBOSS_HP_MULT 4.0", is_equal_approx(GameState.MIDBOSS_HP_MULT, 4.0)) and ok
	ok = _check("MIDBOSS_DAMAGE_MULT 1.6", is_equal_approx(GameState.MIDBOSS_DAMAGE_MULT, 1.6)) and ok
	ok = _check("MIDBOSS_REWARD_MULT 2.5", is_equal_approx(GameState.MIDBOSS_REWARD_MULT, 2.5)) and ok

	ok = _check("MIDBOSS_SLOTS == [2, 5](3번째·6번째)", MainScript.MIDBOSS_SLOTS == [2, 5]) and ok
	ok = _check("MIDBOSS_AREAS 비어있지 않음", not MainScript.MIDBOSS_AREAS.is_empty()) and ok

	var tier: Dictionary = MainScript.TIERS[1]
	var mid_hp := int(tier["hp"] * GameState.MIDBOSS_HP_MULT)
	var normal_hp := int(tier["hp"] * 1.0)
	ok = _check("중간보스 HP가 일반 몹보다 실제로 강함", mid_hp > normal_hp) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
