extends Node
## 적이 죽은 순간 "enemies" 그룹·충돌을 바로 빼서, 0.15초 사망 트윈이 끝나기
## 전에 다른 타격이 또 들어와도 health 가 더 깎이지 않는지 확인한다
## (스킬·처치 손맛 지시, 감독 2026-10-19 23:49).

func _ready() -> void:
	var world := Node2D.new()
	add_child(world)
	var enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	world.add_child(enemy)
	enemy.max_health = 10
	enemy.health = 10
	await get_tree().process_frame

	var ok := true
	ok = _check("죽기 전엔 enemies 그룹에 있음", enemy.is_in_group("enemies")) and ok
	ok = _check("죽기 전엔 충돌이 켜져 있음", not enemy.get_node("CollisionShape2D").disabled) and ok

	enemy.take_damage(999, Vector2.RIGHT)
	await get_tree().process_frame

	ok = _check("사망 즉시 enemies 그룹에서 빠짐(health=%d)" % enemy.health,
		not enemy.is_in_group("enemies")) and ok
	ok = _check("사망 즉시 충돌이 꺼짐", enemy.get_node("CollisionShape2D").disabled) and ok

	# 실제 공격 판정은 "enemies" 그룹을 돌거나 CollisionShape2D 와 겹쳐서
	# 때린다(player.gd) - 사망 트윈(0.15초)이 끝나기 전까지 두 경로 모두
	# 이 적을 못 찾아야 "피격 0"이 보장된다.
	for i in 8:
		await get_tree().process_frame
		if not is_instance_valid(enemy):
			break
		ok = _check("트윈 중 enemies 그룹에 다시 안 들어옴(frame %d)" % i,
			not enemy.is_in_group("enemies")) and ok
		ok = _check("트윈 중 충돌이 계속 꺼져 있음(frame %d)" % i,
			enemy.get_node("CollisionShape2D").disabled) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
