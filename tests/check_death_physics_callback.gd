extends Node
## 몬스터 투사체의 body_entered(실제 물리 콜백) 안에서 플레이어가 죽을 때
## 크래시/노드 누수가 없는지 확인한다. `342fa04`에서 발견한 실버그
## ("Can't change this state while flushing queries" - 물리 콜백 안에서
## 곧장 _change_map을 부르면 노드가 샘) 재발 방지: `_apply_death_penalty()`가
## `call_deferred("_change_map", ...)`를 쓰는지, 실제 투사체 충돌로 죽어도
## 정상적으로 마을로 돌아오는지를 `check_enemy_projectile.gd`와 같은 방식
## (직접 함수 호출이 아니라 실제 Area2D 물리 신호)으로 검증한다.

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

	var proj: Area2D = preload("res://scenes/enemy_projectile.tscn").instantiate()
	proj.global_position = player.global_position
	proj.direction = Vector2.RIGHT
	proj.damage = 50
	proj.kind = "arrow"
	main.add_child(proj)

	# 실제 body_entered 물리 신호가 뜨도록 몇 프레임 기다린다(직접 함수
	# 호출이 아니라 엔진이 실제로 겹침을 감지해야 그때 겪었던 크래시 경로가
	# 재현된다).
	for i in 10:
		await get_tree().physics_frame

	for i in 5:
		await get_tree().process_frame

	var msg: String = main.get_node("HUD/Message").text
	ok = _check("사망 메시지가 실제로 떴음(체력이 순간 0이 됐다가 사망 처리됨, 실제: %s)" % msg,
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
