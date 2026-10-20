extends Node
## 10장_근원_DESIGN.md "보스" 절의 다단계 연출(가배치, 2026-09-05 자율 결정)이
## 실제로 동작하는지 확인한다. enemy.gd _update_boss_phase()를 직접 부르지
## 않고, HP만 바꾼 뒤 _physics_process가 매 프레임 자동으로 부르는 실제
## 경로를 그대로 태운다.

func _new_origin_boss() -> Node:
	GameState.reset()
	GameState.chapter = 10
	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.is_boss = true
	add_child(enemy)
	return enemy


func _ready() -> void:
	var ok := true
	var enemy := _new_origin_boss()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var base_speed: float = enemy.base_speed

	ok = _check("HP 100%: phase=0, 기본 보라 tint", enemy.boss_phase == 0
		and enemy.get_node("Sprite").modulate.is_equal_approx(Color(0.8, 0.35, 0.9))) and ok

	enemy.health = int(enemy.max_health * 0.65)
	await get_tree().physics_frame
	ok = _check("HP 70% 이하: phase=1, 쿨다운 -20%·속도 +15%·붉은보라 tint",
		enemy.boss_phase == 1
		and is_equal_approx(enemy.attack_cooldown_mult, 0.8)
		and is_equal_approx(enemy.speed, base_speed * 1.15)
		and enemy.get_node("Sprite").modulate.is_equal_approx(Color(0.95, 0.25, 0.35))) and ok

	enemy.health = int(enemy.max_health * 0.25)
	await get_tree().physics_frame
	ok = _check("HP 30% 이하: phase=2(최종), 쿨다운 -45%·속도 +30%·어두운 진홍 tint",
		enemy.boss_phase == 2
		and is_equal_approx(enemy.attack_cooldown_mult, 0.55)
		and is_equal_approx(enemy.speed, base_speed * 1.3)
		and enemy.get_node("Sprite").modulate.is_equal_approx(Color(0.55, 0.0, 0.05))) and ok

	# 색이 바뀌어도 눈으로 구분되는지는 유클리드 거리로 단언한다(감독 지적:
	# 1단계 "붉은보라"와 2단계 "진홍"이 거리 0.32로 구분 안 됨 - INBOX
	# 2026-09-05 20:40 보정). 인접 단계끼리 거리 ≥ 0.5을 요구한다.
	var kind: Dictionary = enemy.kind
	var tints: Array[Color] = [kind["tint"]]
	for p in (kind["phases"] as Array):
		tints.append(p["tint"])
	for i in range(tints.size() - 1):
		var dist: float = _color_distance(tints[i], tints[i + 1])
		ok = _check("단계 %d→%d tint 거리 ≥ 0.5 (실측 %.2f)" % [i, i + 1, dist],
			dist >= 0.5) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
