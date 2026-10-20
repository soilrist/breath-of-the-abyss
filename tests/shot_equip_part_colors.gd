extends Node
## INBOX O 조각 1을 실제 화면으로 확인한다 - data/item_palettes.json 14개
## 팔레트 키(세트 10종 + 등급 4종) 전부가 실제 장비 경로로 캐릭터 부위에
## 올바르게 칠해지는지 스크린샷으로 본다. 원래 대표 3종(frost_set/
## captain_set/boss_set)만 보던 것을 몸통/투구 스킨 검사(shot_body_skins.gd/
## shot_helmet_overlays.gd)와 같은 전수 루프 방식으로 넓힌다.
## "mythic"은 뺐다 - 신화 등급 아이템은 전부 "set" 필드가 있어(용각 투구 등
## boss_set) 등급 팔레트 폴백 경로로 화면에 나타난 적이 없다(EQUIPMENT
## 전수 확인, 2026-09-05) - 실제 장비로 확인할 수 없는 키라 스킵.

const KEY_ORDER: Array[String] = ["guardian_set", "captain_set", "frost_set", "abyss_set", "boss_set", "tower_easy_set", "tower_normal_set", "tower_hard_set", "tower_hell_set", "tower_abyss_set", "common", "rare", "epic"]

## 팔레트 키 -> [무기, 방어구, 투구]. 그 세트/등급에 없는 부위는 ""
## (기본 아이템으로 대체돼 해당 부위는 대상 색이 아니라 common으로 보임).
const REPRESENTATIVES := {
	"guardian_set": ["수호자의 검", "", "수호자의 투구"],
	"captain_set": ["", "흑기사 갑주", "흑기사단장의 투구"],
	"frost_set": ["빙결의 창", "서리군주의 갑주", "서리왕관"],
	"abyss_set": ["심연의 파편", "심연의 갑주", ""],
	"boss_set": ["용아 대검", "용린 갑주", "용각 투구"],
	"tower_easy_set": ["파수꾼의 검", "파수꾼의 갑주", "파수꾼의 투구"],
	"tower_normal_set": ["심판자의 검", "심판자의 갑주", "심판자의 투구"],
	"tower_hard_set": ["종언의 검", "종언의 갑주", "종언의 투구"],
	"tower_hell_set": ["겁화의 검", "겁화의 갑주", "겁화의 투구"],
	"tower_abyss_set": ["천공의 검", "천공의 갑주", "천공의 투구"],
	"common": ["낡은 검", "가죽 갑옷", "가죽 모자"],
	"rare": ["강철 대검", "파수병 흉갑", "파수병 투구"],
	"epic": ["빙하의 파편", "용의 비늘", ""],
}
const DEFAULT_WEAPON := "낡은 검"
const DEFAULT_ARMOR := "여행자 옷"
const DEFAULT_HELMET := "가죽 모자"

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 60
	main._change_map("forest_w", false)
	main.get_node("HUD").visible = false

	player.set_physics_process(false)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(6, 6)
	player.facing = Vector2.DOWN

	for key in KEY_ORDER:
		var rep: Array = REPRESENTATIVES[key]
		var weapon: String = rep[0] if rep[0] != "" else DEFAULT_WEAPON
		var armor: String = rep[1] if rep[1] != "" else DEFAULT_ARMOR
		var helmet: String = rep[2] if rep[2] != "" else DEFAULT_HELMET
		GameState.inventory = [weapon, armor, helmet]
		GameState.equip(weapon)
		GameState.equip(armor)
		GameState.equip(helmet)
		main._apply_equipment_to_player()
		cam.global_position = player.global_position
		player._update_sprite(Vector2.ZERO)
		print(key, " weapon_key=", GameState.palette_key_for(weapon),
			" armor_key=", GameState.palette_key_for(armor),
			" helmet_key=", GameState.palette_key_for(helmet))
		# 필드를 돌아다니는 몹이 우연히 화면에 겹쳐 판별을 방해하지 않도록 치운다.
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shot_equip_part_colors_%s.png" % key)

	print("SHOT equip_part_colors done")
	get_tree().quit()
