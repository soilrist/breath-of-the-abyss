extends Node
## 마법사 마력 자연 회복 보너스, 오토/퀘스트에서 마나 순환(4번) 자동 사용,
## 물약 상한에서 buy()가 골드를 안 깎는지 (감독 2026-09-08).
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open:
		main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.job = "mage"
	GameState.level = 8
	player.max_mana = 100
	player.mana = 10
	player.health = player.max_health
	var ok := true
	# 1) 마나 순환 자동 사용: 마력 10% → +35, HP -20%.
	var cast: bool = player._auto_cast_skill(player, 0.0)
	ok = ok and cast and player.mana == 45 and player.health == player.max_health - int(player.max_health * 0.2)
	print("cast=%s mana=%d hp=%d/%d" % [cast, player.mana, player.health, player.max_health])
	# 2) HP 절반 이하면 안 쓴다.
	player.mana = 10
	player.health = int(player.max_health * 0.4)
	for i in player.skill_cooldowns.size():
		player.skill_cooldowns[i] = 0.0
	var cast2: bool = player._auto_cast_skill(player, 0.0)
	ok = ok and not cast2
	print("low-hp cast=%s" % cast2)
	# 3) 자연 회복: 1초에 3 + 100*2% = 5.
	player.mana = 10
	player.mana_regen_tick = 0.99
	player._physics_process(0.02)
	ok = ok and player.mana == 15
	print("regen mana=%d" % player.mana)
	# 4) 물약 상한: 가득 찼으면 골드 그대로.
	GameState.potions = GameState.MAX_POTIONS
	GameState.gold = 100
	var bought: bool = GameState.buy("회복약", 20)
	ok = ok and not bought and GameState.gold == 100 and GameState.potions == GameState.MAX_POTIONS
	print("full buy=%s gold=%d potions=%d" % [bought, GameState.gold, GameState.potions])
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
