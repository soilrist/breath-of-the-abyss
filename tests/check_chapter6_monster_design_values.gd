extends Node
## CHAPTER6_10_MASTERPLAN.md 2절(6장 신규 몬스터)과 enemy.gd KINDS 상수가
## 어긋나지 않는지 대조한다. 문서는 원래 "파편수집자(shard_collector)/
## 격랑골렘(surge_golem)"이라 적고 있었으나 실제로 구현된 것은
## "표류귀(driftghoul)/산호감시병(coral_sentinel)"이라 문서를 코드에 맞춰
## 정정했다(INBOX I "코드가 먼저" 선례를 따름). 표: 조류게(근접)/표류귀
## (근접·돌진)/조류술사(마법)/심해안(원거리)/산호감시병(원거리).

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var kinds: Dictionary = EnemyScript.KINDS
	var ok := true

	ok = _check_kind(kinds, "tideclaw", "조류게", "chase") and ok
	ok = _check_kind(kinds, "driftghoul", "표류귀", "charge") and ok
	ok = _check_kind(kinds, "tidecaster", "조류술사", "magic") and ok
	ok = _check_kind(kinds, "depth_eye", "심해안", "ranged") and ok
	ok = _check_kind(kinds, "coral_sentinel", "산호감시병", "ranged") and ok

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
