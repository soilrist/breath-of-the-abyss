extends Node
## 레벨업 메시지가 퀘스트 문구에 바로 덮이던 버그 (INBOX 2026-10-19 23:40,
## main.gd:444 가 레벨업을 무조건 숫자 안내로 덮어썼다) 는 처음엔 HUD 상단
## 문구로 고쳤으나, 결함(감독, 2026-10-20 01:30)에서 그 문구가 밝은 맵 배경과
## 대비가 안 나고 x270 너머까지 넘쳐 겹친다는 지적을 받아 "연출 중 HUD 위쪽
## 문구는 숨기고 증가치는 LevelUpFx 카드로만 보여준다"로 바꿨다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var level_before: int = GameState.level
	main._on_enemy_defeated(GameState.next_exp, 0)
	ok = _check("레벨업 숫자가 올라감(실제: %d)" % GameState.level, GameState.level > level_before) and ok

	var hud_msg: Node = main.get_node("HUD/Message")
	ok = _check("연출 중 HUD 위쪽 문구가 숨겨짐(실제 visible=%s)" % hud_msg.visible,
		hud_msg.visible == false) and ok

	var card_texts: Array[String] = []
	for child in main._levelup_fx._cards.get_children():
		card_texts.append(child.text)
	var joined := "\n".join(card_texts)
	ok = _check("카드에 레벨 번호 포함(실제: %s)" % joined,
		joined.contains("Lv.%d" % GameState.level)) and ok
	ok = _check("카드에 증가치 포함(실제: %s)" % joined,
		joined.contains("HP ") and joined.contains("공격 ") and joined.contains("능력치 점수 +")) and ok

	# 연출(LevelUpFx)이 끝나면 HUD 문구가 다시 보여야 한다 - 실제 애니메이션
	# 시간을 기다리지 않고 finished 신호를 직접 쏴 연결이 올바른지만 본다.
	main._levelup_fx.finished.emit()
	ok = _check("연출 끝나면 HUD 문구 다시 보임(실제 visible=%s)" % hud_msg.visible,
		hud_msg.visible == true) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
