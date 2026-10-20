extends Node
## CHAPTER6_10_MASTERPLAN.md 2절(8장 신규 몬스터)과 enemy.gd KINDS 상수가
## 어긋나지 않는지 대조한다. 문서는 원래 "잿빛문지기(ash_sentry)/적막의
## 서기(silent_scribe)/무너진 파수병(fallen_watch)"이라 적고 있었으나 실제로
## 구현된 것은 "감독관의 서기(warden_scribe)/잿빛 파수병(grey_sentinel)/
## 침묵골렘(silence_golem)"이라 문서를 코드에 맞춰 정정했다(INBOX I "코드가
## 먼저" 선례를 따름). 표: 말없는 추적자(근접)/메아리귀병(근접·돌진)/
## 감독관의 서기(마법)/잿빛 파수병(원거리)/침묵골렘(근접·돌진).

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var kinds: Dictionary = EnemyScript.KINDS
	var ok := true

	ok = _check_kind(kinds, "muted_stalker", "말없는 추적자", "chase") and ok
	ok = _check_kind(kinds, "echo_wraith", "메아리귀병", "charge") and ok
	ok = _check_kind(kinds, "warden_scribe", "감독관의 서기", "magic") and ok
	ok = _check_kind(kinds, "grey_sentinel", "잿빛 파수병", "ranged") and ok
	ok = _check_kind(kinds, "silence_golem", "침묵골렘", "charge") and ok

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
