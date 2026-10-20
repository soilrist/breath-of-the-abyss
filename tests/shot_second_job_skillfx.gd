extends Node
## 2차 전직 스킬 12개(SKILLS_BY_SECOND_JOB, slot 4/5)가 실제로 다른 이펙트를
## 내는지 눈으로 본다. shot_skillfx.gd(1차 스킬 4개)와 같은 패턴이며,
## check_skill_key_input.gd/check_second_job_defense_key_input.gd가 짚었던
## "guardian/berserker/shadow_dancer 분기는 화면으로 본 적이 없다"는 공백을
## 메운다. run_validation.sh에는 연결하지 않는다(기존 shot_*.gd와 동일 관례).
##
## elementalist_meteor/chain_lightning은 낙하 좌표가 맵 전역
## (player.gd:_spawn_world_skill_fx, 8x2/그 이상 화면 규모)에 무작위로
## 흩어지는 설계라 카메라(320x240 화면 하나에 고정)가 매번 잡는다는
## 보장이 없다. 게임플레이 랜덤성을 바꾸지 않고, 대신 캐스트를 여러 번
## 반복해 매번 다른 무작위 좌표를 뽑게 하고 각 시도를 따로 캡처한다
## (STATUS 114번 후보 — WORLD_SKILL_ATTEMPTS번 중 최소 한 장은 이펙트가
## 화면 안에 잡힐 확률이 높다). 대기 시간도 6프레임(~0.1초)에서
## 낙하가 한창 겹치는 중간 지점으로 늘렸다(예전엔 첫 낙하가 시작하기도
## 전에 찍고 있었다).
const WORLD_SKILL_WAIT := {"elementalist_meteor": 0.45, "elementalist_chain_lightning": 0.35}
const WORLD_SKILL_ATTEMPTS := 5

func _ready() -> void:
	for job in GameState.SECOND_JOB_BRANCHES.keys():
		for second_job in GameState.SECOND_JOB_BRANCHES[job]:
			await _shoot_branch(job, second_job)
	get_tree().quit()


func _shoot_branch(job: String, second_job: String) -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job(job)
	GameState.second_job = second_job
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	main._apply_equipment_to_player()
	main._change_map("forest_w", false)
	var player: Node = main.get_node("Player")
	player.mana = 999
	player.max_mana = 999

	var skills: Array = GameState.SKILLS_BY_SECOND_JOB[second_job]
	for offset in skills.size():
		var slot := 4 + offset
		var data: Dictionary = skills[offset]
		var skill_id := str(data["id"])
		player.facing = Vector2.DOWN
		if WORLD_SKILL_WAIT.has(skill_id):
			for attempt in WORLD_SKILL_ATTEMPTS:
				player.skill_cooldowns[slot] = 0.0
				player.mana = 999
				player.cast_skill(slot)
				await get_tree().create_timer(WORLD_SKILL_WAIT[skill_id]).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("user://fx_%s_%d.png" % [skill_id, attempt])
				print("SHOT ", skill_id, " attempt ", attempt)
				await get_tree().create_timer(0.3).timeout
		else:
			player.skill_cooldowns[slot] = 0.0
			player.mana = 999
			player.cast_skill(slot)
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://fx_%s.png" % skill_id)
			print("SHOT ", skill_id)
			await get_tree().create_timer(0.5).timeout

	main.queue_free()
	await get_tree().process_frame
