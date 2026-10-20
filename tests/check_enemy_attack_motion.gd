extends Node
## (감독, 2026-09-10) 적/보스 근접 공격에 모션이 있는지. 예전엔 사거리에
## 들어오면 예고 없이 즉시 피해가 들어가 "때리고 맞는 느낌"이 없었다.
## ① 잡몹: 붙어도 즉시 안 때리고 예비동작(swing>0, 멈춤, 뒤로 젖힘) 후 친다
## ② 칠 때 플레이어 위치에 베기 궤적(SlashFx)이 생긴다
## ③ 예비동작 중 플레이어가 빠지면 헛스윙(피해 없음)
## ④ 보스 특수기도 예고(swing_special) 뒤에 친다
## ⑤ 피격 시 스프라이트가 찌그러졌다가 원래 크기로 돌아온다(중간보스 1.6 기준 유지)

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = Vector2(160, 120)
	player.max_health = 9999
	player.health = 9999
	player.invulnerability_time = 0.0

	# ① 잡몹 - 붙은 거리
	var mob: CharacterBody2D = _spawn(main, "slime", Vector2(160, 120 + 14))
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _check("① 붙어도 즉시 피해가 아니라 예비동작 중", mob.swing > 0.0 and player.health == 9999) and ok
	ok = _check("① 예비동작 중 멈추고 뒤로 젖힘", mob.velocity == Vector2.ZERO
		and mob.get_node("Sprite").offset != Vector2.ZERO) and ok
	var landed := await _wait_hit(player, 40)
	ok = _check("① 예비동작이 끝나면 피해가 들어감", landed) and ok
	ok = _check("① 친 뒤 젖힘 복귀", mob.get_node("Sprite").offset == Vector2.ZERO) and ok
	# ② 베기 궤적
	var fx_found := false
	for n in main.get_children():
		if n is SlashFx:
			fx_found = true
	ok = _check("② 타격 시 베기 궤적(SlashFx) 생성", fx_found) and ok
	mob.queue_free()
	await get_tree().process_frame

	# ③ 헛스윙
	player.health = 9999
	player.invulnerability_time = 0.0
	var mob2: CharacterBody2D = _spawn(main, "slime", Vector2(160, 120 + 14))
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _check("③ 예비동작 시작", mob2.swing > 0.0) and ok
	player.global_position = Vector2(160, 120 - 90)
	var whiff_hit := await _wait_hit(player, 40)
	ok = _check("③ 예비동작 중 빠지면 헛스윙(피해 없음)", not whiff_hit and mob2.swing == 0.0) and ok
	mob2.queue_free()
	await get_tree().process_frame

	# ④ 보스 특수기
	player.global_position = Vector2(160, 120)
	player.health = 9999
	player.invulnerability_time = 0.0
	var boss: CharacterBody2D = _spawn(main, "beast", Vector2(160, 120 + 60), false, true)
	boss.attack_time = 99.0
	boss.special_time = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _check("④ 보스 특수기는 예고(swing_special) 후", boss.swing > 0.0 and boss.swing_special
		and player.health == 9999) and ok
	var before := boss.global_position
	var special_hit := await _wait_hit(player, 60)
	ok = _check("④ 예고 뒤 덮쳐서 침(전진 + 피해)", special_hit
		and boss.global_position.distance_to(before) > 8.0) and ok

	# ⑤ 피격 스쿼시
	var sprite: Sprite2D = boss.get_node("Sprite")
	var base: Vector2 = sprite.scale
	boss.take_damage(1, Vector2.RIGHT)
	ok = _check("⑤ 피격 직후 스프라이트가 옆으로 퍼짐", sprite.scale.x > base.x and sprite.scale.y < base.y) and ok
	await get_tree().create_timer(0.3).timeout
	ok = _check("⑤ 0.3초 뒤 원래 크기로 복귀", sprite.scale.is_equal_approx(base)) and ok
	boss.queue_free()

	# ⑤' 중간보스는 1.6배 기준으로 돌아와야 한다
	var mid: CharacterBody2D = _spawn(main, "slime", Vector2(40, 40), true)
	await get_tree().process_frame
	var mid_sprite: Sprite2D = mid.get_node("Sprite")
	mid.take_damage(1, Vector2.RIGHT)
	await get_tree().create_timer(0.3).timeout
	ok = _check("⑤ 중간보스 피격 후 1.6배 복귀", mid_sprite.scale.is_equal_approx(Vector2.ONE * 1.6)) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _spawn(main: Node, archetype: String, at: Vector2, midboss := false, boss := false) -> CharacterBody2D:
	var e: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	e.archetype = archetype
	e.is_midboss = midboss
	e.is_boss = boss
	e.area_id = GameState.current_map
	e.position = at
	main.add_child(e)
	e.attack_time = 0.0
	return e


func _wait_hit(player: Node, frames: int) -> bool:
	for i in frames:
		await get_tree().physics_frame
		if player.health < player.max_health:
			return true
	return false


func _check(label: String, cond: bool) -> bool:
	print(("PASS " if cond else "FAIL ") + label)
	return cond
