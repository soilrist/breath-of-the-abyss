extends Node
## 5~9장 마을(원정지)의 퀘스트 담당 NPC는 그 마을의 대사 도입부에서 이미
## 소개된 이름이어야 한다. 예전에는 harbor를 뺀 모든 마을이 "촌장 로한"
## 이름·대사를 그대로 재사용했다(main.gd TOWN_QUEST_NPC 도입 전).
## 각 마을에서 실제 _interact_npc()를 호출해 대화창의 화자 이름을 읽는다.

const EXPECTED := {
	"village": "촌장 로한",
	"harbor": "수비대장 브란",
	"remnant_village": "생존자 렌",
	"driftwood_pier": "등대지기 노아",
	"lantern_village": "등불지기 세인",
	"waystation_camp": "정찰병 이든",
	"rift_camp": "정찰병 이든",
}


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	# 필러 대사(else 분기)만 확인하면 되므로, 의뢰·전직 분기를 전부 비켜 둔다.
	GameState.job = "warrior"
	GameState.bounty_index = GameState.BOUNTIES.size()
	GameState.bounty_taken = false
	GameState.quest_stage = 9999

	var player: CharacterBody2D = main.get_node("Player")
	for map_name in EXPECTED:
		GameState.unlock_map(map_name)
		main._change_map(map_name, false)
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		player.global_position = World.town_npc_position(map_name, "elder")
		main._interact_npc()
		await get_tree().process_frame
		var speaker: String = main.get_node("HUD/Dialogue/Speaker").text
		ok = _check("%s 화자 이름이 %s" % [map_name, EXPECTED[map_name]], speaker == EXPECTED[map_name]) and ok
		while main.dialogue_open: main._advance_dialogue()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
