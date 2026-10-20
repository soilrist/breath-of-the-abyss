extends Node
## 정령 인장(5번째 장비 슬롯)과 그 패시브 효과 4가지를 확인한다.

const SPIRITS := ["숲의 정령 인장", "바람의 정령 인장", "불꽃의 정령 인장", "서리의 정령 인장"]

func _ready() -> void:
	GameState.reset()
	var ok := true

	ok = _check("정령 인장 4개가 spirit 슬롯", SPIRITS.all(
		func(i): return str(GameState.EQUIPMENT[i]["slot"]) == "spirit")) and ok

	GameState.level = 20
	GameState.inventory = ["철검", "숲의 정령 인장"]
	GameState.equip("철검")
	ok = _check("정령 인장 착용해도 무기 슬롯은 그대로", GameState.equip("숲의 정령 인장") and GameState.equipped["weapon"] == "철검") and ok
	ok = _check("정령 인장이 spirit 슬롯에 들어감", GameState.equipped["spirit"] == "숲의 정령 인장") and ok
	ok = _check("spirit_effect() 가 regen 을 돌려줌", GameState.spirit_effect() == "regen") and ok

	# 실제 게임 화면에서 각 효과가 동작하는지.
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player := main.get_node("Player")
	GameState.level = 20
	main._apply_equipment_to_player()

	# 숲의 정령: 5초 지나면 체력이 회복된다.
	GameState.equipped["spirit"] = "숲의 정령 인장"
	player.health = int(player.max_health * 0.5)
	player.hp_regen_tick = 0.0
	var hp_before: int = player.health
	for i in 6:
		player._physics_process(1.0)
	ok = _check("숲의 정령: 시간이 지나면 체력 회복", player.health > hp_before) and ok

	# 불꽃의 정령: 마력 회복량이 더 크다.
	GameState.equipped["spirit"] = "불꽃의 정령 인장"
	player.mana = 0
	player.mana_regen_tick = 0.0
	player._physics_process(1.0)
	var mana_with_spirit: int = player.mana
	GameState.equipped["spirit"] = ""
	player.mana = 0
	player.mana_regen_tick = 0.0
	player._physics_process(1.0)
	var mana_without: int = player.mana
	ok = _check("불꽃의 정령: 마력 회복이 더 많다", mana_with_spirit > mana_without) and ok

	# 바람의 정령: 구르기 쿨타임이 짧다.
	GameState.equipped["spirit"] = "바람의 정령 인장"
	player.dash_cooldown = 0.0
	player.try_dodge()
	var cd_with_spirit: float = player.dash_cooldown
	GameState.equipped["spirit"] = ""
	player.dash_cooldown = 0.0
	player.try_dodge()
	var cd_without: float = player.dash_cooldown
	ok = _check("바람의 정령: 구르기 쿨타임이 더 짧다", cd_with_spirit < cd_without) and ok

	# 서리의 정령: 피격 후 무적 시간이 더 길다.
	GameState.equipped["spirit"] = "서리의 정령 인장"
	player.invulnerability_time = 0.0
	player.health = player.max_health
	player.take_damage(1, Vector2.DOWN)
	var invuln_with_spirit: float = player.invulnerability_time
	GameState.equipped["spirit"] = ""
	player.invulnerability_time = 0.0
	player.take_damage(1, Vector2.DOWN)
	var invuln_without: float = player.invulnerability_time
	ok = _check("서리의 정령: 무적 시간이 더 길다", invuln_with_spirit > invuln_without) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
