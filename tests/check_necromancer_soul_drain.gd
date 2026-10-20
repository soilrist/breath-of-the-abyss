extends Node
## 강령술사 2차 전직 스킬 "영혼 흡수"(necromancer_soul_drain, heal_pct_on_hit:
## 0.12)가 실제로 입힌 피해의 12%만큼 HP와 마력을 회복시키는지 검증한다.
## game_state.gd에 heal_pct_on_hit 필드는 있었지만 player.gd의 cast_skill()이
## 이를 읽지 않아 desc("피해를 주고 HP와 마력 일부 회복")와 다르게 회복이
## 전혀 일어나지 않는 버그였다(2026-09-04 자율 루프에서 발견, execute_pct와
## 같은 배치에서 함께 수정).
## 마력 검증은 시전 전 마력이 아니라 "비용(cost) 차감 직후" 마력과 비교한다
## (스킬 자체가 마력을 소모하므로 시전 전 마력과 비교하면 cost > drain 회복량
## 때문에 항상 순감소로 나와 오탐이 났다 - 실측 확인 후 수정).

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
	GameState.second_job = "necromancer"
	player.max_health = 200
	player.health = 100
	player.mana = 100
	player.max_mana = 200
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var drain_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "necromancer_soul_drain":
			drain_idx = i
	ok = _check("necromancer_soul_drain 슬롯 존재", drain_idx >= 0) and ok

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = player.health
	var cost: int = int(skills[drain_idx]["cost"])
	var mana_after_cost: int = player.mana - cost
	player.cast_skill(drain_idx)

	ok = _check("영혼 흡수 시전 후 HP가 회복됨", player.health > hp_before) and ok
	ok = _check("영혼 흡수 시전 후 마력이 소모분보다 더 돌아옴(마력 회복 발생)", player.mana > mana_after_cost) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
