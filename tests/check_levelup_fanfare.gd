extends Node
## 레벨업 축제 연출 (INBOX 2026-10-20 00:09). 배너·증가치 카드가 LevelUpFx
## 노드에 실제로 뜨는지, 주변 적이 밀려나는지, 전투가 멈추지 않는지 단언한다.
## `--headless` 라 `_hitstop()`은 건너뛴다(main.gd `DisplayServer.get_name()`
## 가드) - 여긴 그 바깥(배너·카드·밀쳐내기)만 검사한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.global_position = main.get_node("Player").global_position + Vector2(20, 0)
	var enemy_pos_before: Vector2 = enemy.global_position

	main._on_enemy_defeated(GameState.next_exp, 0)

	var fx = main._levelup_fx
	ok = _check("LevelUpFx 배너가 보임", fx._banner.visible) and ok
	ok = _check("LevelUpFx 카드 칸이 보임", fx._cards.visible) and ok
	ok = _check("증가치 카드 6줄(레벨·HP·공격·능력치·다음 보상·특성 선택권)", fx._cards.get_child_count() == 6) and ok
	ok = _check("배너 글자에 LEVEL UP 포함(실제: %s)" % fx._banner.text, fx._banner.text.contains("LEVEL UP")) and ok
	ok = _check("가까운 적이 밀려남(실제 변위: %s)" % str(enemy.global_position - enemy_pos_before),
		enemy.global_position != enemy_pos_before) and ok
	ok = _check("전투가 멈추지 않음(일시정지 아님)", not main.get_tree().paused) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
