extends Node
## INBOX O 조각 1: 부위(몸통/투구/무기)마다 착용한 아이템의 팔레트 색을
## 따로 입혀야 한다 - 같은 등급이라도 세트가 다르면 부위 색이 달라야
## 한다. main._physics_process 가 매 틱 player._update_sprite()를 부르므로
## physics_frame 하나를 기다려 실제 렌더 경로로 갱신되게 한다(함수 직접
## 호출로 modulate 값만 읽지 않는다).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	# 대화 스킵 직후의 unpause는 다음 물리 틱부터 적용된다 - 프레임 하나를
	# 더 기다리지 않으면 첫 장비 교체의 physics_frame 대기가 아직 paused인
	# 프레임을 잡아 _update_sprite()가 한 번 안 돈다(실측: 5종 중 첫 항목만
	# 갱신 전 기본 흰색으로 읽힘).
	await get_tree().process_frame
	var player: Node = main.get_node("Player")

	var ok := true
	ok = (await _check_transcendent_armors_differ(player)) and ok
	ok = (await _check_three_slots_differ(player)) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _equip_and_settle(player: Node, slot: String, item: String) -> void:
	GameState.equipped[slot] = item
	GameState._recalc_bonuses()
	# 전체 스위트처럼 부하가 걸리면 물리 틱 하나가 렌더 갱신을 못 태울 때가
	# 있다(간헐 FAIL 실측) - 두 틱을 기다린다.
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check_transcendent_armors_differ(player: Node) -> bool:
	# 5장 탑 세트 초월 갑옷. 색상표는 data/item_palettes.json 참고.
	var armors := ["파수꾼의 갑주", "심판자의 갑주", "종언의 갑주", "겁화의 갑주", "천공의 갑주"]
	var distinct := {}
	for armor in armors:
		await _equip_and_settle(player, "armor", armor)
		distinct[player.get_node("Sprite").modulate] = true
	return _check("초월 갑옷 5종 몸통 색 전부 서로 다름", distinct.size() == armors.size())


func _check_three_slots_differ(player: Node) -> bool:
	await _equip_and_settle(player, "weapon", "빙결의 창")  # frost_set
	await _equip_and_settle(player, "armor", "흑기사 갑주")  # captain_set
	await _equip_and_settle(player, "helmet", "용각 투구")  # boss_set
	var weapon_color: Color = player.get_node("Hand").modulate
	var armor_color: Color = player.get_node("Sprite").modulate
	var helmet_color: Color = player.get_node("Helmet").modulate
	return _check("무기/갑옷/투구 서로 다른 세트 착용 시 세 부위 색 전부 다름",
		weapon_color != armor_color and armor_color != helmet_color and weapon_color != helmet_color)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
