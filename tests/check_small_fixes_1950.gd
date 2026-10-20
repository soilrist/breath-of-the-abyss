extends Node
## 12인 심판 결함(감독, 2026-10-20 19:50) — 작은 결함 3개 묶음.
## ① enemy.gd 의 처치 히트스톱이 Hit.hitstop() 의 "이미 멈춰 있으면 무시" 가드에
## 막혀 죽은 코드였다 — 평타 Hit.strike 의 0.06초가 먼저 걸려 있으면 처치의 0.04초
## (보스는 0.25초)가 전혀 안 먹었다. Hit.hitstop() 이 maxf 로 덮어쓰게 고쳤으니
## 처치 멈춤이 평타 멈춤보다 길게 남아야 한다.
## ② story.gd NAMES 에 "boss_origin" 이 없어 10장 최종보스 대사의 화자 이름이
## 키 그대로("boss_origin") 찍혔다 — "근원" 으로 나와야 한다.
## ③ run_validation.sh 의 RESULT PASS 임계값이 등록 수(223~224)와 무관한 옛값
## 160이라 크래시 70개가 나도 통과였다 — 220 이상으로 올렸다.

func _ready() -> void:
	var ok := true

	Hit.hitstop(0.06)
	Hit.hitstop(0.25)
	ok = _check("처치(0.25) 가 평타(0.06) 뒤에도 더 긴 값으로 남음(실제: %.3f)" % Hit._stop_left,
		Hit._stop_left >= 0.2) and ok

	ok = _check("name_of(boss_origin) == 근원(실제: %s)" % Story.name_of("boss_origin"),
		Story.name_of("boss_origin") == "근원") and ok

	var threshold_line := ""
	for line in FileAccess.get_file_as_string("res://tests/run_validation.sh").split("\n"):
		if line.contains("RESULT PASS") and line.contains("-ge"):
			threshold_line = line
			break
	var threshold := int(threshold_line.get_slice("-ge ", 1).strip_edges())
	ok = _check("run_validation.sh 임계값 >= 220(실제: %d)" % threshold, threshold >= 220) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
