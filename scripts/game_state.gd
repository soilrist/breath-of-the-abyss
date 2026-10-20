extends Node

## 슬롯 세이브. 슬롯을 여럿 둔다.
const SLOT_COUNT := 3

## 진단용 전용 슬롯 — 실제 세이브 슬롯(0~2)과 안 겹치게.
## `auto_quest_probe.gd`가 10장 진입 시점 GameState(장비·능력치·스킬)를
## 여기 떠 두면 `check_origin_death_cause.gd`가 같은 슬롯을 읽어 "장비 없는
## 가짜 재현"이 아니라 실제 seed=1 플레이 상태로 origin_throne을 재현한다
## (감독 2026-10-20 06:30: 기존 재현은 GameState.level만 넣고 장비·능력치
## 배분이 없어 실제 플레이와 다른 사람이었다).
const CHAPTER10_SNAPSHOT_SLOT := 99

## 물약 소지 상한. `buy()`와 `main.gd`의 자동구매 둘 다 이 상수를 쓴다
## (규칙 ③: 밸런스 숫자는 한 파일에만). 9는 너무 적다는 감독 지적(2026-09-08)
## 으로 30. HUD 숫자 칸은 두 자리까지 확인함(tests/shot_boss8_potion).
const MAX_POTIONS := 30
## (감독 2026-09-10) 지도 이동은 상점에서 파는 이동주문서 1장을 쓴다(퀘스트모드 귀환은 무료).
const SCROLL_ITEM := "이동주문서"
const MAX_SCROLLS := 99

## 마법사 마력 자연 회복: 매초 최대 마력의 이 비율을 기본 회복량(3)에 더한다.
## "법사는 마나 자동회복이 있어야" 감독 요청(2026-09-08).
const MAGE_MANA_REGEN_PCT := 0.02

## 사냥터 중간보스 배율. `main.gd:_spawn_area_enemies()`가 같은 지역 일반 몹
## 등급(TIERS)에 곱해 중간보스를 만든다. MAP_MOB_FX_DESIGN.md 5절은 "최종보스의
## 40~50%"를 제안했으나 실제 구현(커밋 3a9affc, 2026-09-02)은 그 대신 지역
## 등급 대비 배율로 대체됐다 — 문서에는 그 사실만 기록하고 이 값 자체를
## 바꾸지는 않는다(이미 여러 장에서 쓰이고 있는 값이라 바꾸면 밸런스가 흔들림).
const MIDBOSS_HP_MULT := 4.0
const MIDBOSS_DAMAGE_MULT := 1.6
const MIDBOSS_REWARD_MULT := 2.5

## (감독 2026-09-10) 장별 보스 3페이즈 + 특수 패턴. enemy.gd가 _ready()에서
## kind["phases"]/kind["patterns"]로 복사해 쓴다(상태 머신 `_act_boss`).
## - "patterns": 0페이즈 패턴. 각 페이즈 항목의 "patterns"는 그 페이즈의 전체 목록.
##   lunge(덮치기) dash(돌진) aoe(범위 폭발) summon(소환) volley(추적 마탄).
##   모든 보스의 첫 패턴은 lunge(tests/check_enemy_attack_motion ④ 계약).
## - "phases": HP 비율 "hp" 이하로 내려가면 다음 페이즈(1→2, 역방향 없음).
##   인접 페이즈 tint는 유클리드 거리 ≥ 0.5(check_origin_boss_phase 규칙).
## - origin 값은 10장_근원_DESIGN.md 그대로(0.7/0.3, 0.8/0.55, 1.15/1.3).
const BOSS_PHASES := {
	"guardian": {"patterns": ["lunge", "summon"], "summon": "beast", "phases": [
		{"hp": 0.7, "tint": Color(0.55, 1.0, 0.45), "cooldown_mult": 0.85, "speed_mult": 1.1,
			"patterns": ["lunge", "summon", "aoe"]},
		{"hp": 0.3, "tint": Color(1.0, 0.45, 0.25), "cooldown_mult": 0.65, "speed_mult": 1.25,
			"patterns": ["lunge", "aoe", "summon", "aoe"]}]},
	"captain": {"patterns": ["lunge", "dash"], "summon": "knight", "phases": [
		{"hp": 0.7, "tint": Color(0.55, 0.6, 1.0), "cooldown_mult": 0.8, "speed_mult": 1.2,
			"patterns": ["lunge", "dash", "aoe"]},
		{"hp": 0.3, "tint": Color(1.0, 0.3, 0.3), "cooldown_mult": 0.6, "speed_mult": 1.35,
			"patterns": ["lunge", "dash", "aoe", "dash"]}]},
	"frost": {"patterns": ["lunge", "volley"], "summon": "frostbear", "phases": [
		{"hp": 0.7, "tint": Color(0.45, 0.8, 1.0), "cooldown_mult": 0.8, "speed_mult": 1.1,
			"patterns": ["lunge", "volley", "aoe"]},
		{"hp": 0.3, "tint": Color(0.9, 0.4, 0.9), "cooldown_mult": 0.6, "speed_mult": 1.2,
			"patterns": ["lunge", "aoe", "volley", "aoe"]}]},
	"abyss": {"patterns": ["lunge", "summon"], "summon": "eye", "phases": [
		{"hp": 0.7, "tint": Color(0.7, 0.4, 1.0), "cooldown_mult": 0.8, "speed_mult": 1.15,
			"patterns": ["lunge", "summon", "volley"]},
		{"hp": 0.3, "tint": Color(1.0, 0.3, 0.4), "cooldown_mult": 0.55, "speed_mult": 1.3,
			"patterns": ["lunge", "dash", "volley", "summon"]}]},
	"primordial": {"patterns": ["lunge", "volley"], "summon": "wraith_soldier", "phases": [
		{"hp": 0.7, "tint": Color(0.3, 0.9, 0.9), "cooldown_mult": 0.8, "speed_mult": 1.15,
			"patterns": ["lunge", "volley", "aoe"]},
		{"hp": 0.3, "tint": Color(1.0, 0.35, 0.35), "cooldown_mult": 0.55, "speed_mult": 1.3,
			"patterns": ["lunge", "volley", "summon", "aoe"]}]},
	"reef_warden": {"patterns": ["lunge", "dash"], "summon": "tideclaw", "phases": [
		{"hp": 0.7, "tint": Color(0.85, 0.95, 0.55), "cooldown_mult": 0.8, "speed_mult": 1.15,
			"patterns": ["lunge", "dash", "summon"]},
		{"hp": 0.3, "tint": Color(0.3, 0.35, 1.0), "cooldown_mult": 0.6, "speed_mult": 1.3,
			"patterns": ["lunge", "dash", "aoe", "summon"]}]},
	"faded_prelate": {"patterns": ["lunge", "aoe"], "summon": "faded_acolyte", "phases": [
		{"hp": 0.7, "tint": Color(0.6, 0.7, 1.0), "cooldown_mult": 0.8, "speed_mult": 1.1,
			"patterns": ["lunge", "aoe", "volley"]},
		{"hp": 0.3, "tint": Color(1.0, 0.35, 0.55), "cooldown_mult": 0.6, "speed_mult": 1.2,
			"patterns": ["lunge", "volley", "summon", "aoe"]}]},
	"warden_overseer": {"patterns": ["lunge", "dash"], "summon": "grey_sentinel", "phases": [
		{"hp": 0.7, "tint": Color(0.95, 0.95, 1.0), "cooldown_mult": 0.75, "speed_mult": 1.2,
			"patterns": ["lunge", "dash", "aoe"]},
		{"hp": 0.3, "tint": Color(0.35, 0.1, 0.15), "cooldown_mult": 0.55, "speed_mult": 1.4,
			"patterns": ["lunge", "dash", "volley", "aoe"]}]},
	"reverted_one": {"patterns": ["lunge", "volley"], "summon": "twisted_knight", "phases": [
		{"hp": 0.7, "tint": Color(0.3, 0.9, 0.7), "cooldown_mult": 0.8, "speed_mult": 1.15,
			"patterns": ["lunge", "volley", "dash"]},
		{"hp": 0.3, "tint": Color(1.0, 0.55, 0.2), "cooldown_mult": 0.55, "speed_mult": 1.3,
			"patterns": ["lunge", "dash", "summon", "volley"]}]},
	"origin": {"patterns": ["lunge", "volley"], "summon": "paradox_caster", "phases": [
		{"hp": 0.7, "tint": Color(0.95, 0.25, 0.35), "cooldown_mult": 0.8, "speed_mult": 1.15,
			"patterns": ["lunge", "volley", "dash"]},
		{"hp": 0.3, "tint": Color(0.55, 0.0, 0.05), "cooldown_mult": 0.55, "speed_mult": 1.3,
			"patterns": ["lunge", "dash", "aoe", "volley", "summon"]}]},
}
## 보스 특수 패턴 수치(가배치). 돌진 속도는 px/s 절대값(보스 기본 25px/s가
## 느려 배율로는 덮치는 맛이 안 남). 소환수는 보스 HP·공격력 비율로 만든다.
const BOSS_SPECIAL_COOLDOWN := 4.0
const BOSS_DASH_WINDUP := 0.5
const BOSS_DASH_TIME := 0.6
const BOSS_DASH_SPEED := 130.0
const BOSS_DASH_DAMAGE_MULT := 1.3
const BOSS_AOE_WINDUP := 0.7
const BOSS_AOE_RADIUS := 56.0
const BOSS_AOE_DAMAGE_MULT := 1.5
const BOSS_SUMMON_CAST := 0.5
const BOSS_SUMMON_COUNT := 2
const BOSS_SUMMON_CAP := 4
const BOSS_SUMMON_HP_RATIO := 0.04
const BOSS_SUMMON_DAMAGE_RATIO := 0.4
## (결함 수정, 2026-10-20 INBOX 00:11 ②) 0.45초는 INBOX "큰 공격엔 0.5초 이상
## 전조" 기준에 못 미쳤다 - 0.5초로 올림(근거: enemy.gd SWING_BOSS 주석과 같은 바퀴).
const BOSS_VOLLEY_CAST := 0.5
const BOSS_VOLLEY_COUNT := 3
const BOSS_VOLLEY_DAMAGE_MULT := 0.6

## AUTOHUNT_DESIGN.md §10.7 후퇴 — 가배치, 근거(감독 답변 2026-09-06 09:30,
## 장르 관례 위임): 오토사냥 봇류는 보통 HP 30~40%에서 이탈하고 동시 감당
## 가능 몹 수는 실측 2~3마리였다(hill_ridge 11마리 조우에서 health 69→5
## 급락). 안전 쪽으로 HP 40%, 몹 4마리부터 후퇴.
const AUTOHUNT_RETREAT_ENEMIES := 4
const AUTOHUNT_RETREAT_HP_RATIO := 0.4
## 같은 지역에서 이만큼 연속 후퇴하면 그 지역을 포기하고 홈 마을로 돌아가
## 한 티어 아래 지역(그 지역의 "w" 방향 이전 지역)에서 사냥을 재개한다.
const AUTOHUNT_RETREAT_GIVEUP_STREAK := 3

## AUTOHUNT_DESIGN.md §10.7(INBOX 10:05 ①): quest_stage 번호 → 분류.
## `main.gd:_quest_stage_text()`의 문구 문자열을 `contains("가자")` 같은
## 텍스트 매칭으로 흉내 내지 않고, 이 표로 구조적으로 분류한다.
## DIALOGUE=마을에서 촌장과 대화할 단계, HUNT=사냥터에서 처치·통과할 단계,
## RETURN=보스를 잡고 M키로 마을에 돌아가야 하는 단계.
const QUEST_STAGE_KIND := {
	0: "DIALOGUE", 1: "HUNT", 2: "RETURN", 3: "DIALOGUE",
	4: "HUNT", 5: "RETURN", 6: "HUNT", 7: "RETURN",
	8: "HUNT", 9: "RETURN", 10: "DIALOGUE",
	11: "HUNT", 19: "RETURN", 20: "DIALOGUE",
	21: "HUNT", 29: "RETURN", 30: "DIALOGUE",
	31: "HUNT", 39: "RETURN", 40: "DIALOGUE",
	41: "HUNT", 49: "RETURN", 50: "DIALOGUE",
	51: "HUNT", 59: "RETURN", 60: "DIALOGUE",
	61: "HUNT", 69: "RETURN",
}

## HUNT 단계의 처치 목표 - `_quest_stage_text()`가 쓰는 것과 같은 숫자를
## 여기서도 조회해 두 곳에 같은 값이 따로 적히지 않게 한다(규칙 ③).
## 8은 목표 카운터 없이 진입 즉시 통과하는 단계라 표에 없다.
const QUEST_HUNT_TARGETS := {
	1: {"field": "kills", "target": 6},
	4: {"field": "chapter_kills", "target": 10},
	6: {"field": "chapter_kills", "target": 12},
	11: {"field": "chapter_kills", "target": 12},
	21: {"field": "chapter_kills", "target": 12},
	31: {"field": "chapter_kills", "target": 12},
	41: {"field": "chapter_kills", "target": 12},
	51: {"field": "chapter_kills", "target": 12},
	61: {"field": "chapter_kills", "target": 12},
}

var slot := 0


func save_path(index := -1) -> String:
	return "user://save%d.json" % (index if index >= 0 else slot)

var level := 1
var exp := 0
var next_exp := 80
var gold := 0
var kills := 0
var potions := 2
var scrolls := 0
## 부활의 깃털 개수. 죽었을 때 쓸지 물어본다. 없으면 마을로 돌아가고 EXP를 잃는다.
var revive_potions := 0
var inventory: Array[String] = []
## inventory 와 1:1로 맞물리는 고유 번호. 강화·소켓 상태를 이름이 아니라
## 이 번호로 구분한다 - 이름만 쓰면 같은 이름 여분 장비끼리 강화 수치가
## 섞인다(실제 버그였다). 0은 "번호 없음"이고 실제 아이템엔 절대 안 붙는다.
var item_uid: Array[int] = []
var _uid_seq := 0
## 최초 기본 장비. 벗었을 때 돌아갈 자리다. 주의: 아래 weapon/armor
## 변수는 이름과 달리 "지금 착용 중인 무기/갑옷"의 실시간 미러라서
## (_recalc_bonuses가 매번 덮어씀) 기본값이 필요하면 반드시 이 두 상수를
## 써야 한다 - 변수를 잘못 참조하면 "벗기"가 자기 자신을 도로 끼우는
## 순환 버그가 난다(실제로 한 번 그랬다).
const DEFAULT_WEAPON := "낡은 검"
const DEFAULT_ARMOR := "여행자 옷"
var weapon := DEFAULT_WEAPON
var armor := DEFAULT_ARMOR
var attack_bonus := 0
var defense_bonus := 0
var health_bonus := 0
var speed_bonus := 0
var quest_stage := 0
var chapter := 1
var boss_defeated := false
var current_map := "village"
var chapter_kills := 0
var dash_unlocked := true
var pending_load := false
var game_cleared := false
var unlocked_maps: Array[String] = ["village"]
## 직업. ""면 아직 전직 안 함(공용 스킬 4개 사용). JOB_DESIGN.md 참고.
var job := ""
## 2차 전직 최종 클래스. ""면 아직 2차 전직 전이다.
var second_job := ""

## 능력치 투자. 레벨을 올릴 때마다 점수를 받아 원하는 곳에 넣는다.
const STAT_KEYS := ["strength", "agility", "vitality", "will"]
const STAT_NAMES := {
	"strength": "힘", "agility": "민첩", "vitality": "건강", "will": "의지",
}
const STAT_EFFECTS := {
	"strength": "공격력 +2, 치명타 피해 +2%", "agility": "이동 속도 +1, 치명타 확률 +1.5%",
	"vitality": "최대 HP +8", "will": "최대 마력 +4",
}
## 장별 보스 키. 대사와 스프라이트가 같은 키를 쓴다.
const BOSS_KEYS := {1: "guardian", 2: "captain", 3: "frost", 4: "abyss", 5: "primordial", 6: "reef_warden", 7: "faded_prelate", 8: "warden_overseer", 9: "reverted_one", 10: "origin"}

const POINTS_PER_LEVEL := 3

## 패시브 특성. 레벨을 올릴 때마다 셋 중 하나를 고른다.
## 패시브 스킬 목록.
const PERKS := {
	"vigor": {"name": "강인함", "desc": "최대 HP +25", "hp": 25},
	"edge": {"name": "예리함", "desc": "공격력 +4", "atk": 4},
	"guard": {"name": "굳은 살", "desc": "방어력 +3", "def": 3},
	"swift": {"name": "날램", "desc": "이동 속도 +4", "spd": 4},
	"focus": {"name": "집중", "desc": "치명타 확률 +4%", "crit": 0.04},
	"font": {"name": "마력 순환", "desc": "최대 마력 +15", "mana": 15},
}

## 고른 특성과 각각 몇 번 골랐는지.
var perks := {}
## 아직 고르지 않은 특성 선택 횟수.
var perk_picks := 0
## 이번에 고를 후보 셋.
var perk_offer: Array[String] = []

var stats := {"strength": 0, "agility": 0, "vitality": 0, "will": 0}
var stat_points := 0
var opened_chests: Array[String] = []

## 공용 창고. 마을 어디서든 같은 상자를 연다.
const STORAGE_MAX := 20

## 던전 열쇠. 지역마다 잠긴 문이 있고 그 지역 어딘가에 열쇠가 있다.
## 그냥 지나가기만 하던 던전에 찾을 거리를 만든다.
var keys: Array[String] = []
var opened_doors: Array[String] = []

## 대화에서 고른 답들. 나중 대사와 보상이 이것을 본다.
var choices: Array[String] = []


func chose(key: String) -> bool:
	return choices.has(key)


func remember_choice(key: String) -> void:
	if key != "" and not choices.has(key):
		choices.append(key)


func has_key(id: String) -> bool:
	return keys.has(id)


func take_key(id: String) -> void:
	if not keys.has(id):
		keys.append(id)


## 문을 연다. 열쇠를 쓰면 사라진다.
func open_door(id: String) -> bool:
	if opened_doors.has(id):
		return true
	if not keys.has(id):
		return false
	keys.erase(id)
	opened_doors.append(id)
	return true
var storage: Array[String] = []
var storage_uid: Array[int] = []

## 장비 강화. 한국 MMORPG식으로 확률제다 - 단계가 오를수록 성공률이 떨어지고,
## +6부터는 실패하면 파괴될 수도 있다. 그 아래는 실패해도 한 단계 하락만.
## 파괴 방지 부적을 갖고 있으면 그 시도에서만 파괴 대신 하락으로 막아 준다.
const MATERIAL := "강화석"
const MAX_ENHANCE := 10
const ENHANCE_STEP := 0.25  # 한 단계마다 원래 능력치의 25%씩 더한다
## 단계별(현재 단계 -> 다음 단계) 성공률. 인덱스 0 = +0에서 +1 시도.
const ENHANCE_RATES := [1.0, 0.95, 0.90, 0.80, 0.65, 0.50, 0.40, 0.32, 0.24, 0.16]
## 이 단계(현재 +5 이상, 즉 +6을 시도)부터 실패하면 파괴 위험이 섞인다.
const ENHANCE_RISK_STEP := 5
const ENHANCE_DESTROY_CHANCE := 0.12
const ENHANCE_WARD := "파괴 방지 부적"
## 확정 강화. "강화가 너무 어렵다, 확률 강화 말고 강화석을 더 내면 무조건
## 되는 방법도 있어야겠다"는 사용자 요청으로 추가했다. 실패·파괴가 아예
## 없는 대신 강화석(+골드)을 몬테카를로 기대 소모량보다는 훨씬 싸게,
## 확률 강화 정가보다는 확실히 비싸게 받는다 - 안전 구간은 4배,
## 위험 구간(+6 이상)은 실패하면 처음부터 다시 해야 하는 확률 강화의
## 기대 비용이 급증하는 것을 반영해 추가로 3배(합 12배) 받는다.
const ENHANCE_GUARANTEED_MULT := 4
const ENHANCE_GUARANTEED_RISK_MULT := 3

## 보스가 확정으로 떨어뜨리는 재료. 강화석과 달리 몬스터는 안 주고
## 보스만 준다. 여러 개 모아 전설 장비를 제작하는 데 쓴다. 개수는
## 확정이 아니라 매번 이 구간에서 무작위로 나와 모으기가 까다롭다.
const BOSS_FRAGMENT := "보스의 파편"
const BOSS_FRAGMENT_CAP := 999
const BOSS_FRAGMENT_MIN := 10
const BOSS_FRAGMENT_MAX := 30
## 5~10장 잡몹·보스가 떨어뜨리는 장별 제작 재료 "정수". 장 -> 이름.
## CHAPTER_CRAFT_RECIPES 가 이걸로 그 장 세트 장비를 만든다.
const CHAPTER_ESSENCES := {5: "태초의 정수", 6: "심해의 정수", 7: "성광의 정수",
	8: "침묵의 정수", 9: "역행의 정수", 10: "근원의 정수"}
const ESSENCE_CAP := 999
const ESSENCE_DROP_RATE := 0.08
const ESSENCE_BOSS_MIN := 4
const ESSENCE_BOSS_MAX := 8

## 전직의 돌. 2차 전직 재료(3타입: 전사/마법사/도적 계열). 사냥터 중간보스만 떨어뜨린다.
## SECOND_JOB_DESIGN.md 5절 참고.
const JOB_STONE_WARRIOR := "전직의 돌(전사)"
const JOB_STONE_MAGE := "전직의 돌(마법사)"
const JOB_STONE_ROGUE := "전직의 돌(도적)"
const JOB_STONES := [JOB_STONE_WARRIOR, JOB_STONE_MAGE, JOB_STONE_ROGUE]
const JOB_STONE_CAP := 100000  # (감독 2026-09-08) 999 → 100000

var materials := {MATERIAL: 0, BOSS_FRAGMENT: 0,
	JOB_STONE_WARRIOR: 0, JOB_STONE_MAGE: 0, JOB_STONE_ROGUE: 0,
	"태초의 정수": 0, "심해의 정수": 0, "성광의 정수": 0, "침묵의 정수": 0, "역행의 정수": 0, "근원의 정수": 0}
var enhance_levels := {}
## 파괴 방지 부적 개수. 위험 구간에서 실패해도 이걸 하나 쓰면 하락으로 막는다.
var enhance_wards := 0

## 드랍 랜덤 옵션(감독 2026-09-08). "아이템이 다 똑같고 지루하다" 피드백.
## 몬스터/보스가 떨어뜨린 장비에만 uid별로 추가 능력치가 무작위로 붙는다
## (상점·퀘스트 보상·제작품은 정가 고정품이라 안 붙는다). 강화 배율은 기본
## 능력치에만 걸리고 옵션 값은 그대로 더한다. 옵션 1줄이면 능력치 이름
## 접두어(예리한 철검), 2줄 "정교한", 3줄 "고대의"로 이름만 봐도 티가 난다.
const AFFIX_KEYS := ["atk", "def", "hp", "spd"]
const AFFIX_PREFIX := {"atk": "예리한", "def": "단단한", "hp": "굳센", "spd": "날쌘", 2: "정교한", 3: "고대의"}
const AFFIX_LABEL := {"atk": "공격", "def": "방어", "hp": "HP", "spd": "속도"}
## 값 = 장비 레벨 × 이 범위의 난수. HP는 자릿수가 커서 크게, 속도는 작게.
const AFFIX_RANGE := {"atk": [0.5, 1.5], "def": [0.4, 1.2], "hp": [2.0, 6.0], "spd": [0.2, 0.5]}
const AFFIX_CHANCE_MOB := 0.45
var affixes := {}  # uid -> {"atk": n, ...}

## 의뢰. 종류를 나눈다.
##   hunt    특정 몬스터를 N마리 잡는다
##   gather  잡몹이 떨어뜨리는 재료를 N개 모은다
##   deliver 지정한 지역의 사람에게 물건을 전한다
##   explore 지정한 지역에 가 본다
const BOUNTIES := [
	{"id": "b1", "type": "hunt", "label": "독버섯 4마리", "kind": "mushroom", "count": 4,
		"gold": 60, "item": "가죽 모자", "desc": "안개숲의 독버섯을 솎아 주게."},
	{"id": "b2", "type": "explore", "label": "바람 언덕 정찰", "area": "hill", "count": 1,
		"gold": 90, "item": "구리 반지", "desc": "북쪽 언덕에 뭐가 있는지 보고 오게."},
	{"id": "b3", "type": "gather", "label": "강화석 5개", "count": 5,
		"gold": 140, "item": "철 투구", "desc": "대장장이가 강화석이 모자라다는군."},
	{"id": "b4", "type": "hunt", "label": "동굴박쥐 5마리", "kind": "bat", "count": 5,
		"gold": 180, "item": "사냥꾼의 활", "desc": "동굴 박쥐가 너무 늘었네."},
	{"id": "b5", "type": "explore", "label": "안개 늪지 답사", "area": "marsh", "count": 1,
		"gold": 220, "item": "수정 목걸이", "desc": "해안 남쪽 늪을 살펴보고 오게."},
	{"id": "b6", "type": "deliver", "label": "야영지에 보급품 전달", "area": "frost_camp", "count": 1,
		"gold": 300, "item": "파수병 투구", "desc": "설원 야영지에 짐을 전해 주게."},
	{"id": "b7", "type": "hunt", "label": "망령 4마리", "kind": "spirit", "count": 4,
		"gold": 380, "item": "정령의 부적", "desc": "폐허의 망령을 걷어내 주게."},
	{"id": "b8", "type": "gather", "label": "강화석 12개", "count": 12,
		"gold": 460, "item": "설원의 망토", "desc": "대장간에 다시 재료가 떨어졌네."},
	{"id": "b9", "type": "hunt", "label": "화염정령 5마리", "kind": "flam", "count": 5,
		"gold": 600, "item": "서리왕관", "desc": "잿불이 번지기 전에 막아 주게."},
	# 사냥터가 생기면서 늘어난 의뢰. 기존 의뢰 순서를 바꾸면 진행 중이던
	# 저장 파일의 bounty_index 가 엉뚱한 의뢰를 가리키게 되어 뒤에 붙인다.
	{"id": "b10", "type": "hunt", "label": "바람 능선 들짐승 6마리", "kind": "beast", "count": 6,
		"gold": 100, "item": "철검", "desc": "능선에 들짐승이 늘었다는군."},
	{"id": "b11", "type": "hunt", "label": "깊은 늪 갓파 6마리", "kind": "kappa", "count": 6,
		"gold": 260, "item": "사슬 갑옷", "desc": "깊은 늪 갓파가 배를 위협한다는군."},
	{"id": "b12", "type": "hunt", "label": "얼어붙은 능선 판다 6마리", "kind": "panda", "count": 6,
		"gold": 340, "item": "질풍의 활", "desc": "능선 판다가 야영지 근처까지 내려온다는군."},
	{"id": "b13", "type": "hunt", "label": "잿불 협곡 키클롭스 6마리", "kind": "cyclope", "count": 6,
		"gold": 500, "item": "영혼 사수의 활", "desc": "협곡의 키클롭스가 마지막 골칫거리라는군."},
]

var bounty_index := 0
var bounty_progress := 0
var bounty_taken := false



## 재료를 주울 때마다 부른다.
func record_material() -> void:
	var bounty := current_bounty()
	if not bounty_taken or bounty.is_empty():
		return
	if str(bounty.get("type", "hunt")) != "gather":
		return
	bounty_progress = mini(materials[MATERIAL], int(bounty["count"]))


## 지역에 들어설 때마다 부른다. 답사·전달 의뢰가 여기서 끝난다.
func record_visit(area: String) -> void:
	var bounty := current_bounty()
	if not bounty_taken or bounty.is_empty():
		return
	var kind := str(bounty.get("type", "hunt"))
	if kind != "explore" and kind != "deliver":
		return
	if str(bounty.get("area", "")) == area:
		bounty_progress = int(bounty["count"])


## 진행도 표시용. 종류마다 세는 게 다르다.
func bounty_progress_text() -> String:
	var bounty := current_bounty()
	if not bounty_taken or bounty.is_empty():
		return ""
	if bounty_done():
		return "[의뢰 완료! 마을로]"
	var have: int = materials[MATERIAL] if str(bounty.get("type", "hunt")) == "gather" else bounty_progress
	return "[의뢰 %s %d/%d]" % [bounty["label"], have, int(bounty["count"])]


func reset() -> void:
	level = 1
	exp = 0
	next_exp = 80
	gold = 0
	kills = 0
	potions = 2
	scrolls = 0
	revive_potions = 0
	inventory = []
	item_uid = []
	_uid_seq = 0
	weapon = "낡은 검"
	armor = "여행자 옷"
	attack_bonus = 0
	defense_bonus = 0
	health_bonus = 0
	speed_bonus = 0
	equipped = {"weapon": "낡은 검", "armor": "여행자 옷", "helmet": "", "trinket": "", "trinket2": "", "spirit": ""}
	equipped_uid = {"weapon": 0, "armor": 0, "helmet": 0, "trinket": 0, "trinket2": 0, "spirit": 0}
	quest_stage = 0
	chapter = 1
	boss_defeated = false
	current_map = "village"
	chapter_kills = 0
	dash_unlocked = true
	game_cleared = false
	unlocked_maps = ["village"]
	job = ""
	opened_chests = []
	storage = []
	storage_uid = []
	keys = []
	opened_doors = []
	choices = []
	materials = {MATERIAL: 0, BOSS_FRAGMENT: 0,
		JOB_STONE_WARRIOR: 0, JOB_STONE_MAGE: 0, JOB_STONE_ROGUE: 0,
		"태초의 정수": 0, "심해의 정수": 0, "성광의 정수": 0, "침묵의 정수": 0, "역행의 정수": 0, "근원의 정수": 0}
	enhance_levels = {}
	enhance_wards = 0
	stone_inventory = {}
	socketed = {}
	affixes = {}
	tower_progress = {"easy": 0, "normal": 0, "hard": 0, "hell": 0, "abyss": 0}
	tower_material_counts = {"easy": 0, "normal": 0, "hard": 0, "hell": 0, "abyss": 0}
	tower_titles = []
	claimed_level_milestones = []
	level_titles = []
	potion_cap_bonus = 0
	claimed_boss_rewards = []
	tower_active = false
	tower_floor = 0
	tower_difficulty = "easy"
	bounty_index = 0
	bounty_progress = 0
	bounty_taken = false
	stats = {"strength": 0, "agility": 0, "vitality": 0, "will": 0}
	stat_points = 0
	perks = {}
	perk_picks = 0
	perk_offer = []
	pending_load = false


## 다음 레벨 필요 경험치. EXP_SOFT_LEVEL까지는 레벨마다 EXP_GROWTH배(예전
## 곡선 그대로), 그 뒤는 EXP_GROWTH_LATE배만 오른다.
## (감독 2026-09-08) 예전엔 끝까지 1.30배라 L43 필요치가 488만(13티어 몹 275
## 기준 1만 8천 마리)이었다 - 사실상 안 오르는 구간. 20 이후 완만하게:
## L40 3.7만·L43 4.5만·L60 12만.
const EXP_GROWTH := 1.30
const EXP_SOFT_LEVEL := 20
const EXP_GROWTH_LATE := 1.06

static func exp_for_level(lv: int) -> int:
	var need := 80.0 * pow(EXP_GROWTH, mini(lv, EXP_SOFT_LEVEL) - 1)
	need *= pow(EXP_GROWTH_LATE, maxi(lv - EXP_SOFT_LEVEL, 0))
	return int(need)


func add_reward(exp_reward: int, gold_reward: int) -> bool:
	exp += exp_reward
	gold += gold_reward
	kills += 1
	chapter_kills += 1
	# 예전 곡선(끝까지 1.30배)으로 저장된 next_exp를 새 곡선으로 끌어내린다.
	next_exp = mini(next_exp, exp_for_level(level))
	var leveled := false
	while exp >= next_exp:
		exp -= next_exp
		level += 1
		next_exp = exp_for_level(level)
		stat_points += POINTS_PER_LEVEL
		perk_picks += 1
		leveled = true
	return leveled


## 레벨 단계별 보상(INBOX 2026-10-20 00:10). 5레벨마다 장비+골드+강화석,
## 10레벨마다 칭호(add_tower_title 패턴)+물약 상한 증가. 숫자 근거는
## DESIGN.md "밸런스 숫자 위치" 절.
const LEVEL_BOX_STEP := 5
const LEVEL_TITLE_STEP := 10
## 10레벨마다 붙는 칭호 이름. 그 뒤(60 초과)는 "Lv%d 전당"으로 생성한다 -
## 10장 클리어 평균 레벨(탑 제외)이 60 안쪽이라 이 표만 손으로 적었다.
const LEVEL_TITLES := {
	10: "숙련자", 20: "노련한 모험가", 30: "용맹한 전사",
	40: "전설의 용사", 50: "심연의 수호자", 60: "초월자",
}
## 받은 5단위 레벨(claimed). 중복 지급 0 보장용.
var claimed_level_milestones: Array[int] = []
## 10단위 레벨에서 받은 칭호. tower_titles와 같은 "있으면 또 안 넣는다" 패턴.
var level_titles: Array[String] = []
## 10레벨마다 +10(큰 보상 중 "물약 상한" 선택지). MAX_POTIONS는 상수라 직접
## 못 늘리니 potion_cap()을 거쳐서만 쓴다.
var potion_cap_bonus := 0
## 즉시 보상(골드·강화석·장비)을 받은 장 번호(claimed). 보스방은 재입장마다
## 다시 스폰돼(main.gd:1000~1002) 몇 번이고 처치할 수 있는데, 이 목록이 없으면
## 매번 보상이 또 나가고 quest_stage 도 되감긴다(결함 2026-10-20 19:50).
var claimed_boss_rewards: Array[int] = []


func potion_cap() -> int:
	return MAX_POTIONS + potion_cap_bonus


## new_level까지 아직 못 받은 5단위 마일스톤을 전부 지급하고, 지급한 보상을
## 순서대로 돌려준다. 옛 세이브 소급(claimed_level_milestones가 비어 있던
## 시절의 세이브)도 load_game() 뒤 한 번 불러 같은 경로로 해결한다 - 이미
## claimed인 단계는 건너뛰므로 다시 불러도 중복 지급 0.
func claim_level_milestones(new_level: int) -> Array:
	var rewards: Array = []
	var m := LEVEL_BOX_STEP
	while m <= new_level:
		if not claimed_level_milestones.has(m):
			rewards.append(_grant_level_milestone(m))
		m += LEVEL_BOX_STEP
	return rewards


## 그 레벨대(±6) 레어 이상 장비 1개 + 골드(40×레벨) + 강화석(2+레벨/5).
## 10의 배수면 칭호 + 물약 상한 +10 도 함께. 장비가 보스급 확정 옵션으로
## 붙게 add_dropped_item(boss=true)로 지급한다("레어 이상 확정"이라 잡몹
## 45% 확률보다 세게).
func _grant_level_milestone(m: int) -> Dictionary:
	claimed_level_milestones.append(m)
	var gold_reward := 40 * m
	var stone_reward := 2 + m / LEVEL_BOX_STEP
	var item := _roll_level_reward_item(m)
	gold += gold_reward
	add_material(stone_reward)
	if item != "":
		add_dropped_item(item, true)
	var reward := {"level": m, "gold": gold_reward, "stones": stone_reward, "item": item,
		"title": "", "big_reward": ""}
	if m % LEVEL_TITLE_STEP == 0:
		var title := str(LEVEL_TITLES.get(m, "Lv%d 전당" % m))
		if not level_titles.has(title):
			level_titles.append(title)
		potion_cap_bonus += 10
		reward["title"] = title
		reward["big_reward"] = "물약 상한 +10"
	return reward


## 장 보스 격파 즉시 보상(INBOX 2026-10-20 23:42). 보스의 파편·정수(제작
## 재료)와는 별개로, 레벨 보상 상자와 같은 체감 보상(골드·강화석·장비 1개)을
## 그 자리에서 준다. 골드·강화석은 레벨 보상 상자 공식(40×lv, 2+lv/5)을
## 장 번호에 맞춰 올린 값(근거: 보스가 레벨 보상보다 드물게 오니 한 번에
## 더 크게) - DESIGN.md §6. 장비 레벨대는 그 장에서 흔히 입는 장비 수준으로
## 가정(🟡, 정확한 평균 캐릭터 레벨 측정 없음 - DESIGN §6).
const BOSS_REWARD_GEAR_LEVEL := {
	1: 5, 2: 10, 3: 15, 4: 20, 5: 26, 6: 30, 7: 34, 8: 38, 9: 42, 10: 46,
}


func boss_instant_reward(ch: int) -> Dictionary:
	var gold_reward: int = 150 * ch
	var stone_reward: int = 4 + ch * 2
	var lvl: int = int(BOSS_REWARD_GEAR_LEVEL.get(ch, 5 * ch))
	var item := _roll_level_reward_item(lvl)
	gold += gold_reward
	add_material(stone_reward)
	if item != "":
		add_dropped_item(item, true)
	return {"gold": gold_reward, "stones": stone_reward, "item": item}


func _roll_level_reward_item(m: int) -> String:
	var min_rarity := RARITY_ORDER.find("레어")
	var candidates: Array = []
	for item_name in EQUIPMENT:
		var lv := int(EQUIPMENT[item_name].get("level", 1))
		if rarity_rank(item_name) >= min_rarity and lv <= m and lv >= maxi(1, m - 6):
			candidates.append(item_name)
	if candidates.is_empty():
		for item_name in EQUIPMENT:
			if int(EQUIPMENT[item_name].get("level", 1)) <= m:
				candidates.append(item_name)
	return str(candidates[randi() % candidates.size()]) if not candidates.is_empty() else ""


## 다음 5단위 보상까지 남은 레벨. 레벨업 카드 맨 아래 "다음 보상: LvN (k 남음)"에 쓴다.
func next_level_milestone(cur_level: int) -> int:
	return (cur_level / LEVEL_BOX_STEP + 1) * LEVEL_BOX_STEP


## 액티브 스킬. 레벨로 열리고 1~4 키로 쓴다.
## damage 는 공격력 배수, radius 는 닿는 거리, heal 은 회복량이다.
## 직업을 고르지 않은 기본 상태(job == "")에서 쓰는 공용 스킬 4개.
const SKILLS := [
	{"id": "slash", "name": "참격", "icon": "res://assets/icons/skills/slash.png",
		"level": 1, "cost": 18, "cooldown": 2.2, "damage": 2.0, "radius": 48.0, "heal": 0,
		"desc": "앞쪽 넓게 두 배 피해"},
	{"id": "burst", "name": "충격파", "icon": "res://assets/icons/skills/burst.png",
		"level": 4, "cost": 26, "cooldown": 4.0, "damage": 1.6, "radius": 78.0, "heal": 0,
		"desc": "주위 전체에 피해"},
	{"id": "flame", "name": "화염구", "icon": "res://assets/icons/skills/flame.png",
		"level": 8, "cost": 34, "cooldown": 6.0, "damage": 3.4, "radius": 62.0, "heal": 0,
		"desc": "강한 화염 피해"},
	{"id": "heal", "name": "치유", "icon": "res://assets/icons/skills/heal.png",
		"level": 6, "cost": 30, "cooldown": 9.0, "damage": 0.0, "radius": 0.0, "heal": 70,
		"desc": "HP를 크게 회복"},
]

## 직업 이름표. 전직 UI와 캐릭터 화면에서 쓴다.
const JOB_NAMES := {"warrior": "전사", "mage": "마법사", "rogue": "도적"}

## 레벨 15부터 전직할 수 있다. JOB_DESIGN.md 4절 참고.
const JOB_UNLOCK_LEVEL := 15

## 직업별 스킬 4개. 필드는 공용 스킬과 같되, 추가 효과 키가 붙는다.
## - stun: 맞은 적을 그만큼(초) 기절시킨다.
## - slow: {"pct": 0.5, "duration": 2.0} 맞은 적 이동속도를 그만큼 늦춘다.
## - buff: {"stat": "atk_mult"|"speed_mult", "value": 0.3, "duration": 5.0} 자신에게 건다.
## - invuln: 그만큼(초) 무적이 된다.
## - heal_pct: 최대 체력 비율만큼 즉시 회복한다.
## - stealth_crit: true면 이 스킬을 쓴 뒤 다음 평타/스킬이 확정 치명타.
## - single_target: true면 범위 안 최근접 적 하나에게만 맞는다.
## - multi_hit: 정수면 그 횟수만큼 즉시피해를 반복 적용한다(기본 1).
## - projectile: true면 arrow.tscn 투사체로 날아간다(맞으면 즉시피해).
const SKILLS_BY_JOB := {
	"warrior": [
		{"id": "strike", "name": "강타", "icon": "res://assets/icons/skills/strike.svg",
			"level": 1, "cost": 20, "cooldown": 2.5, "damage": 2.4, "radius": 50.0, "heal": 0,
			"desc": "전방 넓게 강한 일격"},
		{"id": "shield_charge", "name": "방패 돌진", "icon": "res://assets/icons/skills/shield_charge.svg",
			"level": 4, "cost": 24, "cooldown": 6.0, "damage": 1.2, "radius": 40.0, "heal": 0,
			"dash": 60.0, "stun": 0.4,
			"desc": "전방 돌진, 부딪힌 적 기절"},
		{"id": "warcry", "name": "전투 함성", "icon": "res://assets/icons/skills/warcry.svg",
			"level": 8, "cost": 28, "cooldown": 12.0, "damage": 0.0, "radius": 0.0, "heal": 0,
			"buff": {"stat": "atk_mult", "value": 0.3, "duration": 5.0},
			"desc": "5초간 공격력 +30%"},
		{"id": "undying", "name": "불굴", "icon": "res://assets/icons/skills/undying.svg",
			"level": 6, "cost": 34, "cooldown": 15.0, "damage": 0.0, "radius": 0.0, "heal": 0,
			"invuln": 3.0, "heal_pct": 0.15,
			"desc": "3초 무적 + HP 15% 회복"},
	],
	"mage": [
		{"id": "flame", "name": "화염구", "icon": "res://assets/icons/skills/flame.png",
			"level": 1, "cost": 22, "cooldown": 3.0, "damage": 3.4, "radius": 62.0, "heal": 0,
			"desc": "강한 화염 피해"},
		{"id": "ice_spear", "name": "얼음창", "icon": "res://assets/icons/skills/ice_spear.svg",
			"level": 4, "cost": 26, "cooldown": 5.0, "damage": 3.0, "radius": 90.0, "heal": 0,
			"single_target": true, "slow": {"pct": 0.5, "duration": 2.0},
			"desc": "단일 대상 강타 + 이동속도 감소"},
		{"id": "mana_burst", "name": "마나 폭발", "icon": "res://assets/icons/skills/mana_burst.svg",
			"level": 8, "cost": 36, "cooldown": 8.0, "damage": 1.8, "radius": 90.0, "heal": 0,
			"desc": "주위 전체에 강한 피해"},
		{"id": "heal", "name": "마나 순환", "icon": "res://assets/icons/skills/heal.png",
			"level": 6, "cost": 0, "cooldown": 9.0, "damage": 0.0, "radius": 0.0, "heal": 0,
			"hp_cost_pct": 0.2, "mana_restore_pct": 0.35,
			"desc": "HP 20% 소모, 마력 35% 회복"},
	],
	"rogue": [
		{"id": "double_strike", "name": "연속베기", "icon": "res://assets/icons/skills/double_strike.svg",
			"level": 1, "cost": 18, "cooldown": 2.0, "damage": 1.1, "radius": 44.0, "heal": 0,
			"multi_hit": 2,
			"desc": "전방 2연타"},
		{"id": "shuriken", "name": "표창 던지기", "icon": "res://assets/icons/skills/shuriken.svg",
			"level": 4, "cost": 16, "cooldown": 2.5, "damage": 1.6, "radius": 0.0, "heal": 0,
			"projectile": true,
			"desc": "원거리 단일 표창"},
		{"id": "stealth", "name": "은신", "icon": "res://assets/icons/skills/stealth.svg",
			"level": 8, "cost": 30, "cooldown": 14.0, "damage": 0.0, "radius": 0.0, "heal": 0,
			"invuln": 3.0, "stealth_crit": true,
			"desc": "3초 무적, 종료 후 다음 공격 확정 치명타"},
		{"id": "swift_step", "name": "회피 강화", "icon": "res://assets/icons/skills/swift_step.svg",
			"level": 6, "cost": 20, "cooldown": 10.0, "damage": 0.0, "radius": 0.0, "heal": 0,
			"buff": {"stat": "speed_mult", "value": 0.4, "duration": 5.0},
			"desc": "5초간 이동 속도 +40%"},
	],
}


func skill_unlocked(index: int) -> bool:
	var list: Array = active_skills()
	return index >= 0 and index < list.size() and level >= int(list[index]["level"])


## Lv12·20·30 스킬 공백 메우기(INBOX 2026-10-19 23:43). 공용·직업 스킬이
## Lv1/4/6/8 에 전부 열리고 다음은 2차 전직 Lv40 이라 32레벨 동안 새 버튼이
## 없었다. 5·6번 슬롯(2차 전직 전용)을 Lv12·20 스킬이 먼저 쓰고, 2차 전직
## 때 SKILLS_BY_SECOND_JOB 으로 자연히 교체된다. Lv30 스킬은 새 슬롯 없이
## Lv8 스킬(인덱스 2)을 상위판으로 바꿔 끼운다.
const SKILL_GAP_LV12 := 12
const SKILL_GAP_LV20 := 20
const SKILL_GAP_LV30 := 30

const SKILLS_LV12_BY_JOB := {
	"warrior": {"id": "shield_bash", "name": "방패 밀쳐내기", "icon": "res://assets/icons/skills/shield_bash.svg",
		"level": 12, "cost": 22, "cooldown": 5.0, "damage": 1.2, "radius": 40.0, "heal": 0,
		"dash": 36.0, "stun": 0.5, "desc": "짧게 돌진해 부딪힌 적 기절"},
	"mage": {"id": "frost_wave", "name": "냉기 파동", "icon": "res://assets/icons/skills/frost_wave.svg",
		"level": 12, "cost": 24, "cooldown": 4.5, "damage": 1.6, "radius": 100.0, "heal": 0,
		"slow": {"pct": 0.4, "duration": 2.5}, "desc": "넓게 피해 + 이동속도 감소"},
	"rogue": {"id": "poison_dart", "name": "독침", "icon": "res://assets/icons/skills/poison_dart.svg",
		"level": 12, "cost": 14, "cooldown": 2.2, "damage": 1.4, "radius": 0.0, "heal": 0,
		"projectile": true, "desc": "원거리 단일 독침"},
}

const SKILLS_LV20_BY_JOB := {
	"warrior": {"id": "crush_blow", "name": "분쇄의 일격", "icon": "res://assets/icons/skills/crush_blow.svg",
		"level": 20, "cost": 30, "cooldown": 7.0, "damage": 3.0, "radius": 70.0, "heal": 0,
		"single_target": true, "desc": "단일 대상 강한 일격"},
	"mage": {"id": "mana_shield", "name": "마력 갑주", "icon": "res://assets/icons/skills/mana_shield.svg",
		"level": 20, "cost": 28, "cooldown": 10.0, "damage": 0.0, "radius": 0.0, "heal": 0,
		"buff": {"stat": "damage_reduction", "value": 0.3, "duration": 4.0}, "desc": "4초간 받는 피해 30% 감소"},
	"rogue": {"id": "shadow_slash", "name": "그림자 베기", "icon": "res://assets/icons/skills/shadow_slash.svg",
		"level": 20, "cost": 22, "cooldown": 3.0, "damage": 0.9, "radius": 42.0, "heal": 0,
		"multi_hit": 3, "desc": "전방 3연타"},
}

## 같은 id·아이콘을 그대로 써 _cast_skill_fx() 에 새 분기가 필요 없다 -
## 기존 이펙트를 더 센 숫자로 재생만 한다.
const SKILLS_LV30_UPGRADE_BY_JOB := {
	"warrior": {"id": "warcry", "name": "격노의 외침", "icon": "res://assets/icons/skills/warcry.svg",
		"level": 30, "cost": 32, "cooldown": 12.0, "damage": 0.0, "radius": 0.0, "heal": 0,
		"buff": {"stat": "atk_mult", "value": 0.5, "duration": 5.0}, "desc": "5초간 공격력 +50%"},
	"mage": {"id": "mana_burst", "name": "대마력 폭발", "icon": "res://assets/icons/skills/mana_burst.svg",
		"level": 30, "cost": 40, "cooldown": 7.0, "damage": 2.6, "radius": 110.0, "heal": 0,
		"desc": "주위 전체에 더 강한 피해"},
	"rogue": {"id": "stealth", "name": "심화 은신", "icon": "res://assets/icons/skills/stealth.svg",
		"level": 30, "cost": 34, "cooldown": 12.0, "damage": 0.0, "radius": 0.0, "heal": 0,
		"invuln": 4.5, "stealth_crit": true, "desc": "4.5초 무적, 종료 후 다음 공격 확정 치명타"},
}


## 2차 전직 최종 클래스별 2개 추가 스킬. 기존 1차 스킬 뒤에 붙인다.
## skill 슬롯 5~6을 추가해 기존 1~4 입력과 UI 구조를 유지한다.
const SKILLS_BY_SECOND_JOB := {
	"guardian": [
		{"id": "guardian_ward", "name": "철벽 태세", "icon": "res://assets/icons/skills/guardian_ward.svg", "level": 40, "cost": 42, "cooldown": 14.0, "damage": 0.0, "radius": 0.0, "heal": 0, "buff": {"stat": "damage_reduction", "value": 0.5, "duration": 4.0}, "desc": "4초간 받는 피해 50% 감소"},
		{"id": "guardian_taunt", "name": "도발", "icon": "res://assets/icons/skills/guardian_taunt.svg", "level": 40, "cost": 48, "cooldown": 10.0, "damage": 2.2, "radius": 100.0, "heal": 0, "desc": "주위 적에게 강한 충격파"},
	],
	"berserker": [
		{"id": "berserker_rage", "name": "광기", "icon": "res://assets/icons/skills/berserker_rage.svg", "level": 40, "cost": 40, "cooldown": 14.0, "damage": 0.0, "radius": 0.0, "heal": 0, "buff": {"stat": "atk_mult", "value": 0.8, "duration": 4.0}, "desc": "4초간 공격력 80% 증가"},
		{"id": "berserker_final_strike", "name": "최후의 일격", "icon": "res://assets/icons/skills/berserker_final_strike.svg", "level": 40, "cost": 55, "cooldown": 12.0, "damage": 4.0, "radius": 90.0, "heal": 0, "single_target": true, "low_hp_mult_max": 3.0, "desc": "현재 HP가 낮을수록 강해지는 일격 (최대 3배)"},
	],
	"elementalist": [
		{"id": "elementalist_meteor", "name": "메테오", "icon": "res://assets/icons/skills/elementalist_meteor.svg", "level": 40, "cost": 60, "cooldown": 12.0, "damage": 5.0, "radius": 100000.0, "heal": 0, "desc": "전 지역에 화염 운석이 떨어지는 광역 스킬"},
		{"id": "elementalist_chain_lightning", "name": "연쇄 번개", "icon": "res://assets/icons/skills/elementalist_chain_lightning.svg", "level": 40, "cost": 52, "cooldown": 9.0, "damage": 3.2, "radius": 100000.0, "heal": 0, "chain_count": 6, "desc": "전 지역에 번개가 무작위로 내리꽂히는 광역 스킬"},
	],
	"necromancer": [
		{"id": "necromancer_curse", "name": "저주", "icon": "res://assets/icons/skills/necromancer_curse.svg", "level": 40, "cost": 45, "cooldown": 8.0, "damage": 2.0, "radius": 110.0, "heal": 0, "dot": 3, "dot_duration": 5.0, "desc": "주위 적에게 피해와 지속 저주"},
		{"id": "necromancer_soul_drain", "name": "영혼 흡수", "icon": "res://assets/icons/skills/necromancer_soul_drain.svg", "level": 40, "cost": 50, "cooldown": 10.0, "damage": 3.5, "radius": 100.0, "heal": 0, "heal_pct_on_hit": 0.12, "desc": "피해를 주고 HP와 마력 일부 회복"},
	],
	"assassin": [
		{"id": "assassin_heart_pierce", "name": "심장 관통", "icon": "res://assets/icons/skills/assassin_heart_pierce.svg", "level": 40, "cost": 44, "cooldown": 6.0, "damage": 4.0, "radius": 120.0, "heal": 0, "single_target": true, "desc": "단일 대상에게 치명적인 관통"},
		{"id": "assassin_execute", "name": "처형", "icon": "res://assets/icons/skills/assassin_execute.svg", "level": 40, "cost": 58, "cooldown": 14.0, "damage": 5.5, "radius": 100.0, "heal": 0, "single_target": true, "execute_pct": 0.3, "desc": "HP 30% 이하 적을 즉시 처형"},
	],
	"shadow_dancer": [
		{"id": "shadow_dancer_leap", "name": "그림자 도약", "icon": "res://assets/icons/skills/shadow_dancer_leap.svg", "level": 40, "cost": 42, "cooldown": 7.0, "damage": 2.8, "radius": 60.0, "heal": 0, "dash": 70.0, "desc": "전방으로 순간 이동하며 피해"},
		{"id": "shadow_dancer_clone", "name": "분신술", "icon": "res://assets/icons/skills/shadow_dancer_clone.svg", "level": 40, "cost": 65, "cooldown": 18.0, "damage": 0.0, "radius": 0.0, "heal": 0, "invuln": 1.5, "buff": {"stat": "speed_mult", "value": 0.7, "duration": 3.0}, "desc": "3초간 그림자처럼 빠르게 움직인다"},
	],
}


## 지금 직업의 스킬. 2차 전직이면 기존 1차 스킬 4개 뒤에 전용 2개를 붙인다.
## 2차 전직 전에는 Lv30 에 인덱스 2(Lv8 스킬)가 상위판으로 바뀌고,
## Lv12·20 에 5·6번 슬롯이 채워진다(2차 전직 시 그 두 슬롯은 아래에서
## second_job 분기로 덮여 사라진다).
func active_skills() -> Array:
	var base: Array = (SKILLS_BY_JOB.get(job, SKILLS) as Array).duplicate(true)
	if job != "" and level >= SKILL_GAP_LV30 and SKILLS_LV30_UPGRADE_BY_JOB.has(job):
		base[2] = SKILLS_LV30_UPGRADE_BY_JOB[job]
	if second_job != "":
		return base + SKILLS_BY_SECOND_JOB.get(second_job, [])
	if job != "" and level >= SKILL_GAP_LV12 and SKILLS_LV12_BY_JOB.has(job):
		base.append(SKILLS_LV12_BY_JOB[job])
		if level >= SKILL_GAP_LV20 and SKILLS_LV20_BY_JOB.has(job):
			base.append(SKILLS_LV20_BY_JOB[job])
	return base


func skill_slot_count() -> int:
	return active_skills().size()


func can_change_job() -> bool:
	return level >= JOB_UNLOCK_LEVEL


## 전직 비용. 처음 고를 때는 무료, 이미 직업이 있으면(재전직) 레벨×50골드.
func job_change_cost() -> int:
	return 0 if job == "" else level * 50


## 실패하면 이유를 문구로 돌려주고, 성공하면 빈 문자열을 돌려준다.
func change_job(new_job: String) -> String:
	if not JOB_NAMES.has(new_job):
		return "알 수 없는 직업이다."
	if not can_change_job():
		return "레벨 %d부터 전직할 수 있다." % JOB_UNLOCK_LEVEL
	if new_job == job:
		return "이미 그 직업이다."
	var cost := job_change_cost()
	if gold < cost:
		return "골드가 부족하다. (%d골드 필요)" % cost
	gold -= cost
	job = new_job
	second_job = ""
	return ""


## 2차 전직. SECOND_JOB_DESIGN.md 참고.
## 해금 조건: 레벨 40 이상 AND 4장 진입(chapter >= 4). 1차 직업당 2갈래.
const SECOND_JOB_UNLOCK_LEVEL := 40
const SECOND_JOB_UNLOCK_CHAPTER := 4
const SECOND_JOB_NAMES := {
	"guardian": "수호자", "berserker": "광전사",
	"elementalist": "원소술사", "necromancer": "강령술사",
	"assassin": "암살자", "shadow_dancer": "그림자무희",
}
## 1차 직업별로 갈 수 있는 2차 직업 두 갈래.
const SECOND_JOB_BRANCHES := {
	"warrior": ["guardian", "berserker"],
	"mage": ["elementalist", "necromancer"],
	"rogue": ["assassin", "shadow_dancer"],
}
## 2차 전직 재료: 전직의 돌 200개(고정) + 골드(레벨×200). SECOND_JOB_DESIGN.md 5절.
const SECOND_JOB_STONE_COST := 200
const SECOND_JOB_GOLD_MULT := 200

## 1차 직업별 소모할 전직의 돌 타입.
const SECOND_JOB_STONE_OF := {
	"warrior": JOB_STONE_WARRIOR, "mage": JOB_STONE_MAGE, "rogue": JOB_STONE_ROGUE,
}


func can_change_second_job() -> bool:
	return job != "" and level >= SECOND_JOB_UNLOCK_LEVEL and chapter >= SECOND_JOB_UNLOCK_CHAPTER


func second_job_gold_cost() -> int:
	return 0 if second_job == "" else level * SECOND_JOB_GOLD_MULT


func second_job_stone_type() -> String:
	return str(SECOND_JOB_STONE_OF.get(job, ""))


## 실패하면 이유를, 성공하면 빈 문자열을 돌려준다. 재전직도 같은 값을 요구한다.
func change_second_job(new_job: String) -> String:
	var branches: Array = SECOND_JOB_BRANCHES.get(job, [])
	if not branches.has(new_job):
		return "지금 직업에서는 갈 수 없는 길이다."
	if not can_change_second_job():
		return "레벨 %d, 4장 이상부터 2차 전직할 수 있다." % SECOND_JOB_UNLOCK_LEVEL
	if new_job == second_job:
		return "이미 그 직업이다."
	var stone := second_job_stone_type()
	if int(materials.get(stone, 0)) < SECOND_JOB_STONE_COST:
		return "%s이(가) 부족하다. (%d개 필요)" % [stone, SECOND_JOB_STONE_COST]
	var cost := second_job_gold_cost()
	if gold < cost:
		return "골드가 부족하다. (%d골드 필요)" % cost
	materials[stone] = int(materials[stone]) - SECOND_JOB_STONE_COST
	gold -= cost
	second_job = new_job
	return ""


## 창고에 넣는다. 착용 중이면 거절한다.
func store_item(index: int) -> bool:
	_sync_item_uid()
	_sync_storage_uid()
	if index < 0 or index >= inventory.size() or storage.size() >= STORAGE_MAX:
		return false
	var item := inventory[index]
	if is_equipped_at(index):
		return false
	var uid := item_uid[index]
	inventory.remove_at(index)
	item_uid.remove_at(index)
	storage.append(item)
	storage_uid.append(uid)
	return true


## 창고에서 꺼낸다.
func withdraw_item(index: int) -> bool:
	_sync_item_uid()
	_sync_storage_uid()
	if index < 0 or index >= storage.size():
		return false
	inventory.append(storage[index])
	item_uid.append(storage_uid[index])
	storage.remove_at(index)
	storage_uid.remove_at(index)
	return true


## 지금 받을 수 있는 의뢰. 다 끝냈으면 빈 사전을 준다.
func current_bounty() -> Dictionary:
	if bounty_index >= BOUNTIES.size():
		return {}
	return BOUNTIES[bounty_index]


func take_bounty() -> bool:
	if bounty_taken or current_bounty().is_empty():
		return false
	bounty_taken = true
	bounty_progress = 0
	# 모으기 의뢰는 이미 가진 재료부터 센다.
	if str(current_bounty().get("type", "hunt")) == "gather":
		bounty_progress = mini(materials[MATERIAL], int(current_bounty()["count"]))
	return true


## 몬스터를 잡을 때마다 부른다. 의뢰 대상이면 진행도가 오른다.
## 몬스터를 잡을 때마다 부른다. 사냥 의뢰 대상이면 진행도가 오른다.
func record_kill(kind: String) -> void:
	var bounty: Dictionary = current_bounty()
	if not bounty_taken or bounty.is_empty():
		return
	if str(bounty.get("type", "hunt")) != "hunt" or str(bounty.get("kind", "")) != kind:
		return
	bounty_progress = mini(bounty_progress + 1, int(bounty["count"]))


func bounty_done() -> bool:
	var bounty: Dictionary = current_bounty()
	if not bounty_taken or bounty.is_empty():
		return false
	# 모으기는 지금 가진 개수를 그때그때 본다. 중간에 써 버렸을 수 있다.
	if str(bounty.get("type", "hunt")) == "gather":
		return materials[MATERIAL] >= int(bounty["count"])
	return bounty_progress >= int(bounty["count"])


## 보상을 받고 다음 의뢰로 넘어간다.
## 보상을 받고 다음 의뢰로 넘어간다. 모으기 의뢰는 재료를 가져간다.
func claim_bounty() -> Dictionary:
	if not bounty_done():
		return {}
	var bounty: Dictionary = current_bounty()
	if str(bounty.get("type", "hunt")) == "gather":
		materials[MATERIAL] -= int(bounty["count"])
	gold += int(bounty["gold"])
	add_item(str(bounty["item"]))
	bounty_index += 1
	bounty_taken = false
	bounty_progress = 0
	return bounty


## 이번에 고를 특성 후보 셋을 뽑는다. 같은 특성이 겹치지 않게 한다.
func roll_perk_offer() -> Array[String]:
	if perk_picks <= 0:
		perk_offer = []
		return perk_offer
	var pool: Array[String] = []
	for key in PERKS:
		pool.append(str(key))
	pool.shuffle()
	perk_offer = []
	for key in pool.slice(0, 3):
		perk_offer.append(key)
	return perk_offer


## 특성을 고른다. 같은 특성을 여러 번 골라 쌓을 수 있다.
func take_perk(key: String) -> bool:
	if perk_picks <= 0 or not PERKS.has(key):
		return false
	perk_picks -= 1
	perks[key] = int(perks.get(key, 0)) + 1
	perk_offer = []
	return true


## 고른 특성이 주는 몫. 능력치 계산이 이 값을 더한다.
func perk_bonus(field: String) -> float:
	var total := 0.0
	for key in perks:
		total += float(PERKS[key].get(field, 0)) * int(perks[key])
	return total


## 능치 한 점을 넣는다. 남은 점수가 없으면 아무 일도 없다.
func spend_stat(key: String) -> bool:
	if stat_points <= 0 or not stats.has(key):
		return false
	stat_points -= 1
	stats[key] += 1
	return true


## 투자한 능력치가 실제 수치에 주는 몫. 플레이어와 화면이 같은 값을 쓴다.
func stat_attack() -> int:
	return int(stats["strength"]) * 2 + int(perk_bonus("atk"))


## 치명타 확률. 기본 8%에 민첩 한 점당 1.5%.
func crit_chance() -> float:
	return 0.08 + int(stats["agility"]) * 0.015 + perk_bonus("crit") + stone_bonus("crit") + set_bonus("crit")


## 치명타 피해 배율. 기본 180%에 힘 한 점당 2%.
func crit_damage_mult() -> float:
	return 1.8 + int(stats["strength"]) * 0.02 + perk_bonus("critdmg") + stone_bonus("critdmg") + set_bonus("critdmg")


## 특성이 주는 방어력. 장비 방어와 합산된다.
func perk_defense() -> int:
	return int(perk_bonus("def"))


func stat_speed() -> int:
	return int(stats["agility"]) + int(perk_bonus("spd"))


func stat_health() -> int:
	return int(stats["vitality"]) * 8 + int(perk_bonus("hp"))


func stat_mana() -> int:
	return int(stats["will"]) * 4 + int(perk_bonus("mana"))


## 장비 표. 슬롯·등급·레벨제한·능력치를 한곳에 모은다.
## if 사슬로 흩어 두면 아이템을 늘릴 때마다 여러 함수를 고쳐야 한다.
const SLOTS := ["weapon", "armor", "helmet", "trinket", "trinket2", "spirit"]

const SLOT_NAMES := {
	"weapon": "무기", "armor": "갑옷", "helmet": "투구", "trinket": "장신구1", "trinket2": "장신구2", "spirit": "정령 인장",
}

const RARITY_COLORS := {
	"일반": Color(0.86, 0.88, 0.84),
	"레어": Color(0.44, 0.72, 1.0),
	"에픽": Color(0.78, 0.52, 1.0),
	"전설": Color(1.0, 0.68, 0.16),
	"신화": Color(0.95, 0.15, 0.15),
	## 신화보다 위, 탑 전용 장비만 쓰는 최상위 등급. 하늘빛-백색이라
	## 기존 5개 등급색과 안 겹친다. TOWER_DESIGN.md 6절 참고.
	"초월": Color(0.75, 0.95, 1.0),
}
## 등급순 정렬용. 인벤토리를 희귀도순으로 볼 때 쓴다. 낮을수록 흔하다.
const RARITY_ORDER := ["일반", "레어", "에픽", "전설", "신화", "초월"]


func rarity_rank(item: String) -> int:
	return RARITY_ORDER.find(rarity_of(item))


func display_color(item: String) -> Color:
	return RARITY_COLORS.get(rarity_of(item), Color.WHITE)

## 세트/등급 팔레트의 유일한 출처(tools/build_item_icons.py 와 공유,
## data/item_palettes.json). 아이콘과 캐릭터 부위별 색이 어긋나지
## 않게 이 파일 하나만 읽는다(PROMPT.md ③).
var ITEM_PALETTES: Dictionary = {}
## 세트가 없는 아이템은 등급색을 따른다(등급별 팔레트 키, item_palettes.json 참고).
## "전설"은 5~10장 필드 드랍 12종(legendary 팔레트), "초월"은 전부 "set" 필드가 있어
## 여기서 찾을 일이 없다(EQUIPMENT 전수 확인, 2026-09-04).
const RARITY_PALETTE_KEY := {"일반": "common", "레어": "rare", "에픽": "epic", "전설": "legendary", "신화": "mythic"}


## 갑옷 착용 시 몸통 그림 자체를 바꾸는 매핑(아이템 이름 → assets/characters/
## 파일명). 표에 없으면(예: 기본 "여행자 옷") player.gd가 hero.png로 폴백한다.
var BODY_SKINS: Dictionary = {}

## 투구 착용 시 머리 오버레이 그림을 바꾸는 매핑(아이템 이름 → assets/
## characters/ 파일명, tools/build_helmet_overlays.py가 생성). 표에 없으면
## player.gd가 기존 기본 투구 그림(helmet_overlay_basic.png)으로 폴백한다.
var HELMET_SKINS: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://data/item_palettes.json", FileAccess.READ)
	ITEM_PALETTES = JSON.parse_string(file.get_as_text())
	var skins_file := FileAccess.open("res://data/item_body_skins.json", FileAccess.READ)
	BODY_SKINS = JSON.parse_string(skins_file.get_as_text())
	var helmet_skins_file := FileAccess.open("res://data/item_helmet_skins.json", FileAccess.READ)
	HELMET_SKINS = JSON.parse_string(helmet_skins_file.get_as_text())


## 갑옷 아이템에 해당하는 몸통 스프라이트 경로. 매핑에 없으면 기본 hero.png.
func body_skin_for(item: String) -> String:
	var name: String = BODY_SKINS.get(item, "")
	if name == "":
		return "res://assets/characters/hero.png"
	return "res://assets/characters/" + name


## 투구 아이템에 해당하는 머리 오버레이 경로. 매핑에 없으면 기본 투구 그림.
func helmet_skin_for(item: String) -> String:
	var name: String = HELMET_SKINS.get(item, "")
	if name == "":
		return "res://assets/characters/helmet_overlay_basic.png"
	return "res://assets/characters/" + name


## 아이템이 세트에 속하면 세트 팔레트 키, 아니면 등급 팔레트 키.
func palette_key_for(item: String) -> String:
	var set_key := str(item_data(item).get("set", ""))
	if set_key != "":
		return set_key
	return RARITY_PALETTE_KEY.get(rarity_of(item), "common")


## 부위별 캐릭터 틴트용 대표색(팔레트의 밝은 쪽 색). 무지개 세트는
## is_rainbow_item()으로 따로 판정하고, 이 색은 그 경우의 폴백으로만 쓴다.
func palette_color_for(item: String) -> Color:
	if item == "":
		return Color.WHITE
	var pal: Dictionary = ITEM_PALETTES.get(palette_key_for(item), {})
	if pal.is_empty():
		return display_color(item)
	return Color(str(pal.get("light", "#ffffff")))


func is_rainbow_item(item: String) -> bool:
	if item == "":
		return false
	var pal: Dictionary = ITEM_PALETTES.get(palette_key_for(item), {})
	return bool(pal.get("rainbow", false))

const EQUIPMENT := {
	# 무기
	"낡은 검": {"slot": "weapon", "rarity": "일반", "level": 1, "atk": 0, "price": 5, "hand": "sword_worn"},
	"철검": {"slot": "weapon", "rarity": "일반", "level": 2, "atk": 8, "price": 35, "hand": "sword_iron"},
	"사냥꾼의 활": {"slot": "weapon", "rarity": "일반", "level": 4, "atk": 11, "spd": 6, "price": 60, "kind": "bow"},
	"강철 대검": {"slot": "weapon", "rarity": "레어", "level": 6, "atk": 18, "hp": 10, "price": 90, "hand": "bigsword_steel"},
	"서리 단검": {"slot": "weapon", "rarity": "레어", "level": 8, "atk": 15, "spd": 12, "price": 120, "hand": "dagger_frost"},
	"질풍의 활": {"slot": "weapon", "rarity": "레어", "level": 9, "atk": 17, "spd": 10, "price": 170, "kind": "bow"},
	"영혼 사수의 활": {"slot": "weapon", "rarity": "에픽", "level": 13, "atk": 32, "spd": 14, "price": 400, "kind": "bow"},
	"수호자의 검": {"slot": "weapon", "rarity": "에픽", "level": 11, "atk": 30, "hp": 20, "price": 260, "hand": "katana_guardian", "set": "guardian_set"},
	# 갑옷
	"여행자 옷": {"slot": "armor", "rarity": "일반", "level": 1, "def": 0, "price": 5},
	"가죽 갑옷": {"slot": "armor", "rarity": "일반", "level": 2, "def": 4, "price": 40},
	"사슬 갑옷": {"slot": "armor", "rarity": "일반", "level": 5, "def": 9, "hp": 15, "price": 95},
	"파수병 흉갑": {"slot": "armor", "rarity": "레어", "level": 8, "def": 14, "hp": 30, "price": 150},
	"흑기사 갑주": {"slot": "armor", "rarity": "에픽", "level": 12, "def": 22, "hp": 55, "price": 300, "set": "captain_set"},
	# 투구
	"가죽 모자": {"slot": "helmet", "rarity": "일반", "level": 1, "def": 2, "price": 20},
	"철 투구": {"slot": "helmet", "rarity": "일반", "level": 4, "def": 5, "hp": 10, "price": 55},
	"파수병 투구": {"slot": "helmet", "rarity": "레어", "level": 9, "def": 9, "hp": 20, "price": 130},
	# 장신구
	"구리 반지": {"slot": "trinket", "rarity": "일반", "level": 1, "atk": 2, "price": 25},
	"수정 목걸이": {"slot": "trinket", "rarity": "레어", "level": 5, "atk": 4, "hp": 25, "price": 110},
	"정령의 부적": {"slot": "trinket", "rarity": "에픽", "level": 11, "atk": 9, "def": 6, "spd": 8, "price": 240, "set": "abyss_set"},
	# 3장 설원·신전
	"서리왕관": {"slot": "helmet", "rarity": "에픽", "level": 12, "def": 14, "hp": 35, "price": 380, "set": "frost_set"},
	"빙결의 창": {"slot": "weapon", "rarity": "에픽", "level": 14, "atk": 38, "spd": 10, "price": 460, "hand": "lance_frost", "set": "frost_set"},
	"설원의 망토": {"slot": "armor", "rarity": "에픽", "level": 13, "def": 28, "hp": 70, "price": 420},
	# 보스 전용 드랍. 보스가 직접 떨어뜨리는 확정 장비다.
	"숲의 심장": {"slot": "trinket", "rarity": "에픽", "level": 10, "atk": 5, "hp": 20, "price": 220, "set": "guardian_set"},
	"단장의 견장": {"slot": "trinket", "rarity": "에픽", "level": 13, "atk": 6, "def": 6, "price": 320, "set": "captain_set"},
	"심연의 파편": {"slot": "weapon", "rarity": "에픽", "level": 15, "atk": 42, "spd": 8, "price": 520, "hand": "tsurugi_abyss", "set": "abyss_set"},
	# 보스 세트를 상점템 하나 + 보스템 하나가 아니라 보스만의 전용 세트로
	# 만들기 위해 보스마다 확정 드랍을 하나씩 더 늘렸다. 상점/퀘스트로는
	# 못 구하고 그 보스를 잡아야만 나온다.
	"수호자의 투구": {"slot": "helmet", "rarity": "에픽", "level": 10, "def": 16, "hp": 30, "price": 260, "set": "guardian_set"},
	"흑기사단장의 투구": {"slot": "helmet", "rarity": "에픽", "level": 13, "def": 18, "hp": 35, "price": 340, "set": "captain_set"},
	"서리군주의 갑주": {"slot": "armor", "rarity": "에픽", "level": 14, "def": 32, "hp": 75, "price": 480, "set": "frost_set"},
	"용각 투구": {"slot": "helmet", "rarity": "신화", "level": 16, "def": 30, "atk": 10, "hp": 55, "price": 1600, "set": "boss_set"},
	# 동서남북 던전 전용 드랍. 상점에 안 팔고 그 지역 몬스터만 낮은 확률로 준다.
	"황혼의 부적": {"slot": "trinket", "rarity": "레어", "level": 3, "atk": 3, "hp": 12, "price": 60},
	"가라앉은 목걸이": {"slot": "trinket", "rarity": "레어", "level": 6, "def": 5, "hp": 20, "price": 130},
	"빙하의 파편": {"slot": "weapon", "rarity": "에픽", "level": 13, "atk": 34, "def": 6, "price": 400, "hand": "rapier_glacier"},
	"용의 비늘": {"slot": "armor", "rarity": "에픽", "level": 16, "def": 30, "hp": 60, "price": 560},
	# 전설 등급. 세트마다 비어 있던 네 번째 자리를 채운다. 상점에도 안 팔고
	# 보스도 안 준다 - 대장간에서 보스의 파편으로 제작해야만 나온다.
	# 한 판에 보스 넷을 다 잡아도 파편은 360개뿐이라(40+70+100+150),
	# 넷 중 많아야 둘까지만 완성할 수 있다.
	"용린 갑주": {"slot": "armor", "rarity": "신화", "level": 11, "def": 24, "hp": 45, "price": 900, "set": "boss_set"},
	"용아 대검": {"slot": "weapon", "rarity": "신화", "level": 14, "atk": 36, "hp": 15, "price": 1100, "hand": "claymore_dragon", "set": "boss_set"},
	"용의 인장": {"slot": "trinket", "rarity": "신화", "level": 15, "atk": 10, "def": 10, "spd": 6, "price": 1300, "set": "boss_set"},
	"심연의 갑주": {"slot": "armor", "rarity": "에픽", "level": 15, "def": 30, "hp": 50, "price": 560, "set": "abyss_set"},
	# 정령 인장. 화면에 돌아다니는 동반자 대신, 장비 슬롯 하나를 더 늘려
	# 패시브 효과를 주는 쪽을 골랐다. spirit 값이 실제 효과를 정한다.
	"숲의 정령 인장": {"slot": "spirit", "rarity": "레어", "level": 7, "hp": 20, "price": 130, "spirit": "regen"},
	"바람의 정령 인장": {"slot": "spirit", "rarity": "레어", "level": 7, "spd": 8, "price": 130, "spirit": "swift_dash"},
	"불꽃의 정령 인장": {"slot": "spirit", "rarity": "에픽", "level": 12, "atk": 6, "price": 280, "spirit": "mana_flow"},
	"서리의 정령 인장": {"slot": "spirit", "rarity": "에픽", "level": 12, "def": 6, "price": 280, "spirit": "warding"},

	# 탑 전용 "초월" 등급 장비. 난이도 5단계(쉬움→심연)마다 무기/방어구/
	# 투구/장신구 한 벌씩, 총 20종. 신화(용기사 세트)보다 확실히 세게
	# 잡되 쉬움은 신화와 비슷한 선에서 시작해 심연은 약 2.3배까지
	# 올라간다. 대장간에서 그 난이도 바로 아래 탑을 100층까지 클리어해야
	# 제작할 수 있다(TOWER_CRAFT_RECIPES). 각 계열 4개가 그대로 세트다
	# (아래 SETS의 tower_*_set) - "천공 세트 입었는데 효과가 없다" 피드백으로
	# 처음엔 없던 세트 보너스를 추가했다.
	"파수꾼의 검": {"slot": "weapon", "rarity": "초월", "level": 18, "atk": 32, "hp": 10, "price": 1300, "hand": "falchion_sentinel", "set": "tower_easy_set"},
	"파수꾼의 갑주": {"slot": "armor", "rarity": "초월", "level": 18, "def": 26, "hp": 40, "price": 1300, "set": "tower_easy_set"},
	"파수꾼의 투구": {"slot": "helmet", "rarity": "초월", "level": 18, "def": 24, "atk": 8, "hp": 45, "price": 1300, "set": "tower_easy_set"},
	"파수꾼의 인장": {"slot": "trinket", "rarity": "초월", "level": 18, "atk": 8, "def": 8, "spd": 5, "price": 1300, "set": "tower_easy_set"},
	"심판자의 검": {"slot": "weapon", "rarity": "초월", "level": 19, "atk": 40, "hp": 12, "price": 1700, "hand": "blessed_judge", "set": "tower_normal_set"},
	"심판자의 갑주": {"slot": "armor", "rarity": "초월", "level": 19, "def": 32, "hp": 50, "price": 1700, "set": "tower_normal_set"},
	"심판자의 투구": {"slot": "helmet", "rarity": "초월", "level": 19, "def": 30, "atk": 10, "hp": 56, "price": 1700, "set": "tower_normal_set"},
	"심판자의 인장": {"slot": "trinket", "rarity": "초월", "level": 19, "atk": 10, "def": 10, "spd": 6, "price": 1700, "set": "tower_normal_set"},
	"종언의 검": {"slot": "weapon", "rarity": "초월", "level": 20, "atk": 50, "hp": 15, "price": 2200, "hand": "serrated_end", "set": "tower_hard_set"},
	"종언의 갑주": {"slot": "armor", "rarity": "초월", "level": 20, "def": 40, "hp": 62, "price": 2200, "set": "tower_hard_set"},
	"종언의 투구": {"slot": "helmet", "rarity": "초월", "level": 20, "def": 37, "atk": 12, "hp": 70, "price": 2200, "set": "tower_hard_set"},
	"종언의 인장": {"slot": "trinket", "rarity": "초월", "level": 20, "atk": 12, "def": 12, "spd": 8, "price": 2200, "set": "tower_hard_set"},
	"겁화의 검": {"slot": "weapon", "rarity": "초월", "level": 21, "atk": 61, "hp": 19, "price": 2900, "hand": "flame_hellfire", "set": "tower_hell_set"},
	"겁화의 갑주": {"slot": "armor", "rarity": "초월", "level": 21, "def": 49, "hp": 76, "price": 2900, "set": "tower_hell_set"},
	"겁화의 투구": {"slot": "helmet", "rarity": "초월", "level": 21, "def": 46, "atk": 15, "hp": 85, "price": 2900, "set": "tower_hell_set"},
	"겁화의 인장": {"slot": "trinket", "rarity": "초월", "level": 21, "atk": 15, "def": 15, "spd": 9, "price": 2900, "set": "tower_hell_set"},
	"천공의 검": {"slot": "weapon", "rarity": "초월", "level": 22, "atk": 74, "hp": 23, "price": 3800, "hand": "winged_prism", "set": "tower_abyss_set"},
	"천공의 갑주": {"slot": "armor", "rarity": "초월", "level": 22, "def": 60, "hp": 92, "price": 3800, "set": "tower_abyss_set"},
	"천공의 투구": {"slot": "helmet", "rarity": "초월", "level": 22, "def": 55, "atk": 18, "hp": 103, "price": 3800, "set": "tower_abyss_set"},
	"천공의 인장": {"slot": "trinket", "rarity": "초월", "level": 22, "atk": 18, "def": 18, "spd": 11, "price": 3800, "set": "tower_abyss_set"},
	# 5~10장 상위 장비(감독 2026-09-10). 세트 4종은 보스 확정 드랍(검·투구)
	# + 장별 정수 제작(대장간), 전설 2종은 그 장 잡몹 필드 드랍.
	"태초의 검": {"slot": "weapon", "rarity": "초월", "level": 26, "atk": 83, "hp": 26, "price": 4300, "hand": "primordial_edge", "set": "primordial_set"},
	"태초의 갑주": {"slot": "armor", "rarity": "초월", "level": 26, "def": 67, "hp": 103, "price": 4300, "set": "primordial_set"},
	"태초의 투구": {"slot": "helmet", "rarity": "초월", "level": 26, "def": 62, "atk": 20, "hp": 115, "price": 4300, "set": "primordial_set"},
	"태초의 인장": {"slot": "trinket", "rarity": "초월", "level": 26, "atk": 20, "def": 20, "spd": 12, "price": 4300, "set": "primordial_set"},
	"심해의 검": {"slot": "weapon", "rarity": "초월", "level": 29, "atk": 93, "hp": 29, "price": 4800, "hand": "reef_trident", "set": "reef_set"},
	"심해의 갑주": {"slot": "armor", "rarity": "초월", "level": 29, "def": 75, "hp": 115, "price": 4800, "set": "reef_set"},
	"심해의 투구": {"slot": "helmet", "rarity": "초월", "level": 29, "def": 69, "atk": 23, "hp": 129, "price": 4800, "set": "reef_set"},
	"심해의 인장": {"slot": "trinket", "rarity": "초월", "level": 29, "atk": 23, "def": 23, "spd": 14, "price": 4800, "set": "reef_set"},
	"성광의 검": {"slot": "weapon", "rarity": "초월", "level": 32, "atk": 104, "hp": 32, "price": 5400, "hand": "prelate_gold", "set": "prelate_set"},
	"성광의 갑주": {"slot": "armor", "rarity": "초월", "level": 32, "def": 84, "hp": 129, "price": 5400, "set": "prelate_set"},
	"성광의 투구": {"slot": "helmet", "rarity": "초월", "level": 32, "def": 77, "atk": 25, "hp": 145, "price": 5400, "set": "prelate_set"},
	"성광의 인장": {"slot": "trinket", "rarity": "초월", "level": 32, "atk": 25, "def": 25, "spd": 15, "price": 5400, "set": "prelate_set"},
	"침묵의 검": {"slot": "weapon", "rarity": "초월", "level": 35, "atk": 116, "hp": 36, "price": 6000, "hand": "warden_hammer", "set": "warden_set"},
	"침묵의 갑주": {"slot": "armor", "rarity": "초월", "level": 35, "def": 94, "hp": 145, "price": 6000, "set": "warden_set"},
	"침묵의 투구": {"slot": "helmet", "rarity": "초월", "level": 35, "def": 87, "atk": 28, "hp": 162, "price": 6000, "set": "warden_set"},
	"침묵의 인장": {"slot": "trinket", "rarity": "초월", "level": 35, "atk": 28, "def": 28, "spd": 17, "price": 6000, "set": "warden_set"},
	"역행의 검": {"slot": "weapon", "rarity": "초월", "level": 38, "atk": 130, "hp": 41, "price": 6700, "hand": "reversal_scythe", "set": "reversal_set"},
	"역행의 갑주": {"slot": "armor", "rarity": "초월", "level": 38, "def": 106, "hp": 162, "price": 6700, "set": "reversal_set"},
	"역행의 투구": {"slot": "helmet", "rarity": "초월", "level": 38, "def": 97, "atk": 32, "hp": 182, "price": 6700, "set": "reversal_set"},
	"역행의 인장": {"slot": "trinket", "rarity": "초월", "level": 38, "atk": 32, "def": 32, "spd": 19, "price": 6700, "set": "reversal_set"},
	"근원의 검": {"slot": "weapon", "rarity": "초월", "level": 40, "atk": 146, "hp": 45, "price": 7500, "hand": "origin_singing", "set": "origin_set"},
	"근원의 갑주": {"slot": "armor", "rarity": "초월", "level": 40, "def": 118, "hp": 182, "price": 7500, "set": "origin_set"},
	"근원의 투구": {"slot": "helmet", "rarity": "초월", "level": 40, "def": 109, "atk": 36, "hp": 203, "price": 7500, "set": "origin_set"},
	"근원의 인장": {"slot": "trinket", "rarity": "초월", "level": 40, "atk": 36, "def": 36, "spd": 22, "price": 7500, "set": "origin_set"},
	"순례자의 투구": {"slot": "helmet", "rarity": "전설", "level": 26, "def": 52, "atk": 16, "hp": 90, "price": 2600},
	"잔재의 반지": {"slot": "trinket", "rarity": "전설", "level": 26, "atk": 17, "def": 12, "spd": 10, "price": 2600},
	"산호 흉갑": {"slot": "armor", "rarity": "전설", "level": 29, "def": 64, "hp": 98, "price": 2900},
	"조류의 목걸이": {"slot": "trinket", "rarity": "전설", "level": 29, "atk": 14, "def": 20, "spd": 12, "price": 2900},
	"등불 사제의 관": {"slot": "helmet", "rarity": "전설", "level": 32, "def": 66, "atk": 20, "hp": 120, "price": 3200},
	"빛바랜 성검": {"slot": "weapon", "rarity": "전설", "level": 32, "atk": 90, "hp": 28, "price": 3200, "hand": "faded_holysword"},
	"감독관의 철갑": {"slot": "armor", "rarity": "전설", "level": 35, "def": 82, "hp": 125, "price": 3500},
	"감시탑 인장": {"slot": "trinket", "rarity": "전설", "level": 35, "atk": 24, "def": 24, "spd": 13, "price": 3500},
	"역류의 검": {"slot": "weapon", "rarity": "전설", "level": 38, "atk": 112, "hp": 34, "price": 3800, "hand": "backflow_blade"},
	"역행자의 두건": {"slot": "helmet", "rarity": "전설", "level": 38, "def": 84, "atk": 28, "hp": 160, "price": 3800},
	"원초의 갑주": {"slot": "armor", "rarity": "전설", "level": 40, "def": 102, "hp": 160, "price": 4000},
	"원초의 반지": {"slot": "trinket", "rarity": "전설", "level": 40, "atk": 30, "def": 30, "spd": 17, "price": 4000},
}

## 장비별 전용 아이콘. 파일은 assets/items/<이름>.png 이고
## tools/build_item_icons.py 가 CC0 에셋팩에서 만든다(61종 전부 다른 그림).
## 예전에는 슬롯·손그림 종류별로 아이콘 몇 장을 돌려썼기 때문에 등급이
## 하늘과 땅 차이인 장비가 인벤토리에서 똑같이 보였다. 세트 아이템은
## 같은 색으로 통일했고 천공 세트만 무지갯빛이다.
const ITEM_ICONS := {
	# 무기
	"낡은 검": "icon_sword_worn",
	"철검": "icon_sword_iron",
	"강철 대검": "icon_bigsword_steel",
	"서리 단검": "icon_sai_frost",
	"수호자의 검": "icon_weapon_guardian",
	"심연의 파편": "icon_weapon_abyss",
	"빙결의 창": "icon_weapon_frost",
	"빙하의 파편": "icon_rapier_glacier",
	"용아 대검": "icon_weapon_dragon",
	"파수꾼의 검": "icon_weapon_sentinel",
	"심판자의 검": "icon_weapon_judge",
	"종언의 검": "icon_weapon_end",
	"겁화의 검": "icon_weapon_hellfire",
	"천공의 검": "icon_weapon_prism",
	"사냥꾼의 활": "icon_bow_hunter",
	"질풍의 활": "icon_bow_gale",
	"영혼 사수의 활": "icon_bow_soul",
	# 갑옷
	"여행자 옷": "icon_armor_traveler",
	"가죽 갑옷": "icon_armor_leather",
	"사슬 갑옷": "icon_armor_chain",
	"파수병 흉갑": "icon_armor_sentry",
	"흑기사 갑주": "icon_armor_captain",
	"설원의 망토": "icon_armor_snowcloak",
	"서리군주의 갑주": "icon_armor_frost",
	"심연의 갑주": "icon_armor_abyss",
	"용의 비늘": "icon_armor_scale",
	"용린 갑주": "icon_armor_dragon",
	"파수꾼의 갑주": "icon_armor_sentinel",
	"심판자의 갑주": "icon_armor_judge",
	"종언의 갑주": "icon_armor_end",
	"겁화의 갑주": "icon_armor_hellfire",
	"천공의 갑주": "icon_armor_prism",
	# 투구
	"가죽 모자": "icon_helmet_leather",
	"철 투구": "icon_helmet_iron",
	"파수병 투구": "icon_helmet_sentry",
	"수호자의 투구": "icon_helmet_guardian",
	"서리왕관": "icon_helmet_frost",
	"흑기사단장의 투구": "icon_helmet_captain",
	"용각 투구": "icon_helmet_dragon",
	"파수꾼의 투구": "icon_helmet_sentinel",
	"심판자의 투구": "icon_helmet_judge",
	"종언의 투구": "icon_helmet_end",
	"겁화의 투구": "icon_helmet_hellfire",
	"천공의 투구": "icon_helmet_prism",
	# 장신구
	"구리 반지": "icon_trinket_copper",
	"황혼의 부적": "icon_trinket_dusk",
	"수정 목걸이": "icon_trinket_crystal",
	"가라앉은 목걸이": "icon_trinket_sunken",
	"숲의 심장": "icon_trinket_guardian",
	"정령의 부적": "icon_trinket_abyss",
	"단장의 견장": "icon_trinket_captain",
	"용의 인장": "icon_trinket_dragon",
	"파수꾼의 인장": "icon_trinket_sentinel",
	"심판자의 인장": "icon_trinket_judge",
	"종언의 인장": "icon_trinket_end",
	"겁화의 인장": "icon_trinket_hellfire",
	"천공의 인장": "icon_trinket_prism",
	# 정령 인장
	"숲의 정령 인장": "icon_spirit_forest",
	"바람의 정령 인장": "icon_spirit_wind",
	"불꽃의 정령 인장": "icon_spirit_flame",
	"서리의 정령 인장": "icon_spirit_frostseal",
	"태초의 검": "icon_primordial_sword",
	"태초의 갑주": "icon_primordial_armor",
	"태초의 투구": "icon_primordial_helmet",
	"태초의 인장": "icon_primordial_seal",
	"심해의 검": "icon_reef_sword",
	"심해의 갑주": "icon_reef_armor",
	"심해의 투구": "icon_reef_helmet",
	"심해의 인장": "icon_reef_seal",
	"성광의 검": "icon_prelate_sword",
	"성광의 갑주": "icon_prelate_armor",
	"성광의 투구": "icon_prelate_helmet",
	"성광의 인장": "icon_prelate_seal",
	"침묵의 검": "icon_warden_sword",
	"침묵의 갑주": "icon_warden_armor",
	"침묵의 투구": "icon_warden_helmet",
	"침묵의 인장": "icon_warden_seal",
	"역행의 검": "icon_reversal_sword",
	"역행의 갑주": "icon_reversal_armor",
	"역행의 투구": "icon_reversal_helmet",
	"역행의 인장": "icon_reversal_seal",
	"근원의 검": "icon_origin_sword",
	"근원의 갑주": "icon_origin_armor",
	"근원의 투구": "icon_origin_helmet",
	"근원의 인장": "icon_origin_seal",
	"순례자의 투구": "icon_fd_pilgrim_helm",
	"잔재의 반지": "icon_fd_remnant_ring",
	"산호 흉갑": "icon_fd_coral_plate",
	"조류의 목걸이": "icon_fd_tide_amulet",
	"등불 사제의 관": "icon_fd_lantern_crown",
	"빛바랜 성검": "icon_fd_faded_holysword",
	"감독관의 철갑": "icon_fd_overseer_plate",
	"감시탑 인장": "icon_fd_watchtower_seal",
	"역류의 검": "icon_fd_backflow_sword",
	"역행자의 두건": "icon_fd_reverter_hood",
	"원초의 갑주": "icon_fd_primal_plate",
	"원초의 반지": "icon_fd_primal_ring",
}


## 정령 인장 패시브 효과 설명. item_summary 가 능력치 옆에 붙여 보여 준다.
const SPIRIT_EFFECT_DESC := {
	"regen": "5초마다 최대 HP 2% 회복",
	"swift_dash": "구르기 쿨타임 30% 감소",
	"mana_flow": "마력 자연 회복 증가",
	"warding": "피격 후 무적 시간 증가",
}

## 보스 세트. 보스가 직접 떨어뜨리는 장비와 그 보스 지역 상자 장비를 묶었다.
## 이 게임만의 장비 발전 축이다. 두 조각을 다 껴야 효과가 붙는다.
## 세트마다 세 조각 중 둘은 그 보스만 떨어뜨리는 전용 장비고, 나머지 하나만
## 상점/퀘스트로 구할 수 있다. 2조각부터 효과가 붙고 3조각(풀세트)을 다
## 맞추면 훨씬 세진다.
## 조각 넷 중 셋(무기/방어구/투구 중 둘 + 장신구나 나머지 하나)은 그 보스
## 전용 드랍이거나 상점템이고, 나머지 하나는 대장간에서 파편으로 제작해야
## 하는 전설 등급이다. 4조각을 다 맞추면 2/3조각 때보다 훨씬 세진다.
const SETS := {
	"guardian_set": {"name": "수호자 세트",
		"pieces": ["수호자의 검", "숲의 심장", "수호자의 투구"],
		"bonuses": {2: {"atk": 8, "hp": 15}, 3: {"atk": 14, "def": 8, "hp": 30}}},
	"captain_set": {"name": "흑기사단 세트",
		"pieces": ["흑기사 갑주", "단장의 견장", "흑기사단장의 투구"],
		"bonuses": {2: {"atk": 8, "def": 8}, 3: {"atk": 14, "def": 16, "hp": 20}}},
	"frost_set": {"name": "서리군주 세트",
		"pieces": ["서리왕관", "빙결의 창", "서리군주의 갑주"],
		"bonuses": {2: {"def": 10, "hp": 20}, 3: {"def": 20, "atk": 10, "hp": 40}}},
	"abyss_set": {"name": "심연 세트",
		"pieces": ["정령의 부적", "심연의 파편", "용각 투구"],
		"bonuses": {2: {"atk": 15, "crit": 0.05}, 3: {"atk": 25, "crit": 0.1, "hp": 40}}},
	# 제작으로만 얻는 전설 장비 네 개(용린 갑주/용아 대검/
	# 용의 인장/용각 투구)를 묶은, 기존 4개 세트와는 별개인
	# 다섯 번째 세트. "보스 파편으로 만든 것들끼리 하나의 세트"라는
	# 요청 그대로 반영했다.
	"boss_set": {"name": "용기사 세트",
		"pieces": ["용린 갑주", "용아 대검", "용의 인장", "용각 투구"],
		"bonuses": {2: {"atk": 10, "def": 10}, 3: {"atk": 18, "def": 18, "hp": 30},
			4: {"atk": 30, "def": 30, "hp": 60, "crit": 0.08}}},
	# 탑 전용 장비 5계열(쉬움~심연). 원래는 "세트 보너스 없는 개별 장비"로
	# 설계했으나 "천공 세트 입었는데 효과가 없다, 최강 세트여야 하는데"
	# 피드백으로 뒤집었다. 난이도가 오를수록 보너스도 커져 용기사 세트
	# (4조각 atk/def 30, hp 60, crit 8%)를 전부 앞지른다.
	"tower_easy_set": {"name": "파수꾼 세트",
		"pieces": ["파수꾼의 검", "파수꾼의 갑주", "파수꾼의 투구", "파수꾼의 인장"],
		"bonuses": {2: {"atk": 12, "def": 12}, 3: {"atk": 20, "def": 20, "hp": 30},
			4: {"atk": 34, "def": 34, "hp": 70, "crit": 0.08}}},
	"tower_normal_set": {"name": "심판자 세트",
		"pieces": ["심판자의 검", "심판자의 갑주", "심판자의 투구", "심판자의 인장"],
		"bonuses": {2: {"atk": 15, "def": 15}, 3: {"atk": 25, "def": 25, "hp": 40},
			4: {"atk": 42, "def": 42, "hp": 85, "crit": 0.10}}},
	"tower_hard_set": {"name": "종언 세트",
		"pieces": ["종언의 검", "종언의 갑주", "종언의 투구", "종언의 인장"],
		"bonuses": {2: {"atk": 18, "def": 18}, 3: {"atk": 30, "def": 30, "hp": 50},
			4: {"atk": 50, "def": 50, "hp": 100, "crit": 0.12}}},
	"tower_hell_set": {"name": "겁화 세트",
		"pieces": ["겁화의 검", "겁화의 갑주", "겁화의 투구", "겁화의 인장"],
		"bonuses": {2: {"atk": 21, "def": 21}, 3: {"atk": 35, "def": 35, "hp": 60},
			4: {"atk": 58, "def": 58, "hp": 115, "crit": 0.14}}},
	"tower_abyss_set": {"name": "천공 세트",
		"pieces": ["천공의 검", "천공의 갑주", "천공의 투구", "천공의 인장"],
		"bonuses": {2: {"atk": 24, "def": 24}, 3: {"atk": 40, "def": 40, "hp": 70},
			4: {"atk": 66, "def": 66, "hp": 130, "crit": 0.16}}},
	"primordial_set": {"name": "태초 세트",
		"pieces": ["태초의 검", "태초의 갑주", "태초의 투구", "태초의 인장"],
		"bonuses": {2: {"atk": 27, "def": 27}, 3: {"atk": 45, "def": 45, "hp": 78},
			4: {"atk": 74, "def": 74, "hp": 146, "crit": 0.17}}},
	"reef_set": {"name": "심해 세트",
		"pieces": ["심해의 검", "심해의 갑주", "심해의 투구", "심해의 인장"],
		"bonuses": {2: {"atk": 30, "def": 30}, 3: {"atk": 50, "def": 50, "hp": 88},
			4: {"atk": 83, "def": 83, "hp": 163, "crit": 0.18}}},
	"prelate_set": {"name": "성광 세트",
		"pieces": ["성광의 검", "성광의 갑주", "성광의 투구", "성광의 인장"],
		"bonuses": {2: {"atk": 34, "def": 34}, 3: {"atk": 56, "def": 56, "hp": 98},
			4: {"atk": 93, "def": 93, "hp": 183, "crit": 0.19}}},
	"warden_set": {"name": "침묵 세트",
		"pieces": ["침묵의 검", "침묵의 갑주", "침묵의 투구", "침묵의 인장"],
		"bonuses": {2: {"atk": 38, "def": 38}, 3: {"atk": 63, "def": 63, "hp": 110},
			4: {"atk": 104, "def": 104, "hp": 205, "crit": 0.2}}},
	"reversal_set": {"name": "역행 세트",
		"pieces": ["역행의 검", "역행의 갑주", "역행의 투구", "역행의 인장"],
		"bonuses": {2: {"atk": 42, "def": 42}, 3: {"atk": 70, "def": 70, "hp": 123},
			4: {"atk": 116, "def": 116, "hp": 229, "crit": 0.21}}},
	"origin_set": {"name": "근원 세트",
		"pieces": ["근원의 검", "근원의 갑주", "근원의 투구", "근원의 인장"],
		"bonuses": {2: {"atk": 47, "def": 47}, 3: {"atk": 79, "def": 79, "hp": 138},
			4: {"atk": 130, "def": 130, "hp": 257, "crit": 0.22}}},
}

## 세트를 4조각 다 채우면 스탯 보너스 말고 그 세트만의 특수 효과가
## 따로 하나 붙는다. 정령 인장처럼 이름 붙은 패시브고, player.gd 전투
## 코드가 이 id를 보고 실제 효과를 적용한다.
## 1~4장 보스 세트는 3조각이 끝이라 스탯 보너스만 있다. 4조각짜리
## 특수효과는 "용기사 세트"와, 게임에서 가장 세야 하는 "천공 세트"만의 것이다.
const SET_SPECIAL := {"boss_set": "boss_legacy", "tower_abyss_set": "skyward_grace"}
const SET_SPECIAL_DESC := {
	"boss_legacy": "받는 피해 12% 추가 감소, 치명타 적중 시 피해량의 10% HP 흡수",
	"skyward_grace": "체력이 30% 이하로 떨어지면 받는 피해를 25% 추가로 줄인다",
}


## 4조각을 다 채운 세트가 있으면 그 특수 효과 id를, 없으면 빈 문자열을
## 돌려준다. 두 세트를 동시에 완성할 일은 사실상 없어서 하나만 본다.
func active_set_special() -> String:
	for set_id in _equipped_set_counts():
		var data: Dictionary = SETS.get(set_id, {})
		var total: int = (data.get("pieces", []) as Array).size()
		if _equipped_set_counts()[set_id] >= total:
			return str(SET_SPECIAL.get(set_id, ""))
	return ""


## 마법돌. 소켓에 박아 고정 능력치를 더한다. 강화(배율)와는 다른 축이라
## 나중에 얻은 돌도 이미 낀 장비에 그냥 박으면 된다.
const STONES := {
	"홍옥": {"name": "홍옥", "rarity": "일반", "atk": 3, "price": 40},
	"벽옥": {"name": "벽옥", "rarity": "일반", "def": 3, "price": 40},
	"자수정": {"name": "자수정", "rarity": "일반", "hp": 15, "price": 40},
	"황옥": {"name": "황옥", "rarity": "일반", "spd": 3, "price": 40},
	"홍염석": {"name": "홍염석", "rarity": "레어", "atk": 7, "price": 140},
	"서리결정": {"name": "서리결정", "rarity": "레어", "def": 7, "price": 140},
	"용의눈": {"name": "용의눈", "rarity": "에픽", "atk": 12, "crit": 0.05, "price": 380},
}

## 등급별 소켓 수. 시작 장비 같은 일반 등급은 소켓이 없다.
const SOCKETS_BY_RARITY := {"일반": 0, "레어": 1, "에픽": 2, "전설": 3, "신화": 3, "초월": 3}

## 보스가 죽으면 무조건 떨어뜨리는 전용 장비. 보스마다 다른 확정 드랍이다.
const BOSS_DROPS := {
	"guardian": "숲의 심장", "captain": "단장의 견장",
	"frost": "서리왕관", "abyss": "심연의 파편",
	"primordial": "태초의 검", "reef_warden": "심해의 검", "faded_prelate": "성광의 검",
	"warden_overseer": "침묵의 검", "reverted_one": "역행의 검", "origin": "근원의 검",
}
## 보스 세트를 완전히 보스 전용으로 만드는 두 번째 확정 드랍.
const BOSS_DROPS_EXTRA := {
	"guardian": "수호자의 투구", "captain": "흑기사단장의 투구",
	"frost": "서리군주의 갑주", "abyss": "심연의 갑주",
	"primordial": "태초의 투구", "reef_warden": "심해의 투구", "faded_prelate": "성광의 투구",
	"warden_overseer": "침묵의 투구", "reverted_one": "역행의 투구", "origin": "근원의 투구",
}

## 장(챕터)마다 잡몹이 낮은 확률로 떨어뜨릴 수 있는 장비·마법돌.
## 지역 하나하나 표를 따로 만들면 22개를 다 손봐야 해서, 같은 장 안의
## 지역들은 난이도가 비슷하니 장 단위로 묶었다.
const CHAPTER_ITEM_DROPS := {
	1: ["가죽 모자", "구리 반지", "가죽 갑옷"],
	2: ["철 투구", "수정 목걸이", "사슬 갑옷"],
	3: ["파수병 투구", "파수병 흉갑"],
	4: ["정령의 부적"],
	5: ["순례자의 투구", "잔재의 반지"],
	6: ["산호 흉갑", "조류의 목걸이"],
	7: ["등불 사제의 관", "빛바랜 성검"],
	8: ["감독관의 철갑", "감시탑 인장"],
	9: ["역류의 검", "역행자의 두건"],
	10: ["원초의 갑주", "원초의 반지"],
}
## 동서남북 던전 전용 드랍(현재는 부모 지역에 흡수됨). 그 지역에 가야만 나오는 아이템이다.
const AREA_ITEM_DROPS := {
	"glade": "황혼의 부적",
	"marsh_deep": "가라앉은 목걸이",
	"frost_gorge": "빙하의 파편",
	"ash_ridge": "용의 비늘",
}
const CHAPTER_STONE_DROPS := {
	1: ["홍옥", "벽옥", "자수정", "황옥"],
	2: ["홍옥", "벽옥", "자수정", "황옥", "홍염석"],
	3: ["홍염석", "서리결정"],
	4: ["홍염석", "서리결정", "용의눈"],
	5: ["홍염석", "서리결정", "용의눈"],
	6: ["홍염석", "서리결정", "용의눈"],
	7: ["홍염석", "서리결정", "용의눈"],
	8: ["홍염석", "서리결정", "용의눈"],
	9: ["홍염석", "서리결정", "용의눈"],
	10: ["홍염석", "서리결정", "용의눈"],
}


func boss_drop(boss_key: String) -> String:
	return str(BOSS_DROPS.get(boss_key, ""))


func boss_drop_extra(boss_key: String) -> String:
	return str(BOSS_DROPS_EXTRA.get(boss_key, ""))


func roll_chapter_item() -> String:
	var pool: Array = CHAPTER_ITEM_DROPS.get(chapter, [])
	return str(pool[randi() % pool.size()]) if not pool.is_empty() else ""


func area_item(area: String) -> String:
	return str(AREA_ITEM_DROPS.get(area, ""))


func roll_chapter_stone() -> String:
	var pool: Array = CHAPTER_STONE_DROPS.get(chapter, [])
	return str(pool[randi() % pool.size()]) if not pool.is_empty() else ""


## 슬롯별 착용 중인 장비. weapon/armor 변수는 저장 파일 호환을 위해 남겨 둔다.
var equipped := {"weapon": "낡은 검", "armor": "여행자 옷", "helmet": "", "trinket": "", "trinket2": "", "spirit": ""}
## 슬롯별로 지금 낀 그 물건의 item_uid. 착용 칸의 강화 단계를 정확히
## 짚는 데 쓴다(이름만 보면 같은 이름 여분 장비와 구분이 안 된다).
## equip()을 거치지 않고 equipped를 직접 건드리면(테스트 등) 0으로
## 남고, 그 슬롯은 강화 보너스 없이(미강화 취급) 계산된다.
var equipped_uid := {"weapon": 0, "armor": 0, "helmet": 0, "trinket": 0, "trinket2": 0, "spirit": 0}
## 보유한 마법돌 개수. stone_id -> 개수.
var stone_inventory := {}
## 장비별로 박아 넣은 마법돌. item -> [stone_id, ...]. 뺄 수는 없다 - 강화처럼
## 한 방향으로만 간다.
var socketed := {}


func add_stone(stone_id: String, amount := 1) -> void:
	stone_inventory[stone_id] = mini(int(stone_inventory.get(stone_id, 0)) + amount, 99)


## 등급이 주는 소켓 수. 장비 자체에 소켓이 있는 게 아니라 등급이 정한다 -
## 같은 표를 두 번 안 쓰려고.
func socket_count(item: String) -> int:
	return int(SOCKETS_BY_RARITY.get(rarity_of(item), 0))


func sockets_used(item: String, uid: int = -1) -> int:
	if uid == -1:
		uid = uid_of(item)
	return (socketed.get(uid, []) as Array).size()


func can_socket(item: String, stone_id: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	return EQUIPMENT.has(item) and STONES.has(stone_id) \
		and sockets_used(item, uid) < socket_count(item) \
		and int(stone_inventory.get(stone_id, 0)) > 0


func insert_stone(item: String, stone_id: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	if not can_socket(item, stone_id, uid):
		return false
	stone_inventory[stone_id] = int(stone_inventory[stone_id]) - 1
	if not socketed.has(uid):
		socketed[uid] = []
	(socketed[uid] as Array).append(stone_id)
	_recalc_bonuses()
	return true


## 소켓에 박힌 돌이 주는 몫. field 는 atk/def/hp/spd/crit. 착용 중인
## 칸의 소켓만 센다 - 예전엔 이름으로만 묶여서 창고에 넣어 둔 사본까지
## 스탯에 영구히 반영되는 버그가 있었다.
func stone_bonus(field: String) -> float:
	var total := 0.0
	for slot in SLOTS:
		var uid := int(equipped_uid.get(slot, 0))
		if uid == 0:
			continue
		for stone_id in socketed.get(uid, []):
			total += float(STONES.get(stone_id, {}).get(field, 0))
	return total


## 지금 장비한 세트 조각 수. set_id -> 개수.
func _equipped_set_counts() -> Dictionary:
	var counts := {}
	for slot_key in SLOTS:
		var item: String = str(equipped.get(slot_key, ""))
		if item == "":
			continue
		var set_id := str(item_data(item).get("set", ""))
		if set_id != "":
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


## 세트 효과가 주는 몫. 장비한 세트 조각 수가 기준을 넘으면 더한다.
func set_bonus(field: String) -> float:
	var total := 0.0
	for set_id in _equipped_set_counts():
		var bonuses: Dictionary = SETS.get(set_id, {}).get("bonuses", {})
		var have: int = _equipped_set_counts()[set_id]
		for threshold in bonuses:
			if have >= int(threshold):
				total += float(bonuses[threshold].get(field, 0))
	return total


## 지금 장비한 세트의 이름과 조각 수. 능력치 화면이 보여 준다.
func active_set_summary() -> Array[String]:
	var out: Array[String] = []
	for set_id in _equipped_set_counts():
		var data: Dictionary = SETS.get(set_id, {})
		var total: int = (data.get("pieces", []) as Array).size()
		var have: int = _equipped_set_counts()[set_id]
		var line := "%s (%d/%d)" % [str(data.get("name", set_id)), have, total]
		if have >= total:
			var special := str(SET_SPECIAL.get(set_id, ""))
			if special != "":
				line += "\n  ★ %s" % str(SET_SPECIAL_DESC.get(special, ""))
		out.append(line)
	return out


func _new_uid() -> int:
	_uid_seq += 1
	return _uid_seq


## inventory/item_uid가 어긋나면(테스트가 inventory 배열을 직접 건드린
## 경우) 새 번호로 다시 채운다. 실제 플레이는 add_item 등 래퍼만 거치므로
## 항상 맞물려 있어 여기 걸릴 일이 없다.
func _sync_item_uid() -> void:
	if item_uid.size() != inventory.size():
		item_uid.clear()
		for i in inventory.size():
			item_uid.append(_new_uid())


func _sync_storage_uid() -> void:
	if storage_uid.size() != storage.size():
		storage_uid.clear()
		for i in storage.size():
			storage_uid.append(_new_uid())


## 이름만 갖고 있을 때 가방에서 그 이름의 첫 번째 칸이 가진 고유 번호를
## 찾는다. 없으면 0("번호 없음"). 강화·소켓처럼 물리적으로 딱 한 벌을
## 가리켜야 하는 함수들이 uid를 안 받았을 때 이걸로 기본 대상을 정한다.
func uid_of(item: String) -> int:
	_sync_item_uid()
	var idx := inventory.find(item)
	return item_uid[idx] if idx >= 0 else 0


## UI가 item_uid/storage_uid 배열을 인덱스로 직접 읽기 전에 부른다.
## 화면 새로고침·입력 처리 함수 맨 위에서 호출해 두면 그 뒤로는 배열을
## 안전하게 바로 인덱싱할 수 있다.
func sync_uids() -> void:
	_sync_item_uid()
	_sync_storage_uid()


func add_item(item: String) -> void:
	_sync_item_uid()
	inventory.append(item)
	item_uid.append(_new_uid())


## 몬스터가 떨어뜨린 장비 전용. 잡몹은 45%, 보스는 확정으로 옵션이 붙는다.
func add_dropped_item(item: String, boss: bool) -> void:
	add_item(item)
	if EQUIPMENT.has(item) and (boss or randf() < AFFIX_CHANCE_MOB):
		affixes[item_uid.back()] = roll_affixes(item, boss)


## 잡몹: 1줄 60% / 2줄 30% / 3줄 10%. 보스: 2줄 60% / 3줄 40%.
func roll_affixes(item: String, boss: bool) -> Dictionary:
	var r := randi() % 100
	var lines := (2 if r < 60 else 3) if boss else (1 if r < 60 else (2 if r < 90 else 3))
	var keys := AFFIX_KEYS.duplicate()
	keys.shuffle()
	var lv := int(item_data(item).get("level", 1))
	var rolled := {}
	for i in lines:
		var range_: Array = AFFIX_RANGE[keys[i]]
		rolled[keys[i]] = maxi(1, int(round(lv * randf_range(range_[0], range_[1]))))
	return rolled


func affix_of(uid: int) -> Dictionary:
	return affixes.get(uid, {})


func affix_prefix(uid: int) -> String:
	var rolled := affix_of(uid)
	if rolled.is_empty():
		return ""
	return str(AFFIX_PREFIX[rolled.size() if rolled.size() > 1 else rolled.keys()[0]])


func affix_bonus(key: String) -> int:
	var total := 0
	for slot in SLOTS:
		total += int(affix_of(int(equipped_uid.get(slot, 0))).get(key, 0))
	return total


## 대장간 옵션 재굴림(감독 2026-09-08). 강화석 1개 + 장비 가격의 절반(최소
## 50G). 붙어 있던 옵션은 사라지고 잡몹 드랍 분포(1~3줄)로 새로 굴린다.
## 상점/보상 장비도 여기서 옵션을 얻을 수 있다.
func reroll_cost(item: String) -> Dictionary:
	return {"stones": 1, "gold": maxi(50, int(item_data(item).get("price", 20)) / 2)}


func reroll_affixes(item: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	if not EQUIPMENT.has(item):
		return false
	var cost := reroll_cost(item)
	if gold < int(cost["gold"]) or int(materials[MATERIAL]) < int(cost["stones"]):
		return false
	gold -= int(cost["gold"])
	materials[MATERIAL] -= int(cost["stones"])
	affixes[uid] = roll_affixes(item, false)
	_recalc_bonuses()
	return true


func item_data(item: String) -> Dictionary:
	return EQUIPMENT.get(item, {})


## 무기 종류. "melee" 또는 "bow". 활은 화살을 쏜다.
func weapon_kind() -> String:
	return str(item_data(str(equipped.get("weapon", ""))).get("kind", "melee"))


## 손에 들려 그릴 무기 그림 이름. assets/items/hand/<이름>.png 를 쓴다.
## 없으면(활 등) 빈 문자열 — 손에 아무것도 안 그린다.
func weapon_hand() -> String:
	return str(item_data(str(equipped.get("weapon", ""))).get("hand", ""))


## 낀 정령 인장의 패시브 효과 이름. 없으면 빈 문자열.
func spirit_effect() -> String:
	return str(item_data(str(equipped.get("spirit", ""))).get("spirit", ""))


func rarity_of(item: String) -> String:
	return str(item_data(item).get("rarity", "일반"))


## 착용 중인지. 슬롯이 늘어도 이 함수만 보면 된다.
func is_equipped(item: String) -> bool:
	return equipped.values().has(item)


## 가방의 이 칸이 "착용 중인 그 한 벌"인지. 이름만 보고 판단하면 같은
## 이름의 여분(중복) 아이템까지 전부 착용 중으로 잘못 표시된다.
## equip()으로 낀 경우 그 칸의 고유 번호로 딱 한 벌만 가려낸다. equipped를
## 직접 건드려서(테스트 등) 번호가 없거나 지금 가방 상태와 안 맞으면
## 예전처럼 이름이 가방에서 처음 나오는 칸을 그 자리로 본다.
func is_equipped_at(index: int) -> bool:
	_sync_item_uid()
	if index < 0 or index >= inventory.size():
		return false
	var item := inventory[index]
	if not is_equipped(item):
		return false
	var slot := equipped_slot_of(item)
	var slot_uid := int(equipped_uid.get(slot, 0))
	if slot_uid != 0:
		var slot_idx := item_uid.find(slot_uid)
		if slot_idx >= 0 and inventory[slot_idx] == item:
			return slot_idx == index
	return inventory.find(item) == index


## 레벨이 모자라면 못 든다. 원본처럼 장비에 레벨 제한을 둔다.
func can_equip(item: String) -> bool:
	var data := item_data(item)
	return not data.is_empty() and level >= int(data.get("level", 1))


func equip(item: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	if uid == 0 or not can_equip(item):
		return false
	var data := item_data(item)
	var slot := _equip_slot_for(str(data["slot"]), item)
	equipped[slot] = item
	equipped_uid[slot] = uid
	_recalc_bonuses()
	return true


## 이 아이템이 지금 낀 슬롯 이름. 안 끼고 있으면 빈 문자열.
func equipped_slot_of(item: String) -> String:
	for slot in SLOTS:
		if str(equipped.get(slot, "")) == item:
			return slot
	return ""


## 장비를 벗는다. 무기·갑옷은 맨몸이 될 수 없는 슬롯이라 최초 기본
## 장비(낡은 검/여행자 옷)로 되돌리고, 나머지 슬롯은 그냥 빈 자리로
## 돌아간다("아이폰에서 벗는 기능이 없다" 피드백 - 원래 갈아 끼우는
## 것만 되고 그냥 벗기는 게 안 됐다).
func unequip(slot: String) -> bool:
	if not SLOTS.has(slot) or str(equipped.get(slot, "")) == "":
		return false
	if slot == "weapon":
		equipped[slot] = DEFAULT_WEAPON
	elif slot == "armor":
		equipped[slot] = DEFAULT_ARMOR
	else:
		equipped[slot] = ""
	equipped_uid[slot] = 0
	_recalc_bonuses()
	return true


## 장신구는 슬롯이 둘(trinket/trinket2)이라 어디에 낄지 골라야 한다.
## 이미 낀 같은 물건이면 그 자리를 그대로 쓰고, 아니면 빈 자리부터 채우고,
## 둘 다 찼으면 첫 번째 자리를 새 걸로 바꾼다.
func _equip_slot_for(base_slot: String, item: String) -> String:
	if base_slot != "trinket":
		return base_slot
	if equipped.get("trinket", "") == item or equipped.get("trinket2", "") == item:
		return "trinket" if equipped.get("trinket", "") == item else "trinket2"
	if str(equipped.get("trinket", "")) == "":
		return "trinket"
	if str(equipped.get("trinket2", "")) == "":
		return "trinket2"
	return "trinket"


## 착용 장비의 능력치를 합산한다. 플레이어는 이 값만 읽는다.
func _recalc_bonuses() -> void:
	var totals := {"atk": 0, "def": 0, "hp": 0, "spd": 0}
	for slot in SLOTS:
		var item: String = str(equipped.get(slot, ""))
		if item == "":
			continue
		var data := item_data(item)
		var scale := 1.0 + enhance_of(item, int(equipped_uid.get(slot, 0))) * ENHANCE_STEP
		for key in totals:
			totals[key] += int(round(int(data.get(key, 0)) * scale))
	for key in totals:
		totals[key] += int(stone_bonus(key))
		totals[key] += int(set_bonus(key))
		totals[key] += affix_bonus(key)
	attack_bonus = totals["atk"]
	defense_bonus = totals["def"]
	health_bonus = totals["hp"]
	speed_bonus = totals["spd"]
	weapon = str(equipped.get("weapon", ""))
	armor = str(equipped.get("armor", ""))


## 아이템 한 줄 설명. 인벤토리와 상점이 같은 문구를 쓴다. uid를 안 주면
## 이름으로 가방의 첫 번째 칸을 찾는다(상점 미리보기처럼 실제 소유
## 인스턴스가 없을 땐 uid=0을 명시로 넘겨 항상 +0으로 보여 준다).
func enhance_of(item: String, uid: int = -1) -> int:
	if uid == -1:
		uid = uid_of(item)
	return int(enhance_levels.get(uid, 0))


## 다음 강화에 드는 값. 단계가 오를수록 비싸진다.
func enhance_cost(item: String, uid: int = -1) -> Dictionary:
	if uid == -1:
		uid = uid_of(item)
	var step := enhance_of(item, uid) + 1
	var base: int = int(item_data(item).get("price", 20))
	return {"stones": step, "gold": base * step / 2}


## 확정 강화(파괴·하락 없이 무조건 성공) 비용. 확률 강화보다 훨씬
## 비싸게 받아 "그냥 늘 이것만 쓰면 되는" 상위 호환이 되지 않게 한다.
func enhance_guaranteed_cost(item: String, uid: int = -1) -> Dictionary:
	if uid == -1:
		uid = uid_of(item)
	var base_cost := enhance_cost(item, uid)
	var mult := ENHANCE_GUARANTEED_MULT
	if enhance_is_risky(item, uid):
		mult *= ENHANCE_GUARANTEED_RISK_MULT
	return {"stones": int(base_cost["stones"]) * mult, "gold": int(base_cost["gold"]) * mult}


func can_enhance_guaranteed(item: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	if not EQUIPMENT.has(item) or enhance_of(item, uid) >= MAX_ENHANCE:
		return false
	if uid == 0 or not (item_uid.has(uid) or equipped_uid.values().has(uid)):
		return false
	var cost := enhance_guaranteed_cost(item, uid)
	return materials[MATERIAL] >= int(cost["stones"]) and gold >= int(cost["gold"])


func can_enhance(item: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	if not EQUIPMENT.has(item) or enhance_of(item, uid) >= MAX_ENHANCE:
		return false
	if uid == 0 or not (item_uid.has(uid) or equipped_uid.values().has(uid)):
		return false
	var cost := enhance_cost(item, uid)
	return materials[MATERIAL] >= int(cost["stones"]) and gold >= int(cost["gold"])


## 다음 단계로 갈 성공률. 표를 벗어나면(이미 최대) 0.
func enhance_chance(item: String, uid: int = -1) -> float:
	if uid == -1:
		uid = uid_of(item)
	var step := enhance_of(item, uid)
	if step < 0 or step >= ENHANCE_RATES.size():
		return 0.0
	return float(ENHANCE_RATES[step])


## +6 이상을 시도하는 위험 구간인지. 이 구간부터 실패하면 파괴가 섞인다.
func enhance_is_risky(item: String, uid: int = -1) -> bool:
	if uid == -1:
		uid = uid_of(item)
	return enhance_of(item, uid) >= ENHANCE_RISK_STEP


## 한 단계 올린다. 결과를 문자열로 준다:
##   "blocked"   재료·골드가 모자라거나 이미 최대 단계다
##   "success"   성공, 한 단계 오름
##   "fail"      실패, 한 단계 하락(0 밑으로는 안 내려감)
##   "warded"    위험 구간에서 실패했지만 부적을 써서 하락으로 막음
##   "destroyed" 위험 구간에서 실패해 아예 사라짐
## uid를 안 주면 이름의 첫 번째 칸을 대상으로 한다. 같은 이름 여분
## 장비를 구분해서 강화하려면 호출자가 정확한 uid를 넘겨야 한다
## (대장간 화면은 인벤토리 칸 번호로 uid를 골라 넘긴다).
func enhance(item: String, uid: int = -1) -> String:
	if uid == -1:
		uid = uid_of(item)
	if not can_enhance(item, uid):
		return "blocked"
	var cost := enhance_cost(item, uid)
	materials[MATERIAL] -= int(cost["stones"])
	gold -= int(cost["gold"])
	var step := enhance_of(item, uid)
	if randf() < enhance_chance(item, uid):
		enhance_levels[uid] = step + 1
		_recalc_bonuses()
		return "success"
	if enhance_is_risky(item, uid):
		if enhance_wards > 0:
			enhance_wards -= 1
			enhance_levels[uid] = maxi(step - 1, 0)
			_recalc_bonuses()
			return "warded"
		if randf() < ENHANCE_DESTROY_CHANCE:
			_destroy_item(item, uid)
			return "destroyed"
	enhance_levels[uid] = maxi(step - 1, 0)
	_recalc_bonuses()
	return "fail"


## 확정 강화. 실패·파괴 없이 강화석(+골드)만 더 내고 반드시 한 단계
## 오른다. "blocked"(재료·골드 부족이거나 이미 최대) 아니면 "success".
func enhance_guaranteed(item: String, uid: int = -1) -> String:
	if uid == -1:
		uid = uid_of(item)
	if not can_enhance_guaranteed(item, uid):
		return "blocked"
	var cost := enhance_guaranteed_cost(item, uid)
	materials[MATERIAL] -= int(cost["stones"])
	gold -= int(cost["gold"])
	enhance_levels[uid] = enhance_of(item, uid) + 1
	_recalc_bonuses()
	return "success"


## 파괴됐을 때 정리. 착용 중이었으면 벗기고, 박혀 있던 마법돌은 사라진다.
## 정확히 그 인스턴스(uid)만 지운다 - 같은 이름의 다른 사본은 그대로 남는다.
func _destroy_item(item: String, uid: int = -1) -> void:
	if uid == -1:
		uid = uid_of(item)
	enhance_levels.erase(uid)
	socketed.erase(uid)
	affixes.erase(uid)
	var idx := item_uid.find(uid)
	if idx >= 0:
		inventory.remove_at(idx)
		item_uid.remove_at(idx)
	for slot in SLOTS:
		if uid != 0 and int(equipped_uid.get(slot, 0)) == uid:
			equipped[slot] = ""
			equipped_uid[slot] = 0
	_recalc_bonuses()


## 제작 - 보스의 파편을 모아 전설 장비를 만든다. 파편은 보스 한 마리당
## 확정이 아니라 10~30개 무작위(BOSS_FRAGMENT_MIN~MAX)로만 나오고, 보스
## 넷을 한 판에서 다 잡아도 최악의 경우 40개(10×4)뿐이다. 그래서 파편
## 요구량 합은 그 최저치(40)를 넘지 않게 잡되 - 진짜 어려운 부분은
## 동서남북 사냥터(AREA_ITEM_DROPS)에서만 나오는 전용 아이템을 하나씩
## 구해 와야 한다는 점이다. 그 아이템들은 해당 지역 몬스터에게서 낮은
## 확률로만 나와, 던전을 직접 돌아야 제작이 끝난다.
const CRAFT_RECIPES := {
	"용린 갑주": {"fragments": 8, "stones": 5, "gold": 700, "area_item": "황혼의 부적"},
	"용아 대검": {"fragments": 10, "stones": 6, "gold": 850, "area_item": "가라앉은 목걸이"},
	"용의 인장": {"fragments": 11, "stones": 6, "gold": 950, "area_item": "빙하의 파편"},
	"용각 투구": {"fragments": 11, "stones": 7, "gold": 1100, "area_item": "용의 비늘"},
}


## 탑 전용 재료. 그 난이도 탑의 몬스터만 낮은 확률로 떨어뜨린다.
## 아래 TOWER_CRAFT_RECIPES에서 "초월" 등급 장비를 만들 때 쓴다.
const TOWER_MATERIALS := {
	"easy": "파수의 결정", "normal": "심판의 결정", "hard": "종언의 결정",
	"hell": "겁화의 결정", "abyss": "천공의 결정",
}
var tower_material_counts := {"easy": 0, "normal": 0, "hard": 0, "hell": 0, "abyss": 0}
## 100층까지 클리어한 탑 난이도들. 개수가 곧 이름 옆에 붙는 별 개수다.
## TOWER_TIERS 순서(쉬움→심연)로 쌓인다 - 순서대로만 깰 수 있으니
## 자연히 그 순서로 들어간다.
var tower_titles: Array[String] = []


func add_tower_title(tier: String) -> void:
	if not tower_titles.has(tier):
		tower_titles.append(tier)


func tower_material_name(tier: String) -> String:
	return str(TOWER_MATERIALS.get(tier, ""))


func add_tower_material(tier: String, amount := 1) -> void:
	if tower_material_counts.has(tier):
		tower_material_counts[tier] = mini(int(tower_material_counts[tier]) + amount, 99)


## 탑 전용 "초월" 등급 20종(TOWER_DESIGN.md 6절) 제작 레시피. 제작
## 가능 조건은 그 난이도 탑이 해금됐는지(tower_tier_unlocked)를 그대로
## 쓴다 - 각 난이도가 이전 난이도 100층 클리어를 요구하는 사슬이라,
## "쉬움 깨야 어려움도 제작 가능"이 자연스럽게 성립한다.
## "제작이 너무 쉽다, 쉬운 몹부터 어려운 몹까지 재료를 모아서 만들게"
## 피드백으로 재료를 그 난이도 결정 하나에서 "needs"(여러 난이도 결정
## 조합)로 바꿨다. 난이도가 오를수록 필요한 결정 종류가 늘어 쉬움은
## 1종, 심연(천공)은 5종 + 강화석까지 총 6종을 모아야 한다.
const TOWER_CRAFT_RECIPES := {
	"파수꾼의 검": {"tier": "easy", "needs": {"easy": 6}, "stones": 6, "gold": 1300},
	"파수꾼의 갑주": {"tier": "easy", "needs": {"easy": 6}, "stones": 6, "gold": 1300},
	"파수꾼의 투구": {"tier": "easy", "needs": {"easy": 6}, "stones": 6, "gold": 1300},
	"파수꾼의 인장": {"tier": "easy", "needs": {"easy": 6}, "stones": 6, "gold": 1300},
	"심판자의 검": {"tier": "normal", "needs": {"easy": 3, "normal": 6}, "stones": 7, "gold": 1700},
	"심판자의 갑주": {"tier": "normal", "needs": {"easy": 3, "normal": 6}, "stones": 7, "gold": 1700},
	"심판자의 투구": {"tier": "normal", "needs": {"easy": 3, "normal": 6}, "stones": 7, "gold": 1700},
	"심판자의 인장": {"tier": "normal", "needs": {"easy": 3, "normal": 6}, "stones": 7, "gold": 1700},
	"종언의 검": {"tier": "hard", "needs": {"easy": 3, "normal": 3, "hard": 6}, "stones": 8, "gold": 2200},
	"종언의 갑주": {"tier": "hard", "needs": {"easy": 3, "normal": 3, "hard": 6}, "stones": 8, "gold": 2200},
	"종언의 투구": {"tier": "hard", "needs": {"easy": 3, "normal": 3, "hard": 6}, "stones": 8, "gold": 2200},
	"종언의 인장": {"tier": "hard", "needs": {"easy": 3, "normal": 3, "hard": 6}, "stones": 8, "gold": 2200},
	"겁화의 검": {"tier": "hell", "needs": {"easy": 2, "normal": 2, "hard": 3, "hell": 6}, "stones": 9, "gold": 2900},
	"겁화의 갑주": {"tier": "hell", "needs": {"easy": 2, "normal": 2, "hard": 3, "hell": 6}, "stones": 9, "gold": 2900},
	"겁화의 투구": {"tier": "hell", "needs": {"easy": 2, "normal": 2, "hard": 3, "hell": 6}, "stones": 9, "gold": 2900},
	"겁화의 인장": {"tier": "hell", "needs": {"easy": 2, "normal": 2, "hard": 3, "hell": 6}, "stones": 9, "gold": 2900},
	"천공의 검": {"tier": "abyss", "needs": {"easy": 2, "normal": 2, "hard": 2, "hell": 3, "abyss": 6}, "stones": 10, "gold": 3800},
	"천공의 갑주": {"tier": "abyss", "needs": {"easy": 2, "normal": 2, "hard": 2, "hell": 3, "abyss": 6}, "stones": 10, "gold": 3800},
	"천공의 투구": {"tier": "abyss", "needs": {"easy": 2, "normal": 2, "hard": 2, "hell": 3, "abyss": 6}, "stones": 10, "gold": 3800},
	"천공의 인장": {"tier": "abyss", "needs": {"easy": 2, "normal": 2, "hard": 2, "hell": 3, "abyss": 6}, "stones": 10, "gold": 3800},
}


## 5~10장 세트 장비 제작. 그 장의 정수 + 보스의 파편 + 강화석 + 골드.
## 검·투구는 보스 확정 드랍이기도 하지만 여기서도 만들 수 있다.
const CHAPTER_CRAFT_RECIPES := {
	"태초의 검": {"chapter": 5, "essence": 12, "fragments": 40, "stones": 15, "gold": 4300},
	"태초의 갑주": {"chapter": 5, "essence": 10, "fragments": 30, "stones": 12, "gold": 4300},
	"태초의 투구": {"chapter": 5, "essence": 8, "fragments": 25, "stones": 10, "gold": 4300},
	"태초의 인장": {"chapter": 5, "essence": 6, "fragments": 20, "stones": 8, "gold": 4300},
	"심해의 검": {"chapter": 6, "essence": 12, "fragments": 40, "stones": 15, "gold": 4800},
	"심해의 갑주": {"chapter": 6, "essence": 10, "fragments": 30, "stones": 12, "gold": 4800},
	"심해의 투구": {"chapter": 6, "essence": 8, "fragments": 25, "stones": 10, "gold": 4800},
	"심해의 인장": {"chapter": 6, "essence": 6, "fragments": 20, "stones": 8, "gold": 4800},
	"성광의 검": {"chapter": 7, "essence": 12, "fragments": 40, "stones": 15, "gold": 5400},
	"성광의 갑주": {"chapter": 7, "essence": 10, "fragments": 30, "stones": 12, "gold": 5400},
	"성광의 투구": {"chapter": 7, "essence": 8, "fragments": 25, "stones": 10, "gold": 5400},
	"성광의 인장": {"chapter": 7, "essence": 6, "fragments": 20, "stones": 8, "gold": 5400},
	"침묵의 검": {"chapter": 8, "essence": 12, "fragments": 40, "stones": 15, "gold": 6000},
	"침묵의 갑주": {"chapter": 8, "essence": 10, "fragments": 30, "stones": 12, "gold": 6000},
	"침묵의 투구": {"chapter": 8, "essence": 8, "fragments": 25, "stones": 10, "gold": 6000},
	"침묵의 인장": {"chapter": 8, "essence": 6, "fragments": 20, "stones": 8, "gold": 6000},
	"역행의 검": {"chapter": 9, "essence": 12, "fragments": 40, "stones": 15, "gold": 6700},
	"역행의 갑주": {"chapter": 9, "essence": 10, "fragments": 30, "stones": 12, "gold": 6700},
	"역행의 투구": {"chapter": 9, "essence": 8, "fragments": 25, "stones": 10, "gold": 6700},
	"역행의 인장": {"chapter": 9, "essence": 6, "fragments": 20, "stones": 8, "gold": 6700},
	"근원의 검": {"chapter": 10, "essence": 12, "fragments": 40, "stones": 15, "gold": 7500},
	"근원의 갑주": {"chapter": 10, "essence": 10, "fragments": 30, "stones": 12, "gold": 7500},
	"근원의 투구": {"chapter": 10, "essence": 8, "fragments": 25, "stones": 10, "gold": 7500},
	"근원의 인장": {"chapter": 10, "essence": 6, "fragments": 20, "stones": 8, "gold": 7500},
}


func chapter_essence(ch: int) -> String:
	return str(CHAPTER_ESSENCES.get(ch, ""))


func add_essence(essence: String, amount := 1) -> void:
	if not CHAPTER_ESSENCES.values().has(essence):
		return
	materials[essence] = mini(int(materials.get(essence, 0)) + amount, ESSENCE_CAP)


func can_craft(item: String) -> bool:
	if CHAPTER_CRAFT_RECIPES.has(item):
		var cost: Dictionary = CHAPTER_CRAFT_RECIPES[item]
		var essence := chapter_essence(int(cost["chapter"]))
		return int(materials.get(essence, 0)) >= int(cost["essence"]) \
			and materials[BOSS_FRAGMENT] >= int(cost["fragments"]) \
			and materials[MATERIAL] >= int(cost["stones"]) and gold >= int(cost["gold"])
	if CRAFT_RECIPES.has(item):
		var cost: Dictionary = CRAFT_RECIPES[item]
		var area_item_name := str(cost.get("area_item", ""))
		return materials[BOSS_FRAGMENT] >= int(cost["fragments"]) \
			and materials[MATERIAL] >= int(cost["stones"]) and gold >= int(cost["gold"]) \
			and (area_item_name == "" or inventory.has(area_item_name))
	if TOWER_CRAFT_RECIPES.has(item):
		var cost: Dictionary = TOWER_CRAFT_RECIPES[item]
		if not tower_tier_unlocked(str(cost["tier"])):
			return false
		var needs: Dictionary = cost["needs"]
		for need_tier in needs:
			if int(tower_material_counts.get(need_tier, 0)) < int(needs[need_tier]):
				return false
		return materials[MATERIAL] >= int(cost["stones"]) and gold >= int(cost["gold"])
	return false


## 제작한 장비는 바로 입혀 준다. 안 그러면 만들어도 겉모습·능력치가
## 안 바뀐 것처럼 보인다("장비를 입고있지가않아" 피드백) - 어차피
## 비싼 재료 써서 만드는 건 항상 지금 낀 것보다 좋은 장비다.
func craft(item: String) -> bool:
	if not can_craft(item):
		return false
	if CHAPTER_CRAFT_RECIPES.has(item):
		var cost: Dictionary = CHAPTER_CRAFT_RECIPES[item]
		var essence := chapter_essence(int(cost["chapter"]))
		materials[essence] = int(materials[essence]) - int(cost["essence"])
		materials[BOSS_FRAGMENT] -= int(cost["fragments"])
		materials[MATERIAL] -= int(cost["stones"])
		gold -= int(cost["gold"])
		add_item(item)
		equip(item, item_uid[item_uid.size() - 1])
		return true
	if CRAFT_RECIPES.has(item):
		var cost: Dictionary = CRAFT_RECIPES[item]
		materials[BOSS_FRAGMENT] -= int(cost["fragments"])
		materials[MATERIAL] -= int(cost["stones"])
		gold -= int(cost["gold"])
		var area_item_name := str(cost.get("area_item", ""))
		if area_item_name != "":
			_destroy_item(area_item_name)
		add_item(item)
		equip(item, item_uid[item_uid.size() - 1])
		return true
	var cost: Dictionary = TOWER_CRAFT_RECIPES[item]
	var needs: Dictionary = cost["needs"]
	for need_tier in needs:
		tower_material_counts[need_tier] = int(tower_material_counts[need_tier]) - int(needs[need_tier])
	materials[MATERIAL] -= int(cost["stones"])
	gold -= int(cost["gold"])
	add_item(item)
	equip(item, item_uid[item_uid.size() - 1])
	return true


func add_material(amount := 1) -> void:
	materials[MATERIAL] = mini(materials[MATERIAL] + amount, 99)


func add_boss_fragments(amount: int) -> void:
	materials[BOSS_FRAGMENT] = mini(materials[BOSS_FRAGMENT] + amount, BOSS_FRAGMENT_CAP)


## 중간보스가 확정 드랍하는 전직의 돌 1개. 3타입 중 균등 랜덤(1/3).
## SECOND_JOB_DESIGN.md 5절 - 드랍 확률/타입 근거.
func add_random_job_stone() -> String:
	var stone := str(JOB_STONES[randi() % JOB_STONES.size()])
	add_job_stone(stone)
	return stone


func add_job_stone(stone: String) -> void:
	materials[stone] = mini(int(materials.get(stone, 0)) + 1, JOB_STONE_CAP)


## 탑 - 스토리 클리어 후 여는 엔드게임 다층 던전. 자세한 설계는
## TOWER_DESIGN.md 참고. 난이도마다 최고 도달 층(tower_progress)만
## 저장하고, 진행 중인 층(tower_floor)은 저장 파일에 안 넣는다 - 앱을
## 껐다 켜면 마지막으로 "깬" 층부터 다시 시작하면 충분하다.
var tower_progress := {"easy": 0, "normal": 0, "hard": 0, "hell": 0, "abyss": 0}
var tower_active := false
var tower_floor := 0
var tower_difficulty := "easy"

const TOWER_FLOOR_COUNT := 100
const TOWER_TIERS := {
	"easy":   {"name": "쉬움",   "mob_mult": 1.0, "reward_mult": 1.0, "requires": ""},
	"normal": {"name": "보통",   "mob_mult": 1.5, "reward_mult": 1.3, "requires": "easy"},
	"hard":   {"name": "어려움", "mob_mult": 2.2, "reward_mult": 1.7, "requires": "normal"},
	"hell":   {"name": "헬",     "mob_mult": 3.2, "reward_mult": 2.2, "requires": "hard"},
	"abyss":  {"name": "심연",   "mob_mult": 4.5, "reward_mult": 3.0, "requires": "hell"},
}
## 층 1(쉬움 기준)의 기준 수치. Phase 6 밸런스 점검에서 원래
## TIERS[1](1장 초반 잡몹)과 같은 값으로 잡았던 게 문제로 드러났다 -
## 탑은 스토리를 다 깬 뒤에나 들어가는 엔드게임 콘텐츠인데, 시작이
## 게임 맨 처음 잡몹 수준이라 사실상 도전이 안 됐다("맨 몬스터만 잡고
## 다음층인지도 모르겠다" 피드백의 근본 원인 중 하나). TIERS[6](4장
## 잡몹) 수준으로 올려서, 쉬움 1층부터도 스토리 후반부 정도의 긴장감은
## 있게 했다. 방어는 60% 감쇄 상한이 있어 아무리 층수·난이도가 올라가도
## 안전판이 걸린다.
const TOWER_BASE_STATS := {"hp": 470, "damage": 58, "defense": 20}
## 난이도별 몬스터 풀. 층마다 여기서 섞어 뽑아 한 종류만 반복되지 않게
## 한다. 새 몬스터를 그리지 않고 기존 KINDS를 재활용하되, 난이도가
## 오를수록 이야기 후반부·사냥터 최상급 몬스터로 채워 "탑을 오를수록
## 더 강한 놈들이 나온다"는 체감을 준다.
# 각 난이도 풀에 "tower_warden"(탑 전용, enemy.gd KINDS 참고)을 공통으로
# 섞어 넣어 "탑에서만 보는 놈"이라는 느낌을 준다(TOWER_DESIGN.md §13).
const TOWER_MONSTER_POOLS := {
	"easy": ["beast", "mushroom", "bat", "slime", "tower_warden"],
	"normal": ["knight", "octopus", "kappa", "skull", "tower_warden"],
	"hard": ["panda", "owl", "larva", "spirit", "tower_warden"],
	"hell": ["flam", "cyclope", "skull", "knight", "tower_warden"],
	"abyss": ["eye", "frostbear", "mollusc", "dragon", "tower_warden"],
}


## 이 난이도에 들어갈 수 있는지. 맨 아래(쉬움)는 스토리 클리어가 조건,
## 그 위는 바로 아래 난이도를 100층까지 클리어해야 한다.
func tower_tier_unlocked(tier: String) -> bool:
	if not TOWER_TIERS.has(tier):
		return false
	var requires := str(TOWER_TIERS[tier].get("requires", ""))
	if requires == "":
		return game_cleared
	return int(tower_progress.get(requires, 0)) >= TOWER_FLOOR_COUNT


func tower_reward_mult(tier: String) -> float:
	return float(TOWER_TIERS.get(tier, {}).get("reward_mult", 1.0))


## 종합 전투력. 장비/강화/소켓이 최종 합산된 attack_bonus 등 4종 보너스에
## 투자한 능력치(stat_xxx)와 레벨을 얹는다. 탑 스킵 기준으로만 쓰는
## 값이라 정밀할 필요는 없고, "장비를 맞출수록 오른다"는 체감만 맞으면
## 된다. 방어/속도는 공격만큼 크지 않아 가중치를 낮춰 합산한다.
func combat_power() -> float:
	var atk := float(attack_bonus + stat_attack())
	var def := float(defense_bonus + perk_defense())
	var hp := float(health_bonus + stat_health())
	var spd := float(speed_bonus + stat_speed())
	var base := atk * 2.0 + def * 1.5 + hp * 0.25 + spd * 0.5
	return base * (1.0 + float(level) * 0.04)


## 이 난이도에서 전투력만으로 안전하게 시작할 수 있는 층. 기준은
## tower_floor_stats()가 주는 몬스터 HP·공격력이 combat_power 대비
## 감당할 만한 선까지다. TOWER_DESIGN.md 공식을 거꾸로 풀지 않고,
## 후보 층을 순서대로 훑어 처음으로 못 버티는 층 直前에서 멈춘다 -
## 100번 루프뿐이라 비용이 크지 않다.
func tower_power_floor(tier: String) -> int:
	var power := combat_power()
	var safe := 1
	for f in range(1, TOWER_FLOOR_COUNT + 1):
		var stats := tower_floor_stats(f, tier)
		# 몬스터 HP+공격력 합을 "이 층을 버티는 데 드는 힘"으로 보고,
		# 내 전투력이 그 절반을 넘으면 안전하다고 판단한다(여유 2배).
		var need := float(stats["hp"]) * 0.5 + float(stats["damage"]) * 3.0
		if power < need:
			break
		safe = f
	return safe


## 탑 진입 시 실제로 적용할 시작 층. "이미 깬 최고 층 + 1"(항상 보장된
## 최소값)과 전투력 기준 권장층 중 큰 쪽을 쓴다. 예를 들어 새로 해금한
## 난이도(진행도 0)라도 이미 장비를 다 맞춘 상태라면 전투력만큼 앞
## 층에서 시작하고, 반대로 진행도가 전투력보다 앞서 있으면(꾸준히
## 걸어서 올라온 경우) 그 진행도를 그대로 존중한다 - 어느 쪽이든
## 뒤로 물러나는 일은 없다.
func tower_entry_floor(tier: String) -> int:
	var by_power := tower_power_floor(tier)
	var by_progress := int(tower_progress.get(tier, 0)) + 1
	return clampi(maxi(by_power, by_progress), 1, TOWER_FLOOR_COUNT)


## 전투력 스킵으로 건너뛴 층수만큼 재료·골드를 한 번에 몰아준다.
## 몬스터를 잡지 않았으니 exp는 주지 않는다(계정 레벨은 사냥으로만).
func grant_tower_skip_reward(tier: String, skipped_floors: int) -> Dictionary:
	if skipped_floors <= 0:
		return {"gold": 0, "material": 0}
	var mult := tower_reward_mult(tier)
	var gold_gain := int(6 * mult * skipped_floors * 0.5)
	var material_gain := maxi(int(skipped_floors / 5), 1)
	gold += gold_gain
	add_tower_material(tier, material_gain)
	return {"gold": gold_gain, "material": material_gain}


## 10층 단위 마일스톤 보상. 10/25/50/75/100층은 몬스터 자체가 이미
## 미니보스·보스급으로 세지는데(tower_floor_stats 참고) 그 위험을
## 감수한 보람이 몬스터 개별 처치 보상뿐이라 체감이 약했다("탑 콘텐츠도
## 좀 손 보고" 요청으로 개선) - 그 층을 실제로 클리어하면 그 난이도
## 전용 결정(제작 재료)을 추가로 몰아준다. 25층 배수(더 센 보스급)는
## 10층 배수보다 2배 더 준다.
func tower_milestone_material(floor_num: int) -> int:
	if floor_num % 25 == 0:
		return 3
	if floor_num % 10 == 0:
		return 1
	return 0


## 층별 몬스터 능력치. 10층마다 미니보스(×1.6), 25/50/75/100층은
## 고정 보스급(×2.5)으로 한 번 더 튄다. TOWER_DESIGN.md 3절 공식 그대로.
func tower_floor_stats(floor_num: int, tier: String) -> Dictionary:
	var mult: float = float(TOWER_TIERS.get(tier, {}).get("mob_mult", 1.0))
	var step_mult := 1.0
	if floor_num % 25 == 0:
		step_mult = 2.5
	elif floor_num % 10 == 0:
		step_mult = 1.6
	return {
		"hp": int(TOWER_BASE_STATS["hp"] * (1.0 + floor_num * 0.045) * step_mult * mult),
		"damage": int(TOWER_BASE_STATS["damage"] * (1.0 + floor_num * 0.035) * step_mult * mult),
		"defense": int(TOWER_BASE_STATS["defense"] * (1.0 + floor_num * 0.03) * step_mult * mult),
	}


## 이번 층에 뽑을 몬스터 종류들. 같은 층은 항상 같은 조합이 나오게
## 층수+난이도로 씨앗을 고정한다(재입장해도 지형처럼 안 바뀜).
func tower_floor_monster_kinds(floor_num: int, tier: String, count: int) -> Array[String]:
	var pool: Array = TOWER_MONSTER_POOLS.get(tier, [])
	var kinds: Array[String] = []
	if pool.is_empty():
		return kinds
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_num * 131 + tier.hash()
	for i in count:
		kinds.append(str(pool[rng.randi() % pool.size()]))
	return kinds


## 강화 단계를 이름 뒤에 붙인다. 목록과 상세가 같은 표기를 쓴다. uid를
## 안 주면 가방의 첫 번째 칸 기준(상점 미리보기 등 소유 인스턴스가 없을
## 땐 uid=0을 명시로 넘겨 항상 +0으로 보여 준다).
func item_label(item: String, uid: int = -1) -> String:
	if uid == -1:
		uid = uid_of(item)
	var step := enhance_of(item, uid)
	var prefix := affix_prefix(uid)
	var name := item if prefix == "" else "%s %s" % [prefix, item]
	return name if step == 0 else "%s +%d" % [name, step]


func item_summary(item: String, uid: int = -1) -> String:
	if uid == -1:
		uid = uid_of(item)
	var data := item_data(item)
	if data.is_empty():
		return "기타 물품"
	var slot_label := str(SLOT_NAMES.get(data["slot"], "?"))
	if str(data.get("kind", "")) == "bow":
		slot_label = "활"
	var parts: Array[String] = ["%s · %s · Lv%d" % [
		slot_label, data["rarity"], int(data.get("level", 1))]]
	var scale := 1.0 + enhance_of(item, uid) * ENHANCE_STEP
	for key in [["atk", "공격"], ["def", "방어"], ["hp", "HP"], ["spd", "속도"]]:
		var value := int(data.get(key[0], 0))
		if value != 0:
			parts.append("%s +%d" % [key[1], int(round(value * scale))])
	for key in AFFIX_KEYS:
		var bonus := int(affix_of(uid).get(key, 0))
		if bonus != 0:
			parts.append("✦ %s +%d" % [AFFIX_LABEL[key], bonus])
	var sockets := socket_count(item)
	if sockets > 0:
		var stone_names: Array[String] = []
		for stone_id in socketed.get(uid, []):
			stone_names.append(str(STONES.get(stone_id, {}).get("name", stone_id)))
		var filled_text := "[%s]" % ", ".join(stone_names) if not stone_names.is_empty() else ""
		parts.append("소켓 %d/%d %s" % [stone_names.size(), sockets, filled_text])
	var set_id := str(data.get("set", ""))
	if set_id != "" and SETS.has(set_id):
		parts.append("세트: %s" % str(SETS[set_id]["name"]))
	var spirit_id := str(data.get("spirit", ""))
	if spirit_id != "":
		parts.append(str(SPIRIT_EFFECT_DESC.get(spirit_id, "")))
	return "\n".join(parts)


## qty - 묶음 구매 개수(전직의 돌 ×10). 상한을 넘기면 통째로 거절한다.
func buy(item: String, price: int, qty: int = 1) -> bool:
	if gold < price:
		return false
	# 상한에 닿았는데 골드만 빠지던 버그("9개 이후로 계속 사도 숫자가 안 오르던데").
	if item == "회복약" and potions >= potion_cap():
		return false
	if item == "부활의 깃털" and revive_potions >= 3:
		return false
	if item == ENHANCE_WARD and enhance_wards >= 9:
		return false
	if item == SCROLL_ITEM and scrolls + qty > MAX_SCROLLS:
		return false
	# (감독 2026-09-08) 전직의 돌은 소모품이라 상점에서도 판다.
	if item in JOB_STONES and int(materials.get(item, 0)) + qty > JOB_STONE_CAP:
		return false
	gold -= price
	if item == "회복약":
		potions = mini(potions + 1, potion_cap())
	elif item == "부활의 깃털":
		revive_potions = mini(revive_potions + 1, 3)
	elif item == ENHANCE_WARD:
		enhance_wards = mini(enhance_wards + 1, 9)
	elif item == SCROLL_ITEM:
		scrolls = mini(scrolls + qty, MAX_SCROLLS)
	elif item in JOB_STONES:
		for _i in qty:
			add_job_stone(item)
	else:
		add_item(item)
	return true


## 낚시. 연못이 있는 지역에서 낚싯대를 갖고 있으면 쓸 수 있다.
## 장(chapter)마다 다른 물고기 표. weight 가 클수록 자주 나온다.
const FISHING_ROD := "낚싯대"
const FISH_LOOT := {
	1: [
		{"name": "피라미", "price": 8, "weight": 50},
		{"name": "은어", "price": 18, "weight": 30},
		{"name": "낡은 장화", "price": 2, "weight": 15},
		{"name": "빛나는 진주", "price": 90, "weight": 5},
	],
	2: [
		{"name": "숭어", "price": 22, "weight": 45},
		{"name": "민물게", "price": 30, "weight": 30},
		{"name": "녹슨 열쇠고리", "price": 3, "weight": 20},
		{"name": "산호 조각", "price": 140, "weight": 5},
	],
	3: [
		{"name": "빙어", "price": 35, "weight": 45},
		{"name": "은빛 송어", "price": 55, "weight": 30},
		{"name": "얼어붙은 장화", "price": 4, "weight": 20},
		{"name": "얼음 진주", "price": 220, "weight": 5},
	],
	4: [
		{"name": "심연어", "price": 60, "weight": 45},
		{"name": "가시장어", "price": 90, "weight": 30},
		{"name": "타버린 그물", "price": 5, "weight": 20},
		{"name": "심연의 진주", "price": 380, "weight": 5},
	],
}


func can_fish() -> bool:
	return inventory.has(FISHING_ROD)


func roll_fish() -> String:
	var pool: Array = FISH_LOOT.get(chapter, [])
	if pool.is_empty():
		return ""
	var total := 0
	for entry in pool:
		total += int(entry["weight"])
	var roll := randi() % total
	for entry in pool:
		roll -= int(entry["weight"])
		if roll < 0:
			return str(entry["name"])
	return str(pool[-1]["name"])


func fish_price(item: String) -> int:
	for tier in FISH_LOOT:
		for entry in FISH_LOOT[tier]:
			if str(entry["name"]) == item:
				return int(entry["price"])
	return -1


func sell_price(item: String) -> int:
	var fp := fish_price(item)
	if fp >= 0:
		return fp
	if not EQUIPMENT.has(item):
		return 5
	return int(EQUIPMENT[item]["price"])


func sell_at(index: int) -> int:
	_sync_item_uid()
	if index < 0 or index >= inventory.size():
		return 0
	var item := inventory[index]
	if is_equipped_at(index):
		return 0
	var price := sell_price(item)
	var uid := item_uid[index]
	inventory.remove_at(index)
	item_uid.remove_at(index)
	enhance_levels.erase(uid)
	socketed.erase(uid)
	affixes.erase(uid)
	gold += price
	return price


func has_save(index := -1) -> bool:
	return FileAccess.file_exists(save_path(index))


## 슬롯 한 줄 요약. 타이틀 화면이 쓴다.
func slot_summary(index: int) -> String:
	if not has_save(index):
		return "비어 있음"
	var file := FileAccess.open(save_path(index), FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "손상된 기록"
	# "잔영의 마을 (은둔지)"처럼 괄호 부제가 붙으면 타이틀 슬롯 칸(80px)을 넘쳐 잘린다.
	var where := World.title_of(str(data.get("current_map", "village"))).get_slice(" (", 0)
	var mark := " ★" if bool(data.get("game_cleared", false)) else ""
	return "Lv%d  %s%s" % [int(data.get("level", 1)), where, mark]


func save_game(player: Node) -> bool:
	var data := to_dict()
	data["player_x"] = player.global_position.x
	data["player_y"] = player.global_position.y
	data["health"] = player.health
	data["mana"] = player.mana
	data["max_health"] = player.max_health
	data["max_mana"] = player.max_mana
	data["attack_damage"] = player.attack_damage
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_game(player: Node) -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var file := FileAccess.open(save_path(), FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	level = int(data.get("level", 1))
	exp = int(data.get("exp", 0))
	next_exp = int(data.get("next_exp", 80))
	gold = int(data.get("gold", 0))
	kills = int(data.get("kills", 0))
	potions = int(data.get("potions", 2))
	scrolls = clampi(int(data.get("scrolls", 0)), 0, MAX_SCROLLS)
	revive_potions = int(data.get("revive_potions", 0))
	## 탑 세션(tower_active/floor/difficulty)은 슬롯별로 저장되지 않는다
	## (to_dict()에 없음) - 다른 슬롯에서 탑 진행 중 타이틀로 돌아와 이
	## 슬롯을 불러오면 이전 슬롯의 탑 상태가 그대로 남아 새는 버그가 있어
	## 여기서 항상 초기화한다.
	tower_active = false
	tower_floor = 0
	tower_difficulty = "easy"
	inventory.assign(data.get("inventory", []))
	## 2 이상이면 강화/소켓이 인스턴스 고유 번호(uid)로 저장된 새 형식이다.
	## 1(없음)은 이름으로만 저장하던 예전 파일 - 아래에서 번호를 새로 붙여 옮긴다.
	var save_format := int(data.get("save_format", 1))
	var saved_item_uid = data.get("item_uid", [])
	if save_format >= 2 and typeof(saved_item_uid) == TYPE_ARRAY and saved_item_uid.size() == inventory.size():
		item_uid.clear()
		for v in saved_item_uid:
			item_uid.append(int(v))
		_uid_seq = int(data.get("uid_seq", 0))
	else:
		item_uid.clear()
		_uid_seq = 0
	_sync_item_uid()
	weapon = str(data.get("weapon", "낡은 검"))
	armor = str(data.get("armor", "여행자 옷"))
	var saved_slots = data.get("equipped", {})
	if typeof(saved_slots) == TYPE_DICTIONARY and not saved_slots.is_empty():
		for slot in SLOTS:
			equipped[slot] = str(saved_slots.get(slot, ""))
	else:
		# 예전 저장 파일은 무기·갑옷 두 칸만 들고 있다.
		equipped = {"weapon": weapon, "armor": armor, "helmet": "", "trinket": "", "trinket2": "", "spirit": ""}
	var saved_equipped_uid = data.get("equipped_uid", {})
	if save_format >= 2 and typeof(saved_equipped_uid) == TYPE_DICTIONARY and not saved_equipped_uid.is_empty():
		for slot in SLOTS:
			equipped_uid[slot] = int(saved_equipped_uid.get(slot, 0))
	else:
		# 예전 저장 파일: 이름만 보고 가방에서 아직 안 짝지어진 첫 칸을 찾아 번호를 붙인다.
		equipped_uid = {"weapon": 0, "armor": 0, "helmet": 0, "trinket": 0, "trinket2": 0, "spirit": 0}
		var claimed: Array[int] = []
		for slot in SLOTS:
			var worn_name := str(equipped.get(slot, ""))
			if worn_name == "":
				continue
			for i in inventory.size():
				if inventory[i] == worn_name and not claimed.has(item_uid[i]):
					equipped_uid[slot] = item_uid[i]
					claimed.append(item_uid[i])
					break
	_recalc_bonuses()
	quest_stage = int(data.get("quest_stage", 0))
	chapter = int(data.get("chapter", 1))
	boss_defeated = bool(data.get("boss_defeated", false))
	current_map = str(data.get("current_map", "village"))
	# 합쳐져 사라진 지역(근원 혈맥/기억/핵 등)에 저장돼 있으면 마을로.
	if not World.AREAS.has(current_map):
		current_map = "village"
	chapter_kills = int(data.get("chapter_kills", 0))
	dash_unlocked = bool(data.get("dash_unlocked", true))
	game_cleared = bool(data.get("game_cleared", false))
	unlocked_maps.assign(data.get("unlocked_maps", ["village"]))
	opened_chests.assign(data.get("opened_chests", []))
	storage.assign(data.get("storage", []))
	var saved_storage_uid = data.get("storage_uid", [])
	if save_format >= 2 and typeof(saved_storage_uid) == TYPE_ARRAY and saved_storage_uid.size() == storage.size():
		storage_uid.clear()
		for v in saved_storage_uid:
			storage_uid.append(int(v))
	else:
		storage_uid.clear()
	_sync_storage_uid()
	keys.assign(data.get("keys", []))
	opened_doors.assign(data.get("opened_doors", []))
	choices.assign(data.get("choices", []))
	var saved_stats = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in STAT_KEYS:
			stats[key] = int(saved_stats.get(key, 0))
	stat_points = int(data.get("stat_points", 0))
	var saved_perks = data.get("perks", {})
	perks = saved_perks if typeof(saved_perks) == TYPE_DICTIONARY else {}
	perk_picks = int(data.get("perk_picks", 0))
	bounty_index = int(data.get("bounty_index", 0))
	bounty_progress = int(data.get("bounty_progress", 0))
	bounty_taken = bool(data.get("bounty_taken", false))
	var saved_mats = data.get("materials", {})
	if typeof(saved_mats) == TYPE_DICTIONARY:
		materials[MATERIAL] = int(saved_mats.get(MATERIAL, 0))
		materials[BOSS_FRAGMENT] = int(saved_mats.get(BOSS_FRAGMENT, 0))
		for stone in JOB_STONES:
			materials[stone] = int(saved_mats.get(stone, 0))
		for ess in CHAPTER_ESSENCES.values():
			materials[ess] = int(saved_mats.get(ess, 0))
	var saved_enh = data.get("enhance_levels", {})
	enhance_levels = {}
	if typeof(saved_enh) == TYPE_DICTIONARY:
		if save_format >= 2:
			for k in saved_enh:
				enhance_levels[int(k)] = int(saved_enh[k])
		else:
			# 예전 저장: 이름이 키였다(그때도 같은 이름끼리 수치를 공유했으므로
			# 그 이름을 가진 모든 칸에 그대로 옮겨도 데이터 손실이 아니다).
			for item_name in saved_enh:
				var lvl := int(saved_enh[item_name])
				for i in inventory.size():
					if inventory[i] == item_name:
						enhance_levels[item_uid[i]] = lvl
	enhance_wards = int(data.get("enhance_wards", 0))
	var saved_stones = data.get("stone_inventory", {})
	stone_inventory = saved_stones if typeof(saved_stones) == TYPE_DICTIONARY else {}
	# 랜덤 옵션은 uid 저장(save_format 2) 이후에 생겼으니 예전 형식 변환은 없다.
	var saved_affixes = data.get("affixes", {})
	affixes = {}
	if typeof(saved_affixes) == TYPE_DICTIONARY:
		for k in saved_affixes:
			var rolled := {}
			for key in AFFIX_KEYS:
				if int(saved_affixes[k].get(key, 0)) != 0:
					rolled[key] = int(saved_affixes[k][key])
			if not rolled.is_empty():
				affixes[int(k)] = rolled
	var saved_socketed = data.get("socketed", {})
	socketed = {}
	if typeof(saved_socketed) == TYPE_DICTIONARY:
		if save_format >= 2:
			for k in saved_socketed:
				socketed[int(k)] = saved_socketed[k]
		else:
			for item_name in saved_socketed:
				for i in inventory.size():
					if inventory[i] == item_name:
						socketed[item_uid[i]] = saved_socketed[item_name]
	var saved_tower = data.get("tower_progress", {})
	if typeof(saved_tower) == TYPE_DICTIONARY:
		for tier in tower_progress:
			tower_progress[tier] = int(saved_tower.get(tier, 0))
	var saved_tower_materials = data.get("tower_material_counts", {})
	if typeof(saved_tower_materials) == TYPE_DICTIONARY:
		for tier in tower_material_counts:
			tower_material_counts[tier] = int(saved_tower_materials.get(tier, 0))
	tower_titles.assign(data.get("tower_titles", []))
	claimed_level_milestones.assign(data.get("claimed_level_milestones", []))
	claimed_boss_rewards.assign(data.get("claimed_boss_rewards", []))
	level_titles.assign(data.get("level_titles", []))
	potion_cap_bonus = int(data.get("potion_cap_bonus", 0))
	# 옛 세이브(이 기능 전에 저장됨)는 claimed_level_milestones가 비어 있다 -
	# 소급 지급은 여기서 바로 하지 않는다(세이브 왕복 정밀도 검사들이 레벨
	# 9999 같은 극단값으로 "불러온 뒤 숫자가 똑같아야 한다"를 확인하는데,
	# 여기서 지급하면 그 값이 틀어진다). main._load_current_game()이 불러온
	# 뒤 claim_level_milestones()를 따로 호출해 소급하고 상자를 보여 준다.
	job = str(data.get("job", ""))
	second_job = str(data.get("second_job", ""))
	_recalc_bonuses()
	player.max_health = int(data.get("max_health", 100 + (level - 1) * 15))
	player.max_mana = int(data.get("max_mana", 60 + (level - 1) * 5))
	player.attack_damage = int(data.get("attack_damage", 24 + (level - 1) * 4))
	player.global_position = Vector2(float(data.get("player_x", 160)), float(data.get("player_y", 130)))
	player.health = mini(int(data.get("health", player.max_health)), player.max_health)
	player.mana = mini(int(data.get("mana", player.max_mana)), player.max_mana)
	return true


func to_dict() -> Dictionary:
	return {"level": level, "exp": exp, "next_exp": next_exp, "gold": gold, "kills": kills,
		"potions": potions, "scrolls": scrolls, "revive_potions": revive_potions, "inventory": inventory,
		"item_uid": item_uid, "uid_seq": _uid_seq, "save_format": 2,
		"weapon": weapon, "armor": armor,
		"attack_bonus": attack_bonus, "defense_bonus": defense_bonus,
		"health_bonus": health_bonus, "speed_bonus": speed_bonus, "equipped": equipped,
		"equipped_uid": equipped_uid,
		"quest_stage": quest_stage,
		"chapter": chapter, "boss_defeated": boss_defeated, "current_map": current_map,
		"chapter_kills": chapter_kills, "dash_unlocked": dash_unlocked, "game_cleared": game_cleared,
		"unlocked_maps": unlocked_maps, "opened_chests": opened_chests, "storage": storage,
		"storage_uid": storage_uid,
		"keys": keys, "opened_doors": opened_doors, "choices": choices,
		"stats": stats, "stat_points": stat_points, "perks": perks, "perk_picks": perk_picks,
		"bounty_index": bounty_index, "bounty_progress": bounty_progress, "bounty_taken": bounty_taken,
		"materials": materials, "enhance_levels": enhance_levels, "enhance_wards": enhance_wards,
		"stone_inventory": stone_inventory, "socketed": socketed, "affixes": affixes, "tower_progress": tower_progress,
		"tower_material_counts": tower_material_counts, "tower_titles": tower_titles, "job": job,
		"second_job": second_job,
		"claimed_level_milestones": claimed_level_milestones, "level_titles": level_titles,
		"potion_cap_bonus": potion_cap_bonus, "claimed_boss_rewards": claimed_boss_rewards}


func unlock_map(map_name: String) -> void:
	if not unlocked_maps.has(map_name):
		unlocked_maps.append(map_name)


func complete_game(player: Node) -> bool:
	game_cleared = true
	quest_stage = 10
	unlock_map("tower")
	return save_game(player)


func map_title() -> String:
	return World.title_of(current_map)
