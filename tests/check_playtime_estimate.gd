extends Node
## INBOX E: "실제 사냥해보고 레벨업하고 전직 1,2차 해보고 플레이타임 계산해보고" 리포트.
## 손으로 플레이하는 대신, 이미 있는 실수치(TIERS/BOSS_TIERS/스탯 공식/경험치 곡선)
## 그대로 써서 "전투에만 걸리는 최소 시간"을 계산한다. 이동·대사·파밍 왕복·죽음/도주는
## 뺐다 — 그래서 이 숫자는 실제 플레이타임의 하한선이지 전체가 아니다(리포트에도 그렇게 적는다).
##
## 가정(발명한 밸런스 숫자 없음, 전부 game_state.gd/main.gd/player.gd 기존 상수):
## - 레벨업 스탯 포인트(POINTS_PER_LEVEL=3/레벨)를 전부 힘에 투자(stat_attack: 힘 1당 공격 2).
## - 치명타는 기본값(8% 확률, 180% 배율)만 반영한 평균 배율. 특성·마법돌·세트는 0으로 둔다(맨몸 하한선).
## - 몬스터는 챕터가 가진 사냥터(AREA_SPAWNS)의 티어를 마리 수로 가중평균해 대표 티어 하나로 잡는다.
## - 보스 처치 시간은 15/40레벨(1차/2차 전직 직후) 공격력 두 기준으로 구간을 나눠 계산한다.
## - 탑(엔드게임)은 GameState.tower_floor_stats()/tower_power_floor() 실함수를 40레벨·맨몸
##   전투력으로 그대로 호출해 계산한다(공식을 베끼지 않는다). 강화 기대 시도 횟수는
##   ENHANCE_RATES/ENHANCE_DESTROY_CHANCE로 몬테카를로 시뮬레이션한다. 강화석 파밍 속도는
##   설계 문서 어디에도 없어(재료 획득처는 현상금 퀘스트뿐, 몬스터 드랍 없음) 시간으로
##   환산하지 않는다 - 시도 횟수·강화석 개수까지만 숫자로 낸다.

const POINTS_PER_LEVEL := 3  # game_state.gd:64
const BASE_ATTACK_DAMAGE := 12.0  # player.gd:11 attack_damage
const STR_TO_ATK := 2.0  # game_state.gd stat_attack(): 힘 1당 공격 2
const BASE_CRIT_CHANCE := 0.08  # game_state.gd crit_chance() 기본값
const BASE_CRIT_MULT := 1.8  # game_state.gd crit_damage_mult() 기본값
const AVG_CRIT_FACTOR := 1.0 + BASE_CRIT_CHANCE * (BASE_CRIT_MULT - 1.0)
# main.gd:1992~2017 _quest_stage_text()의 실제 chapter_kills/kills 게이트 값.
# 4장은 이 딕셔너리에 없다 - 게이트 자체가 코드에 없다(확인, 발명 아님).
const CHAPTER_KILL_REQUIREMENT := {
	1: 6, 2: 10, 3: 12, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12,
}


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var attack_cd: float = float(main.get_node("Player").attack_cooldown)
	ok = _check("공격 쿨다운 값 확인(0보다 큼)", attack_cd > 0.0) and ok

	# 챕터별 대표 몬스터 티어 = 그 챕터 사냥터(AREA_SPAWNS)의 티어를 마리 수로 가중평균.
	var chapter_tier := _chapter_avg_tiers(main)
	ok = _check("1장 대표 티어 계산됨", chapter_tier.has(1)) and ok
	ok = _check("4장 대표 티어 계산됨", chapter_tier.has(4)) and ok
	if not (chapter_tier.has(1) and chapter_tier.has(4)):
		print("RESULT FAIL (챕터 대표 티어를 못 구함)")
		get_tree().quit()
		return

	print("--- 챕터별 대표 몬스터 티어(사냥터 가중평균) ---")
	for c in chapter_tier.keys():
		print("%d장: 티어 %d" % [c, chapter_tier[c]])

	# 레벨 1~15는 1장 몬스터로, 15~40은 4장 몬스터로 사냥한다고 가정
	# (2차 전직이 실제로 "레벨 40 & 4장 이상"을 요구하므로 이 구간 배정은 발명이 아니라 실제 게이트).
	var seconds_1_15 := _seconds_to_level_range(1, 15, chapter_tier[1], attack_cd, main.TIERS)
	var seconds_15_40 := _seconds_to_level_range(15, 40, chapter_tier[4], attack_cd, main.TIERS)
	ok = _check("1->15 사냥 시간이 유한한 양수", seconds_1_15 > 0.0 and is_finite(seconds_1_15)) and ok
	ok = _check("15->40 사냥 시간이 유한한 양수", seconds_15_40 > 0.0 and is_finite(seconds_15_40)) and ok

	print("--- 레벨업 사냥 시간(전투만, 이동/파밍 왕복 제외) ---")
	print("1 -> 15레벨 (1장 %d티어 기준): %.1f분" % [chapter_tier[1], seconds_1_15 / 60.0])
	print("15 -> 40레벨 (4장 %d티어 기준): %.1f분" % [chapter_tier[4], seconds_15_40 / 60.0])
	print("주의: 15->40 구간은 4장 몬스터 한 티어에 25레벨 내내 고정해 놓고 계산한 것이라")
	print("과대평가됐다 - 실제로는 레벨이 오르며 5~9장의 더 센 몬스터로 옮겨가 exp효율이")
	print("올라간다. 이 구간만은 하한선이 아니라 상한선에 가깝다(다음 조각에서 챕터별로")
	print("구간을 잘게 나눠 고칠 것).")

	# 챕터별 보스 처치 시간: 1차 전직 직후(15레벨)와 2차 전직 직후(40레벨) 공격력 두 기준.
	var atk15 := _attack_power_at(15) * AVG_CRIT_FACTOR
	var atk40 := _attack_power_at(40) * AVG_CRIT_FACTOR
	print("--- 챕터 보스 처치 시간(맨몸 기준, 장비 강화 반영 안 함) ---")
	var boss_seconds_total := 0.0
	var prev_hp := -1
	for c in main.BOSS_TIERS.keys():
		var boss: Dictionary = main.BOSS_TIERS[c]
		var hp := float(boss["hp"])
		var t15: float = ceil(hp / atk15) * attack_cd
		var t40: float = ceil(hp / atk40) * attack_cd
		print("%d장 보스: 15레벨 기준 %.1f분 / 40레벨 기준 %.1f분" % [c, t15 / 60.0, t40 / 60.0])
		# 초반 3개 장은 15레벨 공격력, 나머지는 40레벨 공격력으로 보수적으로 잡는다.
		boss_seconds_total += (t15 if c <= 3 else t40)
		ok = _check("%d장 보스 처치 시간이 유한한 양수" % c, t15 > 0.0 and is_finite(t15) and t40 > 0.0 and is_finite(t40)) and ok
		prev_hp = int(hp)

	# INBOX E-2 나머지: "챕터별 권장 레벨대"는 코드/기획서 어디에도 없어 발명이
	# 필요하지만(질문 대기 중), 각 챕터의 필수 처치 수(chapter_kills/kills 게이트,
	# main.gd:1992~2017에 이미 있는 실제 값)로 "챕터별 필수 처치 완료 시간"은
	# 발명 없이 낼 수 있다(STATUS 다음 후보). 4장은 그런 게이트 자체가 없다
	# (몬스터를 잡지 않고 지나가도 됨 - main.gd:2010 "잿불 황야를 지나
	# 심연의 왕좌로"에 %d/N 표시가 없음, 확인됨).
	print("--- 챕터별 필수 처치 완료 시간(main.gd 실제 chapter_kills/kills 게이트, 15/40레벨 공격력 기준) ---")
	var chapter_kill_seconds_total := 0.0
	for c in range(1, 11):
		if not CHAPTER_KILL_REQUIREMENT.has(c):
			print("%d장: 처치 게이트 없음(main.gd에 %%d/N 표시 없음, 스킵)" % c)
			continue
		var required: int = CHAPTER_KILL_REQUIREMENT[c]
		if not chapter_tier.has(c):
			print("%d장: 대표 티어 없음(스킵)" % c)
			continue
		var tier: int = chapter_tier[c]
		if not main.TIERS.has(tier):
			print("%d장: 티어 %d 정의 없음(스킵)" % [c, tier])
			continue
		var atk: float = atk15 if c <= 3 else atk40
		var mob: Dictionary = main.TIERS[tier]
		var hits: float = ceil(float(mob["hp"]) / max(1.0, atk))
		var chapter_seconds: float = required * hits * attack_cd
		chapter_kill_seconds_total += chapter_seconds
		print("%d장: %d마리 처치(티어 %d): %.1f분" % [c, required, tier, chapter_seconds / 60.0])
		ok = _check("%d장 필수 처치 시간이 유한한 양수" % c, chapter_seconds > 0.0 and is_finite(chapter_seconds)) and ok
	print("챕터별 필수 처치 합계: %.1f분 (%.1f시간)" % [chapter_kill_seconds_total / 60.0, chapter_kill_seconds_total / 3600.0])
	print("주의: 이 숫자는 위 1->15/15->40 레벨업 사냥 시간과 별개다(레벨업에 필요한 킬 수가")
	print("스토리 게이트 킬 수보다 훨씬 많아 이미 그 안에 포함돼 있을 가능성이 높다) - 합계에는")
	print("더하지 않는다. \"최소한 각 장을 몇 분 만에 통과할 수 있는가\"를 보여주는 별도 지표다.")

	# 탑(엔드게임): 40레벨·맨몸(장비 0) 전투력으로 GameState의 실제 스킵 공식
	# (tower_power_floor)이 주는 시작 층부터 100층까지, 실제 층별 능력치
	# (tower_floor_stats)로 몬스터를 잡는 시간. 난이도 5종은 순서대로 이전
	# 난이도 100층 클리어가 조건이라(TOWER_TIERS.requires) 5개를 전부 더한다.
	GameState.level = 40
	GameState.stats = {"strength": (40 - 1) * POINTS_PER_LEVEL, "agility": 0, "vitality": 0, "will": 0}
	GameState.attack_bonus = 0
	GameState.defense_bonus = 0
	GameState.health_bonus = 0
	GameState.speed_bonus = 0
	print("--- 탑(엔드게임) 층별 처치 시간(40레벨·맨몸 기준, 난이도 5종 각 100층) ---")
	var tower_seconds_total := 0.0
	for tier in GameState.TOWER_TIERS:
		var start_floor: int = GameState.tower_power_floor(tier)
		var tier_seconds := 0.0
		for f in range(start_floor, GameState.TOWER_FLOOR_COUNT + 1):
			var stats: Dictionary = GameState.tower_floor_stats(f, tier)
			var count := 5 + f / 10  # main.gd:2353 _spawn_tower_floor()의 층당 마리 수
			var hits: float = ceil(float(stats["hp"]) / max(1.0, atk40))
			tier_seconds += count * hits * attack_cd
		var tier_name := str(GameState.TOWER_TIERS[tier].get("name", tier))
		print("%s: %d층부터 스킵(전투력 기준) 시작, 100층까지 %.1f분" % [tier_name, start_floor, tier_seconds / 60.0])
		ok = _check("%s 탑 처치 시간이 유한한 양수" % tier_name, tier_seconds > 0.0 and is_finite(tier_seconds)) and ok
		tower_seconds_total += tier_seconds
	print("주의: 5개 난이도 내내 40레벨·무장비로 고정한 계산이라 뒤로 갈수록 과대평가된다")
	print("(실제로는 탑을 오르며 레벨·장비도 같이 오른다) - 상한선에 가깝다.")

	# 강화 기대 시도 횟수: ENHANCE_RATES/ENHANCE_DESTROY_CHANCE로 +0 -> MAX_ENHANCE 몬테카를로.
	# 부적(enhance_wards) 0개 가정(맨몸 하한선과 같은 원칙). 시간으로는 안 바꾼다 - 강화석
	# 파밍 속도가 설계 문서 어디에도 없다(현상금 퀘스트로만 얻고 몬스터 드랍 없음).
	var enhance_stats := _simulate_enhance_attempts(2000)
	print("--- 강화 +0 -> +%d 기대 시도 횟수(몬테카를로 %d회 평균, 부적 0개) ---" % [GameState.MAX_ENHANCE, 2000])
	print("확률 강화: 평균 시도 %.1f회, 평균 소모 강화석 %.1f개 (성공률/파괴 확률 실수치, 시간 환산 안 함)" % [
		enhance_stats["attempts"], enhance_stats["stones"]])
	ok = _check("강화 기대 시도 횟수가 유한한 양수", enhance_stats["attempts"] > 0.0 and is_finite(enhance_stats["attempts"])) and ok

	# INBOX J(탑 콘텐츠) 후속: 확정 강화(Z키, b7f6b6b)가 생기면서 탑 진행 속도가
	# 달라질 수 있다는 지시를 실제 수치로 확인한다. 확정 강화는 RNG가 없어(항상
	# 성공, 하락/파괴 없음) 몬테카를로가 필요 없고 ENHANCE_GUARANTEED_MULT/
	# _RISK_MULT로 시도 10회 고정 비용을 그대로 더하면 된다(game_state.gd:1278
	# enhance_guaranteed_cost와 동일 공식).
	var guaranteed_stones := 0
	for step in range(GameState.MAX_ENHANCE):
		var mult := GameState.ENHANCE_GUARANTEED_MULT
		if step >= GameState.ENHANCE_RISK_STEP:
			mult *= GameState.ENHANCE_GUARANTEED_RISK_MULT
		guaranteed_stones += (step + 1) * mult
	print("확정 강화: 시도 %d회 고정(파괴/하락 없음), 소모 강화석 %d개(항상 이 값, RNG 없음)" % [
		GameState.MAX_ENHANCE, guaranteed_stones])
	print("-> 확정 강화가 확률 강화 평균보다 시도 %.1f배 적고, 강화석도 평균 %.1f배 적게 든다" % [
		enhance_stats["attempts"] / float(GameState.MAX_ENHANCE), enhance_stats["stones"] / guaranteed_stones])
	print("(단계당 배율은 확률 강화보다 비싸지만, 실패/파괴로 인한 재시도 낭비가 없어 총량은 오히려 적다)")
	print("(강화석 파밍 속도가 설계 문서에 없어 이 차이를 시간으로는 못 바꾼다 - 위와 같은 이유)")
	ok = _check("확정 강화 강화석 소모가 유한한 양수", guaranteed_stones > 0) and ok

	var total_seconds := seconds_1_15 + seconds_15_40 + boss_seconds_total + tower_seconds_total
	print("--- 합계 ---")
	print("전투 시간 하한선: %.1f시간 (사냥 %.1f시간 + 보스 %.1f시간 + 탑 %.1f시간)" % [
		total_seconds / 3600.0, (seconds_1_15 + seconds_15_40) / 3600.0, boss_seconds_total / 3600.0,
		tower_seconds_total / 3600.0])
	print("주의: 이동·대사·상점/대장간·죽음 후 재도전·강화석 파밍은 이 숫자에 안 들어 있다.")
	print("실제 체감 플레이타임은 이보다 길다 — 하한선일 뿐이다.")

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## 챕터별 사냥터(AREA_SPAWNS) 몬스터 티어를 마리 수 가중평균해 대표 티어 하나로 잡는다.
func _chapter_avg_tiers(main: Node) -> Dictionary:
	var weighted := {}  # chapter -> {"sum": float, "count": int}
	for area in World.AREAS:
		var chapter := int(World.AREAS[area].get("chapter", 0))
		if chapter <= 0:
			continue
		var roster: Array = main.AREA_SPAWNS.get(area, [])
		if roster.is_empty():
			continue
		if not weighted.has(chapter):
			weighted[chapter] = {"sum": 0.0, "count": 0}
		for entry in roster:
			var count := int(entry.get("count", 1))
			weighted[chapter]["sum"] += float(entry["tier"]) * count
			weighted[chapter]["count"] += count
	var result := {}
	for chapter in weighted:
		var w = weighted[chapter]
		if w["count"] > 0:
			result[chapter] = int(round(w["sum"] / w["count"]))
	return result


## POINTS_PER_LEVEL을 전부 힘에 투자했다고 가정한 레벨 L의 공격력(치명타 제외).
func _attack_power_at(level: int) -> float:
	var stat_points := (level - 1) * POINTS_PER_LEVEL
	return BASE_ATTACK_DAMAGE + stat_points * STR_TO_ATK


## from_level -> to_level 까지 주어진 티어 몬스터만 사냥해 레벨업하는 데 걸리는 실제 초.
func _seconds_to_level_range(from_level: int, to_level: int, tier: int, attack_cd: float, tiers: Dictionary) -> float:
	if not tiers.has(tier):
		return 0.0
	var mob: Dictionary = tiers[tier]
	var mob_hp := float(mob["hp"])
	var mob_exp := float(mob["exp"])
	var total := 0.0
	for level in range(from_level, to_level):
		var attack_power := _attack_power_at(level) * AVG_CRIT_FACTOR
		var hits_to_kill: float = ceil(mob_hp / max(1.0, attack_power))
		var time_per_kill: float = hits_to_kill * attack_cd
		var kills_needed: float = ceil(float(GameState.exp_for_level(level)) / mob_exp)
		total += kills_needed * time_per_kill
	return total


## +0에서 MAX_ENHANCE까지 GameState.enhance()와 같은 확률표(ENHANCE_RATES/
## ENHANCE_RISK_STEP/ENHANCE_DESTROY_CHANCE)로 실제 랜덤워크를 trials번 굴려
## 평균 시도 횟수·평균 소모 강화석을 낸다. 부적은 0개로 고정(맨몸 하한선과 같은 원칙).
## 강화석 비용은 아이템 가격과 무관하게 항상 "다음 단계 번호"라 아이템 없이도 계산된다
## (game_state.gd:1260 enhance_cost의 stones = step).
func _simulate_enhance_attempts(trials: int) -> Dictionary:
	var total_attempts := 0.0
	var total_stones := 0.0
	for _t in trials:
		var step := 0
		while step < GameState.MAX_ENHANCE:
			var attempt_step := step + 1  # enhance_cost()의 stones = 다음 단계 번호
			total_stones += attempt_step
			total_attempts += 1
			if randf() < float(GameState.ENHANCE_RATES[step]):
				step += 1
			elif step >= GameState.ENHANCE_RISK_STEP and randf() < GameState.ENHANCE_DESTROY_CHANCE:
				step = 0  # 파괴 - 새 아이템으로 다시 +0부터
			else:
				step = maxi(step - 1, 0)
	return {"attempts": total_attempts / trials, "stones": total_stones / trials}


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
