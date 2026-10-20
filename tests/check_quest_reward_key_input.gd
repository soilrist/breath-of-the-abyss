extends Node
## STATUS.md "다음에 할 것" 97번 (c): 퀘스트 완료 보상 수령이 실제 E 키
## 입력 경로로 검사됐는지 확인한다. `main.gd:746~752`(quest_stage == 2일 때
## 촌장과 대화하면 골드 100 + 가죽 갑옷을 주고 quest_stage를 3으로 올리는
## 분기)는 `integration_test.gd:946`에서 `game._interact_npc()`를 코드로
## 직접 호출해서만 검증됐다(⑥ 규칙이 경고하는 패턴). `check_interact_key_input.gd`
## 와 같은 방식으로 main._unhandled_input(InputEventKey)에 진짜 E 키를 넣어
## 보상 수령까지 이어지는지 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := await _check_reward_via_key_input()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_reward_via_key_input() -> bool:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.quest_stage = 2
	var gold_before: int = GameState.gold
	var inv_count_before: int = GameState.inventory.size()
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = main.NPC_POSITION

	_send_key(main, KEY_E)
	await get_tree().process_frame

	var ok := _check("E 키 입력만으로 보상 대화 열림", main.dialogue_open)
	ok = _check("보상 수령 즉시 quest_stage 3으로 전진", GameState.quest_stage == 3) and ok
	ok = _check("골드 100 지급", GameState.gold == gold_before + 100) and ok
	ok = _check("가죽 갑옷 지급", GameState.inventory.size() == inv_count_before + 1
		and GameState.inventory[-1] == "가죽 갑옷") and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("다음 대사에 보상 문구(100골드와 가죽 갑옷)",
		main.get_node("HUD/Dialogue/Text").text.contains("100골드")) and ok

	while main.dialogue_open: main._advance_dialogue()
	ok = _check("대화 닫힌 뒤 골드는 그대로 유지", GameState.gold == gold_before + 100) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
