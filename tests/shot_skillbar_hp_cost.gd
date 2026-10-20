extends Node
## INBOX 11:40 검증용 1회성 캡처 — mage 4번 스킬(heal, hp_cost_pct)
## Cost 라벨 "HP20%"가 칸 밖으로 안 삐져나오는지, 조이스틱이 StatBar와
## 안 겹치는지 눈으로 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame

	GameState.reset()
	GameState.job = "mage"
	GameState.level = 40

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame
	await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://skillbar_hp_cost.png")

	print("SHOT skillbar_hp_cost cost3=", main.get_node("HUD/SkillBar/Skill3/Cost").text)
	get_tree().quit()
