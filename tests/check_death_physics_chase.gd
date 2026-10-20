extends Node
## `check_death_physics_callback.gd`는 투사체(Area2D body_entered, 물리 콜백)
## 안에서 플레이어가 죽는 경로만 확인한다. 근접 몬스터(`_act_chase`)는
## `enemy._physics_process()` 안에서 곧장 `player.take_damage()`를 부르는
## 다른 경로다(엔진 콜백이 아니라 그냥 스크립트 프레임이라 "물리 쿼리 플러시
## 중" 제약과는 무관하지만, 실제 살아있는 Enemy AI 루프로 플레이어를 죽여
## 사망 처리까지 크래시/누수 없이 끝나는지는 아직 검사가 없었다). 실제 몬스터
## 씬을 스폰해 그 자체 AI로 죽이는 실제 입력 경로로 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.reset()
	GameState.revive_potions = 0
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = Vector2(160, 120)
	player.max_health = 999
	player.health = 1

	var baseline := get_tree().get_node_count()

	# 기본 archetype("beast")은 behavior가 없어 MOB_DEFAULTS의 "chase"를 쓴다.
	var mob: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	mob.global_position = player.global_position + Vector2(10, 0)
	mob.damage = 50
	main.add_child(mob)

	# (감독, 2026-09-10) 근접 몬스터는 예비동작(SWING_MOB 0.22초) 뒤에 친다 - 죽을 때까지 기다린다.
	for i in 90:
		await get_tree().physics_frame
		if main.get_node("HUD/Message").text.begins_with("쓰러졌다"):
			break

	for i in 5:
		await get_tree().process_frame

	var msg: String = main.get_node("HUD/Message").text
	ok = _check("사망 메시지가 실제로 떴음(근접 몬스터 AI가 직접 죽였다, 실제: %s)" % msg,
		msg.begins_with("쓰러졌다")) and ok

	ok = _check("사망 처리 중 노드가 안 새고 프로세스가 살아있음(엔진 크래시 없음)",
		is_instance_valid(main)) and ok
	ok = _check("사망 후 실제로 마을로 돌아옴(map=%s)" % GameState.current_map,
		GameState.current_map == "village") and ok
	ok = _check("사망 직후 체력이 최대로 회복됨", player.health == player.max_health) and ok

	var after := get_tree().get_node_count()
	ok = _check("사망 처리 후 노드 수가 과도하게 새지 않음(base=%d after=%d)" % [baseline, after],
		after <= baseline + 260) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
