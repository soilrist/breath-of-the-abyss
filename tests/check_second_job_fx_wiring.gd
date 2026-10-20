extends Node
## 2차 전직 스킬 12개(SKILLS_BY_SECOND_JOB)가 실제로 시전 시 자기 전용
## assets/fx/skill2/<id>.png 텍스처의 SkillFx를 스폰하는지 확인한다.
## check_skill1_fx_wiring.gd와 같은 이유: player.gd:_cast_skill_fx()의
## match 목록에 스킬 id가 하드코딩돼 있어, 스킬을 추가/개명하면서 이 목록
## 갱신을 빠뜨리면 조용히 기본 슬래시 이펙트로 떨어져도 shot_second_job_skillfx.gd
## (육안 확인 전용, run_validation.sh 미등록)로는 못 잡는다.
##
## elementalist_meteor/chain_lightning은 player.gd:_spawn_world_skill_fx()가
## 여러 낙하 지점을 call_deferred + 무작위 딜레이로 흩뿌리는 방식이라(맵 전역
## 좌표), shot_second_job_skillfx.gd처럼 여러 프레임 기다린 뒤 main의 자식
## 전체에서 찾는다(마지막 자식 하나만 보면 다른 스킬의 fx와 섞여 놓칠 수 있다).
const DIRECT_SKILLS := {
	"guardian": {0: "guardian_ward", 1: "guardian_taunt"},
	"berserker": {0: "berserker_rage", 1: "berserker_final_strike"},
	"necromancer": {0: "necromancer_curse", 1: "necromancer_soul_drain"},
	"assassin": {0: "assassin_heart_pierce", 1: "assassin_execute"},
	"shadow_dancer": {0: "shadow_dancer_leap", 1: "shadow_dancer_clone"},
}
const WORLD_SKILLS := {
	"elementalist": {0: "elementalist_meteor", 1: "elementalist_chain_lightning"},
}
## player.gd:_spawn_world_impact()가 count*delay_step에 걸쳐 낙하 지점을
## 흩뿌린 뒤(meteor 18개×0.035s, lightning 26개×0.025s) frame_time(0.42/0.18초)
## 뒤 스스로 queue_free하므로, shot_second_job_skillfx.gd와 같이 낙하가 한창
## 겹치는 중간 지점에서 확인해야 이미 다 사라진 뒤를 보지 않는다.
const WORLD_SKILL_WAIT := {"elementalist_meteor": 0.45, "elementalist_chain_lightning": 0.35}

func _ready() -> void:
	var ok := true
	for job in GameState.SECOND_JOB_BRANCHES.keys():
		for second_job in GameState.SECOND_JOB_BRANCHES[job]:
			ok = await _check_branch(job, second_job) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check_branch(job: String, second_job: String) -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.gold = 999999
	GameState.change_job(job)
	GameState.second_job = second_job
	player.max_mana = 999
	player.health = player.max_health

	var skills: Array = GameState.SKILLS_BY_SECOND_JOB[second_job]
	var by_offset: Dictionary = DIRECT_SKILLS.get(second_job, WORLD_SKILLS.get(second_job, {}))
	var is_world := WORLD_SKILLS.has(second_job)

	for offset_key in by_offset.keys():
		var offset: int = offset_key
		var expected_id: String = by_offset[offset]
		var slot: int = 4 + offset
		var data: Dictionary = skills[offset]
		ok = _check("%s 슬롯%d id는 %s" % [second_job, slot, expected_id], str(data["id"]) == expected_id) and ok
		var expected_path := "res://assets/fx/skill2/%s.png" % expected_id
		for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
		player.mana = 999
		player.health = player.max_health

		if is_world:
			player.cast_skill(slot)
			await get_tree().create_timer(WORLD_SKILL_WAIT[expected_id]).timeout
			var fx := _find_skill_fx_with_path(main, expected_path)
			ok = _check("%s(%s) 시전 시 %s 텍스처의 SkillFx 스폰됨" % [second_job, expected_id, expected_path], fx != null) and ok
			if fx != null: fx.queue_free()
		else:
			player.cast_skill(slot)
			var fx := _find_last_skill_fx(main)
			ok = _check("%s(%s) 시전 시 SkillFx 스폰됨" % [second_job, expected_id], fx != null) and ok
			if fx != null:
				var actual_path: String = fx.texture.resource_path if fx.texture else ""
				ok = _check("%s(%s) 전용 텍스처 사용(기대 %s, 실제 %s)" % [second_job, expected_id, expected_path, actual_path],
					actual_path == expected_path) and ok
				fx.queue_free()

	main.queue_free()
	await get_tree().process_frame
	return ok


## 방금 스폰된 SkillFx를 main의 직계 자식들 중에서 찾는다(_spawn_skill_fx는
## get_parent().add_child(fx)로 Player의 부모, 즉 main 루트에 붙인다).
func _find_last_skill_fx(main: Node) -> Node:
	var found: Node = null
	for child in main.get_children():
		if child is SkillFx:
			found = child
	return found


## 광역 필드 스킬은 여러 SkillFx가 동시에 떠 있을 수 있어, 기대 텍스처 경로를
## 쓰는 것을 하나라도 찾으면 성공으로 본다.
func _find_skill_fx_with_path(main: Node, expected_path: String) -> Node:
	for child in main.get_children():
		if child is SkillFx and child.texture and child.texture.resource_path == expected_path:
			return child
	return null


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
