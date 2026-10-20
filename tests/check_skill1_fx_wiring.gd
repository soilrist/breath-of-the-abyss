extends Node
## 1차 전직 스킬 8개(shield_charge/warcry/undying/ice_spear/mana_burst/
## shuriken/stealth/swift_step)가 실제로 casting 시 자기 전용
## assets/fx/skill1/<id>.png 텍스처의 SkillFx를 스폰하는지 확인한다.
## _cast_skill_fx()의 match 목록에 스킬 id가 하드코딩돼 있어, 스킬을
## 새로 추가/변경하면서 이 목록 갱신을 빠뜨리면 조용히 기본 슬래시
## 이펙트로 떨어진다 - 그 회귀를 잡는다.
##
## mage의 "heal"(마나 순환)은 커밋 6b7d565 메시지가 나열한 8개 명단에
## 없다 - 전용 이펙트를 새로 만들지 않고 기존 공용 heal.png를 그대로
## 쓰는 것이 의도된 설계라, 여기서는 skill1/*.png가 아니라 그 공용
## 경로를 fx_path로 직접 지정한다.
const EXPECTED := {
	"warrior": {
		1: {"id": "shield_charge", "fx_path": "res://assets/fx/skill1/shield_charge.png"},
		2: {"id": "warcry", "fx_path": "res://assets/fx/skill1/warcry.png"},
		3: {"id": "undying", "fx_path": "res://assets/fx/skill1/undying.png"},
	},
	"mage": {
		1: {"id": "ice_spear", "fx_path": "res://assets/fx/skill1/ice_spear.png"},
		2: {"id": "mana_burst", "fx_path": "res://assets/fx/skill1/mana_burst.png"},
		3: {"id": "heal", "fx_path": "res://assets/fx/heal.png"},
	},
	"rogue": {
		1: {"id": "shuriken", "fx_path": "res://assets/fx/skill1/shuriken.png"},
		2: {"id": "stealth", "fx_path": "res://assets/fx/skill1/stealth.png"},
		3: {"id": "swift_step", "fx_path": "res://assets/fx/skill1/swift_step.png"},
	},
}

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	player.max_mana = 999
	player.health = player.max_health

	for job in EXPECTED.keys():
		GameState.change_job(job)
		for skill_index in EXPECTED[job].keys():
			var expect: Dictionary = EXPECTED[job][skill_index]
			var skill_id: String = expect["id"]
			var expected_path: String = expect["fx_path"]
			# EXPECTED의 id가 실제 GameState 데이터와 여전히 일치하는지
			# 먼저 확인한다 - 스킬 목록이 바뀌면 이 표도 같이 갱신해야 한다.
			var data: Dictionary = GameState.active_skills()[skill_index]
			ok = _check("%s 스킬%d id는 %s" % [job, skill_index, skill_id], str(data["id"]) == skill_id) and ok
			for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
			player.mana = 999
			player.health = player.max_health
			player.cast_skill(skill_index)
			var fx := _find_last_skill_fx(main)
			ok = _check("%s(%s) 시전 시 SkillFx 스폰됨" % [job, skill_id], fx != null) and ok
			if fx != null:
				var actual_path: String = fx.texture.resource_path if fx.texture else ""
				ok = _check("%s(%s) 전용 텍스처 사용(기대 %s, 실제 %s)" % [job, skill_id, expected_path, actual_path],
					actual_path == expected_path) and ok
				fx.queue_free()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## 방금 스폰된 SkillFx를 main의 직계 자식들 중에서 찾는다(_spawn_skill_fx는
## get_parent().add_child(fx)로 Player의 부모, 즉 main 루트에 붙인다).
func _find_last_skill_fx(main: Node) -> Node:
	var found: Node = null
	for child in main.get_children():
		if child is SkillFx:
			found = child
	return found


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
