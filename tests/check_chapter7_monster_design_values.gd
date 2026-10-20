extends Node
## CHAPTER6_10_MASTERPLAN.md 2절(7장 신규 몬스터)과 enemy.gd KINDS 상수가
## 어긋나지 않는지 대조한다. 문서 표: 빛바랜 수도사(근접)/금박망령
## (근접·돌진)/합창술사(마법)/유물의 눈(원거리)/종소리골렘(근접·돌진).

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var kinds: Dictionary = EnemyScript.KINDS
	var ok := true

	ok = _check_kind(kinds, "faded_acolyte", "빛바랜 수도사", "chase") and ok
	ok = _check_kind(kinds, "gilded_wraith", "금박망령", "charge") and ok
	ok = _check_kind(kinds, "choir_caster", "합창술사", "magic") and ok
	ok = _check_kind(kinds, "relic_eye", "유물의 눈", "ranged") and ok
	ok = _check_kind(kinds, "bell_golem", "종소리골렘", "charge") and ok

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
