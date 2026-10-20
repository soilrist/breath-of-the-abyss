extends CharacterBody2D

signal defeated(exp: int, gold: int, kind_id: String)
signal dropped(data: Dictionary, at: Vector2)
signal boss_fallen
## 보스 페이즈가 올라갈 때(1, 2). main.gd가 HUD 메시지로 알린다.
signal phase_changed(phase: int)

@export var max_health := 52
@export var damage := 9
## 받는 피해 감소. 플레이어 쪽 방어 공식과 같은 체감 감소율 공식을 쓴다
## (45 기준, 60% 상한). 탑 전용 - 일반 몬스터는 기본값 0이라 영향 없다.
@export var defense := 0
@export var speed := 31.0
@export var detection_range := 105.0
@export var attack_range := 17.0
@export var exp_reward := 18
@export var gold_reward := 7
@export var is_boss := false
## 사냥터 중간보스. 장별 보스보다는 약하지만 일반 몹보다 훨씬 강하고,
## 처치 시 전직의 돌을 확정 드랍한다. SECOND_JOB_DESIGN.md 5절.
@export var is_midboss := false
@export var area_id := "forest"
@export_enum("beast", "knight", "mage", "boss") var archetype := "beast"

## 이 거리보다 가까운 적만 이름표를 보여준다("적 이름표 겹침" - HANDOFF.md).
const NAME_LABEL_RANGE := 46.0

var health := max_health
var hit_time := 0.0
var attack_time := 0.0
var home := Vector2.ZERO
var special_time := 2.5
var cast_started := false
var cast_time := 0.0
var cast_direction := Vector2.ZERO
var anim_tick := 0.0
var kind := {}
## 돌진형이 노려보는 시간과 돌진이 남은 시간.
var wind_up := 0.0
var charging := 0.0
var charge_dir := Vector2.ZERO
## 전사 "방패 돌진"에 맞으면 이 시간만큼 완전히 멈춘다.
var stun_time := 0.0
## 마법사 "얼음창"에 맞으면 이동 속도가 이 배율로 줄어든다(1.0 = 정상).
var slow_time := 0.0
var slow_mult := 1.0
## 강령술사 "저주"에 맞으면 이 시간 동안 매초 dot_damage_per_sec만큼
## take_damage()로 지속 피해를 입는다(사망 처리·드랍은 take_damage()의
## 기존 로직을 그대로 재사용한다).
var dot_time := 0.0
var dot_damage_per_sec := 0
var dot_tick_time := 0.0
## 10장 근원 보스 전용(그 외 몬스터는 항상 phase 0, mult 1.0이라 영향 없다).
var boss_phase := 0
## (감독, 2026-09-10) 근접 공격 모션. 예전엔 사거리에 들어오면 예고 없이
## 즉시 피해가 들어가 "때리는 느낌"이 전혀 없었다. 시트에 공격 프레임이 없어
## (보스 시트는 걷기 한 줄뿐) 절차적으로 만든다: 멈춰서 뒤로 살짝 젖힘(예비동작)
## → 한 발 전진(돌진) → 플레이어 위치에 베기 궤적 + 히트스톱. 피격 시엔 스프라이트
## 찌그러짐(squash). 잡몹·보스·보스 특수기 모두 같은 경로를 쓴다.
const SWING_MOB := 0.22
## (결함 수정, 2026-10-20 INBOX 00:11 origin_throne 반복 사망 ②) 0.32 그대로면
## 보스 특수기(lunge, special=true) 전조가 0.32*1.4=0.448초로 INBOX가 정한
## "큰 공격엔 0.5초 이상 전조" 기준에 못 미쳤다(실측: check_origin_death_cause.gd
## 5회 사망 중 3회가 melee/lunge, enemies_near=0 은 사망 처리 후 거리 측정
## 시점 차이일 뿐 원거리 판정 결함이 아님 - 전조 부족이 근거). 0.36으로 올려
## 0.36*1.4=0.504초로 기준을 넘긴다(일반 공격 0.32→0.36초는 "큰 공격"이 아니라
## 범위 밖, 체감 영향 미미).
const SWING_BOSS := 0.36
const LUNGE_MOB := 6.0
const LUNGE_BOSS := 10.0
const SLASH_FX := preload("res://scenes/slash_fx.tscn")
var swing := 0.0
var swing_dir := Vector2.ZERO
var swing_special := false
var _sprite_scale := Vector2.ONE
var base_speed := 0.0
var attack_cooldown_mult := 1.0
## (감독 2026-09-10) 장별 보스 상태 머신. 데이터는 GameState.BOSS_PHASES.
## boss_state: "" = 일반 추격/근접(_act_boss). 그 외는 특수 패턴 진행 중
##   ("dash_windup" "dash" "aoe_windup" "aoe_flash" "summon" "volley").
## boss_patterns: 현재 페이즈의 패턴 목록. pattern_index로 라운드로빈.
var boss_state := ""
var pattern_time := 0.0
var pattern_index := 0
var boss_patterns: Array = []
## 감지: detection_range 안에 들어오면 물고, 2배 밖으로 나가야 놓는다.
var boss_aggro := false
var nav_agent: NavigationAgent2D = null
var _nav_ok := false
var _dash_struck := false
## 범위 공격 예고 원(_draw). 0 = 안 그림.
var aoe_progress := 0.0

# 잡몹 시트는 4열이 아래·위·왼쪽·오른쪽 방향이고, 보스 시트는 방향 없이 한 줄이다.
# 어느 쪽도 확대하지 않는다. 배경 타일과 픽셀 크기를 맞추기 위해서다.
## 잡몹 시트는 전부 4열 4행 규격이라 공통값을 여기서 채운다.
const MOB_DEFAULTS := {
	"hframes": 4, "vframes": 4, "directional": true,
	"walk_row": 0, "walk_frames": 4, "radius": 6.0,
	"behavior": "chase",
}

## 행동 유형.
## chase  곧장 다가와 때린다. 기본.
## charge 잠깐 노려보다 빠르게 돌진한다. 피할 틈이 있다.
## ranged 거리를 두고 멀리서 친다. 붙으면 물러난다.
## magic 긴 시전 준비 후 마법 투사체를 발사한다.

## 장마다 다른 보스가 나온다.
const BOSS_BY_CHAPTER := {1: "guardian", 2: "captain", 3: "frost", 4: "abyss", 5: "primordial", 6: "reef_warden", 7: "faded_prelate", 8: "warden_overseer", 9: "reverted_one", 10: "origin"}

const KINDS := {
	"beast": {
		"texture": "res://assets/characters/enemy_beast.png",
		"label": "숲짐승", "hframes": 4, "vframes": 4,
		"directional": true, "walk_row": 0, "walk_frames": 4, "radius": 6.0,
	},
	"knight": {
		"texture": "res://assets/characters/enemy_knight.png",
		"label": "흑기사", "hframes": 4, "vframes": 7,
		"directional": true, "walk_row": 1, "walk_frames": 4, "radius": 6.0,
	},
	"mushroom": {"texture": "res://assets/characters/mob_mushroom.png", "label": "독버섯"},
	"snake": {"behavior": "charge", "texture": "res://assets/characters/mob_snake.png", "label": "숲뱀"},
	"bat": {"behavior": "charge", "texture": "res://assets/characters/mob_bat.png", "label": "동굴박쥐"},
	"slime": {"texture": "res://assets/characters/mob_slime.png", "label": "끈적이"},
	"skull": {"texture": "res://assets/characters/mob_skull.png", "label": "해골병"},
	"octopus": {"behavior": "ranged", "texture": "res://assets/characters/mob_octopus.png", "label": "먹물문어"},
	"kappa": {"texture": "res://assets/characters/mob_kappa.png", "label": "물도깨비"},
	"spirit": {"behavior": "ranged", "texture": "res://assets/characters/mob_spirit.png", "label": "망령"},
	"flam": {"behavior": "magic", "texture": "res://assets/characters/mob_flam.png", "label": "화염정령", "attack_range": 122.0, "spell_cooldown": 2.6, "spell_damage": 12, "cast_time": 0.42},
	"mage": {"behavior": "magic", "texture": "res://assets/characters/mob_flam.png", "label": "화염술사", "attack_range": 122.0, "spell_cooldown": 2.6, "spell_damage": 12, "cast_time": 0.42},
	"cyclope": {"behavior": "charge", "texture": "res://assets/characters/mob_cyclope.png", "label": "외눈마수"},
	"panda": {"behavior": "charge", "texture": "res://assets/characters/mob_panda.png", "label": "눈곰"},
	"larva": {"texture": "res://assets/characters/mob_larva.png", "label": "얼음벌레"},
	"owl": {"behavior": "ranged", "texture": "res://assets/characters/mob_owl.png", "label": "설원올빼미"},
	# 동서남북 던전 전용 몬스터.
	"eye": {"behavior": "ranged", "texture": "res://assets/characters/mob_eye.png", "label": "감시의 눈"},
	"frostbear": {"behavior": "charge", "texture": "res://assets/characters/mob_bear.png", "label": "서리곰"},
	"mollusc": {"texture": "res://assets/characters/mob_mollusc.png", "label": "물이끼조개"},
	"dragon": {"behavior": "ranged", "texture": "res://assets/characters/mob_dragon.png", "label": "심연의 용"},
	# 5장(유민의 땅) 전용 신규 몬스터 5종. 새 스프라이트를 그리지 않고
	# 기존 텍스처를 색으로 물들여 "침식된 유령·기계 잔해" 테마를 낸다
	# (CHAPTER5_EXPANSION_DESIGN.md 5절).
	"wraith_soldier": {"texture": "res://assets/characters/mob_skull.png", "label": "잔영병",
		"tint": Color(0.55, 0.6, 0.75, 0.75)},
	"floating_shard": {"behavior": "ranged", "texture": "res://assets/characters/mob_eye.png",
		"label": "부유석", "tint": Color(0.65, 0.55, 0.8)},
	"corruptor": {"behavior": "magic", "texture": "res://assets/characters/mob_flam.png",
		"label": "침식술사", "tint": Color(0.5, 0.85, 0.45),
		"attack_range": 122.0, "spell_cooldown": 2.6, "spell_damage": 14, "cast_time": 0.42},
	"shard_watcher": {"behavior": "magic", "texture": "res://assets/characters/mob_owl.png",
		"label": "파편감시자", "tint": Color(0.7, 0.5, 0.9),
		"attack_range": 130.0, "spell_cooldown": 2.4, "spell_damage": 16, "cast_time": 0.4},
	"rampaging_golem": {"behavior": "charge", "texture": "res://assets/characters/mob_cyclope.png",
		"label": "폭주골렘", "tint": Color(0.45, 0.4, 0.5)},
	# 6장(파편의 바다) 전용 신규 몬스터 5종. 심해 생물 테마, 원거리/마법
	# 비중을 높였다(CHAPTER6_10_MASTERPLAN.md 2절). 기존 텍스처를 청록/
	# 남색 계열로 물들여 구분(신규 스프라이트 없음).
	"tideclaw": {"texture": "res://assets/characters/mob_kappa.png", "label": "조류게",
		"tint": Color(0.35, 0.75, 0.8)},
	"driftghoul": {"behavior": "charge", "texture": "res://assets/characters/mob_bear.png",
		"label": "표류귀", "tint": Color(0.3, 0.55, 0.6)},
	"tidecaster": {"behavior": "magic", "texture": "res://assets/characters/mob_flam.png",
		"label": "조류술사", "tint": Color(0.25, 0.6, 0.85),
		"attack_range": 124.0, "spell_cooldown": 2.5, "spell_damage": 15, "cast_time": 0.4},
	"depth_eye": {"behavior": "ranged", "texture": "res://assets/characters/mob_eye.png",
		"label": "심해안", "tint": Color(0.2, 0.45, 0.7)},
	"coral_sentinel": {"behavior": "ranged", "texture": "res://assets/characters/mob_octopus.png",
		"label": "산호감시병", "tint": Color(0.4, 0.8, 0.7)},
	# 7장(잊힌 성소) 전용 신규 몬스터 5종. "침식된 신성" 테마 -- 빛바랜
	# 금색/흰색 계열로 물들여 구분(신규 스프라이트 없음).
	"faded_acolyte": {"texture": "res://assets/characters/mob_skull.png", "label": "빛바랜 수도사",
		"tint": Color(0.95, 0.85, 0.55)},
	"gilded_wraith": {"behavior": "charge", "texture": "res://assets/characters/mob_spirit.png",
		"label": "금박망령", "tint": Color(0.9, 0.75, 0.35)},
	"choir_caster": {"behavior": "magic", "texture": "res://assets/characters/mob_owl.png",
		"label": "합창술사", "tint": Color(0.95, 0.9, 0.55),
		"attack_range": 128.0, "spell_cooldown": 2.3, "spell_damage": 17, "cast_time": 0.4},
	"relic_eye": {"behavior": "ranged", "texture": "res://assets/characters/mob_eye.png",
		"label": "유물의 눈", "tint": Color(0.85, 0.7, 0.3)},
	"bell_golem": {"behavior": "charge", "texture": "res://assets/characters/mob_cyclope.png",
		"label": "종소리골렘", "tint": Color(0.8, 0.75, 0.5)},
	# 8장(침묵의 회랑) 전용 신규 몬스터 5종. "소리와 색이 지워진 공간"
	# 테마 -- 무채색(회백/흑)으로 물들여 구분(신규 스프라이트 없음).
	"muted_stalker": {"texture": "res://assets/characters/mob_bat.png", "label": "말없는 추적자",
		"tint": Color(0.55, 0.55, 0.58)},
	"echo_wraith": {"behavior": "charge", "texture": "res://assets/characters/mob_snake.png",
		"label": "메아리귀병", "tint": Color(0.35, 0.35, 0.4)},
	"warden_scribe": {"behavior": "magic", "texture": "res://assets/characters/mob_larva.png",
		"label": "감독관의 서기", "tint": Color(0.6, 0.6, 0.65),
		"attack_range": 128.0, "spell_cooldown": 2.1, "spell_damage": 18, "cast_time": 0.4},
	"grey_sentinel": {"behavior": "ranged", "texture": "res://assets/characters/mob_octopus.png",
		"label": "잿빛 파수병", "tint": Color(0.45, 0.45, 0.5)},
	"silence_golem": {"behavior": "charge", "texture": "res://assets/characters/mob_bear.png",
		"label": "침묵골렘", "tint": Color(0.25, 0.25, 0.28)},
	# 9장(역전의 탑) 전용 신규 몬스터 5종. "지나온 장의 잔향"이 자홍색
	# 계열로 뒤틀려 나타난다는 테마(CHAPTER6_10_MASTERPLAN.md 2절).
	"twisted_knight": {"texture": "res://assets/characters/enemy_knight.png",
		"label": "뒤틀린 흑기사", "hframes": 4, "vframes": 7,
		"directional": true, "walk_row": 1, "walk_frames": 4, "radius": 6.0,
		"tint": Color(0.75, 0.35, 0.8)},
	"twisted_beast": {"texture": "res://assets/characters/enemy_beast.png",
		"label": "뒤틀린 숲짐승", "hframes": 4, "vframes": 4,
		"directional": true, "walk_row": 0, "walk_frames": 4, "radius": 6.0,
		"tint": Color(0.7, 0.3, 0.75)},
	"reversed_wisp": {"behavior": "ranged", "texture": "res://assets/characters/mob_spirit.png",
		"label": "역행하는 정령", "tint": Color(0.8, 0.4, 0.85)},
	"paradox_caster": {"behavior": "magic", "texture": "res://assets/characters/mob_flam.png",
		"label": "모순의 술사", "tint": Color(0.65, 0.25, 0.75),
		"attack_range": 128.0, "spell_cooldown": 2.0, "spell_damage": 22, "cast_time": 0.38},
	"seam_walker": {"behavior": "charge", "texture": "res://assets/characters/mob_cyclope.png",
		"label": "이음매 방랑자", "tint": Color(0.55, 0.2, 0.65)},
	# 심연의 탑 전용 몬스터(TOWER_DESIGN.md §13). 5·6장과 같은 방식으로
	# 새 스프라이트 없이 기존 텍스처를 물들여 "탑에서만 보는 놈" 느낌을 낸다.
	"tower_warden": {"behavior": "charge", "texture": "res://assets/characters/mob_dragon.png",
		"label": "탑의 파수룡", "tint": Color(0.35, 0.25, 0.55)},
	"guardian": {
		"texture": "res://assets/characters/boss_guardian.png",
		"label": "숲의 수호자", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 22.0,
	},
	# boss_captain.png은 576×48 = 96×48 여섯 프레임(쌍검 기사)이다. 예전엔
	# 48×48 열두 프레임으로 잘라 몸통 반쪽만 번갈아 그렸다("8장보스 또
	# 반쪽짜리" — 8장 감독관도 이 텍스처를 쓴다). tests/check_boss_sprite_frames.
	"captain": {
		"texture": "res://assets/characters/boss_captain.png",
		"label": "흑기사단장", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 22.0,
	},
	"abyss": {
		"texture": "res://assets/characters/boss_abyss.png",
		"label": "심연의 군주", "hframes": 5, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 5, "radius": 22.0,
	},
	"frost": {
		"texture": "res://assets/characters/boss_frost.png",
		"label": "얼음 군주", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 24.0,
	},
	# 5장(유민의 땅) 최종보스. 신규 스프라이트 없이 심연의 군주 텍스처를
	# 보라색으로 물들여 "같은 근원, 다른 존재"라는 설정을 색으로 표현한다.
	"primordial": {
		"texture": "res://assets/characters/boss_abyss.png",
		"label": "태초의 심연", "hframes": 5, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 5, "radius": 24.0,
		"tint": Color(0.72, 0.5, 0.95),
	},
	# 6장(파편의 바다) 최종보스. 신규 스프라이트 없이 얼음 군주 텍스처를
	# 청록으로 물들여 "심해에 가라앉은 파수꾼"이라는 설정을 표현한다.
	"reef_warden": {
		"texture": "res://assets/characters/boss_frost.png",
		"label": "파수꾼의 유해", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 24.0,
		"tint": Color(0.35, 0.7, 0.75),
	},
	# 7장(잊힌 성소) 최종보스. 신규 스프라이트 없이 숲의 수호자 텍스처를
	# 금색/흰색으로 물들여 "침식된 신성"이라는 설정을 표현한다.
	"faded_prelate": {
		"texture": "res://assets/characters/boss_guardian.png",
		"label": "빛바랜 사제왕", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 22.0,
		"tint": Color(0.95, 0.85, 0.5),
	},
	# 8장(침묵의 회랑) 최종보스. 신규 스프라이트 없이 흑기사단장 텍스처를
	# 무채색으로 물들여 "감정도 색도 없는 감시자"라는 설정을 표현한다.
	"warden_overseer": {
		"texture": "res://assets/characters/boss_captain.png",
		"label": "말없는 감독관", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 22.0,
		"tint": Color(0.5, 0.5, 0.55),
	},
	# 9장(역전의 탑) 최종보스. 신규 스프라이트 없이 얼음 군주 텍스처를
	# 짙은 보라색으로 물들여 "뒤틀린 존재"라는 설정을 표현한다. 중간보스는
	# (5~8장과 동일하게) 별도 정의 없이 그 지역 잡몹 중 하나를 확대해
	# 재사용한다(_spawn_area_enemies() 참고).
	"reverted_one": {
		"texture": "res://assets/characters/boss_frost.png",
		"label": "역행자", "hframes": 6, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 6, "radius": 26.0,
		"tint": Color(0.55, 0.2, 0.7),
	},
	"origin": {
		"texture": "res://assets/characters/boss_abyss.png",
		"label": "근원의 보스", "hframes": 5, "vframes": 1,
		"directional": false, "walk_row": 0, "walk_frames": 5, "radius": 28.0,
		"tint": Color(0.8, 0.35, 0.9),
		## 3페이즈·특수 패턴은 GameState.BOSS_PHASES["origin"](모든 보스 공통 구조).
	},
}


func _ready() -> void:
	# Player와 같은 이유(Main = ALWAYS 상속)로 명시한다. 대화·메뉴가 열려도
	# 몬스터가 계속 움직이며 공격하면 안 된다.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	home = global_position
	add_to_group("enemies")
	var kind_id := archetype
	if is_boss:
		kind_id = BOSS_BY_CHAPTER.get(GameState.chapter, "guardian")
	kind = MOB_DEFAULTS.merged(KINDS[kind_id], true)
	kind["id"] = kind_id
	if is_boss and GameState.BOSS_PHASES.has(kind_id):
		var spec: Dictionary = GameState.BOSS_PHASES[kind_id]
		kind["phases"] = spec["phases"]
		kind["behavior"] = "boss"
		boss_patterns = (spec["patterns"] as Array).duplicate()
		nav_agent = NavigationAgent2D.new()
		nav_agent.path_desired_distance = 6.0
		nav_agent.target_desired_distance = 6.0
		add_child(nav_agent)
		# 부모(main)의 World가 그린 지역으로 네브메시를 만든다. 부모가 없는
		# 단독 테스트에선 직선 추격으로 자연히 대체.
		_setup_nav.call_deferred()
	base_speed = speed
	_apply_kind()
	$Health.max_value = max_health
	$Health.value = health


## 스프라이트 크기에 맞춰 충돌·이름표·체력바 위치를 잡는다.
## 보스는 62px까지 크기 때문에 고정 오프셋을 쓰면 몸통과 글자가 겹친다.
func _apply_kind() -> void:
	$Sprite.texture = load(kind["texture"])
	$Sprite.hframes = kind["hframes"]
	$Sprite.vframes = kind["vframes"]
	# 신규 몬스터는 새 스프라이트 대신 기존 텍스처를 색으로 물들여 구분한다.
	# 피격 시 흰/빨강 플래시는 이 노드가 아니라 자기 자신(모체)의 modulate를
	# 쓰므로(take_damage() 참고) 서로 겹치지 않는다.
	$Sprite.modulate = kind.get("tint", Color.WHITE)
	var half: float = $Sprite.texture.get_height() / float(kind["vframes"]) / 2.0
	$Sprite.position = Vector2(0, -half + 3.0)
	# 중간보스는 일반 몹 그래픽을 재사용하되 확대 + 이름에 표시를 붙여
	# 눈에 띄게 한다("보스 전에 중간보스들 사냥터에 끼워넣는거야" 요청).
	if is_midboss:
		$Sprite.scale = Vector2.ONE * 1.6
		_sprite_scale = $Sprite.scale
		$Name.text = "%s (중간보스)" % kind["label"]
	else:
		$Sprite.scale = Vector2.ONE
		_sprite_scale = $Sprite.scale
		$Name.text = kind["label"]
	($CollisionShape2D.shape as CircleShape2D).radius = kind["radius"] * (1.6 if is_midboss else 1.0)
	var top: float = $Sprite.position.y - half
	$Health.offset_top = top - 6.0
	$Health.offset_bottom = top - 2.0
	$Name.offset_top = 5.0
	$Name.offset_bottom = 16.0
	# 중간보스는 "(중간보스)" 접미사가 붙어 이름표가 기본(44px) 폭을 훨씬
	# 넘긴다 - 화면 확인 결과 글자가 서로 겹쳐 읽을 수 없었다(스크린샷 검사
	# tests/shot_midboss_name.gd). 폭을 넓혀 겹침 없이 한 줄로 들어가게 한다.
	$Name.offset_left = -50.0 if is_midboss else -22.0
	$Name.offset_right = 50.0 if is_midboss else 22.0


func _physics_process(delta: float) -> void:
	# 사망 트윈(0.15초) 동안은 그림만 사라지고 AI는 계속 움직여 플레이어를
	# 때리는 "죽은 뒤에도 공격하는" 버그를 막는다 - 이미 그룹·충돌에서
	# 빠졌으니 안전하게 멈춘다.
	if health <= 0:
		return
	## (감독 결함 수정, 2026-09-08) 플레이어는 `_clamp_to_bounds()`로 지역 안에
	## 갇히지만 적은 아니었다. 원거리형(`_act_ranged`)은 플레이어가 다가오면
	## 반대쪽으로 도망치는데, 위쪽 지역 끝을 넘어서도 계속 도망쳐 y가 매분
	## 43,200px씩 줄고(10장 탐침 shore 89분 STALL 실측), 퀘스트 모드는 그
	## 적을 "가장 가까운 산 적"으로 영원히 쫓았다. 지역 픽셀 크기로 가둔다.
	## (감독, 2026-09-09) 가장자리 줄(0번 칸)은 `World.walkable()`이 거부하는
	## 칸이라 그 줄의 소품 몸체가 적을 매 프레임 밖으로 밀어낸다(hill 실측:
	## 14로 가둔 뒤 소품 탈출 보정으로 -5.7까지 튕김) - 그러면 퀘스트 모드가
	## 닿을 수 없는 적을 영원히 쫓는다. 걸을 수 있는 1번 칸 안쪽으로 가둔다.
	var edge := Vector2(World.TILE + 8, World.TILE + 8)
	global_position = global_position.clamp(edge, World.pixel_size_of(GameState.current_map) - edge)
	# AI 판정용 상태는 최소 한 프레임 유지해 외부 관찰과 실제 동작이 일치한다.
	hit_time = maxf(hit_time - delta, 0.0)
	attack_time = maxf(attack_time - delta, 0.0)
	special_time = maxf(special_time - delta, 0.0)
	cast_time = maxf(cast_time - delta, 0.0)
	# 준비 상태는 외부 판정이 읽을 수 있도록 시전 플래그로 유지한다.
	stun_time = maxf(stun_time - delta, 0.0)
	slow_time = maxf(slow_time - delta, 0.0)
	if slow_time == 0.0:
		slow_mult = 1.0
	if dot_time > 0.0:
		dot_time = maxf(dot_time - delta, 0.0)
		dot_tick_time -= delta
		if dot_tick_time <= 0.0:
			dot_tick_time += 1.0
			if dot_damage_per_sec > 0 and health > 0:
				take_damage(dot_damage_per_sec, Vector2.ZERO)
		if dot_time == 0.0:
			dot_damage_per_sec = 0
	if not (kind.get("phases", []) as Array).is_empty():
		_update_boss_phase()
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or hit_time > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if stun_time > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var offset := player.global_position - global_position
	var gap := offset.length() - body_radius()
	## 적이 여럿 모이면 이름표가 겹쳐 읽을 수 없다(HANDOFF.md "적 이름표 겹침").
	## 플레이어에게 가까운 적만 이름표를 보여줘 겹침을 없앤다. 체력바는 원래도
	## 피격 시에만 잠깐 보였다 사라지므로 그대로 둔다.
	$Name.visible = gap <= NAME_LABEL_RANGE
	wind_up = maxf(wind_up - delta, 0.0)
	charging = maxf(charging - delta, 0.0)
	if swing > 0.0:
		# 예비동작: 멈춰서 뒤로 젖히고 색을 띄운다. 끝나는 프레임에 친다.
		swing = maxf(swing - delta, 0.0)
		velocity = Vector2.ZERO
		$Sprite.offset = -swing_dir * (4.0 if swing_special else 3.0)
		modulate = Color(1.0, 0.7, 0.55) if swing_special else Color(1.0, 0.85, 0.7)
		move_and_slide()
		_update_sprite(velocity)
		if swing == 0.0:
			_land_swing(player)
		return
	if boss_state != "":
		_tick_boss_pattern(player, offset, gap, delta)
		velocity *= slow_mult
		move_and_slide()
		anim_tick += delta * (9.0 if velocity != Vector2.ZERO else 3.0)
		_update_sprite(velocity)
		return
	match str(kind.get("behavior", "chase")):
		"boss": _act_boss(player, offset, gap)
		"charge": _act_charge(player, offset, gap, delta)
		"ranged": _act_ranged(player, offset, gap)
		"magic": _act_magic(player, offset, gap)
		_: _act_chase(player, offset, gap)
	velocity *= slow_mult
	move_and_slide()
	anim_tick += delta * (9.0 if velocity != Vector2.ZERO else 3.0)
	_update_sprite(velocity)
	if is_boss and special_time == 0.0:
		if boss_patterns.is_empty():
			if gap <= 72.0:
				special_time = 4.0 * attack_cooldown_mult
				_start_swing(offset, true)
		elif boss_aggro:
			_start_boss_pattern(player, offset, gap)


## 예비동작 시작. special 은 보스 특수기(더 길게 젖히고 더 멀리 덮친다).
func _start_swing(offset: Vector2, special: bool) -> void:
	swing = (SWING_BOSS if is_boss else SWING_MOB) * (1.4 if special else 1.0)
	swing_dir = offset.normalized()
	swing_special = special
	velocity = Vector2.ZERO
	$Sprite.offset = -swing_dir * (4.0 if special else 3.0)


## 예비동작 끝: 한 발 전진하고, 아직 닿는 거리면 친다. 아니면 헛스윙.
func _land_swing(player: Node) -> void:
	$Sprite.offset = Vector2.ZERO
	modulate = Color.WHITE
	var lunge := (LUNGE_BOSS if is_boss else LUNGE_MOB) * (2.0 if swing_special else 1.0)
	move_and_collide(swing_dir * lunge)
	var to_player: Vector2 = player.global_position - global_position
	var gap := to_player.length() - body_radius()
	var reach := 72.0 if swing_special else attack_range + lunge + 4.0
	if gap > reach:
		return
	_strike_player(player, to_player, damage + (7 if swing_special else 0), swing_special, "lunge" if swing_special else "melee")


## 실제 타격: 피해 + 플레이어 위치에 베기 궤적 + 히트스톱. 돌진형도 여기로 온다.
## source: 진단 로그(player.last_hit_source)가 읽는 태그 - 호출하는 쪽에서 지정.
func _strike_player(player: Node, dir: Vector2, amount: int, heavy: bool, source := "melee") -> void:
	player.take_damage(amount, dir, source)
	var fx: Sprite2D = SLASH_FX.instantiate()
	fx.position = player.global_position + Vector2(0, -4)
	fx.rotation = Vector2.DOWN.angle_to(dir.normalized())
	fx.modulate = Color(1.0, 0.45, 0.4)
	if heavy:
		fx.scale = Vector2(1.3, 1.3)
	get_parent().add_child(fx)
	Hit.hitstop(0.09 if heavy else 0.05)


## kind["phases"]가 있는 보스 전용 3페이즈. HP 비율이 각 단계의 "hp"
## 임계값 아래로 내려가면 다음 페이즈로 오르며(역방향 없음 - 회복해도
## 안 내려감) 스프라이트 색·이동속도·공격 쿨다운·특수 패턴 목록을 바꾸고
## 전환 연출(파티클 + 효과음 + 흔들림)을 낸다. phases는 임계값 내림차순.
func _update_boss_phase() -> void:
	var phases: Array = kind.get("phases", [])
	var ratio := float(health) / float(max_health) if max_health > 0 else 1.0
	var phase := 0
	for i in range(phases.size()):
		if ratio <= float(phases[i]["hp"]):
			phase = i + 1
	if phase <= boss_phase:
		return
	boss_phase = phase
	var p: Dictionary = phases[phase - 1]
	$Sprite.modulate = p["tint"]
	attack_cooldown_mult = p.get("cooldown_mult", 1.0)
	speed = base_speed * float(p.get("speed_mult", 1.0))
	if p.has("patterns"):
		boss_patterns = (p["patterns"] as Array).duplicate()
		pattern_index = 0
	# 전환 연출: 페이즈 색 파티클 + 보스 효과음 + 화면 흔들림. 진행 중이던
	# 패턴은 끊고 곧바로 다음 패턴이 나오게 쿨다운을 비운다.
	var fx: CPUParticles2D = preload("res://scenes/enhance_fx.tscn").instantiate()
	fx.name = "PhaseFx"
	fx.position = global_position
	fx.color = p["tint"]
	fx.amount = 40
	if get_parent() != null:
		get_parent().add_child(fx)
	Audio.play_sfx("boss")
	Hit.shake(3.0)
	_end_boss_pattern()
	special_time = minf(special_time, 0.6)
	phase_changed.emit(phase)


## 보스 기본 행동: 감지(물기/놓기) → 네브메시 추격 → 사거리면 근접 휘두르기.
## 특수 패턴은 _physics_process 끝의 special_time 블록에서 고른다.
func _act_boss(player: Node, offset: Vector2, gap: float) -> void:
	if gap <= detection_range:
		boss_aggro = true
	elif gap > detection_range * 2.0:
		boss_aggro = false
	if not boss_aggro:
		_go_home()
		return
	if gap <= attack_range:
		velocity = Vector2.ZERO
		if attack_time == 0.0:
			attack_time = 1.3 * attack_cooldown_mult
			_start_swing(offset, false)
	else:
		velocity = _chase_dir(player, offset) * speed


## 네브메시 경로의 다음 점 방향. 네브메시가 없거나(단독 테스트) 경로가
## 비면 직선.
func _chase_dir(player: Node, offset: Vector2) -> Vector2:
	if _nav_ok and nav_agent != null:
		nav_agent.target_position = player.global_position
		var to_next: Vector2 = nav_agent.get_next_path_position() - global_position
		if to_next.length() > 1.0:
			return to_next.normalized()
	return offset.normalized()


func _setup_nav() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var world := parent.get_node_or_null("World")
	if world != null and world.has_method("ensure_nav"):
		_nav_ok = bool(world.ensure_nav())


## 현재 페이즈 패턴 목록에서 라운드로빈으로 다음 걸 고른다. 사거리가 안 맞는
## 패턴(lunge/dash/aoe)은 건너뛰고, 아무것도 안 맞으면 이번 틱은 쉰다.
func _start_boss_pattern(player: Node, offset: Vector2, gap: float) -> void:
	for _try in boss_patterns.size():
		var name: String = str(boss_patterns[pattern_index % boss_patterns.size()])
		pattern_index += 1
		if _begin_pattern(name, player, offset, gap):
			special_time = GameState.BOSS_SPECIAL_COOLDOWN * attack_cooldown_mult
			return


func _begin_pattern(name: String, _player: Node, offset: Vector2, gap: float) -> bool:
	match name:
		"lunge":
			if gap > 72.0:
				return false
			_start_swing(offset, true)
		"dash":
			if gap > 110.0:
				return false
			boss_state = "dash_windup"
			pattern_time = GameState.BOSS_DASH_WINDUP
			charge_dir = offset.normalized()
			$Sprite.offset = -charge_dir * 5.0
		"aoe":
			if gap > GameState.BOSS_AOE_RADIUS + 8.0:
				return false
			boss_state = "aoe_windup"
			pattern_time = GameState.BOSS_AOE_WINDUP
			aoe_progress = 0.001
			queue_redraw()
		"summon":
			if _live_minions() >= GameState.BOSS_SUMMON_CAP:
				return false
			boss_state = "summon"
			pattern_time = GameState.BOSS_SUMMON_CAST
		"volley":
			boss_state = "volley"
			pattern_time = GameState.BOSS_VOLLEY_CAST
			cast_direction = offset.normalized()
		_:
			return false
	return true


func _tick_boss_pattern(player: Node, offset: Vector2, gap: float, delta: float) -> void:
	pattern_time = maxf(pattern_time - delta, 0.0)
	match boss_state:
		"dash_windup":
			velocity = Vector2.ZERO
			modulate = Color(1.0, 0.6, 0.6)
			if pattern_time == 0.0:
				boss_state = "dash"
				charging = GameState.BOSS_DASH_TIME
				charge_dir = offset.normalized()
				_dash_struck = false
				$Sprite.offset = Vector2.ZERO
				modulate = Color.WHITE
				Audio.play_sfx("skill")
		"dash":
			velocity = charge_dir * GameState.BOSS_DASH_SPEED
			if not _dash_struck and gap <= attack_range + 6.0:
				_dash_struck = true
				_strike_player(player, charge_dir, int(damage * GameState.BOSS_DASH_DAMAGE_MULT), true, "dash")
			if charging == 0.0:
				_end_boss_pattern()
		"aoe_windup":
			velocity = Vector2.ZERO
			aoe_progress = 1.0 - pattern_time / GameState.BOSS_AOE_WINDUP
			modulate = Color(1.0, 0.8, 0.6)
			queue_redraw()
			if pattern_time == 0.0:
				var radius := GameState.BOSS_AOE_RADIUS
				if gap <= radius + 8.0:
					_strike_player(player, offset, int(damage * GameState.BOSS_AOE_DAMAGE_MULT), true, "aoe")
				var fx: CPUParticles2D = preload("res://scenes/enhance_fx.tscn").instantiate()
				fx.position = global_position
				fx.color = Color(1.0, 0.5, 0.2)
				fx.initial_velocity_max = radius * 1.4
				if get_parent() != null:
					get_parent().add_child(fx)
				Audio.play_sfx("skill")
				Hit.shake(3.0)
				boss_state = "aoe_flash"
				pattern_time = 0.15
				aoe_progress = 1.0
				queue_redraw()
		"aoe_flash":
			velocity = Vector2.ZERO
			if pattern_time == 0.0:
				_end_boss_pattern()
		"summon":
			velocity = Vector2.ZERO
			modulate = Color(0.8, 0.7, 1.0)
			if pattern_time == 0.0:
				_spawn_minions()
				_end_boss_pattern()
		"volley":
			velocity = Vector2.ZERO
			modulate = Color(1.0, 0.55, 0.35)
			if pattern_time == 0.0:
				var amount := maxi(int(damage * GameState.BOSS_VOLLEY_DAMAGE_MULT), 1)
				var n := GameState.BOSS_VOLLEY_COUNT
				for i in n:
					var angle := deg_to_rad(-30.0 + 60.0 * i / maxf(n - 1, 1))
					_fire_projectile(cast_direction.rotated(angle), amount, "magic", true)
				Audio.play_sfx("skill")
				Hit.shake(1.5)
				_end_boss_pattern()
		_:
			_end_boss_pattern()


func _end_boss_pattern() -> void:
	boss_state = ""
	pattern_time = 0.0
	aoe_progress = 0.0
	charging = 0.0
	$Sprite.offset = Vector2.ZERO
	modulate = Color.WHITE
	queue_redraw()


## 범위 공격 예고: 바깥 링 + 차오르는 원. aoe_progress 0이면 안 그린다.
func _draw() -> void:
	if aoe_progress <= 0.0:
		return
	var radius := GameState.BOSS_AOE_RADIUS
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.35, 0.2, 0.9), 1.5)
	draw_circle(Vector2.ZERO, radius * minf(aoe_progress, 1.0), Color(1.0, 0.4, 0.2, 0.35 if aoe_progress < 1.0 else 0.8))


func _live_minions() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("summoned_by") and e.get_meta("summoned_by") == get_instance_id():
			n += 1
	return n


## 소환: 보스 좌우에 잡몹 2마리. 체력·공격력은 보스 비율. 처치 보상·퀘스트
## 카운트는 안 준다(defeated 미연결) - 드랍(물약)만 연결. 보스가 죽으면
## 같이 사라진다(take_damage 참고). 지역 이동 시엔 main이 잡몹과 함께 치운다.
func _spawn_minions() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var summon_id := str(GameState.BOSS_PHASES[str(kind["id"])].get("summon", "beast"))
	var room := GameState.BOSS_SUMMON_CAP - _live_minions()
	for i in mini(GameState.BOSS_SUMMON_COUNT, room):
		var minion: CharacterBody2D = load("res://scenes/enemy.tscn").instantiate()
		minion.archetype = summon_id
		minion.max_health = maxi(int(max_health * GameState.BOSS_SUMMON_HP_RATIO), 10)
		minion.health = minion.max_health
		minion.damage = maxi(int(damage * GameState.BOSS_SUMMON_DAMAGE_RATIO), 1)
		minion.exp_reward = 0
		minion.gold_reward = 0
		minion.area_id = "summon"
		minion.position = position + Vector2(body_radius() + 12.0, 0.0) * (1.0 if i % 2 == 0 else -1.0)
		minion.set_meta("summoned_by", get_instance_id())
		parent.add_child(minion)
		if parent.has_method("_on_enemy_dropped"):
			minion.dropped.connect(parent._on_enemy_dropped)
	var fx: CPUParticles2D = preload("res://scenes/enhance_fx.tscn").instantiate()
	fx.position = global_position
	fx.color = Color(0.75, 0.55, 1.0)
	parent.add_child(fx)
	Audio.play_sfx("boss")


## 전사 "방패 돌진"에 부딪히면 그 시간만큼 완전히 움직이지 못한다.
func apply_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)


## 마법사 "얼음창"에 맞으면 그 시간만큼 이동 속도가 줄어든다. 여러 번 맞아도
## 남은 시간만 늘어나고 배율은 가장 강한 감속을 따른다.
func apply_slow(pct: float, duration: float) -> void:
	slow_time = maxf(slow_time, duration)
	slow_mult = minf(slow_mult, 1.0 - pct)


## 강령술사 "저주"에 맞으면 duration 동안 매초 dps만큼 지속 피해를 입는다.
## 중첩되어도 남은 시간과 초당 피해 모두 더 강한 쪽을 따른다(연속 시전 시
## 저주가 약해지는 일이 없도록).
func apply_dot(dps: int, duration: float) -> void:
	dot_time = maxf(dot_time, duration)
	dot_damage_per_sec = maxi(dot_damage_per_sec, dps)
	if dot_tick_time <= 0.0:
		dot_tick_time = 1.0


## 곧장 다가와 때린다.
func _act_chase(player: Node, offset: Vector2, gap: float) -> void:
	if gap <= attack_range:
		velocity = Vector2.ZERO
		if attack_time == 0.0:
			attack_time = 1.3 * attack_cooldown_mult
			_start_swing(offset, false)
	elif gap <= detection_range:
		velocity = offset.normalized() * speed
	else:
		_go_home()


## 잠깐 멈춰 노려보다 빠르게 달려든다. 멈춘 사이에 피할 수 있다.
func _act_charge(player: Node, offset: Vector2, gap: float, _delta: float) -> void:
	if charging > 0.0:
		velocity = charge_dir * speed * 2.6
		if gap <= attack_range and attack_time == 0.0:
			attack_time = 1.6
			_strike_player(player, charge_dir, damage + 4, false)
			charging = 0.0
		return
	if wind_up > 0.0:
		velocity = Vector2.ZERO
		modulate = Color(1.0, 0.75, 0.75)
		if wind_up <= 0.05:
			charging = 0.45
			charge_dir = offset.normalized()
			modulate = Color.WHITE
		return
	if wind_up == 0.0 and gap <= detection_range and attack_time == 0.0:
		wind_up = 0.45
		velocity = Vector2.ZERO
	elif gap <= detection_range:
		velocity = offset.normalized() * speed * 0.6
	else:
		_go_home()


## 시전 준비 후 화염 투사체를 발사한다. 근접하면 거리를 벌린다.
func _act_magic(player: Node, offset: Vector2, gap: float) -> void:
	var spell_range: float = float(kind.get("attack_range", 122.0))
	if cast_time > 0.0:
		cast_started = true
		velocity = Vector2.ZERO
		modulate = Color(1.0, 0.55, 0.35)
		return
	if cast_started:
		cast_started = false
		velocity = Vector2.ZERO
		modulate = Color.WHITE
		if cast_time <= 0.05:
			_fire_projectile(cast_direction, int(kind.get("spell_damage", damage)), "magic")
			Audio.play_sfx("skill")
			Hit.shake(1.5)
			modulate = Color.WHITE
		return
	if gap < spell_range - 24.0:
		velocity = -offset.normalized() * speed
	elif gap <= spell_range + 14.0 and attack_time == 0.0:
		attack_time = float(kind.get("spell_cooldown", 2.6))
		cast_time = float(kind.get("cast_time", 0.42))
		cast_direction = offset.normalized()
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * speed if gap > spell_range else Vector2.ZERO


## 거리를 두고 멀리서 친다. 너무 붙으면 물러난다. 이제 즉시 맞히지 않고
## 화살을 실제로 날려 보내며, 그 화살이 플레이어에게 닿아야 피해가
## 들어간다("무조건 내가 맞는 구조 같다" 지적 - 원거리 몹도 arrow.gd와
## 같은 실제 투사체를 쓰도록 바꿈).
func _act_ranged(player: Node, offset: Vector2, gap: float) -> void:
	var keep := attack_range + 46.0
	if gap < keep - 12.0:
		velocity = -offset.normalized() * speed * 0.9
		return
	if gap <= detection_range and attack_time == 0.0 and gap <= keep + 14.0:
		attack_time = 2.0
		_fire_projectile(offset.normalized(), damage, "arrow")
		Audio.play_sfx("skill")
		Hit.shake(1.2)
	if gap < keep - 12.0:
		velocity = -offset.normalized() * speed * 0.9
	elif gap > keep + 10.0 and gap <= detection_range:
		velocity = offset.normalized() * speed * 0.8
	else:
		velocity = Vector2.ZERO


## 화살/마법구 투사체를 실제로 생성해 날려 보낸다.
func _fire_projectile(direction: Vector2, amount: int, projectile_kind: String, homing := false) -> void:
	var proj: Area2D = preload("res://scenes/enemy_projectile.tscn").instantiate()
	proj.global_position = global_position + direction * body_radius()
	proj.direction = direction
	proj.damage = amount
	proj.kind = projectile_kind
	proj.homing = homing
	get_parent().add_child(proj)


func _go_home() -> void:
	var back := home - global_position
	velocity = back.normalized() * speed * 0.5 if back.length() > 3.0 else Vector2.ZERO


## 사거리는 중심이 아니라 몸 표면에서 잰다. 보스는 반지름이 커서
## 중심 거리로 재면 몸에 붙어도 사거리 밖으로 계산된다.
func body_radius() -> float:
	return kind["radius"]


func _update_sprite(motion: Vector2) -> void:
	var step := int(anim_tick) % int(kind["walk_frames"])
	if not kind["directional"]:
		$Sprite.frame = step
		return
	var column := 0
	if absf(motion.x) > absf(motion.y):
		column = 3 if motion.x > 0.0 else 2
	elif motion.y < 0.0:
		column = 1
	$Sprite.frame = (int(kind["walk_row"]) + step) * 4 + column


func take_damage(amount: int, knockback: Vector2, critical := false) -> void:
	if defense > 0:
		var cut := minf(float(defense) / (float(defense) + 45.0), 0.6)
		amount = int(round(amount * (1.0 - cut)))
	health -= amount
	Hit.strike(get_parent(), global_position, amount, critical)
	Audio.play_sfx("hit")
	$Health.value = maxi(health, 0)
	$Health.visible = true
	hit_time = 0.16
	# 보스를 7px씩 밀어내면 이동 속도가 느려 계속 도망만 다니는 꼴이 된다.
	# 좌표를 직접 더하면 벽/소품을 뚫고 밀려나 못 닿는 자리에 갇힌다 - 충돌을 보며 민다.
	move_and_collide(knockback.normalized() * (2.0 if is_boss else 7.0))
	# 피격 흰 번쩍: 0.06초 — 어떤 몹 색이든(초록 늪지·갈색 흙 몹 포함) 선명히 보이게
	# 빨강 틴트보다 흰색을 쓴다(감독 결함 2026-10-20 14:40).
	modulate = Color(2.2, 2.2, 2.2)
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(self):
			modulate = Color.WHITE)
	# 피격 스쿼시: 옆으로 퍼졌다가 0.12초에 원래 크기로.
	$Sprite.scale = _sprite_scale * Vector2(1.3, 0.75)
	create_tween().tween_property($Sprite, "scale", _sprite_scale, 0.12)
	if health <= 0:
		# 처치 순간: 히트스톱 0.04초(보스는 0.25초 + 화면 번쩍) + 흰 번쩍 + 파편 4~6개로
		# "박히는" 느낌을 더한다(감독 결함 2026-10-20 14:40 — 디버그 피해 99999 캡처에서도
		# 처치가 안 보였다). 12인 심판 19:50: 평타 Hit.strike 의 0.06초가 먼저 걸려 있으면
		# hitstop() 의 "이미 멈춰 있으면 무시" 가드에 막혀 처치 멈춤이 죽은 코드였다 —
		# Hit.hitstop 이 maxf 로 덮어쓰게 고쳐 더 긴 값이 항상 이긴다.
		if is_boss:
			Hit.hitstop(0.25)
			Hit.shake(6.0)
		else:
			Hit.hitstop(0.04)
		modulate = Color(2.5, 2.5, 2.5, 1.0)
		_spawn_death_debris()
		var drop := Pickup.roll_drop(is_boss)
		if is_boss:
			# 이 게임만의 보스 전용 확정 드랍. 세트 효과와 짝을 이룬다.
			var boss_id := str(kind.get("id", ""))
			var signature := GameState.boss_drop(boss_id)
			drop["item_name"] = signature if signature != "" else "강철 대검"
			drop["boss"] = true
		if not drop.is_empty():
			dropped.emit(drop, global_position)
		if not is_boss:
			# 동서남북 던전 전용 드랍. 낮은 확률로 그 지역에서만 나온다.
			var area_drop := GameState.area_item(area_id)
			if area_drop != "" and randf() < 0.05:
				dropped.emit({"kind": "chest", "item_name": area_drop}, global_position + Vector2(-8, 0))
			# 탑 전용 결정. 그 난이도 탑 몬스터만 떨어뜨린다("초월" 등급
			# 제작 재료).
			if area_id == "tower" and randf() < 0.08:
				dropped.emit({"kind": "tower_material", "tower_tier": GameState.tower_difficulty},
					global_position + Vector2(0, -8))
			# 5~10장 잡몹은 그 장의 정수를 떨어뜨린다(세트 장비 제작 재료).
			var essence := GameState.chapter_essence(World.chapter_of(area_id))
			if essence != "" and randf() < GameState.ESSENCE_DROP_RATE:
				dropped.emit({"kind": "essence", "essence": essence}, global_position + Vector2(0, -8))
		if is_boss:
			# 세트를 완전히 보스 전용으로 만드는 두 번째 확정 드랍.
			var extra := GameState.boss_drop_extra(str(kind.get("id", "")))
			if extra != "":
				dropped.emit({"kind": "chest", "item_name": extra, "boss": true}, global_position + Vector2(8, 0))
			# 소환수는 보스와 함께 사라진다.
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_meta("summoned_by") and e.get_meta("summoned_by") == get_instance_id():
					e.remove_from_group("enemies")
					e.queue_free()
			boss_fallen.emit()
		if is_midboss:
			# 중간보스 확정 드랍: 전직의 돌 1개(3타입 균등 랜덤). SECOND_JOB_DESIGN.md 5절.
			var stone := str(GameState.JOB_STONES[randi() % GameState.JOB_STONES.size()])
			dropped.emit({"kind": "job_stone", "stone_id": stone}, global_position + Vector2(0, -8))
		defeated.emit(exp_reward, gold_reward, str(kind.get("id", archetype)))
		# 사망 트윈 중 추가 피격을 받지 않게 그룹에서 먼저 빼고 충돌을 끈다
		# (CLAUDE.md 함정: queue_free는 프레임 끝 처리라 그대로 두면 한 프레임
		# 더 그룹·충돌에 남는다).
		remove_from_group("enemies")
		$CollisionShape2D.set_deferred("disabled", true)
		var death_tween := create_tween()
		# 보스는 죽는 순간 대사(_on_boss_fallen→_play_dialogue)가 트리를
		# 일시정지한다 - 트윈이 트리를 따라 멈추면 대사가 끝날 때까지
		# queue_free가 영영 안 불려 처치 판정이 막힌다(10장 전 보스 전부
		# kill_boss FAIL로 실측). 대사와 무관하게 계속 흐르게 한다.
		death_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		death_tween.tween_property($Sprite, "scale", _sprite_scale * 1.3, 0.15)
		death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
		death_tween.tween_callback(queue_free)


## 처치 순간 터지는 파편 4~6개(코드로 그린 사각형, 새 에셋 없이). 바깥으로 튀며 사라진다.
func _spawn_death_debris() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var count := randi_range(4, 6)
	for i in count:
		var chip := ColorRect.new()
		chip.size = Vector2(3.0, 3.0)
		chip.color = Color(1.0, 1.0, 1.0, 0.9)
		chip.z_index = 45
		chip.global_position = global_position - chip.size / 2.0
		parent.add_child(chip)
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var dist := randf_range(10.0, 18.0)
		var chip_tween := chip.create_tween()
		chip_tween.set_parallel(true)
		chip_tween.tween_property(chip, "global_position",
			chip.global_position + dir * dist, 0.18).set_ease(Tween.EASE_OUT)
		chip_tween.tween_property(chip, "modulate:a", 0.0, 0.18)
		chip_tween.chain().tween_callback(chip.queue_free)
