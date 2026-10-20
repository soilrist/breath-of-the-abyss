extends Node
## AUTOHUNT_DESIGN.md §10.7(INBOX 10:05③) 검증.
## `_quest_home_town()`는 World.TOWNS 중 chapter_of(t)==GameState.chapter인
## 마을을 찾는데, 3·4·10장은 설계상 마을이 없어(docs/STATUS.md:3113) ""를
## 반환해 RETURN 단계 귀환 로직이 조용히 멈추는 버그가 있었다. 정확히
## 일치하는 장이 없으면 직전에 풀린 마을로 대체하도록 고쳤는지 확인한다.

## chapter -> 기대하는 홈 마을. (감독 2026-09-09) 장마다 마을이 하나씩 있다 -
## 3장 frost_camp, 4장 abyss(잿불 야영지), 10장 origin_camp(근원의 야영지) 추가.
## 사용자 요청("각 챕터별로 마을이있으면 그 마을에 전부 npc들이 있어야지").
const EXPECTED := {
	1: "village", 2: "harbor", 3: "frost_camp", 4: "abyss",
	5: "remnant_village", 6: "driftwood_pier", 7: "lantern_village",
	8: "waystation_camp", 9: "rift_camp", 10: "origin_camp",
}


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	for chapter in EXPECTED.keys():
		GameState.chapter = chapter
		var got: String = main._quest_home_town()
		ok = _check("chapter %d -> %s" % [chapter, EXPECTED[chapter]], got == EXPECTED[chapter]) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
