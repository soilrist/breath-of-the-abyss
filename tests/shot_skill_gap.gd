extends Node
## (루프, 2026-10-20) INBOX 23:43 "Lv8~40 스킬 공백 메우기" 3층 — Lv12·20 새 스킬
## 6개(전사 shield_bash/crush_blow, 마법사 frost_wave/mana_shield, 도적
## poison_dart/shadow_slash)가 실제로 발동해 FX 가 뜨는지 직업별로 찍는다.
## Lv30 스킬(warcry/mana_burst/stealth 상위판)은 기존 FX id 를 그대로 재사용해
## 이미 #21/#22 캡처로 확인됐으므로 이번엔 새 id 6개만 찍는다.
## (결함 2026-10-20 16:40) 세 직업을 같은 main 씬·같은 플레이어로 이어서 찍다
## 보니 이전 직업 Lv20 스킬의 SkillFx(총 재생 0.28초)가 채 안 사라진 채로
## 다음 직업 Lv12 스킬을 찍어 두 이펙트가 겹쳐 보였다(예: 전사 주황 crush_blow
## 위에 마법사 하늘색 frost_wave가 묻힘). 직업마다 main 씬을 통째로 새로 띄워
## 이전 FX 잔상이 전혀 없게 고친다.
const JOBS := ["warrior", "mage", "rogue"]


func _ready() -> void:
	for job in JOBS:
		var scene := await _setup_scene(job)
		var player: CharacterBody2D = scene["player"]

		player.skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
		# 슬롯 4 = Lv12 새 스킬. skill_fx.gd 는 scale 0·alpha 0 에서 0.1초
		# 동안 팝인하므로 몇 틱(0.05초) 기다린 뒤 찍어야 FX 가 보인다.
		player.cast_skill(4)
		for i in 3:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shot_skill_gap_%s_lv12.png" % job)
		player.skill_cooldowns[5] = 0.0
		# 슬롯 5 = Lv20 새 스킬.
		player.cast_skill(5)
		for i in 3:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shot_skill_gap_%s_lv20.png" % job)
		print("SHOT skill_gap ", job)

		(scene["main"] as Node).free()

	get_tree().quit()


## 직업 하나를 위한 깨끗한 main 씬을 새로 띄운다(적 없음, 이전 FX 잔상 없음).
func _setup_scene(job: String) -> Dictionary:
	GameState.reset()
	GameState.job = job
	GameState.level = 20
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var guard := 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	main._change_map("forest_w", false)
	guard = 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame

	var player: CharacterBody2D = main.get_node("Player")
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.DOWN
	return {"main": main, "player": player}
