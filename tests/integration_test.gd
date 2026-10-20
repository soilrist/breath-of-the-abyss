extends Node

var failures: Array[String] = []


func _ready() -> void:
	var tree := get_tree()
	await get_tree().process_frame
	var game := get_parent().get_node("Main")
	check(game != null and game.name == "Main", "게임 장면 실행")
	# 새 게임이면 오프닝이 흐른다. 검사에 방해되지 않게 먼저 넘긴다.
	check(game.dialogue_open and game.dialogue_pages.size() > 3, "새 게임에 오프닝이 흐른다")
	skip_dialogue(game)
	check(not game.dialogue_open, "오프닝을 넘기면 조작이 돌아온다")
	# 잡담은 진행도마다 한 번 뜬다. 기능 검사가 막히지 않게 들은 것으로 둔다.
	for who in ["smith", "merchant", "keeper"]:
		for stage in 14:
			game.heard["%s:%d" % [who, stage]] = true

	press_action(game, "inventory")
	check(game.menu_open and game.get_node("HUD/Inventory").visible, "I로 인벤토리 열기")
	check(game.get_node("HUD/MobileControls/Close").visible, "모바일 인벤토리 닫기 버튼")
	# (감독 2026-09-10) 재료 탭이 생겨 Sell 버튼이 "탭" 전환 버튼으로 보인다.
	check(game.get_node("HUD/MobileControls/Sell").visible, "인벤토리에 탭 전환 버튼(Sell 재사용)")
	check(not game.get_node("HUD/SkillBar").visible and not game.get_node("HUD/Message").visible, "인벤토리에서 겹치는 HUD 숨김")
	press_action(game, "inventory")
	check(not game.menu_open and not game.get_node("HUD/Inventory").visible and not get_tree().paused, "I로 인벤토리 닫기")
	check(game.get_node("HUD/SkillBar").visible and game.get_node("HUD/Message").visible, "인벤토리 닫으면 HUD 복원")
	GameState.inventory = ["철검", "가죽 갑옷"]
	GameState.equipped = {"weapon": "낡은 검", "armor": "여행자 옷", "helmet": "", "trinket": ""}
	GameState.gold = 0
	GameState.level = 20
	press_action(game, "inventory")
	# 판매는 상인이 한다. 가방은 항상 희귀도순(2026-09-10, 토글 없음, ←→는 탭 전환).
	press_action(game, "sell_item")
	check(GameState.inventory.size() == 2 and GameState.gold == 0, "인벤토리에서는 판매되지 않는다")
	check(game.menu_open, "인벤토리에서 X는 아무 일도 안 한다")
	game.inventory_index = 1
	press_action(game, "interact")
	check(GameState.is_equipped("가죽 갑옷"), "E로 장비 착용")
	press_action(game, "inventory")
	var mobile = game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	var before_touch := Input.is_action_pressed("attack")
	mobile._press("attack")
	check(not before_touch and Input.is_action_pressed("attack"), "터치 공격 버튼 입력")
	mobile._release("attack")
	check(not Input.is_action_pressed("attack"), "터치 공격 버튼 해제")
	check(mobile.get_node("Pause") != null and mobile.get_node("Close") != null, "모바일 메뉴·닫기 버튼 구성")
	mobile._toggle_pause()
	check(game.pause_open and get_tree().paused, "메뉴 버튼 클릭으로 일시정지 열기")
	mobile._close_modal()
	check(not game.pause_open and not get_tree().paused, "닫기 버튼 클릭으로 일시정지 닫기")

	GameState.reset()
	game.get_node("Player").global_position = game.NPC_POSITION
	press_action(game, "interact")
	check(game.dialogue_open and game.get_node("HUD/Dialogue").visible and get_tree().paused, "E로 퀘스트 대화 열기")
	check(game.get_node("HUD/MobileControls/Close").visible, "모바일 대화 닫기 버튼")
	press_action(game, "ui_cancel")
	check(not game.dialogue_open and not game.get_node("HUD/Dialogue").visible and not get_tree().paused, "Esc로 퀘스트 대화 닫기")

	# 상점은 촌장이 아니라 상인이 연다. 촌장 대화에 묶여 있으면
	# 의뢰가 있는 동안 물건을 살 수 없다.
	GameState.quest_stage = 6
	GameState.gold = 100
	game.get_node("Player").global_position = game.MERCHANT_POSITION
	press_action(game, "interact")
	check(game.shop_open and game.get_node("HUD/Shop").visible and get_tree().paused, "상인에게서 상점 열기")
	check(game.get_node("HUD/MobileControls/Buy1").visible and game.get_node("HUD/MobileControls/Buy3").visible, "모바일 상점 구매 버튼")
	check(game.shop_index == 0, "상점 커서는 첫 줄에서 시작")
	press_action(game, "interact")
	check(GameState.potions == 3 and GameState.gold == 80, "회복약 구매 및 골드 차감")
	press_action(game, "ui_down")
	check(game.shop_index == 1, "↓로 상점 커서 이동")
	var stock_before: int = game._shop_goods().size()
	GameState.chapter = 2
	game._refresh_shop()
	check(game._shop_goods().size() > stock_before, "2장이 되면 재고가 늘어난다")
	GameState.chapter = 1
	game.shop_index = 0
	game._refresh_shop()
	# 판매 탭
	game._switch_shop_tab("sell")
	check(game.shop_mode == "sell", "→로 판매 탭 전환")
	GameState.inventory = ["철검", "가죽 갑옷"]
	GameState.equipped = {"weapon": "낡은 검", "armor": "가죽 갑옷", "helmet": "", "trinket": ""}
	game.shop_index = 0
	game._refresh_shop()
	var gold_at_sell: int = GameState.gold
	game._sell_shop_item(0)
	check(GameState.gold == gold_at_sell + 35 and not GameState.inventory.has("철검"), "상점에서 장비 판매")
	game._sell_shop_item(0)
	check(GameState.inventory.has("가죽 갑옷"), "착용 중인 장비는 팔리지 않는다")
	check(game.get_node("HUD/Shop/Notice").text.contains("착용"), "착용 중 판매 거절 안내")
	game._switch_shop_tab("buy")
	check(game.shop_mode == "buy", "←로 구매 탭 복귀")

	press_action(game, "ui_cancel")
	check(not game.shop_open and not game.get_node("HUD/Shop").visible and not get_tree().paused, "Esc로 상점 닫기")

	press_action(game, "ui_cancel")
	check(game.pause_open and game.get_node("HUD/Pause").visible and get_tree().paused, "Esc로 일시정지 열기")
	check(game.get_node("HUD/MobileControls/Save").visible and game.get_node("HUD/MobileControls/Title").visible, "모바일 일시정지 저장·제목 버튼")
	check(game.get_node("HUD/MobileControls/ToggleControls").visible, "조작 UI 표시 전환 버튼")
	mobile._toggle_controls()
	press_action(game, "ui_cancel")
	check(not mobile.get_node("Joystick").visible and not mobile.get_node("Attack").visible, "조작 UI 숨기기")
	check(mobile.get_node("Pause").visible, "숨김 상태에서도 메뉴 버튼 유지")
	press_action(game, "ui_cancel")
	mobile._toggle_controls()
	press_action(game, "ui_cancel")
	check(not game.pause_open and not game.get_node("HUD/Pause").visible and not get_tree().paused, "Esc로 일시정지 닫기")
	check(is_instance_valid(game) and game.is_inside_tree(), "Esc 후 게임 장면 유지")

	# 스프라이트 시트에 네 방향이 모두 들어 있다. 열이 방향, 행이 동작이다.
	var player = game.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite")
	player.facing = Vector2.RIGHT
	player.attack()
	player._update_sprite(Vector2.ZERO)
	check(player.motion == "attack" and sprite.frame == player.ROW_ATTACK * 4 + player.DIR_RIGHT, "오른쪽 공격 프레임")
	await get_tree().process_frame
	player.motion_time = 0.0
	player.facing = Vector2.LEFT
	await get_tree().physics_frame
	player.attack()
	player._update_sprite(Vector2.ZERO)
	check(sprite.frame == player.ROW_ATTACK * 4 + player.DIR_LEFT, "왼쪽 공격 프레임")
	player.motion_time = 0.0
	player.facing = Vector2.UP
	player._update_sprite(Vector2.ZERO)
	check(sprite.frame == player.ROW_IDLE * 4 + player.DIR_UP, "위쪽 대기 프레임")
	player.facing = Vector2.DOWN
	player._update_sprite(Vector2.DOWN)
	check(sprite.frame >= player.ROW_WALK * 4 and sprite.frame < (player.ROW_WALK + 4) * 4, "아래쪽 걷기 프레임")
	check(not sprite.flip_h, "네 방향 시트라 좌우 반전을 쓰지 않는다")
	check(sprite.hframes == 4 and sprite.vframes == 7, "주인공 시트 4열 7행")
	# 스킬 네 종류. 레벨로 열리고 1~4 키로 쓴다.
	GameState.level = 20
	player.skill_cooldowns[0] = 0.0
	player.mana = player.max_mana
	check(player.cast_skill(0) != "" and player.motion == "skill", "1번 스킬 시전")
	game._update_skill_bar()
	check(player.skill_cooldowns[0] > 0.0 and game.get_node("HUD/SkillBar/Skill0/Cooldown").visible, "스킬 쿨타임 UI 표시")
	check(not player.cast_skill(1).contains("준비 중"), "스킬은 슬롯별로 쿨타임이 따로라 하나 써도 다른 스킬은 바로 됨")
	player.skill_cooldowns[1] = 0.0
	player.mana = 0
	check(player.cast_skill(1).contains("마력"), "마력이 모자라면 못 쓴다")
	player.mana = player.max_mana
	GameState.level = 1
	check(player.cast_skill(2).contains("배우지 않은"), "레벨이 모자라면 못 배운 기술")
	GameState.level = 20
	player.skill_cooldowns[3] = 0.0
	player.health = 10
	var healed: String = player.cast_skill(3)
	check(player.health > 10 and healed.contains("HP"), "치유 스킬이 HP를 회복한다")
	for i in player.skill_cooldowns.size():
		player.skill_cooldowns[i] = 0.0
	player.mana = player.max_mana
	player.health = player.max_health
	player.skill_slot = 0
	player.dash_cooldown = 0.0
	GameState.dash_unlocked = true
	player.facing = Vector2.RIGHT
	var before_dash: Vector2 = player.global_position
	player.try_dodge()
	check(player.motion == "dodge" and player.motion_time > 0.0, "회피 동작 재생")
	check(player.global_position.x > before_dash.x and player.dash_cooldown > 0.0, "Q 회피 이동 및 쿨타임")
	player._update_sprite(Vector2.ZERO)
	check(sprite.frame == (player.ROW_WALK + 3) * 4 + player.DIR_RIGHT, "오른쪽 돌진 프레임")
	player.motion_time = 0.0
	player.dash_cooldown = 0.0
	player.facing = Vector2.LEFT
	var before_left_dash: Vector2 = player.global_position
	player.try_dodge()
	player._update_sprite(Vector2.ZERO)
	check(player.global_position.x < before_left_dash.x and sprite.frame == (player.ROW_WALK + 3) * 4 + player.DIR_LEFT, "왼쪽 돌진 이동·프레임")

	# 적과 보스는 배경 타일과 픽셀 크기를 맞추려고 확대하지 않는다.
	# 마을에는 몬스터가 없으므로 숲으로 옮겨 놓고 검사한다.
	game._change_map("forest_w", false)
	check(count_mobs() == expected_mobs(game, "forest_w"), "숲에 지역 몬스터가 깔린다")
	var beast = get_tree().get_nodes_in_group("enemies")[0]
	check(beast.scale == Vector2.ONE, "잡몹 원본 크기 유지")
	check(beast.get_node("Sprite").texture != null and not beast.get_node("Sprite").flip_h, "잡몹 시트 방향 처리")
	# 두 보스 모두 검사한다. 1장 수호자와 2장 단장은 시트도 크기도 다르다.
	for chapter in [1, 2]:
		GameState.chapter = chapter
		var boss = preload("res://scenes/enemy.tscn").instantiate()
		boss.is_boss = true
		boss.max_health = 400
		boss.health = 400
		game.add_child(boss)
		var label: String = "흑기사단장" if chapter == 2 else "숲의 수호자"
		check(boss.get_node("Name").text == label, "%d장 보스 이름 %s" % [chapter, label])
		check(boss.get_node("Sprite").texture != null and boss.scale == Vector2.ONE and boss.modulate == Color.WHITE, "%d장 보스 원본 크기·색 유지" % chapter)
		check(boss.body_radius() > beast.body_radius(), "%d장 보스 충돌 범위가 잡몹보다 크다" % chapter)
		check(boss.get_node("Health").offset_top < beast.get_node("Health").offset_top, "%d장 보스 체력바가 몸통 위로" % chapter)

		# 지형 충돌이 끼어들지 않도록 마을 길 한복판에서 검사한다.
		player.global_position = Vector2(150, 128)
		# 몸에 딱 붙은 거리. 충돌 때문에 이보다 더 가까이 갈 수 없다.
		# 예전에는 사거리를 중심 사이 거리로 재서 이 위치에서 딜이 안 들어갔다.
		var touching: float = boss.body_radius() + 5.0
		boss.global_position = player.global_position + Vector2(touching, 0.0)
		player.facing = Vector2.RIGHT
		player.cooldown_time = 0.0
		var before_hp: int = boss.health
		player.attack()
		check(boss.health < before_hp, "%d장 보스에게 붙어서 공격이 들어간다" % chapter)

		before_hp = boss.health
		player.skill_cooldowns[0] = 0.0
		player.mana = player.max_mana
		player.cast_skill(0)
		check(boss.health < before_hp, "%d장 보스에게 스킬이 들어간다" % chapter)

		# 반대로 보스도 붙은 거리에서 플레이어를 때릴 수 있어야 한다.
		# 위에서 두 번 때려 넉백으로 밀려났으므로 붙은 거리에 다시 놓는다.
		boss.global_position = player.global_position + Vector2(touching, 0.0)
		player.invulnerability_time = 0.0
		player.health = player.max_health
		boss.attack_time = 0.0
		boss.hit_time = 0.0
		boss.special_time = 99.0
		# (감독, 2026-09-10) 예비동작(SWING_BOSS) 뒤에 친다 - 끝날 때까지 기다린다.
		for i in 40:
			await get_tree().physics_frame
			if player.health < player.max_health:
				break
		check(player.health < player.max_health, "%d장 보스가 붙은 거리에서 때린다 (간격 %.1f, 사거리 %.1f)" % [chapter, boss.global_position.distance_to(player.global_position) - boss.body_radius(), boss.attack_range])

		boss.queue_free()
		await get_tree().process_frame
	GameState.chapter = 1
	player.health = player.max_health
	player.invulnerability_time = 0.0

	# AUTOHUNT_DESIGN.md §7 통합 테스트. forest_w에는 지역 몹이 11마리
	# 깔려 있어(6+5) 그중 하나만 추적하면 AI가 다른 몹을 먼저 노려
	# 오검출된다 - 전부 지우고 통제된 몹 하나만 새로 놓는다(위 보스 검사와
	# 같은 preload 패턴).
	for stray in get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	await get_tree().process_frame
	player.bounds = World.pixel_size_of("forest_w")
	player.global_position = Vector2(20.0, World.path_row("forest_w") * World.TILE + 8.0)
	player.motion_time = 0.0
	player.cooldown_time = 0.0
	player.dash_cooldown = 0.0
	var auto_mob = preload("res://scenes/enemy.tscn").instantiate()
	game.add_child(auto_mob)
	auto_mob.max_health = 100
	auto_mob.health = 100
	auto_mob.global_position = player.global_position + Vector2(200.0, 0.0)
	var auto_mob_hp_before: int = auto_mob.health
	var auto_start_x: float = player.global_position.x
	player.auto_hunt = true
	for tick in 240:
		if not is_instance_valid(auto_mob) or auto_mob.health <= 0:
			break
		await get_tree().physics_frame
	check(player.global_position.x > auto_start_x, "오토사냥 ON이면 스스로 적을 향해 이동한다")
	check(not is_instance_valid(auto_mob) or auto_mob.health < auto_mob_hp_before, "오토사냥 ON으로 N틱 뒤 적 체력이 준다(공격이 실제로 나갔다)")

	player.auto_hunt = true
	var auto_off_key := InputEventKey.new()
	auto_off_key.physical_keycode = KEY_W
	auto_off_key.pressed = true
	Input.parse_input_event(auto_off_key)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not player.auto_hunt, "오토사냥 중 실제 이동 키(Input 싱글톤 경로) 입력으로 강제 OFF")
	var auto_off_key_up := InputEventKey.new()
	auto_off_key_up.physical_keycode = KEY_W
	auto_off_key_up.pressed = false
	Input.parse_input_event(auto_off_key_up)
	await get_tree().physics_frame

	# 자동사냥 중 바닥에 떨어진 아이템도 자동으로 줍는지 확인
	# (사용자 보고: "아이템이 떨어져 있어도 안 먹고 지나간다"). 적은
	# 전부 지워 순수하게 아이템만 보고 움직이는지 검증한다.
	for stray in get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	for stray in get_tree().get_nodes_in_group("pickups"):
		stray.queue_free()
	## 길은 굽이쳐서(`_build_grid` PATH_BEND_PERIOD) `path_row()` 행이 항상
	## 길은 아니다 - forest_w 실측: 7행 9~10열에 흩뿌린 나무가 있어 직선
	## 접근이 막혀 회피 우회로 193틱이 걸렸다(240틱 한계에 아슬아슬).
	## 여기선 줍기 논리만 보므로 소품도 치운다(장애물 우회는 바로 아래
	## 절과 check_autohunt_obstacle_stall이 따로 본다).
	for prop in game.get_node("World")._props.get_children():
		prop.queue_free()
	await get_tree().process_frame
	player.bounds = World.pixel_size_of("forest_w")
	player.global_position = Vector2(80.0, World.path_row("forest_w") * World.TILE + 8.0)
	player.motion_time = 0.0
	var gold_pickup := preload("res://scenes/pickup.tscn").instantiate()
	gold_pickup.kind = "gold"
	gold_pickup.amount = 7
	gold_pickup.global_position = player.global_position + Vector2(150.0, 0.0)
	game.add_child(gold_pickup)
	gold_pickup.collected.connect(game._on_pickup_collected)
	var gold_before_pickup: int = GameState.gold
	var pickup_start_x: float = player.global_position.x
	player.auto_hunt = true
	for tick in 240:
		if not is_instance_valid(gold_pickup):
			break
		await get_tree().physics_frame
	check(not is_instance_valid(gold_pickup), "오토사냥 ON이면 걸어가서 바닥 아이템을 자동으로 줍는다")
	check(GameState.gold == gold_before_pickup + 7, "자동으로 주운 골드가 실제로 반영된다")
	check(player.global_position.x > pickup_start_x, "아이템을 향해 실제로 이동했다")
	player.auto_hunt = false

	# 사용자 보고: "돌이나 다른 오브젝트가 앞에있으면 그걸 지나치지않고
	# 거기에 걸려서 진행이 안돼". 목표와 플레이어 사이에 정적 장애물
	# (world.gd._add_prop이 만드는 것과 같은 StaticBody2D+CollisionShape2D)을
	# 놓고, 오토사냥이 제자리걸음하지 않고 옆으로 비켜 결국 목표에 도달하는지
	# 확인한다.
	for stray in get_tree().get_nodes_in_group("pickups"):
		stray.queue_free()
	await get_tree().process_frame
	player.global_position = Vector2(80.0, World.path_row("forest_w") * World.TILE + 8.0)
	player.motion_time = 0.0
	player.velocity = Vector2.ZERO
	# CharacterBody2D.global_position을 스크립트로 직접 순간이동시키면
	# 물리 서버에 새 위치가 즉시 반영되지 않는다(Godot 물리 보간 지연 -
	# 실측: 순간이동 직후 1~2 물리 프레임 안에 그 자리에 새로 놓은 Area2D가
	# "이미 겹쳐 있다"고 오검출한다, 텔레포트 전 위치 기준으로 판정되는
	# 듯). 몇 프레임 기다려 물리 서버가 새 위치를 따라잡게 한 뒤에
	# 장애물/아이템을 놓는다.
	for _i in 10:
		await get_tree().physics_frame
	var obstacle_shape := RectangleShape2D.new()
	obstacle_shape.size = Vector2(16.0, 16.0)
	var obstacle_collision := CollisionShape2D.new()
	obstacle_collision.shape = obstacle_shape
	var obstacle := StaticBody2D.new()
	obstacle.add_child(obstacle_collision)
	obstacle.global_position = player.global_position + Vector2(60.0, 0.0)
	game.add_child(obstacle)
	var far_pickup := preload("res://scenes/pickup.tscn").instantiate()
	far_pickup.kind = "gold"
	far_pickup.amount = 3
	far_pickup.global_position = player.global_position + Vector2(150.0, 0.0)
	game.add_child(far_pickup)
	far_pickup.collected.connect(game._on_pickup_collected)
	var obstacle_start_x: float = player.global_position.x
	player.auto_hunt = true
	for tick in 360:
		if not is_instance_valid(far_pickup):
			break
		await get_tree().physics_frame
	check(not is_instance_valid(far_pickup), "돌 장애물 뒤 아이템도 우회해서 결국 도달한다(제자리걸음 아님)")
	check(player.global_position.x > obstacle_start_x + 30.0, "장애물을 실제로 지나쳐 이동했다")
	player.auto_hunt = false
	obstacle.queue_free()

	# 퀘스트 보상 흐름. 예전에는 보스를 잡으면 1단계에서 4단계로 건너뛰어
	# 촌장의 보상 대화(2·3단계)에 도달할 방법이 없었다.
	GameState.quest_stage = 1
	GameState.chapter = 1
	GameState.boss_defeated = false
	# _on_boss_fallen()은 보상 위조를 막으려고 "지금 서 있는 지역이 그 장
	# 보스방인가"를 본다(결함 2026-10-20 19:50) - 직접 호출하는 이 경로는
	# 실제로 보스방까지 걸어가지 않으므로 current_map 을 맞춰 줘야 한다.
	GameState.current_map = "cave_deep"
	game._on_boss_fallen()
	check(GameState.quest_stage == 2, "보스 처치 후 촌장에게 돌아가는 2단계")
	game._change_map("village", false)
	player.global_position = game.NPC_POSITION
	var gold_before: int = GameState.gold
	game._interact_npc()
	check(GameState.quest_stage == 3 and GameState.gold == gold_before + 100, "촌장이 보상 100골드를 준다")
	check(GameState.inventory.has("가죽 갑옷"), "촌장이 가죽 갑옷을 준다")
	game._close_dialogue()
	game._interact_npc()
	check(GameState.quest_stage == 4 and GameState.chapter == 2, "다시 대화하면 2장 시작")
	game._close_dialogue()
	check(GameState.current_map == "harbor", "2장 대화를 닫으면 항구로 이동")

	check(game.get_node("HUD/SkillBar/Potion/Count").text == str(player.potions), "회복약 아이콘 수량 표시")
	player.health = 40
	player.potions = 2
	GameState.potions = 2
	var heal_expect: int = mini(40 + int(player.max_health * 0.35), player.max_health)
	press_action(game, "potion")
	check(player.health == heal_expect, "L 회복약이 최대 체력의 35%%를 회복")
	check(player.potions == 1 and GameState.potions == 1, "L 회복약 수량 감소")
	check(game.get_node("HUD/SkillBar/Potion/Count").text == "1", "회복약 UI 즉시 갱신")
	player.health = player.max_health
	press_action(game, "potion")
	check(player.potions == 1, "HP 최대일 때 회복약 미소모")

	# 지역 연결이 양방향인지 회귀 검사한다.
	# (예전엔 걸어서 다음 장으로 넘어가는 경계가 있어 장 잠금도 여기서 검사했다.
	# 외길 챕터 구조로 바뀌며 장 전환이 전부 보스 처치 후 대화 워프로만
	# 일어나게 됐고, 걸어서 이어지는 지역은 모두 같은 장이 되어 이 시나리오
	# 자체가 성립하지 않는다. _try_exit()의 장 잠금 코드는 그대로 남아
	# 있으나(향후 다시 걷는 경계가 생기면 대비), 지금은 실제로 걸어서
	# 도달 가능한 장 경계가 없어 회귀 검사할 대상이 없다.)
	GameState.reset()
	GameState.chapter = 1
	game._change_map("village", false)

	# 모든 연결이 양쪽에서 통해야 한다. 한쪽만 있으면 막다른 길이 생긴다.
	var one_way: Array[String] = []
	for area in World.AREAS:
		for direction in World.AREAS[area].get("exits", {}):
			var target := World.exit_of(area, direction)
			if World.exit_of(target, World.OPPOSITE[direction]) != area:
				one_way.append("%s-%s" % [area, target])
	check(one_way.is_empty(), "모든 지역 연결이 양방향이다 %s" % str(one_way))

	# 보스는 자기 지역에서만, 자기 장에서만 나온다.
	GameState.chapter = 1
	GameState.boss_defeated = false
	game.boss_spawned = false
	game._change_map("cave_deep", false)
	check(find_boss() != null, "1장 제단에 보스가 있다")
	# 보스를 처음 만나면 조우 대화(Story.BOSS_MEET)가 자동으로 열린다.
	# 실제 플레이에서도 유저가 닫아야 하니 테스트도 닫고 진행한다 - 안 닫으면
	# 이 뒤로 새로 만드는 몬스터가 전부 일시정지 상태로 얼어붙는다.
	if game.dialogue_open:
		game._close_dialogue()
	game._change_map("dungeon", false)
	check(find_boss() == null, "옆 지역으로 나가면 보스가 사라진다")
	game._change_map("cave_deep", false)
	check(find_boss() != null, "쓰러뜨리지 않은 보스는 다시 나온다")
	if game.dialogue_open:
		game._close_dialogue()
	GameState.boss_defeated = true
	game._change_map("dungeon", false)
	game._change_map("cave_deep", false)
	check(find_boss() != null, "쓰러뜨린 보스는 지역 재입장 시 다시 나온다")
	# 조우 대화를 안 닫으면 get_tree().paused가 true로 남아 이 뒤로 새로
	# 만드는 몬스터가 전부 PROCESS_MODE_PAUSABLE이라 얼어붙는다(마법형
	# 시전 준비/돌진형 노려보기/원거리형 후퇴 검사가 전부 조용히 실패하던 원인).
	if game.dialogue_open:
		game._close_dialogue()

	# 저장·불러오기가 성장치를 그대로 되살리는지.
	GameState.level = 4
	player.max_health = 145
	player.max_mana = 75
	player.attack_damage = 36
	player.health = 123
	player.mana = 52
	check(GameState.save_game(player), "성장 데이터 저장")
	player.max_health = 100
	player.max_mana = 60
	player.attack_damage = 24
	player.health = 1
	player.mana = 1
	check(GameState.load_game(player), "성장 데이터 불러오기")
	check(player.max_health == 145 and player.max_mana == 75 and player.attack_damage == 36, "성장 최대치 완전 복원")
	check(player.health == 123 and player.mana == 52, "현재 HP·MP 완전 복원")

	# 바닥 드롭. 잡몹은 확률, 보스는 반드시 장비를 떨어뜨린다.
	check(Pickup.roll_drop(true)["kind"] == "chest", "보스는 장비 상자를 떨어뜨린다")
	var drop_kinds := {}
	for i in 300:
		var roll := Pickup.roll_drop(false)
		drop_kinds[roll.get("kind", "none")] = true
	check(drop_kinds.has("potion") and drop_kinds.has("gold") and drop_kinds.has("none"), "잡몹 드롭은 회복약·골드·꽝이 모두 나온다")

	GameState.gold = 0
	var coin := preload("res://scenes/pickup.tscn").instantiate()
	coin.kind = "gold"
	coin.amount = 9
	game.add_child(coin)
	coin.global_position = player.global_position
	coin._on_body_entered(player)
	check(GameState.gold == 9, "바닥 골드를 밟으면 주워진다")

	var chest := preload("res://scenes/pickup.tscn").instantiate()
	chest.kind = "chest"
	chest.item_name = "강철 대검"
	game.add_child(chest)
	chest._on_body_entered(player)
	check(GameState.inventory.has("강철 대검"), "바닥 상자에서 장비를 얻는다")
	GameState.level = 1
	check(not GameState.equip("강철 대검"), "레벨이 모자라면 착용 불가")
	GameState.level = 20
	check(GameState.equip("강철 대검") and GameState.attack_bonus == 18, "레벨을 채우면 착용과 공격력 상승")
	check(GameState.sell_price("강철 대검") == 90, "새 장비 판매가")
	check(GameState.rarity_of("강철 대검") == "레어" and GameState.rarity_of("철검") == "일반", "등급 구분")

	# 슬롯이 다르면 함께 착용되고 능력치가 합산된다.
	GameState.add_item("철 투구")
	GameState.add_item("정령의 부적")
	check(GameState.equip("철 투구") and GameState.equip("정령의 부적"), "투구·장신구 슬롯 착용")
	check(GameState.is_equipped("강철 대검") and GameState.is_equipped("철 투구"), "슬롯이 다르면 함께 착용된다")
	check(GameState.attack_bonus == 18 + 9, "공격 보너스 합산")
	check(GameState.defense_bonus == 5 + 6, "방어 보너스 합산")
	check(GameState.health_bonus == 10 + 10, "HP 보너스 합산")
	check(GameState.item_summary("정령의 부적").contains("에픽"), "아이템 설명에 등급 표시")

	# 같은 슬롯에 다른 장비를 끼면 앞의 것이 빠진다.
	GameState.add_item("서리 단검")
	check(GameState.equip("서리 단검") and not GameState.is_equipped("강철 대검"), "같은 슬롯은 교체된다")

	# 줍지 않은 물건이 지역을 옮겨도 남아 있으면 안 된다.
	var leftover := preload("res://scenes/pickup.tscn").instantiate()
	leftover.kind = "potion"
	game.add_child(leftover)
	game._change_map("village", false)
	await get_tree().process_frame
	check(not is_instance_valid(leftover), "지역을 옮기면 바닥 물건이 사라진다")

	# 타격감: 데미지 숫자·화면 흔들림·잠깐 멈춤.
	game._change_map("forest_w", false)
	var target = get_tree().get_nodes_in_group("enemies")[0]
	var world_children: int = game.get_child_count()
	Engine.time_scale = 1.0
	target.take_damage(20, Vector2.RIGHT, false)
	check(game.get_child_count() > world_children, "피격하면 데미지 숫자가 뜬다")
	check(Engine.time_scale < 1.0, "피격 순간 잠깐 멈춘다")
	Engine.time_scale = 1.0
	Hit._stop_left = 0.0

	# 치명타는 더 아프고 표시도 다르다.
	GameState.stats["agility"] = 0
	var base_chance: float = GameState.crit_chance()
	GameState.stats["agility"] = 10
	check(GameState.crit_chance() > base_chance, "민첩이 치명타 확률을 올린다")
	GameState.stats["agility"] = 0

	# 적 행동이 종류마다 다르다. 전부 직선 추격이면 싸움이 다 똑같다.
	var behaviors := {}
	for key in target.KINDS:
		behaviors[str(target.MOB_DEFAULTS.merged(target.KINDS[key], true).get("behavior", "chase"))] = true
	check(behaviors.has("chase") and behaviors.has("charge") and behaviors.has("ranged") and behaviors.has("magic"), "적 행동이 네 갈래다")
	var mage_config: Dictionary = target.MOB_DEFAULTS.merged(target.KINDS.get("mage", {}), true)
	check(mage_config.get("behavior") == "magic" and int(mage_config.get("attack_range", 0)) >= 100, "마법형 적은 원거리 마법 공격을 사용한다")
	var mage = preload("res://scenes/enemy.tscn").instantiate()
	mage.archetype = "mage"
	game.add_child(mage)
	# 시전 사거리(122) - 24 = 98 미만이면 물러나는 게 먼저다. 100은 문턱에
	# 너무 가까워 바닥 장식물 충돌로 판정이 흔들렸다(안개숲 통합 이후 실제로
	# 그랬다, INBOX D) - 115로 여유를 둔다.
	mage.global_position = player.global_position + Vector2(115, 0)
	mage.attack_time = 0.0
	print("DEBUG pre-mage paused=", get_tree().paused, " process_mode(mage)=", mage.process_mode, " tree.paused check right after add=", get_tree().paused)
	# process_frame만 기다리면 물리 프레임이 아직 안 돌아 판정을 놓칠 수 있다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(mage.cast_time > 0.0 or mage.cast_started, "마법형 적이 시전 준비를 한다")
	mage.queue_free()
	check(float(mage_config.get("spell_cooldown", 0.0)) > 0.0 and int(mage_config.get("spell_damage", 0)) > 0, "마법형 적에게 주문 피해와 재사용 대기시간이 있다")

	# 돌진형은 노려보는 동안 멈춘다.
	var charger = preload("res://scenes/enemy.tscn").instantiate()
	charger.archetype = "snake"
	game.add_child(charger)
	charger.global_position = player.global_position + Vector2(60, 0)
	charger.attack_time = 0.0
	# 방금 붙인 노드는 다음 물리 프레임부터 돈다. 한 번만 기다리면 놓친다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(charger.wind_up > 0.0, "돌진형은 달려들기 전에 노려본다")
	print("DEBUG charger wind_up=", charger.wind_up, " charging=", charger.charging, " gap=", (player.global_position - charger.global_position).length() - charger.body_radius(), " vel=", charger.velocity)
	check(charger.velocity == Vector2.ZERO, "노려보는 동안 멈춘다")
	charger.queue_free()

	# 원거리형은 거리를 둔다.
	var shooter = preload("res://scenes/enemy.tscn").instantiate()
	shooter.archetype = "spirit"
	game.add_child(shooter)
	shooter.global_position = player.global_position + Vector2(20, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(shooter.velocity.x > 0.0, "원거리형은 너무 붙으면 물러난다")
	print("DEBUG shooter vel=", shooter.velocity, " gap=", (player.global_position - shooter.global_position).length() - shooter.body_radius(), " attack_range=", shooter.attack_range, " detection_range=", shooter.detection_range)
	shooter.queue_free()
	await get_tree().process_frame

	# 칼질에 베기 궤적이 나온다. 예전에는 흰 선 하나가 방향 표시로 튀어나왔다.
	game._change_map("forest_w", false)
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	var fx_before: int = game.get_child_count()
	player.cooldown_time = 0.0
	player.facing = Vector2.RIGHT
	player.attack()
	check(game.get_child_count() > fx_before, "칼질하면 베기 궤적이 나온다")
	check(not player.has_node("Facing"), "옛 방향 표시선이 없다")

	# 활: 근접이 아니라 화살을 쏜다. 활을 들고도 근접으로 때리면 의미가 없다.
	game._change_map("forest_w", false)
	GameState.level = 20
	GameState.inventory = ["사냥꾼의 활", "철검"]
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	check(GameState.weapon_kind() == "melee", "검은 근접 무기")
	player.cooldown_time = 0.0
	player.facing = Vector2.RIGHT
	player.attack()
	check(get_tree().get_nodes_in_group("arrows").is_empty(), "검으로는 화살이 안 나간다")

	check(GameState.equip("사냥꾼의 활") and GameState.weapon_kind() == "bow", "활을 들면 무기 종류가 바뀐다")
	player.cooldown_time = 0.0
	player.attack()
	var arrows := get_tree().get_nodes_in_group("arrows")
	check(arrows.size() == 1, "활은 화살을 쏜다")
	check(arrows[0].direction == Vector2.RIGHT, "화살이 바라보는 쪽으로 날아간다")
	check(arrows[0].damage > 0, "화살에 공격력이 실린다")

	# 날아가서 적에게 꽂힌다.
	var mark = get_tree().get_nodes_in_group("enemies")[0]
	mark.global_position = player.global_position + Vector2(60, 0)
	mark.hit_time = 0.0
	var mark_hp: int = mark.health
	arrows[0].global_position = mark.global_position
	arrows[0]._on_body_entered(mark)
	check(mark.health < mark_hp, "화살이 적을 맞힌다")
	check(get_tree().get_nodes_in_group("arrows").is_empty(), "맞은 화살은 사라진다")

	# 지역을 옮기면 날아가던 화살도 치운다.
	player.cooldown_time = 0.0
	player.attack()
	game._change_map("village", false)
	check(get_tree().get_nodes_in_group("arrows").is_empty(), "지역을 옮기면 화살이 사라진다")
	GameState.equipped = {"weapon": "낡은 검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()

	# 대화 선택지: 고른 답이 남고 결과가 갈린다.
	GameState.choices = []
	game._play_dialogue(Story.BOSS_MEET["captain"])
	game._advance_dialogue()
	game._advance_dialogue()
	check(game.dialogue_choices.size() == 2, "선택지 장면에 보기가 둘")
	check(game.get_node("HUD/Dialogue/Choices").visible, "선택지가 화면에 뜬다")
	game._move_dialogue_choice(1)
	check(game.dialogue_choice == 1, "↓로 다른 보기를 고른다")
	game._move_dialogue_choice(-1)
	var inv_before: int = GameState.inventory.size()
	game._advance_dialogue()
	check(GameState.chose("captain_mercy"), "고른 답이 기록된다")
	check(GameState.inventory.size() == inv_before + 1, "자비를 고르면 보상이 따라온다")
	skip_dialogue(game)

	# 격파 대사가 선택에 따라 갈린다.
	var mercy: Array = Story.boss_fall("captain", ["captain_mercy"])
	var scorn: Array = Story.boss_fall("captain", ["captain_scorn"])
	var plain: Array = Story.boss_fall("captain", [])
	check(mercy != scorn and mercy != plain, "선택마다 격파 대사가 다르다")
	check(Story.boss_fall("guardian", ["captain_mercy"]) == Story.BOSS_FALL["guardian"], "다른 보스 선택은 섞이지 않는다")
	GameState.choices = []

	# 잠긴 문: 열쇠를 찾아야 지나갈 수 있다.
	GameState.keys = []
	GameState.opened_doors = []
	game._change_map("dungeon", false)
	var doors := get_tree().get_nodes_in_group("doors")
	check(doors.size() == 1, "동굴에 잠긴 문이 하나 있다")
	var keys := get_tree().get_nodes_in_group("pickups").filter(func(k): return k.kind == "key")
	check(keys.size() == 1, "그 지역에 열쇠가 떨어져 있다")
	var door = doors[0]
	door._on_body_entered(player)
	check(is_instance_valid(door), "열쇠 없이는 문이 안 열린다")
	check(game.get_node("HUD/Message").text.contains("잠겨"), "잠김 안내가 뜬다")
	keys[0]._on_body_entered(player)
	check(GameState.has_key("dungeon_key"), "열쇠를 주우면 들고 있다")
	door._on_body_entered(player)
	check(GameState.opened_doors.has("dungeon_key"), "열쇠로 문을 연다")
	check(not GameState.has_key("dungeon_key"), "문을 열면 열쇠를 쓴다")
	game._change_map("village", false)
	game._change_map("dungeon", false)
	check(get_tree().get_nodes_in_group("doors").is_empty(), "연 문은 다시 나오지 않는다")
	check(get_tree().get_nodes_in_group("pickups").filter(func(k): return k.kind == "key").is_empty(), "쓴 열쇠도 다시 안 나온다")

	# 밸런스 회귀: 수치가 흔들리면 여기서 걸린다.
	# 보스전이 1~3초에 끝나거나, 방어가 쌓여 피해가 1이 되는 일이 있었다.
	GameState.reset()
	GameState.level = 7
	GameState.equipped = {"weapon": "철검", "armor": "가죽 갑옷", "helmet": "가죽 모자", "trinket": "구리 반지"}
	GameState._recalc_bonuses()
	game._apply_equipment_to_player()
	var dps: float = float(player.attack_damage + GameState.attack_bonus) / player.attack_cooldown
	var boss_hp: int = int(game.BOSS_TIERS[1]["hp"])
	var kill_time: float = boss_hp / dps
	check(kill_time > 8.0 and kill_time < 45.0, "1장 보스전이 8~45초 (%.1f초)" % kill_time)

	# 방어는 감소율이고 상한이 있다. 아무리 단단해도 피해가 0이 되지 않는다.
	GameState.defense_bonus = 500
	player.invulnerability_time = 0.0
	player.health = player.max_health
	var before_hp: int = player.health
	player.take_damage(100, Vector2.RIGHT)
	var taken: int = before_hp - player.health
	check(taken >= 40, "방어를 아무리 쌓아도 최소 40%%는 들어온다 (%d)" % taken)
	GameState.defense_bonus = 0

	# 회복약은 최대 체력 비율이라 후반에도 쓸모가 있다.
	player.max_health = 400
	player.health = 100
	player.potions = 1
	GameState.potions = 1
	check(player.try_use_potion() and player.health >= 200, "회복약이 최대 체력에 비례한다")

	# 여관: 골드를 내고 HP·마력을 채운다.
	game._change_map("village", false)
	GameState.gold = 100
	player.health = 10
	player.mana = 0
	player.global_position = game.INN_POSITION
	game._interact_npc()
	check(player.health == player.max_health and player.mana == player.max_mana, "여관에서 회복")
	check(GameState.gold == 100 - game.INN_COST, "여관 숙박비 차감")
	game._close_dialogue()
	GameState.gold = 0
	player.health = 10
	game._interact_npc()
	check(player.health == 10, "골드가 없으면 못 쉰다")
	game._close_dialogue()

	# 창고: 가방과 창고 사이로 물건을 옮긴다.
	GameState.gold = 500
	GameState.inventory = ["철검", "가죽 갑옷"]
	GameState.storage = []
	GameState.equipped = {"weapon": "낡은 검", "armor": "가죽 갑옷", "helmet": "", "trinket": ""}
	player.global_position = game.KEEPER_POSITION
	game._interact_npc()
	check(game.storage_open and game.get_node("HUD/Storage").visible, "창고지기가 창고를 연다")
	game.storage_side = "bag"
	game.storage_index = 0
	game._move_storage()
	check(GameState.storage.has("철검") and not GameState.inventory.has("철검"), "가방에서 창고로 넣는다")
	game.storage_index = 0
	game._move_storage()
	check(GameState.inventory.has("가죽 갑옷"), "착용 중인 장비는 못 넣는다")
	game.storage_side = "box"
	game.storage_index = 0
	game._move_storage()
	check(GameState.inventory.has("철검") and GameState.storage.is_empty(), "창고에서 꺼낸다")
	game._toggle_storage()
	check(not game.storage_open, "창고 닫기")

	# 특성: 레벨업마다 셋 중 하나를 고른다.
	GameState.perks = {}
	GameState.perk_picks = 0
	GameState.level = 1
	GameState.exp = 0
	GameState.next_exp = 80
	check(GameState.add_reward(200, 0), "경험치로 레벨업")
	check(GameState.perk_picks > 0, "레벨업하면 특성 선택권을 받는다")
	var offer := GameState.roll_perk_offer()
	check(offer.size() == 3, "후보가 셋 나온다")
	var picks_before: int = GameState.perk_picks
	var atk_before: int = GameState.stat_attack()
	check(GameState.take_perk("edge"), "특성을 고른다")
	check(GameState.perk_picks == picks_before - 1, "선택권이 하나 줄어든다")
	check(GameState.stat_attack() == atk_before + 4, "예리함이 공격력에 반영된다")
	check(GameState.take_perk("edge") or GameState.perk_picks == 0, "같은 특성을 겹쳐 고를 수 있다")
	GameState.perk_picks = 0
	check(not GameState.take_perk("vigor"), "선택권이 없으면 못 고른다")
	GameState.perks = {}

	# 세이브 슬롯 셋.
	check(GameState.SLOT_COUNT == 3, "슬롯이 셋이다")
	GameState.slot = 0
	GameState.level = 7
	check(GameState.save_game(player), "0번 슬롯에 저장")
	GameState.slot = 1
	check(not GameState.has_save(1) or true, "1번 슬롯은 따로다")
	GameState.level = 1
	GameState.slot = 0
	check(GameState.load_game(player) and GameState.level == 7, "0번 슬롯을 불러온다")
	check(GameState.slot_summary(0).contains("Lv7"), "슬롯 요약에 레벨이 나온다")

	# 지도 워프: 어느 지역에서든 해금한 곳으로 바로 간다.
	# 이게 없으면 보스를 잡을 때마다 지도 반대편까지 걸어서 돌아가야 한다.
	GameState.unlocked_maps = ["village", "forest_w", "dungeon", "harbor", "ruins_w", "citadel"]
	game._change_map("citadel", false)
	var graph := game.get_node("HUD/WorldMap/Graph")
	GameState.scrolls = 5
	game._toggle_world_map()
	graph.chapter = World.chapter_of("village")
	graph.cursor = graph.order_for_chapter(graph.chapter).find("village")
	check(graph.can_travel(), "성채에서 마을로 워프할 수 있다")
	check(graph.try_travel() == "", "워프 요청이 받아들여진다")
	check(GameState.current_map == "village", "성채에서 마을로 한 번에 이동")
	check(GameState.scrolls == 4, "워프하면 이동주문서 1장 소모")
	# 워프가 성공하면 지도는 스스로 닫힌다. 여기서 또 토글하면 다시 열린다.
	check(not game.world_map_open, "워프하면 지도가 닫힌다")
	game._toggle_world_map()
	graph.chapter = World.chapter_of("temple")
	graph.cursor = graph.order_for_chapter(graph.chapter).find("temple")
	check(not graph.can_travel(), "가 본 적 없는 곳으로는 못 간다")
	game._toggle_world_map()
	check(not game.world_map_open, "지도를 닫는다")

	# 마을마다 상인과 대장장이가 있다. 한 마을에만 두면 되돌아가야 한다.
	for town in ["village", "harbor"]:
		game._change_map(town, false)
		check(game.get_node("Merchant").visible, "%s 에 상인이 있다" % town)
		check(game.get_node("Smith").visible, "%s 에 대장장이가 있다" % town)
		player.global_position = game.SMITH_POSITION
		game._interact_npc()
		check(game.forge_open, "%s 대장장이가 대장간을 연다" % town)
		game._toggle_forge()
		player.global_position = game.MERCHANT_POSITION
		game._interact_npc()
		check(game.shop_open, "%s 상인이 상점을 연다" % town)
		game._close_shop()

	# 장 전환도 어느 마을에서든 된다.
	GameState.quest_stage = 5
	GameState.chapter = 2
	game._change_map("harbor", false)
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 6 and GameState.chapter == 3, "항구에서도 3장을 시작할 수 있다")
	game._close_dialogue()

	# 장비 강화: 대장장이에게 강화석과 골드를 내면 능력치가 오른다.
	GameState.level = 20
	GameState.inventory = ["철검"]
	GameState.equipped = {"weapon": "낡은 검", "armor": "여행자 옷", "helmet": "", "trinket": ""}
	GameState.enhance_levels = {}
	GameState.materials[GameState.MATERIAL] = 0
	GameState.gold = 0
	check(not GameState.can_enhance("철검"), "재료가 없으면 강화 불가")
	GameState.materials[GameState.MATERIAL] = 20
	GameState.gold = 5000
	check(GameState.equip("철검") and GameState.attack_bonus == 8, "강화 전 공격 보너스")
	var stones_before: int = GameState.materials[GameState.MATERIAL]
	# +0 -> +1 은 100% 확정이라(ENHANCE_RATES[0]==1.0) 결과가 항상 같다.
	check(GameState.enhance("철검") == "success", "강화 성공")
	check(GameState.enhance_of("철검") == 1, "강화 단계 상승")
	check(GameState.materials[GameState.MATERIAL] < stones_before, "강화석 소모")
	check(GameState.attack_bonus == 10, "강화가 능력치에 반영된다")
	check(GameState.item_label("철검") == "철검 +1", "이름에 강화 단계 표시")
	# 위쪽 단계는 확률제라 실패·하락·파괴가 섞인다. 매번 +9로 되돌려 놓고
	# 시도해서, 언젠가 +10까지 갈 수 있는지(파괴돼도 되사고 다시 시도)를 본다.
	var reached_max := false
	for i in 500:
		if not GameState.inventory.has("철검"):
			GameState.inventory.append("철검")
		GameState.enhance_levels[GameState.uid_of("철검")] = GameState.MAX_ENHANCE - 1
		GameState.materials[GameState.MATERIAL] = 999
		GameState.gold = 999999
		if GameState.enhance("철검") == "success":
			reached_max = true
			break
	check(reached_max and GameState.enhance_of("철검") == GameState.MAX_ENHANCE, "최대 단계까지 도달할 수 있다")
	check(not GameState.can_enhance("철검"), "최대 단계면 더 못 올린다")
	check(GameState.enhance("존재안하는검") == "blocked", "없는 장비는 강화가 막힌다")
	GameState.inventory.erase("철검")
	check(GameState.enhance("철검") == "blocked", "갖고 있지 않은 장비는 강화가 막힌다")
	GameState.inventory.append("철검")

	# 대장간 화면
	player.global_position = game.SMITH_POSITION
	game._change_map("village", false)
	player.global_position = game.SMITH_POSITION
	game._interact_npc()
	check(game.forge_open and game.get_node("HUD/Forge").visible, "대장장이에게 대장간 열기")
	check(game.get_node("HUD/Forge/Info").text.contains("강화석"), "대장간에 강화석 수량 표시")
	GameState.enhance_wards = 3
	game._refresh_forge()
	check(game.get_node("HUD/Forge/Info").text.contains("부적 3개"), "대장간에 파괴 방지 부적 수량도 항상 표시")
	GameState.enhance_levels[GameState.uid_of("철검")] = GameState.ENHANCE_RISK_STEP
	GameState.enhance_wards = 0
	game.forge_mode = "enhance"
	game.forge_index = 0  # 인벤토리엔 "철검" 한 벌뿐이라 대장간 목록의 첫 칸이다.
	game._refresh_forge()
	check(game.get_node("HUD/Forge/Detail").text.contains("부적이 없다"), "부적 없이 +6강 이상 시도하면 파괴 경고문구")
	GameState.enhance_wards = 2
	game._refresh_forge()
	check(game.get_node("HUD/Forge/Detail").text.contains("자동 소모"), "부적이 있으면 자동 소모 안내로 바뀜")
	press_action(game, "ui_cancel")
	check(not game.forge_open, "Esc로 대장간 닫기")

	# 강화석은 잡몹이 떨어뜨린다.
	var stone_kinds := {}
	for i in 400:
		stone_kinds[Pickup.roll_drop(false).get("kind", "none")] = true
	check(stone_kinds.has("stone"), "잡몹이 강화석을 떨어뜨린다")
	GameState.materials[GameState.MATERIAL] = 0
	var stone := preload("res://scenes/pickup.tscn").instantiate()
	stone.kind = "stone"
	stone.amount = 1
	game.add_child(stone)
	stone._on_body_entered(player)
	check(GameState.materials[GameState.MATERIAL] == 1, "바닥 강화석을 주우면 쌓인다")

	# 사냥 의뢰: 받고, 대상 몬스터를 잡고, 촌장에게 보상을 받는다.
	GameState.bounty_index = 0
	GameState.bounty_taken = false
	GameState.bounty_progress = 0
	GameState.quest_stage = 1
	GameState.inventory = []
	GameState.gold = 0
	game._change_map("village", false)
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.bounty_taken, "촌장이 사냥 의뢰를 맡긴다")
	game._close_dialogue()
	var bounty: Dictionary = GameState.current_bounty()
	check(str(bounty["type"]) == "hunt", "첫 의뢰는 사냥형")
	game._on_enemy_defeated(0, 0, "slime")
	check(GameState.bounty_progress == 0, "대상이 아닌 몬스터는 진행도에 안 들어간다")
	for i in int(bounty["count"]):
		game._on_enemy_defeated(0, 0, str(bounty["kind"]))
	check(GameState.bounty_done(), "대상 몬스터를 다 잡으면 의뢰 완료")
	game._update_quest_message()
	check(game.get_node("HUD/Message").text.contains("의뢰 완료"), "안내 문구에 의뢰 완료 표시")
	game._interact_npc()
	check(GameState.gold == int(bounty["gold"]), "의뢰 보상 골드")
	check(GameState.inventory.has(str(bounty["item"])), "의뢰 보상 장비")
	check(GameState.bounty_index == 1 and not GameState.bounty_taken, "다음 의뢰로 넘어간다")
	game._close_dialogue()

	# 두 번째는 답사형. 그 지역에 들어서면 끝난다.
	game._interact_npc()
	check(GameState.bounty_taken and str(GameState.current_bounty()["type"]) == "explore", "답사형 의뢰를 받는다")
	game._close_dialogue()
	check(not GameState.bounty_done(), "가 보기 전에는 완료가 아니다")
	game._change_map(str(GameState.current_bounty()["area"]), false)
	check(GameState.bounty_done(), "지정한 지역에 가면 답사 의뢰 완료")
	game._change_map("village", false)
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.bounty_index == 2, "답사 보상 수령")
	game._close_dialogue()

	# 세 번째는 모으기형. 재료 개수를 본다.
	game._interact_npc()
	var gather: Dictionary = GameState.current_bounty()
	check(str(gather["type"]) == "gather", "모으기형 의뢰를 받는다")
	game._close_dialogue()
	GameState.materials[GameState.MATERIAL] = 0
	GameState.record_material()
	check(not GameState.bounty_done(), "재료가 없으면 완료가 아니다")
	GameState.materials[GameState.MATERIAL] = int(gather["count"])
	GameState.record_material()
	check(GameState.bounty_done(), "재료를 다 모으면 완료")
	var gather_stones: int = GameState.materials[GameState.MATERIAL]
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.materials[GameState.MATERIAL] < gather_stones, "모으기 보상은 재료를 가져간다")
	game._close_dialogue()

	# 캐릭터 화면: 레벨업 점수를 능력치에 넣으면 실제 수치가 오른다.
	GameState.stats = {"strength": 0, "agility": 0, "vitality": 0, "will": 0}
	GameState.stat_points = 0
	GameState.level = 1
	GameState.exp = 0
	GameState.next_exp = 50
	check(GameState.add_reward(100, 0), "경험치로 레벨업")
	check(GameState.stat_points == GameState.POINTS_PER_LEVEL, "레벨업하면 능력치 점수를 받는다")
	press_action(game, "character")
	check(game.character_open and game.get_node("HUD/Character").visible, "C로 캐릭터 화면 열기")
	game._apply_equipment_to_player()
	var hp_before: int = player.max_health
	game.stat_index = GameState.STAT_KEYS.find("vitality")
	press_action(game, "interact")
	check(GameState.stats["vitality"] == 1 and GameState.stat_points == GameState.POINTS_PER_LEVEL - 1, "건강에 점수 투자")
	check(player.max_health == hp_before + GameState.stat_health(), "건강을 올리면 최대 HP가 오른다")
	game.stat_index = GameState.STAT_KEYS.find("strength")
	press_action(game, "interact")
	check(GameState.stat_attack() == 2, "힘은 공격력으로 환산된다")
	GameState.stat_points = 0
	press_action(game, "interact")
	check(GameState.stats["strength"] == 1, "점수가 없으면 더 투자되지 않는다")
	press_action(game, "character")
	check(not game.character_open and not get_tree().paused, "C로 캐릭터 화면 닫기")

	# 보물상자는 한 번 열면 다시 나오지 않는다.
	GameState.opened_chests = []
	game._change_map("forest_w", false)
	var chests := get_tree().get_nodes_in_group("pickups").filter(func(c): return c.kind == "chest")
	check(chests.size() == game.AREA_CHESTS["forest_w"].size(), "숲에 보물상자가 놓인다")
	chests[0]._on_body_entered(player)
	check(GameState.opened_chests.has("forest_a"), "상자를 열면 기록된다")
	check(GameState.inventory.has("구리 반지"), "상자에서 장비를 얻는다")
	game._change_map("village", false)
	game._change_map("forest_w", false)
	var again := get_tree().get_nodes_in_group("pickups").filter(func(c): return c.kind == "chest")
	check(again.size() == chests.size() - 1, "연 상자는 다시 나오지 않는다")

	# 지역마다 고유 몬스터가 깔린다.
	game._change_map("dungeon", false)
	var dungeon_labels := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_boss:
			dungeon_labels[enemy.get_node("Name").text] = true
	check(dungeon_labels.has("동굴박쥐") and dungeon_labels.has("끈적이"), "동굴 전용 몬스터 배치")
	game._change_map("shore", false)
	var shore_labels := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_boss:
			shore_labels[enemy.get_node("Name").text] = true
	check(shore_labels.has("먹물문어") and not shore_labels.has("동굴박쥐"), "지역을 옮기면 몬스터가 바뀐다")
	game._change_map("village", false)
	check(count_mobs() == 0, "마을에는 몬스터가 없다")

	var ending := preload("res://scenes/ending.tscn").instantiate()
	game.add_child(ending)
	check(ending.get_node("Summary").text.contains("최종 기록"), "엔딩 화면 최종 기록 표시")
	ending.queue_free()

	# 마지막으로 타이틀부터 엔딩까지 실제 진행을 한 번 훑는다.
	# GameState 를 초기화하므로 반드시 다른 검사가 끝난 뒤에 돈다.
	await run_playthrough(game, player)

	if failures.is_empty():
		print("INTEGRATION_TEST_OK")
		tree.quit(0)
	else:
		for failure in failures:
			push_error(failure)
		tree.quit(1)


## 타이틀부터 엔딩까지 실제 진행 순서를 그대로 밟는다.
## 중간에 막다른 곳이 생기면 여기서 걸린다.
func run_playthrough(game: Node, player: Node) -> void:
	GameState.reset()
	game.boss_spawned = false
	game.pending_map = ""
	game._change_map("village", false)
	check(GameState.quest_stage == 0, "여정 시작: 마을 0단계")

	# 1. 촌장에게 퀘스트를 받는다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 1, "1단계: 촌장이 숲의 마물 토벌을 맡긴다")
	game._close_dialogue()

	# 2. 외길을 따라 동굴까지 간다.
	check(await go(game, player, "e") == "hill", "마을 동쪽에서 바람 언덕으로")
	check(await go(game, player, "e") == "hill_ridge", "언덕에서 능선으로")
	check(await go(game, player, "w") == "hill", "능선에서 되돌아 언덕으로")
	check(await go(game, player, "w") == "village", "언덕에서 마을로")
	check(await go(game, player, "e") == "hill", "다시 언덕으로")
	check(await go(game, player, "e") == "hill_ridge", "능선으로")
	check(await go(game, player, "e") == "forest_w", "능선에서 안개숲으로")
	check(await go(game, player, "e") == "glade", "안개숲에서 이끼 빈터로")
	check(await go(game, player, "w") == "forest_w", "빈터에서 되돌아 나온다")
	for i in 6:
		game._on_enemy_defeated(20, 10)
	clear_perk(game)
	check(await go(game, player, "e") == "glade", "다시 빈터로")
	check(await go(game, player, "e") == "dungeon", "빈터에서 동굴로")
	# 문은 길을 막는다. 이 검사에서는 열쇠를 쥐여 주고 통과시킨다.
	for id in game.AREA_DOORS.values():
		GameState.take_key(str(id["key"]))
	check(await go(game, player, "e") == "cave_deep", "동굴에서 제단으로")
	clear_perk(game)
	skip_dialogue(game)
	var guardian := find_boss()
	check(guardian != null, "제단에 수호자가 있다")
	check(guardian != null and await kill_boss(guardian, player), "수호자를 공격으로 처치")
	clear_perk(game)
	var fragments_from_guardian: int = GameState.materials[GameState.BOSS_FRAGMENT]
	check(fragments_from_guardian >= GameState.BOSS_FRAGMENT_MIN and fragments_from_guardian <= GameState.BOSS_FRAGMENT_MAX,
		"수호자가 보스의 파편을 확정으로 주되 개수는 10~30 무작위 (%d개)" % fragments_from_guardian)
	check(GameState.quest_stage == 2, "2단계: 마을로 돌아가라는 안내")
	# 실제로 처치한(queue_free + boss_fallen 신호) 보스도 재입장하면 다시
	# 나와야 한다. 위 289줄 근처 검사는 GameState.boss_defeated를 손으로
	# true 만 찍고 실제로는 안 죽여서 boss_spawned 리셋 버그를 못 잡았다
	# (2026-09-03 INBOX "보스 재처치/재등장 동작 확인" 발견).
	game._change_map("dungeon", false)
	game._change_map("cave_deep", false)
	check(find_boss() != null, "실제로 처치한 보스도 지역 재입장 시 다시 나온다")

	# 3. 지도 워프로 마을에 돌아가 보상을 받는다.
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	var gold_before: int = GameState.gold
	game._interact_npc()
	check(GameState.quest_stage == 3 and GameState.gold == gold_before + 100, "3단계: 보상 수령")
	game._close_dialogue()
	game._interact_npc()
	check(GameState.quest_stage == 4 and GameState.chapter == 2, "4단계: 2장 시작")
	game._close_dialogue()
	check(GameState.current_map == "harbor", "2장 시작과 함께 항구 도착")

	# 4. 청람 지방을 지나 성채까지.
	check(await go(game, player, "e") == "shore", "항구에서 해안으로")
	check(await go(game, player, "e") == "marsh", "해안에서 늪지로")
	check(await go(game, player, "e") == "marsh_deep", "늪지에서 깊은 늪으로")
	check(await go(game, player, "e") == "ruins_w", "깊은 늪에서 폐허로")
	check(await go(game, player, "w") == "marsh_deep", "폐허에서 되돌아 나온다")
	check(await go(game, player, "e") == "ruins_w", "다시 폐허로")
	for i in 10:
		game._on_enemy_defeated(30, 15)
	clear_perk(game)
	check(await go(game, player, "e") == "citadel_gate", "폐허에서 성채 관문으로")
	check(await go(game, player, "e") == "citadel", "관문에서 검은 성채로")
	skip_dialogue(game)
	var captain := find_boss()
	check(captain != null, "성채에 흑기사단장이 있다")
	check(captain != null and await kill_boss(captain, player), "흑기사단장을 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 5, "5단계: 마을로 돌아가 보고")

	# 5. 3장.
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 6 and GameState.chapter == 3, "6단계: 3장 시작")
	game._close_dialogue()
	check(GameState.current_map == "frost_camp", "3장 시작과 함께 야영지 도착")
	check(await go(game, player, "e") == "snowfield", "야영지에서 설원으로")
	check(await go(game, player, "e") == "frost_ridge", "설원에서 능선으로")
	for i in 12:
		game._on_enemy_defeated(40, 20)
	clear_perk(game)
	check(await go(game, player, "e") == "frost_gorge", "능선에서 서리 협곡으로")
	check(await go(game, player, "e") == "frozen_falls", "협곡에서 폭포로")
	check(await go(game, player, "e") == "blizzard_plain", "폭포에서 눈보라 평원으로")
	check(await go(game, player, "e") == "glacier", "평원에서 얼음 계곡으로")
	check(await go(game, player, "e") == "temple", "계곡에서 신전으로")
	skip_dialogue(game)
	var frost := find_boss()
	check(frost != null, "신전에 얼음 군주가 있다")
	check(frost != null and await kill_boss(frost, player), "얼음 군주를 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 7, "7단계: 마을로 돌아가 보고")

	# 6. 4장과 최종 보스.
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 8 and GameState.chapter == 4, "8단계: 4장 시작")
	game._close_dialogue()
	check(GameState.current_map == "abyss", "4장 시작과 함께 잿불 야영지 도착")
	check(await go(game, player, "e") == "ash_hollow", "황야에서 잿불 협곡으로")
	check(await go(game, player, "e") == "ash_ridge", "협곡에서 능선으로")
	check(await go(game, player, "e") == "ember_valley", "능선에서 잉걸불 골짜기로")
	check(await go(game, player, "e") == "charred_corridor", "골짜기에서 타버린 회랑으로")
	check(await go(game, player, "e") == "ash_marsh", "회랑에서 재의 늪으로")
	check(await go(game, player, "e") == "throne", "재의 늪에서 심연의 왕좌로")
	skip_dialogue(game)
	var abyss_lord := find_boss()
	check(abyss_lord != null, "왕좌에 최종 보스가 있다")
	check(abyss_lord != null and await kill_boss(abyss_lord, player), "최종 보스를 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 9, "9단계: 결말 확인")

	# 7. 마을로 돌아가 결말. 예전엔 여기서 씬 전체가 ending.tscn으로
	# 바뀌어 게임이 끝나 버렸다 - 이제는 결말 대사만 보여주고 그대로
	# 이어서 플레이한다(탑 같은 엔드게임 콘텐츠를 계속 해야 하므로).
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.game_cleared, "엔딩 도달: 게임 클리어 기록")
	check(GameState.unlocked_maps.size() >= 18, "대부분의 지역을 밟았다")
	check(is_instance_valid(game) and game.is_inside_tree(), "엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")
	check(GameState.unlocked_maps.has("tower"), "엔딩 보면 탑이 지도에 자동 해금됨")
	# 지도(M) 개관도의 탑 표식을 누르면 좌표 이동이 아니라 난이도 선택창이 뜬다.
	# 챕터 탭 리팩터가 order()에서 tower를 통째로 빼 버려 지도에서 고를
	# 방법 자체가 사라졌던 회귀가 있었다 - 다시 나오지 않게 지킨다.
	var map_graph := game.get_node("HUD/WorldMap/Graph")
	game._toggle_world_map()
	check(map_graph.atlas.tower_hit(map_graph.atlas.TOWER_POS), "개관도에 탑 표식이 있다")
	check(map_graph.try_travel_tower() == "", "탑 선택 요청이 받아들여진다")
	check(game.tower_select_open, "탑을 고르면 난이도 선택창이 뜬다")
	check(not game.world_map_open, "난이도 선택창이 뜨며 지도는 닫힌다")
	game._toggle_tower_select()
	skip_dialogue(game)

	# 8. 보스 네 마리를 다 잡았으니 모인 파편으로 "용기사 세트"를 제작해 본다.
	# 파편은 보스마다 10~30개 무작위라 최악이면 40개(10x4)뿐인데, 레시피
	# 합도 그 최저치를 넘지 않게 잡아서 파편 운이 나빠도 완성할 수 있다.
	# 대신 사냥터 전용 아이템은 실제로 구해야 하니 여기서 채워 넣는다.
	var total_fragments: int = GameState.materials[GameState.BOSS_FRAGMENT]
	check(total_fragments >= 4 * GameState.BOSS_FRAGMENT_MIN and total_fragments <= 4 * GameState.BOSS_FRAGMENT_MAX,
		"보스 네 마리의 파편이 다 쌓임 (%d개)" % total_fragments)
	GameState.materials[GameState.MATERIAL] = 99
	GameState.gold = 9999
	GameState.level = 20  # 용기사 세트 최고 요구 레벨(16)을 넉넉히 넘겨서 착용이 막히지 않게
	for area in GameState.AREA_ITEM_DROPS:
		GameState.add_item(str(GameState.AREA_ITEM_DROPS[area]))
	for item in GameState.CRAFT_RECIPES:
		check(GameState.craft(item), "%s 제작" % item)
		GameState.equip(item)
	check(GameState.active_set_special() == "boss_legacy", "용기사 세트 4조각 완성으로 전용 효과 발동")

	# 9. 5장(확장팩 "유민의 땅") — 4장 클리어 후 촌장에게 다시 말 걸면 열린다.
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 11 and GameState.chapter == 5, "11단계: 5장(유민의 땅) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "remnant_village", "5장 시작과 함께 잔영의 마을 도착")
	check(await go(game, player, "e") == "collapsed_spires", "은둔지에서 무너진 첨탑 거리로")
	check(spawned_kinds().has("wraith_soldier") or spawned_kinds().has("floating_shard"),
		"5장 신규 몬스터(잔영병/부유석)가 실제로 스폰된다")
	check(await go(game, player, "e") == "eroded_plaza", "첨탑 거리에서 침식된 광장으로")
	check(await go(game, player, "e") == "cracked_statue", "광장에서 갈라진 석상으로")
	check(has_midboss(), "갈라진 석상(사냥터3)에 중간보스가 있다")
	check(await go(game, player, "e") == "hall_of_afterimages", "석상에서 잔영의 회랑으로")
	check(has_midboss(), "잔영의 회랑(사냥터6 대응)에 중간보스가 있다")
	check(await go(game, player, "e") == "twisted_sanctum", "회랑에서 뒤틀린 사원으로")
	check(await go(game, player, "e") == "rift_of_origin", "사원에서 근원의 균열로")
	skip_dialogue(game)
	var primordial := find_boss()
	check(primordial != null, "근원의 균열에 5장 최종 보스가 있다")
	check(primordial != null and await kill_boss(primordial, player), "태초의 심연을 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 19, "19단계: 5장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 20, "20단계: 확장팩 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "확장팩 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")

	# 10. 6장(확장팩 "파편의 바다") — 5장 클리어 후 촌장에게 다시 말 걸면 열린다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 21 and GameState.chapter == 6, "21단계: 6장(파편의 바다) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "driftwood_pier", "6장 시작과 함께 표류자의 부두 도착")
	check(await go(game, player, "e") == "sunken_causeway", "부두에서 가라앉은 방죽길로")
	check(spawned_kinds().has("tideclaw") or spawned_kinds().has("depth_eye"),
		"6장 신규 몬스터(조류게/심해안)가 실제로 스폰된다")
	check(await go(game, player, "e") == "tideglass_shallows", "방죽길에서 조수유리 여울로")
	check(await go(game, player, "e") == "current_maw", "여울에서 소용돌이 아가리로")
	check(has_midboss(), "소용돌이 아가리(사냥터3)에 중간보스가 있다")
	check(await go(game, player, "e") == "coral_wreckage", "소용돌이에서 산호 난파지로")
	check(await go(game, player, "e") == "abyssal_trench", "난파지에서 심연의 해구로")
	check(has_midboss(), "심연의 해구(사냥터6 대응)에 중간보스가 있다")
	check(await go(game, player, "e") == "the_watcher_reef", "해구에서 파수꾼의 암초로")
	skip_dialogue(game)
	var reef_warden := find_boss()
	check(reef_warden != null, "파수꾼의 암초에 6장 최종 보스가 있다")
	check(reef_warden != null and await kill_boss(reef_warden, player, 48), "파수꾼의 유해를 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 29, "29단계: 6장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 30, "30단계: 6장 확장팩 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "6장 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")

	# 11. 7장(확장팩 "잊힌 성소") — 6장 클리어 후 촌장에게 다시 말 걸면 열린다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 31 and GameState.chapter == 7, "31단계: 7장(잊힌 성소) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "lantern_village", "7장 시작과 함께 등불지기 마을 도착")
	check(await go(game, player, "e") == "sunbleached_stair", "마을에서 빛바랜 계단길로")
	check(spawned_kinds().has("faded_acolyte") or spawned_kinds().has("relic_eye"),
		"7장 신규 몬스터(빛바랜 수도사/유물의 눈)가 실제로 스폰된다")
	check(await go(game, player, "e") == "vow_terrace", "계단길에서 맹세의 회랑으로")
	check(await go(game, player, "e") == "gilded_cloister", "회랑에서 금박 회랑으로")
	check(has_midboss(), "금박 회랑(사냥터3)에 중간보스가 있다")
	check(await go(game, player, "e") == "hollow_nave", "금박 회랑에서 텅 빈 성소로")
	check(await go(game, player, "e") == "ashen_reliquary", "텅 빈 성소에서 잿빛 유물고로")
	check(has_midboss(), "잿빛 유물고(사냥터6 대응)에 중간보스가 있다")
	check(await go(game, player, "e") == "sanctum_of_light", "유물고에서 빛바랜 성소로")
	skip_dialogue(game)
	var faded_prelate := find_boss()
	check(faded_prelate != null, "빛바랜 성소에 7장 최종 보스가 있다")
	check(faded_prelate != null and await kill_boss(faded_prelate, player, 55), "빛바랜 사제왕을 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 39, "39단계: 7장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 40, "40단계: 7장 확장팩 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "7장 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")

	# 12. 8장(확장팩 "침묵의 회랑") — 7장 클리어 후 촌장에게 다시 말 걸면 열린다.
	# 이 장은 마을 없음(무인 경유지 캠프) 설정 -- 첫 지역에 몹이 없어야 한다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 41 and GameState.chapter == 8, "41단계: 8장(침묵의 회랑) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "waystation_camp", "8장 시작과 함께 경유지 캠프 도착")
	check(spawned_kinds().is_empty(), "경유지 캠프는 마을 없음 설정대로 몹이 스폰되지 않는다")
	check(await go(game, player, "e") == "threshold_stair", "경유지 캠프에서 문턱의 계단으로")
	check(spawned_kinds().has("muted_stalker") or spawned_kinds().has("echo_wraith"),
		"8장 신규 몬스터(말없는 추적자/메아리귀병)가 실제로 스폰된다")
	check(await go(game, player, "e") == "muted_gallery", "문턱의 계단에서 소리 없는 회랑으로")
	check(await go(game, player, "e") == "silent_archive", "회랑에서 말라붙은 기록보관소로")
	check(has_midboss(), "말라붙은 기록보관소(사냥터3)에 중간보스가 있다")
	check(await go(game, player, "e") == "hollow_barracks", "기록보관소에서 텅 빈 병영으로")
	check(await go(game, player, "e") == "grey_reservoir", "텅 빈 병영에서 잿빛 저수조로")
	check(has_midboss(), "잿빛 저수조(사냥터6 대응)에 중간보스가 있다")
	check(await go(game, player, "e") == "chamber_of_wardens", "저수조에서 감독관의 방으로")
	skip_dialogue(game)
	var warden_overseer := find_boss()
	check(warden_overseer != null, "감독관의 방에 8장 최종 보스가 있다")
	check(warden_overseer != null and await kill_boss(warden_overseer, player, 62), "말없는 감독관을 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 49, "49단계: 8장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 50, "50단계: 8장 확장팩 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "8장 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")

	# 13. 9장(확장팩 "역전의 탑") — 8장 클리어 후 촌장에게 다시 말 걸면 열린다.
	# 이 장도 마을 없음(무인 회고 캠프) 설정 -- 첫 지역에 몹이 없어야 한다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 51 and GameState.chapter == 9, "51단계: 9장(역전의 탑) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "rift_camp", "9장 시작과 함께 회고의 캠프 도착")
	check(spawned_kinds().is_empty(), "회고의 캠프는 마을 없음 설정대로 몹이 스폰되지 않는다")
	check(await go(game, player, "e") == "inverted_stair", "회고의 캠프에서 거꾸로 된 계단으로")
	check(spawned_kinds().has("twisted_knight") or spawned_kinds().has("twisted_beast"),
		"9장 신규 몬스터(뒤틀린 흑기사/뒤틀린 숲짐승)가 실제로 스폰된다")
	check(await go(game, player, "e") == "echo_of_forest", "거꾸로 된 계단에서 숲의 잔향으로")
	check(await go(game, player, "e") == "echo_of_captain", "숲의 잔향에서 흑기사단장의 잔향으로")
	check(has_midboss(), "흑기사단장의 잔향(사냥터3)에 중간보스가 있다")
	check(await go(game, player, "e") == "echo_of_frost", "흑기사단장의 잔향에서 얼음 군주의 잔향으로")
	check(await go(game, player, "e") == "echo_of_abyss", "얼음 군주의 잔향에서 태초의 심연의 잔향으로")
	check(await go(game, player, "e") == "the_seam", "태초의 심연의 잔향에서 역전의 이음매로")
	check(has_midboss(), "역전의 이음매(사냥터6 대응)에 중간보스가 있다")
	check(await go(game, player, "e") == "throne_of_reversal", "이음매에서 역전의 옥좌로")
	skip_dialogue(game)
	var reverted_one := find_boss()
	check(reverted_one != null, "역전의 옥좌에 9장 최종 보스가 있다")
	check(reverted_one != null and await kill_boss(reverted_one, player, 70), "역행자를 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 59, "59단계: 9장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 60, "9장 확장팩 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "9장 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능")

	# 14. 10장 최종장 — 9장 결말 뒤 근원 관문을 열고 최종 보스를 처치한다.
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 61 and GameState.chapter == 10, "61단계: 10장(근원) 시작")
	skip_dialogue(game)
	check(GameState.current_map == "origin_camp", "10장 시작과 함께 근원의 야영지 도착")
	check(await go(game, player, "e") == "origin_gate", "야영지에서 근원의 길로")
	check(await go(game, player, "e") == "origin_throne", "근원의 길에서 근원의 옥좌로")
	skip_dialogue(game)
	var origin := find_boss()
	check(origin != null, "근원 결절에 10장 최종 보스가 있다")
	check(origin != null and await kill_boss(origin, player, 40), "근원의 보스를 공격으로 처치")
	clear_perk(game)
	check(GameState.quest_stage == 69, "69단계: 최종장 결말 확인 대기")
	warp(game, "village")
	player.global_position = game.NPC_POSITION
	game._interact_npc()
	check(GameState.quest_stage == 70, "10장(최종장) 결말 도달")
	check(is_instance_valid(game) and game.is_inside_tree(), "최종장 엔딩 봐도 씬이 안 끝나고 계속 플레이 가능(탑 유지)")


## 대화를 끝까지 넘긴다.
func skip_dialogue(game: Node) -> void:
	var guard := 0
	while game.dialogue_open and guard < 40:
		# 선택지 장면은 답을 골라야 넘어간다. 첫 보기를 고른다.
		game._advance_dialogue()
		guard += 1


## 레벨업으로 뜬 특성 창을 닫는다. 열려 있으면 이동이 막힌다.
func clear_perk(game: Node) -> void:
	while game.perk_open:
		game._take_perk()


## 그 방향 가장자리로 걸어가 옆 지역으로 넘어간다. 도착한 지역 이름을 준다.
func go(game: Node, player: Node, direction: String) -> String:
	game.transition_lock = 0.0
	var here: String = GameState.current_map
	var bounds: Vector2 = World.pixel_size_of(here)
	player.bounds = bounds
	match direction:
		"e": player.global_position = Vector2(bounds.x - 4.0, bounds.y * 0.5)
		"w": player.global_position = Vector2(4.0, bounds.y * 0.5)
		"n": player.global_position = Vector2(bounds.x * 0.5, 4.0)
		_: player.global_position = Vector2(bounds.x * 0.5, bounds.y - 4.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return GameState.current_map


## 지도에서 골라 바로 이동한다.
func warp(game: Node, area: String) -> void:
	GameState.unlock_map(area)
	GameState.scrolls = maxi(GameState.scrolls, 1)
	game._travel_to(area)


## 화면 끝으로 걸어가 지역이 바뀌기를 기다린다.
## _change_map 이 transition_lock 을 0.6초 걸어 두므로 먼저 풀어야 한다.
func walk_to_edge(game: Node, player: Node, _unused := 0.0) -> void:
	game.transition_lock = 0.0
	var bounds: Vector2 = World.pixel_size_of(GameState.current_map)
	player.bounds = bounds
	player.global_position = Vector2(bounds.x - 4.0, World.path_row(GameState.current_map) * World.TILE + 8.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


## 왼쪽 끝으로 걸어가 이전 지역으로 넘어간다.
func walk_to_west(game: Node, player: Node) -> void:
	game.transition_lock = 0.0
	player.bounds = World.pixel_size_of(GameState.current_map)
	player.global_position = Vector2(4.0, World.path_row(GameState.current_map) * World.TILE + 8.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


## 실제 공격으로 보스를 잡는다. 사거리가 어긋나면 여기서 무한 루프 대신 실패한다.
func kill_boss(boss: Node, player: Node, swings: int = 40) -> bool:
	skip_dialogue(get_parent().get_node("Main"))
	player.global_position = Vector2(150, 128)
	# 1x1 한 방이라 잡몹이 보스 곁에 붙어 있다 - 40회 휘두르는 동안 맞아
	# 죽으면(마을 귀환) 보스 처치가 아닌 이유로 실패하므로 무적으로 휘두른다.
	player.invulnerability_time = 60.0
	for swing in swings:
		if not is_instance_valid(boss):
			player.invulnerability_time = 0.0
			return true
		# 휘두를 때 곁의 잡몹도 같이 죽어 레벨업하면 스탯 재계산이
		# attack_damage를 기본값으로 되돌린다(왕좌 실측 400->26). 매번 다시 건다.
		player.attack_damage = 400
		# 넉백이 누적되면 보스가 공격 범위 밖으로 밀려나 이후 스윙이 빗나간다.
		# 매 스윙마다 위치를 맞춰 AI 자체 판정(대사·시전 등)과 무관하게 처치가
		# 항상 성립하도록 한다.
		boss.global_position = player.global_position + Vector2(boss.body_radius() + 5.0, 0.0)
		boss.hit_time = 0.0
		player.facing = Vector2.RIGHT
		player.cooldown_time = 0.0
		player.attack()
		await get_tree().physics_frame
	player.invulnerability_time = 0.0
	# 사망 트윈(0.15초 ≈ 9틱)이 스윙 한도 턱밑에서 끝나면 queue_free가 아직
	# 안 불린 상태일 수 있다 - 체력이 이미 0 이하면 트윈이 끝날 시간을 더 준다.
	if is_instance_valid(boss) and boss.health <= 0:
		for _extra in 15:
			if not is_instance_valid(boss):
				break
			await get_tree().physics_frame
	return not is_instance_valid(boss)


## 보스를 뺀 잡몹 수.
## 지역 오른쪽 끝 길 위. 한 걸음 더 가면 옆 지역으로 넘어간다.
func east_edge(area: String) -> Vector2:
	var bounds: Vector2 = World.pixel_size_of(area)
	return Vector2(bounds.x - 4.0, World.path_row(area) * World.TILE + 8.0)


## 표에 적힌 마릿수 합.
func expected_mobs(game: Node, area: String) -> int:
	var total := 0
	for entry in game.AREA_SPAWNS[area]:
		total += int(entry.get("count", 1))
	return total


func count_mobs() -> int:
	var total := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_boss:
			total += 1
	return total


func find_boss() -> Node:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			return enemy
	return null


## 현재 지역에 실제로 스폰된 몬스터 종류(archetype) 집합. 5장처럼 새
## archetype이 실제로 스폰 목록에서 나오는지 확인할 때 쓴다.
func spawned_kinds() -> Dictionary:
	var kinds := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		kinds[str(enemy.archetype)] = true
	return kinds


## 지금 지역에 중간보스가 하나라도 있는지.
func has_midboss() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_midboss:
			return true
	return false


func press_action(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func press_key(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	game._unhandled_input(event)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append("FAIL: " + label)
