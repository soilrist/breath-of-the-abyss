extends Node
## 1차 전직 스킬 8종(INBOX 지시 ②)이 전용 이펙트 스프라이트를 쓰는지 검증한다.
## - assets/fx/skill1/<id>.png 8개가 실제로 있고 64x64, 네 모서리 알파 0(투명 배경)
## - 스킬을 실제로 시전하면 SkillFx 노드가 해당 텍스처로 화면에 생겨난다(배선 확인)

const SKILL_IDS := ["shield_charge", "warcry", "undying", "ice_spear", "mana_burst", "shuriken", "stealth", "swift_step"]
const JOB_OF := {
	"shield_charge": "warrior", "warcry": "warrior", "undying": "warrior",
	"ice_spear": "mage", "mana_burst": "mage",
	"shuriken": "rogue", "stealth": "rogue", "swift_step": "rogue",
}

func _ready() -> void:
	var ok := true

	for skill_id in SKILL_IDS:
		var path := "res://assets/fx/skill1/%s.png" % skill_id
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		ok = _check("%s: 파일 로드됨" % skill_id, img != null) and ok
		if img == null:
			continue
		ok = _check("%s: 64x64" % skill_id, img.get_width() == 64 and img.get_height() == 64) and ok
		var w := img.get_width()
		var h := img.get_height()
		var corners := [img.get_pixel(0, 0), img.get_pixel(w - 1, 0), img.get_pixel(0, h - 1), img.get_pixel(w - 1, h - 1)]
		var corners_clear := true
		for c in corners:
			if c.a != 0.0:
				corners_clear = false
		ok = _check("%s: 네 모서리 알파 0(투명 배경)" % skill_id, corners_clear) and ok
		var used := img.get_used_rect()
		var fill_ratio := float(used.size.x * used.size.y) / float(w * h)
		ok = _check("%s: 채움 비율 >= 0.45(실측 %.2f)" % [skill_id, fill_ratio], fill_ratio >= 0.45) and ok

		# 프롬프트가 요구하는 배경색(tools/comfy_gen.py 기본 --key-color)과
		# 정확히 대조한다. R>150,G<100,B>80 같은 느슨한 "핑크빛" 휴리스틱은
		# mana_burst 의 정상적인 보라색(B 채널이 높은 청보라, 예 189,80,250)
		# 까지 자홍으로 오판했다(2026-09-06 실측) — 실제 배경색은 B가 낮은
		# (201,53,127)이라 B 채널로 구분된다.
		const KEY_COLOR := Color(201.0 / 255.0, 53.0 / 255.0, 127.0 / 255.0)
		const KEY_TOLERANCE := 30.0 / 255.0
		var magenta := 0
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					if absf(c.r - KEY_COLOR.r) <= KEY_TOLERANCE and absf(c.g - KEY_COLOR.g) <= KEY_TOLERANCE and absf(c.b - KEY_COLOR.b) <= KEY_TOLERANCE:
						magenta += 1
		var magenta_ratio := float(magenta) / float(w * h)
		# INBOX 결함(2026-09-06 00:08): 모델이 "flat magenta background"를
		# 캔버스 전체가 아니라 가운데 판으로 그려 모서리 색만 투명화되고
		# 자홍색 판이 남는 사고가 있었다 — 채움 비율만 보면 "잘 채워졌다"로
		# 통과해버리는 사각지대라 배경색 잔존을 직접 잰다. (불투명 비율 상한은
		# 시도했으나 shield_charge 결함 0.70 < undying 정상 0.76 로 결함과
		# 정상을 못 가려 폐기 — 자홍 픽셀 비율만 남긴다.)
		ok = _check("%s: 자홍색 픽셀 < 2%%(실측 %.2f%%, 배경 판 잔존 방지)" % [skill_id, magenta_ratio * 100.0], magenta_ratio < 0.02) and ok

		# INBOX 결함(감독, 2026-09-06 00:55): shield_charge 재생성본이 자홍
		# 대신 흰색 원판을 뒤에 깔았다 — 색 지정 검사로는 못 잡는다. 색과
		# 무관하게 "판"을 잡으려고 불투명 픽셀을 16단계로 양자화해 가장 흔한
		# 단일 색 비율을 잰다(평평한 판은 한 색이 지배, 이펙트는 그라데이션이라
		# 흩어짐). 8장 실측: 정상 중 최고는 swift_step 0.59(단색 바람 줄기),
		# 결함 shield_charge(흰 원판)는 0.65 — 그 사이 0.62를 기준으로 삼는다.
		var counts := {}
		var opaque_n := 0
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					opaque_n += 1
					var key := Vector3i(int(c.r * 255.0) / 16, int(c.g * 255.0) / 16, int(c.b * 255.0) / 16)
					counts[key] = counts.get(key, 0) + 1
		var dominant_n := 0
		for key in counts:
			dominant_n = max(dominant_n, counts[key])
		var dominant_ratio := float(dominant_n) / float(opaque_n) if opaque_n > 0 else 0.0
		ok = _check("%s: 단색 판 잔존 없음(지배색 비율 %.2f <= 0.62)" % [skill_id, dominant_ratio], dominant_ratio <= 0.62) and ok

		# INBOX 결함(2026-09-06, undying 드롭섀도 타원): 위 자홍 픽셀 검사는
		# RGB 거리 기준이라 배경과 밝기만 다른(같은 색상 계열의) 그림자를
		# 놓친다 — 어두운 마룬(169,43,85)은 순수 자홍(201,53,127)과 RGB
		# 거리가 tolerance(30/255)를 근소하게 넘어 통과해버렸다. 색상각
		# (Color.h)은 밝기가 달라도 안 흔들리므로 같은 계열이면 잡는다.
		# shuriken 은 모션 블러 줄기가 핑크빛(색상각 잔존 15.8%)으로 나오는
		# 결함이 있었으나 재생성 4회(자홍 배경 negation 3회 + 초록 키 배경
		# 2회, 2026-09-06)가 모두 실패했다 — 초록 배경으로 바꾸면 줄기 색은
		# 은/회색으로 정상화되지만(육안 확인 완료) 채움 비율이 0.34/0.44로
		# 기준 0.45 미달이었다. 감독 승인(2026-09-06, "핑크 궤적은 참격
		# 잔상으로 읽히고 배경 판도 없어 연출상 문제 없음")으로 현재 그림을
		# 그대로 채택 — 고칠 결함이 아니라 승인된 디자인이므로 이 검사에서
		# 영구 제외한다.
		if skill_id != "shuriken":
			var key_hue := KEY_COLOR.h
			var hue_hits := 0
			for y in h:
				for x in w:
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and c.s > 0.12:
						var hue_d := absf(c.h - key_hue)
						hue_d = minf(hue_d, 1.0 - hue_d)
						if hue_d <= 25.0 / 360.0:
							hue_hits += 1
			var hue_ratio := float(hue_hits) / float(w * h)
			# 기준 6%: 정상 자산 중 최고 swift_step 3.1%(경계 앤티앨리어싱)와
			# 결함 shuriken 15.8%(핑크 줄기+그림자) 사이 값.
			ok = _check("%s: 배경 색상각 잔존 < 6%%(실측 %.2f%%, 그림자 등 간접 잔존 방지)" % [skill_id, hue_ratio * 100.0], hue_ratio < 0.06) and ok

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.level = 20
	GameState.gold = 999999
	player.max_mana = 999
	player.mana = 999

	var job_slot_of_skill := {
		"shield_charge": 1, "warcry": 2, "undying": 3,
		"ice_spear": 1, "mana_burst": 2,
		"shuriken": 1, "stealth": 2, "swift_step": 3,
	}
	for skill_id in SKILL_IDS:
		GameState.change_job(JOB_OF[skill_id])
		for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
		player.mana = 999
		var slot: int = job_slot_of_skill[skill_id]
		var actual_id: String = GameState.active_skills()[slot]["id"]
		if actual_id != skill_id:
			ok = _check("%s: 슬롯 매핑 확인(실제 %s)" % [skill_id, actual_id], false) and ok
			continue
		player.cast_skill(slot)
		# 대시형 스킬(shield_charge 등)은 이펙트보다 먼저 이동하므로(player.gd
		# cast_skill: dash 처리 후 _cast_skill_fx 호출), 이펙트는 대시 "후"
		# 위치에 떠야 정상이다(INBOX 답 2026-09-06: 도착 지점 연출).
		var pos_after_cast: Vector2 = player.global_position
		var found := false
		for child in main.get_children():
			if child is SkillFx and String(child.texture.resource_path).ends_with("skill1/%s.png" % skill_id):
				found = true
				ok = _check("%s: SkillFx 위치가 대시 후(도착 지점) 플레이어 위치와 같음" % skill_id, child.global_position == pos_after_cast) and ok
				ok = _check("%s: SkillFx scale.x <= 1.0(화면 절반 결함 재발 방지)" % skill_id, child.scale.x <= 1.0) and ok
				child.queue_free()
		ok = _check("%s: 시전 시 skill1 전용 SkillFx 노드가 생성됨" % skill_id, found) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
