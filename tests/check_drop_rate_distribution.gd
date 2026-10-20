extends Node
## Pickup.roll_drop(false)의 실제 확률을 대량 시행으로 실측해 코드 자체에
## 박힌 의도(scripts/pickup.gd 주석: "대부분(46%) 아무것도 안 나온다",
## 컷오프 12/30/48/52/57)와 일치하는지 검사한다. 기획서에 이 수치를
## 명시한 절이 없어(규칙③) 새 숫자를 만들지 않고, 코드가 스스로 적어둔
## 의도와 코드의 실제 동작이 일치하는지만 대조한다.

const TRIALS := 20000
## 이항분포 표준편차(p=0.12, n=20000)가 약 0.23%p라 4%p 문턱은 넉넉하다.
const TOLERANCE := 0.04

func _ready() -> void:
	GameState.reset()
	GameState.chapter = 1
	var counts := {"potion": 0, "gold": 0, "stone": 0, "magic_stone": 0, "chest": 0, "none": 0}
	for i in range(TRIALS):
		var drop := Pickup.roll_drop(false)
		var kind: String = drop.get("kind", "none") if not drop.is_empty() else "none"
		counts[kind] = counts.get(kind, 0) + 1

	var expected := {"potion": 0.12, "gold": 0.18, "stone": 0.18, "magic_stone": 0.04, "chest": 0.05, "none": 0.43}
	var ok := true
	for kind: String in expected.keys():
		var actual: float = float(counts.get(kind, 0)) / float(TRIALS)
		var diff: float = absf(actual - expected[kind])
		print(kind, " 기대=", expected[kind], " 실측=", actual, " ", "OK" if diff <= TOLERANCE else "FAIL")
		ok = ok and diff <= TOLERANCE

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
