extends Node
## 6~10장 신규 사냥터 26곳(charred_corridor~the_seam, 모두 11마리 스폰)은
## forest_w/ruins_w/tower와 달리 프레임 성능 검사가 하나도 없었다(합격
## 기준①의 공백). 26곳 전부 60프레임씩 재면 느려서(스크린샷/씬 로드
## 비용), 대표로 처음/중간/끝 3곳만 60프레임 정밀 측정하고, 나머지
## 23곳은 스폰 수만 빠르게 순회 확인하는 절충안으로 짠다.

const FRAMES := 60
const MAX_AVG_FRAME_MS := 50.0  # check_forest_w_perf.gd와 동일 문턱.

# scripts/main.gd AREA_SPAWNS에서 count 합이 11인 6~10장 사냥터 26곳
# (hill_ridge/shore는 count가 우연히 11인 1~4장 기존 지역이라 제외).
const CH6_10_HUNTS := [
	"charred_corridor", "collapsed_spires", "eroded_plaza", "cracked_statue",
	"hall_of_afterimages", "twisted_sanctum", "sunken_causeway", "tideglass_shallows",
	"current_maw", "coral_wreckage", "abyssal_trench", "sunbleached_stair",
	"vow_terrace", "gilded_cloister", "hollow_nave", "ashen_reliquary",
	"threshold_stair", "silent_archive", "hollow_barracks", "grey_reservoir",
	"inverted_stair", "echo_of_forest", "echo_of_captain", "echo_of_frost",
	"echo_of_abyss", "the_seam",
]
# 프레임 정밀 측정 대상(처음/중간/끝).
const PERF_SAMPLE := ["charred_corridor", "gilded_cloister", "the_seam"]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.game_cleared = true

	for region in CH6_10_HUNTS:
		main._change_map(region, false)
		await get_tree().process_frame
		var mobs := get_tree().get_nodes_in_group("enemies")
		ok = _check("%s 몬스터 11마리 스폰" % region, mobs.size() == 11) and ok

		if region in PERF_SAMPLE:
			var start_us := Time.get_ticks_usec()
			for i in FRAMES:
				await get_tree().physics_frame
			var elapsed_ms := (Time.get_ticks_usec() - start_us) / 1000.0
			var avg_ms := elapsed_ms / FRAMES
			ok = _check("%s 프레임당 평균 %.2fms < %.0fms" % [region, avg_ms, MAX_AVG_FRAME_MS],
				avg_ms < MAX_AVG_FRAME_MS) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
