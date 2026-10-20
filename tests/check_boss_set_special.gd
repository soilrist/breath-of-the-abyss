extends Node
## "용기사 세트"(제작 전용 전설 장비 4개를 묶은 새 세트)를 4개 다 착용하면
## 스탯 보너스 말고 세트 전용 특수효과가 붙는지, 세트 아이템은 등급과
## 상관없이 주황색으로 표시되는지 확인한다. 기존 4개 보스 세트(수호자·
## 흑기사단·서리군주·심연)는 이 세트랑 무관하게 원래 3조각 그대로다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	# 색: 등급색 그대로. 에픽은 에픽, 전설은 전설, 보스템(용기사 세트)만
	# 별도 등급 "신화"로 빨간색.
	ok = _check("에픽 등급 기존 세트템은 에픽 색 그대로", GameState.display_color("수호자의 검") == GameState.RARITY_COLORS["에픽"]) and ok
	ok = _check("용기사 세트템은 신화 등급이라 빨간색", GameState.display_color("용린 갑주") == GameState.RARITY_COLORS["신화"]) and ok
	ok = _check("신화 색은 전설 색과 다름", GameState.RARITY_COLORS["신화"] != GameState.RARITY_COLORS["전설"]) and ok
	ok = _check("세트 아닌 에픽템은 원래 등급색", GameState.display_color("설원의 망토") == GameState.RARITY_COLORS["에픽"]) and ok

	ok = _check("기존 흑기사단 세트는 3조각 그대로", GameState.SETS["captain_set"]["pieces"].size() == 3) and ok
	ok = _check("용기사 세트는 제작템 4개로만 구성", GameState.SETS["boss_set"]["pieces"].size() == 4) and ok

	GameState.level = 20
	GameState.inventory = ["흑기사 갑주", "단장의 견장", "흑기사단장의 투구"]
	for item in GameState.inventory:
		GameState.equip(item)
	ok = _check("기존 세트는 3조각을 다 껴도 특수효과 없음(스탯만)",
		GameState.active_set_special() == "") and ok

	GameState.inventory = ["용린 갑주", "용아 대검", "용의 인장", "용각 투구"]
	for item in GameState.inventory:
		GameState.equip(item)
	ok = _check("용기사 세트 4조각을 다 채우면 특수효과 발동", GameState.active_set_special() == "boss_legacy") and ok

	player.max_health = 1000
	player.health = 1000
	GameState.defense_bonus = 0
	player.take_damage(100, Vector2.DOWN)
	var taken_with_set: int = 1000 - player.health

	GameState.equipped["weapon"] = ""  # 세트 하나 벗겨서 4/4가 깨지게
	player.health = 1000
	player.invulnerability_time = 0.0
	player.take_damage(100, Vector2.DOWN)
	var taken_without_set: int = 1000 - player.health

	ok = _check("용기사 세트 완성시 특수효과로 피해가 더 줄어듦",
		taken_with_set < taken_without_set) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
