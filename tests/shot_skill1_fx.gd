extends Node
## 1차 전직 스킬 8개(INBOX 지시 ②, MAP_MOB_FX_DESIGN.md §4)가 새 skill1
## 전용 이펙트로 실제 화면에 나오는지 눈으로 본다. shot_second_job_skillfx.gd와
## 같은 패턴. run_validation.sh에는 연결하지 않는다(기존 shot_*.gd와 동일 관례).
## 먼저 `godot --headless --path . --import`를 돌려라 - 이 스크립트는
## cast_skill()이 preload/load로 텍스처를 읽어 ResourceLoader(.godot/imported
## 캐시)를 거치므로, 임포트를 안 하면 에셋을 바꿔도 옛 그림이 찍힌다
## (2026-09-06 INBOX 지시, shield_charge 흰 원판 사례).

const JOB_OF := {
	"shield_charge": "warrior", "warcry": "warrior", "undying": "warrior",
	"ice_spear": "mage", "mana_burst": "mage",
	"shuriken": "rogue", "stealth": "rogue", "swift_step": "rogue",
}

func _ready() -> void:
	for job in ["warrior", "mage", "rogue"]:
		await _shoot_job(job)
	get_tree().quit()


func _shoot_job(job: String) -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	GameState.level = 20
	GameState.gold = 999999
	GameState.change_job(job)
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	main._apply_equipment_to_player()
	main._change_map("forest_w", false)
	var player: Node = main.get_node("Player")
	player.mana = 999
	player.max_mana = 999

	var skills: Array = GameState.SKILLS_BY_JOB[job]
	for slot in skills.size():
		var data: Dictionary = skills[slot]
		var skill_id := str(data["id"])
		if not JOB_OF.has(skill_id):
			continue
		player.facing = Vector2.DOWN
		player.skill_cooldowns[slot] = 0.0
		player.mana = 999
		player.cast_skill(slot)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://fx_skill1_%s.png" % skill_id)
		print("SHOT ", skill_id)
		await get_tree().create_timer(0.4).timeout

	main.queue_free()
	await get_tree().process_frame
