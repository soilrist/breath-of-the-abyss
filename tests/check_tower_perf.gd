extends Node
## 탑 최고 난이도 구간(floor_num이 클수록 몬스터 수가 늘어나는
## count = 5 + floor_num / 10 식 때문에 100층 근처에서 최대치가 된다)에서도
## 프레임당 처리 시간이 안 튀는지 검증한다. check_forest_w_perf.gd/
## check_ruins_w_perf.gd는 필드 지역만 다뤘고, 탑은 check_tower_floor_advance_leak.gd
## 가 누수만 봤을 뿐 프레임 시간을 잰 적은 없었다(합격 기준①의 "끊김 없이" 공백).
## 100층에서 count = 5 + 100/10 = 15마리(필드 최대 40마리보다 적어 여유는
## 있지만, 탑 전용 스폰 로직 자체를 처음으로 프레임 측정하는 데 의의가 있다).

const FRAMES := 60
const MAX_AVG_FRAME_MS := 50.0  # check_forest_w_perf.gd와 동일 문턱(60fps 예산의 3배).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.game_cleared = true
	GameState.tower_difficulty = "easy"
	GameState.tower_progress["easy"] = 100
	GameState.tower_active = true
	main._change_map("tower", false)
	await get_tree().process_frame
	GameState.tower_floor = 100
	main._spawn_tower_floor()
	await get_tree().process_frame

	var mobs := get_tree().get_nodes_in_group("enemies")
	ok = _check("탑 100층 몬스터 %d마리 스폰(기대 15)" % mobs.size(), mobs.size() == 15) and ok

	var start_us := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().physics_frame
	var elapsed_ms := (Time.get_ticks_usec() - start_us) / 1000.0
	var avg_ms := elapsed_ms / FRAMES
	ok = _check("탑 100층 프레임당 평균 %.2fms < %.0fms" % [avg_ms, MAX_AVG_FRAME_MS], avg_ms < MAX_AVG_FRAME_MS) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
