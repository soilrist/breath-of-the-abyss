extends Node
## 대장간 "옵션" 탭(감독 2026-09-08): 골드+강화석으로 장비 랜덤 옵션을 다시
## 굴린다. 탭 순환에 끼어 있고, 비용 부족이면 거절, 성공하면 옵션이 붙고
## 착용 중이면 능력치에 바로 반영돼야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.reset()
	GameState.level = 20
	seed(11)
	GameState.add_item("철검")
	var uid: int = GameState.item_uid[0]
	GameState.equip("철검", uid)
	var base_atk := GameState.attack_bonus

	main._toggle_forge()
	for i in 3:
		main._cycle_forge_mode(1)
	ok = _check("←→ 세 번이면 옵션 탭", main.forge_mode == "reroll") and ok
	ok = _check("탭 줄에 [옵션] 표시", main._forge_tabs_text().contains("[옵션]")) and ok
	ok = _check("상세에 비용 안내", main.get_node("HUD/Forge/Detail").text.contains("옵션 재굴림")) and ok
	main._cycle_forge_mode(1)
	ok = _check("한 번 더 돌면 강화 탭으로 감싼다", main.forge_mode == "enhance") and ok
	main._cycle_forge_mode(-1)

	GameState.gold = 0
	GameState.materials[GameState.MATERIAL] = 5
	main._activate_selected_forge_item()
	ok = _check("골드 부족이면 거절", GameState.affix_of(uid).is_empty()
		and main.get_node("HUD/Forge/Notice").text.contains("부족")) and ok

	var cost: Dictionary = GameState.reroll_cost("철검")
	ok = _check("비용은 강화석 1 + 최소 50G", int(cost["stones"]) == 1 and int(cost["gold"]) >= 50) and ok
	GameState.gold = int(cost["gold"])
	main._activate_selected_forge_item()
	var rolled: Dictionary = GameState.affix_of(uid)
	ok = _check("재굴림 성공: 옵션 1~3줄", rolled.size() >= 1 and rolled.size() <= 3) and ok
	ok = _check("골드/강화석 차감", GameState.gold == 0 and int(GameState.materials[GameState.MATERIAL]) == 4) and ok
	ok = _check("착용 중이면 공격 보너스에 즉시 반영",
		GameState.attack_bonus == base_atk + int(rolled.get("atk", 0))) and ok
	ok = _check("알림에 새 이름", main.get_node("HUD/Forge/Notice").text.contains("재굴림")) and ok

	var changed := false
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	for i in 30:
		main._activate_selected_forge_item()
		if GameState.affix_of(uid) != rolled:
			changed = true
			break
	ok = _check("다시 굴리면 옵션이 바뀐다", changed) and ok

	main._toggle_forge()
	GameState.reset()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
