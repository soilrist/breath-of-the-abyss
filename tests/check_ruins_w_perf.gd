extends Node
## check_forest_w_perf.gd와 같은 패턴. STATUS.md는 forest_w(40마리)가 "가장 밀도
## 높은 사례"라고 적었지만 AREA_SPAWNS 전체 합계를 다시 세어보니 ruins_w(2장,
## INBOX D `d3e1ef6`에서 ruins_w/watchtower/ruins_e를 합친 지역)가 41마리로 더
## 많다 - 그 문장은 확인 없이 적힌 추정이었다. 이 지역도 같은 스모크 검사로 잰다.

const FRAMES := 60
const MAX_AVG_FRAME_MS := 50.0  # 60fps 예산(16.6ms)의 3배 - 헤드리스 노이즈 감안한 넉넉한 문턱.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._change_map("ruins_w", false)
	await get_tree().process_frame
	var mobs := get_tree().get_nodes_in_group("enemies")
	ok = _check("ruins_w 몬스터 41마리 스폰", mobs.size() == 41) and ok

	var start_us := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().physics_frame
	var elapsed_ms := (Time.get_ticks_usec() - start_us) / 1000.0
	var avg_ms := elapsed_ms / FRAMES
	ok = _check("몬스터 41마리 프레임당 평균 %.2fms < %.0fms" % [avg_ms, MAX_AVG_FRAME_MS], avg_ms < MAX_AVG_FRAME_MS) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
