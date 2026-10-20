extends Node
## _quest_stage_text()가 실제로 쓰이는 모든 quest_stage 값에 전용 문구를 갖는지 확인한다.
## 9월4일 발견: 51/61(9·10장 진행 중)에 케이스가 없어 default("게임 클리어")로
## 빠져 스크린샷에서 진행 중인데 "게임 클리어"가 뜨는 버그가 있었다.

## scripts/main.gd에서 GameState.quest_stage = N 형태로 실제 대입되는 값들.
## 69만 진짜 최종 클리어라 default("게임 클리어")로 떨어져도 맞다.
const USED_STAGES: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 19, 20, 21, 29, 30, 31,
	39, 40, 41, 49, 50, 51, 59, 60, 61,
]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	for stage in USED_STAGES:
		GameState.quest_stage = stage
		var text: String = main._quest_stage_text()
		ok = _check("stage %d 전용 문구" % stage, text != "게임 클리어") and ok

	# 3장 서리벌 설원: 실제 진입 조건은 chapter_kills>=12(main.gd:220)인데
	# 문구 전환 조건이 <6으로 어긋나 있던 버그(수정 완료, 회귀 방지).
	GameState.quest_stage = 6
	GameState.chapter_kills = 11
	ok = _check("stage 6, 11마리는 아직 진행 중 문구", main._quest_stage_text().contains("11/12")) and ok
	GameState.chapter_kills = 12
	ok = _check("stage 6, 12마리면 완료 문구", main._quest_stage_text() == "얼어붙은 신전으로 들어가자") and ok

	# INBOX 10:05 ①: QUEST_STAGE_KIND가 _quest_stage_text()의 match 가지를
	# 빠짐없이(과부족 없이) 덮는지 확인한다. 가지 목록을 여기 다시 베끼면
	# main.gd가 바뀔 때 둘이 따로 놀 수 있으니, main.gd 소스에서 직접
	# 뽑아 비교한다(규칙③: 숫자는 한 곳에서만 조회).
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var body_start := src.find("func _quest_stage_text()")
	var body_end := src.find("\nfunc ", body_start + 1)
	var body := src.substr(body_start, body_end - body_start)
	var match_stages: Array[int] = []
	for line in body.split("\n"):
		var stripped := line.strip_edges()
		var colon := stripped.find(": return")
		if colon > 0 and stripped.substr(0, colon).is_valid_int():
			match_stages.append(int(stripped.substr(0, colon)))
	match_stages.sort()
	var kind_stages: Array = GameState.QUEST_STAGE_KIND.keys()
	kind_stages.sort()
	ok = _check("QUEST_STAGE_KIND가 match 가지 %s개를 정확히 덮음: %s vs %s" %
		[match_stages.size(), match_stages, kind_stages], match_stages == kind_stages) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
