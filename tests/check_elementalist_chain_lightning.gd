extends Node
## 원소술사 2차 전직 스킬 "연쇄 번개"(elementalist_chain_lightning,
## chain_count: 6, radius: 100000.0)가 실제로 chain_count 필드를 반영해
## 적 전부가 아니라 최대 6체까지만 맞는지 검증한다. game_state.gd에
## chain_count 필드는 있었지만 player.gd의 cast_skill()이 이를 읽지 않아
## radius가 사실상 무한대라 화면 안 적 전부(제한 없음)가 한꺼번에 맞는
## 상태였다(desc "무작위로 내리꽂히는"과도 안 맞음, 2026-09-04 자율 루프
## 발견, execute_pct/heal_pct_on_hit와 같은 계열 버그).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("mage")
	GameState.second_job = "elementalist"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var chain_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "elementalist_chain_lightning":
			chain_idx = i
	ok = _check("elementalist_chain_lightning 슬롯 존재", chain_idx >= 0) and ok
	var chain_count: int = int(skills[chain_idx]["chain_count"])
	ok = _check("chain_count 값은 6", chain_count == 6) and ok

	# 적 10체를 흩어 배치(모두 radius 100000.0 안에 들어옴).
	var enemies: Array = []
	for i in 10:
		var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_health = 9999
		enemy.health = 9999
		enemy.defense = 0
		main.get_node("World").add_child(enemy)
		enemy.global_position = player.global_position + Vector2(30 + i * 20, 0)
		enemies.append(enemy)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.cast_skill(chain_idx)

	var hit_count := 0
	for enemy in enemies:
		if enemy.health < 9999:
			hit_count += 1
	ok = _check("적 10체 중 chain_count(6)개 이하만 맞음", hit_count <= chain_count) and ok
	ok = _check("적 10체 중 최소 1개는 맞음(0체 아님)", hit_count > 0) and ok

	print("맞은 적 수: ", hit_count, " / chain_count: ", chain_count)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
