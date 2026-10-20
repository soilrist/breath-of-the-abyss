extends Node
## CHAPTER5_EXPANSION_DESIGN.md 5절(신규 몬스터 표)과 enemy.gd KINDS 상수가
## 어긋나지 않는지 대조한다. 표: 잔영병(근접)/부유석(원거리)/침식술사(마법)/
## 파편감시자(마법)/폭주골렘(근접·돌진). 밸런스 숫자는 game_state.gd(스킬·
## 아이템)와 별개로 몬스터 표는 enemy.gd KINDS에 있으므로 그쪽과 대조한다.

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var kinds: Dictionary = EnemyScript.KINDS
	var ok := true

	ok = _check_kind(kinds, "wraith_soldier", "잔영병", "chase") and ok
	ok = _check_kind(kinds, "floating_shard", "부유석", "ranged") and ok
	ok = _check_kind(kinds, "corruptor", "침식술사", "magic") and ok
	ok = _check_kind(kinds, "shard_watcher", "파편감시자", "magic") and ok
	ok = _check_kind(kinds, "rampaging_golem", "폭주골렘", "charge") and ok

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
