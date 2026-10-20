## CHAPTER6_10_MASTERPLAN.md 2절(9장 신규 몬스터)과 enemy.gd KINDS 상수가
## 어긋나지 않는지 대조한다. 표: 뒤틀린 흑기사(근접)/뒤틀린 숲짐승(근접)/
## 역행하는 정령(원거리)/모순의 술사(마법)/이음매 방랑자(근접·돌진).
extends Node

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var kinds: Dictionary = EnemyScript.KINDS
	var ok := true

	ok = _check_kind(kinds, "twisted_knight", "뒤틀린 흑기사", "chase") and ok
	ok = _check_kind(kinds, "twisted_beast", "뒤틀린 숲짐승", "chase") and ok
	ok = _check_kind(kinds, "reversed_wisp", "역행하는 정령", "ranged") and ok
	ok = _check_kind(kinds, "paradox_caster", "모순의 술사", "magic") and ok
	ok = _check_kind(kinds, "seam_walker", "이음매 방랑자", "charge") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_kind(kinds: Dictionary, key: String, label: String, behavior: String) -> bool:
	if not kinds.has(key):
		print(label, " (", key, ") 존재 ", "FAIL")
		return false
	var kind: Dictionary = kinds[key]
	var ok := true
	ok = _check(label + " label", str(kind.get("label", "")) == label) and ok
	# behavior 키가 없으면 기본값이 근접(chase)이다(enemy.gd _act() 참고).
	var actual_behavior: String = str(kind.get("behavior", "chase"))
	ok = _check(label + " behavior=" + behavior, actual_behavior == behavior) and ok
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
