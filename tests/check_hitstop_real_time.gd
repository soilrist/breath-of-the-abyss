extends Node
## 결함(감독, 2026-10-20 02:28): `_hitstop()`의 `create_timer()` 2번째 인자는
## `process_always` 지 `ignore_time_scale` 이 아니라 time_scale 0.05 에서
## 0.12초 타이머가 실제 2.4초(0.12/0.05) 걸렸다. 4번째 인자
## `ignore_time_scale=true` 로 고쳤으니, Engine.time_scale 을 실제로 0.05 로
## 둔 채 `_hitstop` 을 끝까지 await 하면 실제 경과가 duration(0.12초) 그대로여야
## 한다. 아래쪽 경계(0.1초)가 없으면 await 가 타이머를 안 기다리고 바로
## 반환되는 거짓 통과(경과 0.001초)도 "통과"로 잘못 찍힌다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	Engine.time_scale = 0.05
	var start_ms := Time.get_ticks_msec()
	await main._hitstop(0.12, 0.05)
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	ok = _check("히트스톱 시작~복구 실제 경과 0.1~0.2초(실제: %.3f초)" % elapsed, elapsed >= 0.1 and elapsed <= 0.2) and ok
	ok = _check("복구 후 time_scale == 1.0(실제: %s)" % Engine.time_scale, Engine.time_scale == 1.0) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
