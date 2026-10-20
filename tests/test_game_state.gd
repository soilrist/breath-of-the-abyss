extends SceneTree


func _init() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state.reset()
	assert(state.add_reward(50, 7))
	assert(state.level == 2 and state.exp == 0 and state.gold == 7)
	state.add_item("철검")
	assert(state.equip("철검"))
	assert(state.attack_bonus == 8)
	state.add_item("가죽 갑옷")
	assert(state.equip("가죽 갑옷") and state.defense_bonus == 4)
	assert(state.inventory.size() == 2)
	state.gold = 20
	assert(state.buy("회복약", 15) and state.gold == 5 and state.potions == 3)
	assert(not state.buy("철검", 70))
	assert(state.map_title() == "바람골 마을")
	state.current_map = "dungeon"
	assert(state.map_title() == "수호자의 동굴")
	state.current_map = "citadel"
	assert(state.map_title() == "검은 성채")
	assert(not state.game_cleared)
	state.game_cleared = true
	assert(state.to_dict()["game_cleared"])
	var mock_player := Node2D.new()
	mock_player.set("health", 145)
	mock_player.set("mana", 72)
	mock_player.set("max_health", 160)
	mock_player.set("max_mana", 80)
	mock_player.set("attack_damage", 40)
	mock_player.free()
	assert(not state.equip("없는 장비"))
	print("GAME_STATE_TEST_OK")
	state.free()
	quit()
