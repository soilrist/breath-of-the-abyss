extends Node
## (결함 수정 검증, INBOX 2026-10-20 00:11 origin_throne 반복 사망 ②) "큰 공격엔
## 0.5초 이상 전조 표시" 기준선이 실제 코드에 들어갔는지 — 보스 특수기(lunge)
## 예비동작·돌진·범위·원거리(volley) 시전 네 가지 전부 ≥0.5초인지 단언한다.


func _ready() -> void:
	var ok := true
	var boss: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	boss.is_boss = true
	add_child(boss)
	await get_tree().physics_frame

	var lunge_windup: float = boss.SWING_BOSS * 1.4
	ok = _check("보스 lunge(특수기) 전조 ≥0.5초(실제: %.3f초)" % lunge_windup, lunge_windup >= 0.5) and ok
	ok = _check("보스 dash 전조 ≥0.5초(실제: %.3f초)" % GameState.BOSS_DASH_WINDUP, GameState.BOSS_DASH_WINDUP >= 0.5) and ok
	ok = _check("보스 aoe 전조 ≥0.5초(실제: %.3f초)" % GameState.BOSS_AOE_WINDUP, GameState.BOSS_AOE_WINDUP >= 0.5) and ok
	ok = _check("보스 volley 시전 ≥0.5초(실제: %.3f초)" % GameState.BOSS_VOLLEY_CAST, GameState.BOSS_VOLLEY_CAST >= 0.5) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print(("PASS " if cond else "FAIL ") + label)
	return cond
