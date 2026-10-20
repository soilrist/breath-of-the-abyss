extends Node
## INBOX D에서 안개숲 3지역을 forest_w 하나(8x2)로 합친 뒤(`ca0a38d`) 몬스터
## 40마리가 한 화면에 함께 깔리게 됐다(AREA_SPAWNS["forest_w"] 합계 6+5+4+6+4+6+5+4).
## 합격 기준①("끊김 없이 플레이")과 직결되는데 이 프로젝트엔 성능 검사가 하나도
## 없었다 - 지역 하나에서 물리 프레임을 다수 돌려 프레임당 처리 시간이 터무니없이
## 느려지지 않는지(예: 몬스터 수 증가가 어딘가 O(n^2) 스캔을 깨웠는지)만 잡는
## 스모크 검사다. 엄밀한 FPS 측정이 아니라 "떨어뜨린 뒤 회귀했는가"용 넉넉한 문턱이다.

const FRAMES := 60
const MAX_AVG_FRAME_MS := 50.0  # 60fps 예산(16.6ms)의 3배 - 헤드리스 노이즈 감안한 넉넉한 문턱.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._change_map("forest_w", false)
	await get_tree().process_frame
	var mobs := get_tree().get_nodes_in_group("enemies")
	ok = _check("forest_w 몬스터 40마리 스폰", mobs.size() == 40) and ok

	var start_us := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().physics_frame
	var elapsed_ms := (Time.get_ticks_usec() - start_us) / 1000.0
	var avg_ms := elapsed_ms / FRAMES
	ok = _check("몬스터 40마리 프레임당 평균 %.2fms < %.0fms" % [avg_ms, MAX_AVG_FRAME_MS], avg_ms < MAX_AVG_FRAME_MS) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
