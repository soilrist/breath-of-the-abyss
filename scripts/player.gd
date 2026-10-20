extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died
signal potion_changed(count: int)
signal mana_changed(current: int, maximum: int)
signal potion_used(healed: int)

@export var move_speed := 72.0
@export var max_health := 100
@export var attack_damage := 12
@export var attack_range := 25.0
@export var attack_cooldown := 0.45
@export var max_mana := 60
@export var skill_mana_cost := 18
@export var dash_cooldown_max := 1.1

var health := max_health
var facing := Vector2.DOWN
var cooldown_time := 0.0
var invulnerability_time := 0.0
## (결함 조사용, 2026-10-20 origin_throne 반복 사망) 사망 순간 무엇에 맞았는지
## 진단 로그(auto_quest_probe.gd DEATH 줄)가 읽는다 - 근접인지 투사체(volley)
## 인지 구분이 "enemies_near=0" 만으로는 안 되기 때문.
var last_hit_source := ""
var spawn_position := Vector2.ZERO
var potions := 2
## 스킬 4개가 쿨타임을 공유하던 걸 슬롯별로 따로 관리하게 바꿨다.
## 하나 쓰면 다른 스킬도 같이 막히던 버그가 여기서 나던 것이었다.
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var skill_cooldown_maxes: Array[float] = [2.2, 2.2, 2.2, 2.2, 2.2, 2.2]
var skill_slot := 0
## 지금 지역의 픽셀 크기. 지역이 바뀔 때 main 이 넣어 준다.
var bounds := Vector2(320, 240)
var dash_cooldown := 0.0
var mana := max_mana
var mana_regen_tick := 0.0
var hp_regen_tick := 0.0
var animation_tick := 0.0
var motion := ""
var motion_time := 0.0
var motion_duration := 0.0
## 오토사냥이 돌/나무 같은 정적 장애물에 막혀 제자리걸음할 때 옆으로
## 비켜가게 하는 상태. 실제 이동 거리가 계속 작으면 의도한 방향을 90도
## 틀어 우회하고, 오래 안 막히면(0.4초) 원래 목표 방향으로 되돌아간다.
var _auto_stuck_time := 0.0
var _auto_avoid_sign := 1.0
## (INBOX 결함, 2026-09-07 04:25) 같은 회피 시도가 계속 막혀 반대 방향으로
## 재시도(sign 반전)해도 못 빠져나오면, 다음 시도부터 옆으로 비키는 거리를
## 키운다. 소품이 _AUTO_AVOID_CLEAR_DIST(18px)보다 넓게 뭉쳐 있으면 고정
## 거리로는 영원히 못 벗어나 제자리에서 계속 방향만 바꾸는 긴 정지가
## 생겼다(시드 20260909 실측 worst_streak=652). 실제로 전진(막히지 않고
## 목표 방향 복귀)하면 원래 거리로 되돌린다.
var _auto_avoid_escalation := 1.0
const _AUTO_AVOID_ESCALATION_MAX := 4.0
## (INBOX 10:05(a) 후속, 2026-09-07) 회피 거리를 최대(4배)까지 키워도
## 못 빠져나오면(양쪽으로 다 시도해도 막힘) 옆이 아니라 사방이 막힌
## 막다른 구석(glade rock_s 부근 헤드리스 재현: escalation=4.0에서도
## 계속 정지)으로 본다. 옆걸음 대신 일단 목표 반대 방향으로 물러나
## 구석 자체에서 빠져나온 뒤 다시 접근을 시도한다 - 새 길찾기 시스템
## 없이 기존 옆걸음 회피가 못 푸는 경우에만 보충하는 동작이다.
var _auto_avoid_retreat_time := 0.0
const _AUTO_AVOID_RETREAT_TIME := 1.0
## (INBOX 답, 2026-09-06 19:40) 프레임 단위 이동량만 보면 장애물 모서리에서
## 위아래로 미세하게 떨며(매 프레임은 기준치를 넘기지만 누적 실제 진행은
## 0에 가까움) _auto_stuck_time이 매 프레임 0으로 리셋돼 영원히 트리거되지
## 않는 경우가 있었다(hill (410,291)~(410,298), 게임 5분 고정 실측). 매
## 프레임 대신 _AUTO_STUCK_WINDOW초 동안의 순 이동 거리로 판정한다.
var _auto_stuck_window_time := 0.0
var _auto_stuck_window_origin := Vector2.ZERO
const _AUTO_STUCK_WINDOW := 0.5
## 회피가 시작되면 이 시간(초) 동안은 매 틱 "막혔나?"를 다시 재지 않고
## 무조건 비켜가는 방향을 유지한다. 장애물 옆을 스치듯 지나가며 생기는
## 작은 순간 이동량만으로 매 틱 안 막힌 걸로 오판해 방향을 원래대로
## 되돌리면, 장애물 모서리를 채 벗어나기도 전에 다시 정면으로 부딪혀
## 제자리에서 위아래로만 떠는 상태가 됐다(실측: 장애물 앞에서 y좌표만
## 왔다갔다하며 6초 내내 옆으로 못 빠져나감).
var _auto_avoid_commit_time := 0.0
const _AUTO_AVOID_COMMIT := 0.6
## 회피 시작 시점의 좌표. 여기서 얼마나 실제로 비켜났는지(거리)를 재서
## 시간이 아니라 "장애물을 실제로 벗어났는지"로 복귀 시점을 판단한다.
var _auto_avoid_origin := Vector2.ZERO
## glade rock_s 옆(pos=(501,300) 부근) 소품 여러 개가 뭉쳐 있으면 회피가
## 아무리 커도(_AUTO_AVOID_CLEAR_DIST) 여전히 못 빠져나오는 경우가 실측됨
## (60분 probe, game_min≈20.7 STALL). 소품 폭을 재서 우회 거리를 늘리는
## 대신, 같은 적을 향해 _AUTO_HUNT_GIVEUP_STUCK초 동안 거리가 안 줄면 그
## 적을 잠깐 포기하고 다른 적을 고른다 - 장애물이 얼마나 크게 뭉쳐있든
## "막힌 목표를 계속 추격"만 그만두면 되므로 소품 크기를 몰라도 된다.
var _auto_hunt_target_id := 0
var _auto_hunt_best_dist_seen := INF
var _auto_hunt_no_progress_time := 0.0
## 아이템 줍기도 같은 무진행 포기를 쓴다(소품 안에 떨어진 아이템을 향해
## 영원히 벽을 밀던 hill FREEZE, 2026-09-09). 포기한 픽업은 blacklist에
## 영구(INF) 등록 - 지역을 나가면 픽업이 사라지므로 냉각이 필요 없다.
var _auto_pickup_id := 0
var _auto_pickup_best_dist := INF
var _auto_pickup_no_progress_time := 0.0
var _auto_hunt_blacklist := {} ## 적 instance id -> 남은 냉각 시간(초)
const _AUTO_HUNT_GIVEUP_STUCK := 2.5
const _AUTO_HUNT_BLACKLIST_TIME := 6.0
## (INBOX 10:05(a) 후속, 2026-09-07) glade rock_s(cell 32,19) 부근에서
## 위 포기 로직 자체가 무력화되는 새 결함 실측: 장애물 뒤편에 적이 2마리
## 이상 있으면 A를 포기(블랙리스트)해도 곧장 방향이 비슷한 B를 골라 같은
## 장애물에 다시 막히고, B도 포기하면 그새 A의 냉각이 끝나 다시 A로
## 돌아가 영원히 핑퐁한다(헤드리스 재현, pos≈(490.9,307) 부근). 포기 시
## 그 목표와 "같은 방향"(장애물 뒤편일 가능성이 높은 쪽)의 다른 후보도
## 같이 잠깐 접어 핑퐁 자체를 막는다 - 장애물 크기·위치를 몰라도 된다.
const _AUTO_HUNT_GIVEUP_DIR_COS := 0.7 ## 대략 45도 이내를 "같은 방향"으로 봄.
## (INBOX 10:05 후속, 2026-09-07) hill_ridge cell(3,7)/(4,7) 계단형 담은
## 위 거리 기반 포기(_AUTO_HUNT_GIVEUP_STUCK)가 몇 분이 지나도 안 걸렸다
## (`auto_quest_probe --seed=1/3/4` 재현, game_min≈12 STALL) - 담을 따라
## 천천히 표류하며 `_auto_hunt_best_dist_seen`을 아주 조금씩 계속
## 갱신해(옆걸음마다 우연히 4px 넘게 가까워짐) 타이머가 매번 트리거
## 직전에 리셋됐다. `_auto_avoid_obstacle()`이 "사방이 막힌 구석"으로
## 판단해 물러난 횟수(같은 목표를 쫓는 동안)를 별도로 세어, 그게
## 여러 번 반복되면 실제 거리 진행 여부와 상관없이 포기한다 - 옆걸음
## 리셋 조건 자체(±두 번 되돌렸다 회귀난 부분)는 손대지 않는다.
var _auto_hunt_retreat_count := 0
const _AUTO_HUNT_GIVEUP_RETREAT_COUNT := 3
## 직업 스킬의 지속 버프. 키는 "atk_mult"/"speed_mult", 값은 {value, remaining}.
## JOB_DESIGN.md 3절 - 기존에 없던 지속효과 시스템을 이 스킬에서 새로 도입했다.
var active_buffs := {}
## 도적 "은신" 스킬 표시: 켜져 있으면 다음 피해를 주는 행동 한 번이 확정 치명타.
var stealth_crit_pending := false
## 오토사냥(AUTOHUNT_DESIGN.md). AI가 direction/attack()/cast_skill()을
## 그대로 호출한다 — Input 이벤트를 거치지 않으므로 사람의 실제 입력과
## 충돌하지 않는다(main.gd가 사람 입력을 감지하면 이 값을 false로 끈다).
var auto_hunt := false
## AUTOHUNT_DESIGN.md §10.2. 퀘스트모드가 NPC에게 걸어갈 때만 쓴다 -
## 오토사냥 전투 AI와 별개라 auto_hunt보다 먼저 확인한다. 도착 판정(§10.3
## TALK_RANGE)과 해제는 main.gd가 한다.
var auto_walk_target := Vector2.ZERO
var auto_walk_active := false
## (INBOX 답, 2026-09-07 08:10) main.gd가 World.walk_waypoints()로 구한
## AStarGrid2D 경로. 비어 있으면(예: 이 필드를 안 쓰고 auto_walk_target만
## 직접 지정하는 기존 테스트들) _auto_walk_tick()이 옛 직선 이동으로
## 대체한다 - 기존 검사와의 하위호환.
var auto_walk_waypoints: Array[Vector2] = []

# hero.png 배치: 4열 = 아래·위·왼쪽·오른쪽, 7행 = 대기 / 걷기 4 / 공격 / 기타.
const DIR_DOWN := 0
const DIR_UP := 1
const DIR_LEFT := 2
const DIR_RIGHT := 3
const ROW_IDLE := 0
const ROW_WALK := 1
const ROW_ATTACK := 5
const ROW_EXTRA := 6  # 사망·아이템·특수 프레임이 든 줄

## 8방향 손 무기 위치. back 이 참이면 몸 뒤로 그린다(위를 볼 때 칼이 등 뒤로 가야 자연스럽다).
## 순서는 아래·아래오른쪽·오른쪽·위오른쪽·위·위왼쪽·왼쪽·아래왼쪽. hand_fx 시트 생성 스크립트와 순서를 맞춰야 한다.
const HAND_OCTANT := [
	{"pos": Vector2(4, -2), "back": false},
	{"pos": Vector2(6, -2), "back": false},
	{"pos": Vector2(6, -3), "back": false},
	{"pos": Vector2(5, -5), "back": true},
	{"pos": Vector2(-2, -6), "back": true},
	{"pos": Vector2(-5, -5), "back": true},
	{"pos": Vector2(-6, -3), "back": false},
	{"pos": Vector2(-6, -2), "back": false},
]

var _hand: Sprite2D
var _hand_item := ""
var _helmet: Sprite2D
var _helmet_skin := ""
var _job_icon: Sprite2D
## 천공 세트(무지개) 전용 틴트. 부위마다 독립된 인스턴스를 써서 하나가
## 숨겨져도(예: 투구 미착용) 다른 부위 재생이 영향받지 않는다.
const RAINBOW_SHADER := preload("res://assets/shaders/rainbow_tint.gdshader")
var _armor_rainbow := ShaderMaterial.new()
var _helmet_rainbow := ShaderMaterial.new()
var _hand_rainbow := ShaderMaterial.new()
## 마지막에 그린 직업. 바뀔 때만 텍스처를 다시 로드한다.
var _job_icon_of := ""


func _ready() -> void:
	# Main(부모)이 process_mode = ALWAYS라서 명시하지 않으면 이 노드도
	# 상속받아 대화창·인벤토리 등으로 게임이 일시정지돼도 계속 움직인다
	# ("NPC와 대화 중 방향키를 누르면 캐릭터가 그대로 움직인다" 버그).
	# 플레이어는 반드시 일시정지를 따라야 하므로 PAUSABLE로 고정한다.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_position = global_position
	add_to_group("player")
	_armor_rainbow.shader = RAINBOW_SHADER
	_helmet_rainbow.shader = RAINBOW_SHADER
	_hand_rainbow.shader = RAINBOW_SHADER
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	_hand = Sprite2D.new()
	_hand.name = "Hand"
	_hand.centered = true
	add_child(_hand)
	# 투구 착용감을 주는 덮개. 인벤토리에 이미 있는 투구 아이콘(등급별
	# icon_helmet/icon_tower_helmet/icon_boss_helmet)을 그대로 잘라
	# 4방향으로 뒤집어 만든 스프라이트를 쓴다("투구를 써도 머리가
	# 그대로 보인다" / "아이콘 있으니까 그걸로 하면 되잖아" 피드백).
	_helmet = Sprite2D.new()
	_helmet.name = "Helmet"
	_helmet.centered = $Sprite.centered
	_helmet.position = $Sprite.position
	_helmet.hframes = 4
	add_child(_helmet)
	# 전직하면 머리 위에 뜨는 작은 직업 상징. 헬멧보다 더 위, 이름표보다
	# 위쪽에 그려야 겹치지 않는다("전직과 동시에 캐릭터 머리위에 작게
	# 그 아이콘이 있었으면 좋겠어" 요청).
	_job_icon = Sprite2D.new()
	_job_icon.name = "JobIcon"
	_job_icon.centered = true
	_job_icon.position = Vector2($Sprite.position.x, $Sprite.position.y - 18.0)
	add_child(_job_icon)
	_update_job_icon()


func _physics_process(delta: float) -> void:
	motion_time = maxf(motion_time - delta, 0.0)
	cooldown_time = maxf(cooldown_time - delta, 0.0)
	# 2차 전직으로 5~6번 슬롯이 추가된다. 배열은 저장/전직 전환에도
	# 안전하게 현재 스킬 수 이상을 항상 보장한다.
	var required_slots := GameState.active_skills().size()
	while skill_cooldowns.size() < required_slots:
		skill_cooldowns.append(0.0)
		skill_cooldown_maxes.append(2.2)
	for i in skill_cooldowns.size():
		skill_cooldowns[i] = maxf(skill_cooldowns[i] - delta, 0.0)
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	_tick_buffs(delta)
	mana_regen_tick += delta
	if mana_regen_tick >= 1.0 and mana < max_mana:
		mana_regen_tick = 0.0
		# 불꽃의 정령: 마력 회복이 더 빠르다.
		var mana_gain := 5 if GameState.spirit_effect() == "mana_flow" else 3
		if GameState.job == "mage":
			mana_gain += int(max_mana * GameState.MAGE_MANA_REGEN_PCT)
		mana = mini(mana + mana_gain, max_mana)
		mana_changed.emit(mana, max_mana)
	# 숲의 정령: 5초마다 최대 체력의 2%를 회복한다.
	if GameState.spirit_effect() == "regen" and health > 0 and health < max_health:
		hp_regen_tick += delta
		if hp_regen_tick >= 5.0:
			hp_regen_tick = 0.0
			health = mini(health + maxi(int(max_health * 0.02), 1), max_health)
			health_changed.emit(health, max_health)
	invulnerability_time = maxf(invulnerability_time - delta, 0.0)
	modulate = Color.WHITE if invulnerability_time == 0.0 else Color(1.0, 0.55, 0.55)
	var direction := Vector2.ZERO
	if motion_time == 0.0:
		if auto_walk_active:
			direction = _auto_walk_tick()
		elif auto_hunt:
			direction = _auto_hunt_tick(delta)
		else:
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var pos_before_move := global_position
	## (INBOX 답, 2026-09-06 10:05 ④) 회피는 auto_hunt일 때만 적용돼
	## auto_walk(마을 이동·사냥터 출구 이동) 중에는 장애물 모서리에서
	## velocity != 0인 채 위치가 영원히 고정되는 결함이 있었다(hill_ridge
	## 실측, pos=(427.0, 248.0) 부근). 새 이동 시스템 없이 같은 회피 로직을
	## auto_walk에도 그대로 적용한다.
	var auto_moving := auto_hunt or auto_walk_active
	if auto_moving and direction != Vector2.ZERO:
		direction = _auto_avoid_obstacle(direction, delta)
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	velocity = direction * _current_move_speed()
	if direction != Vector2.ZERO:
		animation_tick += delta * 8.0
	else:
		animation_tick = 0.0
	_update_sprite(direction)
	move_and_slide()
	if auto_moving:
		_auto_track_stuck(direction, pos_before_move, delta)
	_clamp_to_bounds()
	_lock_camera_to_screen()
	if not auto_hunt:
		if Input.is_action_just_pressed("attack") and cooldown_time == 0.0:
			attack()
		if Input.is_action_just_pressed("dash"):
			try_dodge()


## AUTOHUNT_DESIGN.md §10.2. auto_walk_target으로 곧장 걸어간다. 도착
## 판정과 auto_walk_active 해제는 main.gd의 퀘스트모드 상태머신이 한다.
func _auto_walk_tick() -> Vector2:
	while auto_walk_waypoints.size() > 0 and global_position.distance_to(auto_walk_waypoints[0]) < 4.0:
		auto_walk_waypoints.remove_at(0)
	if auto_walk_waypoints.size() > 0:
		return (auto_walk_waypoints[0] - global_position).normalized()
	if global_position.distance_to(auto_walk_target) < 4.0:
		return Vector2.ZERO
	return (auto_walk_target - global_position).normalized()


## AUTOHUNT_DESIGN.md §3. 사람 입력 대신 AI가 매 틱 이 함수로
## direction을 만들고, 필요하면 attack()/cast_skill()/try_dodge()/
## try_use_potion()을 직접 호출한다 - 새 전투 로직을 만들지 않고
## 기존 함수를 그대로 재사용하는 게 핵심 설계 원칙이다.
func _auto_hunt_tick(_delta: float) -> Vector2:
	if health < max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO and potions > 0:
		try_use_potion()
	for id in _auto_hunt_blacklist.keys():
		_auto_hunt_blacklist[id] -= _delta
		if _auto_hunt_blacklist[id] <= 0.0:
			_auto_hunt_blacklist.erase(id)
	var target: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health <= 0:
			continue
		if _auto_hunt_blacklist.has(enemy.get_instance_id()):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			target = enemy
	# 전투 중(공격 사거리 안)이면 거리가 그대로여도 정상 - 포기 판정은
	# 접근 단계(사거리 밖에서 다가가는 중)에만 적용한다.
	var reaching: bool = target != null and best_dist - target.body_radius() > attack_range
	if not reaching:
		_auto_hunt_target_id = (target.get_instance_id() if target != null else 0)
		_auto_hunt_no_progress_time = 0.0
	else:
		var tid := target.get_instance_id()
		if tid != _auto_hunt_target_id:
			_auto_hunt_target_id = tid
			_auto_hunt_best_dist_seen = best_dist
			_auto_hunt_no_progress_time = 0.0
			_auto_hunt_retreat_count = 0
		elif best_dist < _auto_hunt_best_dist_seen - 4.0:
			_auto_hunt_best_dist_seen = best_dist
			_auto_hunt_no_progress_time = 0.0
			_auto_hunt_retreat_count = 0
		else:
			_auto_hunt_no_progress_time += _delta
			if _auto_hunt_no_progress_time >= _AUTO_HUNT_GIVEUP_STUCK \
					or _auto_hunt_retreat_count >= _AUTO_HUNT_GIVEUP_RETREAT_COUNT:
				var giveup_offset: Vector2 = target.global_position - global_position
				var giveup_dir: Vector2 = giveup_offset.normalized() if giveup_offset.length() > 0.001 else Vector2.ZERO
				_auto_hunt_blacklist[tid] = _AUTO_HUNT_BLACKLIST_TIME
				if giveup_dir != Vector2.ZERO:
					for other in get_tree().get_nodes_in_group("enemies"):
						if other.health <= 0 or other.get_instance_id() == tid:
							continue
						var other_offset: Vector2 = other.global_position - global_position
						if other_offset.length() <= attack_range:
							continue
						if other_offset.normalized().dot(giveup_dir) >= _AUTO_HUNT_GIVEUP_DIR_COS:
							_auto_hunt_blacklist[other.get_instance_id()] = _AUTO_HUNT_BLACKLIST_TIME
				_auto_hunt_target_id = 0
				_auto_hunt_no_progress_time = 0.0
				_auto_hunt_retreat_count = 0
				target = null
				best_dist = INF
	# 사냥 중 바닥에 떨어진 아이템도 자동으로 줍는다(사람이 밟으면 줍는
	# Pickup.body_entered와 같은 경로 - 여기선 그쪽으로 걸어가기만 하면
	# 됨, 새 픽업 로직 불필요). 전투 중(적이 공격 사거리 안)에는 싸움을
	# 끊지 않고, 그 외에는 더 가까운 쪽(적 vs 아이템)을 향해 간다.
	var in_combat: bool = target != null and best_dist - target.body_radius() <= attack_range
	if not in_combat:
		var nearest_pickup: Node2D = null
		var pickup_dist := INF
		for pickup in get_tree().get_nodes_in_group("pickups"):
			if _auto_hunt_blacklist.has(pickup.get_instance_id()):
				continue
			var pdist := global_position.distance_to(pickup.global_position)
			if pdist < pickup_dist:
				pickup_dist = pdist
				nearest_pickup = pickup
		if nearest_pickup != null and (target == null or pickup_dist < best_dist):
			var pid := nearest_pickup.get_instance_id()
			if pid != _auto_pickup_id or pickup_dist < _auto_pickup_best_dist - 4.0:
				_auto_pickup_id = pid
				_auto_pickup_best_dist = pickup_dist
				_auto_pickup_no_progress_time = 0.0
			else:
				_auto_pickup_no_progress_time += _delta
				if _auto_pickup_no_progress_time >= _AUTO_HUNT_GIVEUP_STUCK:
					_auto_hunt_blacklist[pid] = INF
					_auto_pickup_id = 0
					return Vector2.ZERO
			var poffset: Vector2 = nearest_pickup.global_position - global_position
			if poffset.length() > 0.001:
				facing = poffset.normalized()
				return poffset.normalized()
			return Vector2.ZERO
	if target == null:
		return Vector2.ZERO
	var offset: Vector2 = target.global_position - global_position
	if offset.length() > 0.001:
		facing = offset.normalized()
	if ("charging" in target) and target.charging > 0.0 and best_dist < attack_range * 1.5:
		try_dodge()
	if _auto_cast_skill(target, best_dist):
		return Vector2.ZERO
	if cooldown_time == 0.0 and best_dist - target.body_radius() <= attack_range:
		attack()
	if best_dist - target.body_radius() <= attack_range:
		return Vector2.ZERO
	return offset.normalized()


## 오토사냥이 목표 방향으로 곧장 걷다가 돌/나무 같은 정적 장애물(StaticBody2D)에
## 막히면 move_and_slide()는 미끄러지긴 해도 방향 자체는 계속 장애물 쪽이라
## 제자리걸음이 된다. 실제 이동 거리가 계속 작으면 목표 방향과 수직인 쪽으로
## 완전히 틀어 비켜가게 하고, 장애물 폭(약 16px)만큼 실제로 비켜난 뒤에야
## 원래 목표 방향으로 되돌린다(시간 기준이면 다 비켜나기 전에 복귀해 다시
## 정면으로 부딪히는 지그재그가 생긴다 - 실측으로 확인됨).
const _AUTO_STUCK_TRIGGER := 0.25
const _AUTO_AVOID_CLEAR_DIST := 18.0


func _auto_avoid_obstacle(direction: Vector2, delta: float) -> Vector2:
	if _auto_avoid_retreat_time > 0.0:
		_auto_avoid_retreat_time -= delta
		return -direction
	## (INBOX 답, 2026-09-06 10:05 ④) 모서리에 걸리면 회피 중(옆으로 비켜
	## 가는 방향)에도 여전히 막힐 수 있다 - 그럴 땐 같은 쪽으로 계속
	## 밀어붙이는 대신 반대 방향으로 다시 시도한다.
	if _auto_avoid_commit_time > 0.0 and _auto_stuck_time >= _AUTO_STUCK_TRIGGER:
		## (INBOX 10:05(a) 후속) 반대 방향까지 최대 거리로 다시 시도했는데도
		## 또 막히면 옆이 아니라 사방이 막힌 구석이다 - 옆걸음을 그만 접고
		## 일단 물러난다.
		if _auto_avoid_escalation >= _AUTO_AVOID_ESCALATION_MAX:
			_auto_avoid_retreat_time = _AUTO_AVOID_RETREAT_TIME
			_auto_avoid_commit_time = 0.0
			_auto_avoid_escalation = 1.0
			_auto_stuck_time = 0.0
			_auto_hunt_retreat_count += 1
			return -direction
		_auto_avoid_sign = -_auto_avoid_sign
		_auto_avoid_origin = global_position
		_auto_stuck_time = 0.0
		_auto_avoid_escalation = minf(_auto_avoid_escalation + 1.0, _AUTO_AVOID_ESCALATION_MAX)
	if _auto_avoid_commit_time <= 0.0 and _auto_stuck_time >= _AUTO_STUCK_TRIGGER:
		_auto_avoid_commit_time = _AUTO_AVOID_COMMIT
		_auto_avoid_origin = global_position
	if _auto_avoid_commit_time <= 0.0:
		return direction
	# 회피 중에는 목표 방향을 섞지 않고 순수하게 옆으로만 이동한다(대각선으로
	# 섞으면 수직 이동량이 줄어 장애물을 다 벗어나기 전에 시간이 끝난다).
	# 회피 시작 지점에서 실제로 _AUTO_AVOID_CLEAR_DIST*escalation만큼
	# 비켜났으면 그때 목표 방향으로 복귀한다.
	if global_position.distance_to(_auto_avoid_origin) >= _AUTO_AVOID_CLEAR_DIST * _auto_avoid_escalation:
		_auto_avoid_commit_time = 0.0
		_auto_avoid_escalation = 1.0
		return direction
	_auto_avoid_commit_time -= delta
	return Vector2(-direction.y, direction.x) * _auto_avoid_sign


func _auto_track_stuck(direction: Vector2, pos_before: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		_auto_stuck_time = 0.0
		_auto_stuck_window_time = 0.0
		return
	if _auto_stuck_window_time == 0.0:
		_auto_stuck_window_origin = pos_before
	_auto_stuck_window_time += delta
	if _auto_stuck_window_time < _AUTO_STUCK_WINDOW:
		return
	var moved := global_position.distance_to(_auto_stuck_window_origin)
	var expected := _current_move_speed() * _auto_stuck_window_time
	var window_time := _auto_stuck_window_time
	_auto_stuck_window_time = 0.0
	if expected <= 0.001:
		return
	if moved < expected * 0.3:
		if _auto_stuck_time == 0.0:
			_auto_avoid_sign = 1.0 if randf() < 0.5 else -1.0
		_auto_stuck_time += window_time
	else:
		_auto_stuck_time = 0.0
		_auto_avoid_escalation = 1.0


## 슬롯 index가 지금 당장 성공할 조건(배움/쿨타임/마력/HP)을 갖췄는지
## cast_skill() 안의 실패 검사와 같은 조건으로 미리 확인한다. cast_skill()은
## 성공/실패 모두 사람이 읽는 문구를 돌려주므로(빈 문자열이 아님) 반환값으로
## 성공 여부를 구분할 수 없다 - 호출 전에 먼저 걸러야 한다.
func _auto_skill_ready(slot: int) -> bool:
	if not GameState.skill_unlocked(slot):
		return false
	if skill_cooldowns[slot] > 0.0:
		return false
	var data: Dictionary = GameState.active_skills()[slot]
	if mana < int(data["cost"]):
		return false
	if data.has("hp_cost_pct") and health <= 1:
		return false
	return true


## AUTOHUNT_DESIGN.md §4 우선순위: 회복 > 미적용 버프 > 광역(적 2체 이상 뭉침) > 나머지 공격.
func _auto_cast_skill(target: Node2D, dist: float) -> bool:
	var skills: Array = GameState.active_skills()
	var nearby := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health > 0 and global_position.distance_to(enemy.global_position) <= attack_range * 2.5:
			nearby += 1
	var heal_slot := -1
	var mana_slot := -1
	var buff_slot := -1
	var aoe_slot := -1
	var atk_slot := -1
	for i in skills.size():
		if not _auto_skill_ready(i):
			continue
		var data: Dictionary = skills[i]
		var is_self_cast: bool = data.has("buff") or float(data.get("heal_pct", 0.0)) > 0.0 or data.has("mana_restore_pct")
		var effective_range: float = maxf(float(data.get("radius", 0.0)), attack_range * 2.5)
		if not is_self_cast and dist > effective_range:
			continue
		if heal_slot == -1 and float(data.get("heal_pct", 0.0)) > 0.0 and health < max_health * 0.6:
			heal_slot = i
		# 마나 순환(마법사 4번): 마력 30% 미만이면 HP 절반 이상일 때만 쓴다.
		elif mana_slot == -1 and data.has("mana_restore_pct") and mana < max_mana * 0.3 and health > max_health * 0.5:
			mana_slot = i
		elif buff_slot == -1 and data.has("buff") and not active_buffs.has(str(data["buff"]["stat"])):
			buff_slot = i
		elif aoe_slot == -1 and nearby >= 2 and (data.has("chain_count") or float(data.get("radius", 0.0)) > attack_range):
			aoe_slot = i
		elif atk_slot == -1 and float(data.get("damage", 0.0)) > 0.0:
			atk_slot = i
	var chosen := heal_slot
	if chosen == -1:
		chosen = mana_slot
	if chosen == -1:
		chosen = buff_slot
	if chosen == -1:
		chosen = aoe_slot
	if chosen == -1:
		chosen = atk_slot
	if chosen == -1:
		return false
	cast_skill(chosen)
	return true


## 시트에 네 방향이 모두 있으므로 좌우 반전을 쓰지 않는다.
func _facing_column() -> int:
	if absf(facing.x) > absf(facing.y):
		return DIR_RIGHT if facing.x > 0.0 else DIR_LEFT
	return DIR_DOWN if facing.y >= 0.0 else DIR_UP


func _update_sprite(direction: Vector2) -> void:
	var column := _facing_column()
	var row := ROW_IDLE
	if motion_time > 0.0 and motion == "death":
		# 6행 0열이 쓰러진 자세다. 방향과 무관하다.
		$Sprite.frame = ROW_EXTRA * 4
		return
	if motion_time > 0.0 and (motion == "attack" or motion == "skill"):
		row = ROW_ATTACK
	elif motion_time > 0.0 and motion == "dodge":
		row = ROW_WALK + 3
	elif direction != Vector2.ZERO:
		row = ROW_WALK + int(animation_tick) % 4
	$Sprite.frame = row * 4 + column
	_update_hand()
	_update_armor_tint()
	_update_helmet(column)
	_update_job_icon()


## 갑옷마다 몸통 그림 자체를 바꾼다("갑옷 입어도 머리만 계속 보인다,
## 색만 바뀌지 말고 옷이 바뀌어야지" 피드백, INBOX O 조각 2). 16x16
## 규격에 맞는 무료 레이어형(장비 교체) 캐릭터 팩이 없어 새로 그릴 수
## 없으므로, hero.png와 같은 틀(64x112, 4방향 x idle/걷기4/공격/기타)인
## assets/vendor/ninja_adventure/(CC0) 캐릭터 시트를 갑옷별로 배분해
## assets/characters/body_*.png로 복사해 두고 GameState.body_skin_for()로
## 찾는다(매핑은 data/item_body_skins.json, PROMPT.md ③). 그 위에 기존
## 세트/등급 색 틴트를 그대로 얹는다.
var _body_skin := ""

func _update_armor_tint() -> void:
	var armor := str(GameState.equipped.get("armor", ""))
	var skin := GameState.body_skin_for(armor)
	if skin != _body_skin:
		_body_skin = skin
		$Sprite.texture = load(skin)
	if GameState.is_rainbow_item(armor):
		$Sprite.material = _armor_rainbow
		$Sprite.modulate = Color.WHITE
	else:
		$Sprite.material = null
		$Sprite.modulate = GameState.palette_color_for(armor)


## 투구마다 머리 오버레이 그림 자체를 바꾼다(INBOX O 조각 2 나머지 절반 —
## 몸통은 위 _update_armor_tint()가 이미 이렇게 함). 벤더 팩은 투구만 뗀
## 오버레이가 없어 tools/build_helmet_overlays.py가 캐릭터 시트 idle 행의
## 머리 부분만 잘라 assets/characters/helmet_shape_*.png로 미리 만들어
## 둔다. 매핑은 data/item_helmet_skins.json, GameState.helmet_skin_for().
func _update_helmet(column: int) -> void:
	var helmet := str(GameState.equipped.get("helmet", ""))
	_helmet.visible = helmet != ""
	if helmet == "":
		return
	var skin := GameState.helmet_skin_for(helmet)
	if skin != _helmet_skin:
		_helmet_skin = skin
		_helmet.texture = load(skin)
	_helmet.frame = column
	if GameState.is_rainbow_item(helmet):
		_helmet.material = _helmet_rainbow
		_helmet.modulate = Color.WHITE
	else:
		_helmet.material = null
		_helmet.modulate = GameState.palette_color_for(helmet)


## 전직한 직업 아이콘을 머리 위에 띄운다. 전직 전(job == "")이면 숨긴다.
func _update_job_icon() -> void:
	var job := GameState.job
	if job == "":
		_job_icon.visible = false
		_job_icon_of = ""
		return
	_job_icon.visible = true
	if job != _job_icon_of:
		_job_icon_of = job
		_job_icon.texture = load("res://assets/icons/jobs/job_%s.svg" % job)


## 시트 위쪽 8방향과 순서를 맞춘 각도표. facing 각도(도)에서 가장 가까운 방향을 고른다.
## 90=아래, 45=아래오른쪽, 0=오른쪽, -45=위오른쪽, -90=위, -135=위왼쪽, 180=왼쪽, 135=아래왼쪽.
func _facing_octant() -> int:
	var deg := rad_to_deg(facing.angle())
	var idx := int(round((90.0 - deg) / 45.0))
	return ((idx % 8) + 8) % 8


## 칼을 뽑아 들고(draw) 자세를 잡았다가(ready) 베고(slash) 마무리(follow)하는 4단계 프레임.
## 평소엔 0번째 칸(idle, 칼을 내려 든 자세)을 보여준다. 무기별로 다른 그림(칼집 모양)을 쓴다.
const HAND_PHASE_COUNT := 5

func _update_hand() -> void:
	var item := GameState.weapon_hand()
	if item != _hand_item:
		_hand_item = item
		if item != "":
			_hand.texture = load("res://assets/items/hand_fx/%s_swing.png" % item)
			_hand.hframes = HAND_PHASE_COUNT
			_hand.vframes = 8
		else:
			_hand.texture = null
	_hand.visible = item != ""
	if item == "":
		return
	var octant := _facing_octant()
	var phase := 0
	if motion_time > 0.0 and (motion == "attack" or motion == "skill") and motion_duration > 0.0:
		var progress := clampf(1.0 - motion_time / motion_duration, 0.0, 1.0)
		# draw(뽑기) -> ready(자세) -> slash(베기) -> follow(마무리) 4칸에 고르게 나눈다.
		phase = 1 + mini(int(progress * 4.0), 3)
	var setup: Dictionary = HAND_OCTANT[octant]
	_hand.position = setup["pos"]
	_hand.rotation = 0.0
	_hand.frame = octant * HAND_PHASE_COUNT + phase
	_hand.z_index = -1 if setup["back"] else 1
	var weapon := str(GameState.equipped.get("weapon", ""))
	if GameState.is_rainbow_item(weapon):
		_hand.material = _hand_rainbow
		_hand.modulate = Color.WHITE
	else:
		_hand.material = null
		_hand.modulate = GameState.palette_color_for(weapon)



func try_dodge() -> bool:
	if dash_cooldown > 0.0 or not GameState.dash_unlocked:
		return false
	# 바람의 정령: 구르기 쿨타임이 30% 짧다.
	dash_cooldown = dash_cooldown_max * (0.7 if GameState.spirit_effect() == "swift_dash" else 1.0)
	Audio.play_sfx("dodge")
	play_motion("dodge", 0.42)
	global_position += facing * 42.0
	_clamp_to_bounds()
	invulnerability_time = 0.22
	return true


## 직업 스킬의 지속 버프(공격력/이동속도 배율)를 시간이 지나면 지운다.
func _tick_buffs(delta: float) -> void:
	var expired: Array = []
	for key in active_buffs:
		var buff: Dictionary = active_buffs[key]
		buff["remaining"] = maxf(float(buff["remaining"]) - delta, 0.0)
		if buff["remaining"] <= 0.0:
			expired.append(key)
	for key in expired:
		active_buffs.erase(key)


func _apply_buff(stat: String, value: float, duration: float) -> void:
	active_buffs[stat] = {"value": value, "remaining": duration}


func _buff_value(stat: String) -> float:
	return float(active_buffs[stat]["value"]) if active_buffs.has(stat) else 0.0


func _current_move_speed() -> float:
	return move_speed * (1.0 + _buff_value("speed_mult"))


## 평타·스킬·화살이 공통으로 쓰는 공격력 계산. 전투 함성(atk_mult) 버프를 반영한다.
func _attack_power() -> int:
	var base := attack_damage + GameState.attack_bonus + GameState.stat_attack()
	return int(round(base * (1.0 + _buff_value("atk_mult"))))


## 은신(stealth_crit_pending)이 걸려 있으면 다음 한 방은 무조건 치명타로 처리하고 소모한다.
func _roll_critical() -> bool:
	if stealth_crit_pending:
		stealth_crit_pending = false
		return true
	return randf() < GameState.crit_chance()


## 지역 밖으로 나가지 않게 한다. 지역마다 크기가 다르다.
## 세로는 적과 같은 24px(테두리 두 줄 밖)로 막는다. (감독 2026-09-09) 9장 echo_of_forest
## game_min 967 FREEZE: 테두리 줄은 충돌체가 없어 몸이 y=227까지 들어갔고, 바로 위
## 큰나무 충돌체(y 200~224)에 눌린 채 적(57px)이 못 내려오는 줄에서 옆걸음만 반복했다.
## 가로 10px은 동/서 출구 걷기용이라 그대로 둔다.
func _clamp_to_bounds() -> void:
	global_position = global_position.clamp(Vector2(10, 24), bounds - Vector2(10, 24))


## 화면 한 칸(320x240) 단위로 카메라를 고정한다. 방을 넘어갈 때만
## 화면이 턱 넘어가고, 방 안에서는 카메라가 움직이지 않는다.
const SCREEN := Vector2(320.0, 240.0)


func _lock_camera_to_screen() -> void:
	var cell := (global_position / SCREEN).floor()
	$Camera2D.global_position = (cell + Vector2(0.5, 0.5)) * SCREEN


func attack() -> void:
	# 무기 종류가 공격 방식을 정한다. 활을 들고도 근접으로 때리면
	# 활을 든 의미가 없다.
	if GameState.weapon_kind() == "bow":
		_shoot_arrow()
		return
	Audio.play_sfx("attack")
	play_motion("attack", 0.42)
	cooldown_time = attack_cooldown
	_spawn_slash(facing)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() - enemy.body_radius() <= attack_range and facing.dot(offset.normalized()) >= 0.25:
			var critical := _roll_critical()
			var power := _attack_power()
			var final_power := int(power * GameState.crit_damage_mult()) if critical else power
			enemy.take_damage(final_power, facing, critical)
			_apply_set_lifesteal(critical, final_power)


## 용기사 세트(제작템 4개 완성): 치명타로 때리면 준 피해의 10%만큼 흡수한다.
func _apply_set_lifesteal(critical: bool, damage_dealt: int) -> void:
	if not critical or GameState.active_set_special() != "boss_legacy":
		return
	var healed := maxi(int(round(damage_dealt * 0.1)), 1)
	health = mini(health + healed, max_health)
	health_changed.emit(health, max_health)


## 베기 궤적을 낸다. 그림이 아래쪽을 향해 그려져 있어 아래 기준으로 돌린다.
func _spawn_slash(direction: Vector2, tint := Color.WHITE, scale_up := 1.0) -> void:
	var fx: Sprite2D = preload("res://scenes/slash_fx.tscn").instantiate()
	fx.global_position = global_position + Vector2(0, -4) + direction.normalized() * 12.0
	fx.rotation = Vector2.DOWN.angle_to(direction.normalized())
	fx.modulate = tint
	fx.scale = Vector2.ONE * scale_up
	get_parent().add_child(fx)


## 스킬 아이디별 이펙트. 2차 광역기는 화면 전체 연출과 피해 판정을 함께 낸다.
func _cast_skill_fx(skill_id: String) -> void:
	match skill_id:
		"elementalist_meteor":
			_spawn_world_skill_fx("meteor")
			return
		"elementalist_chain_lightning":
			_spawn_world_skill_fx("lightning")
			return
		"guardian_ward", "guardian_taunt", "berserker_rage", "berserker_final_strike", "necromancer_curse", "necromancer_soul_drain", "assassin_heart_pierce", "assassin_execute", "shadow_dancer_leap", "shadow_dancer_clone":
			_spawn_skill_fx("res://assets/fx/skill2/%s.png" % skill_id, 1, 0.28, Color.WHITE, 0.7)
			return
		"shield_charge", "warcry", "undying", "ice_spear", "mana_burst", "stealth", "swift_step":
			_spawn_skill_fx("res://assets/fx/skill1/%s.png" % skill_id, 1, 0.28, Color.WHITE, 0.7)
			return
		# 투사체 스킬(projectile: true)은 탄이 날아가 적에게 박혀서 도는 게
		# 주인공이라, 몸에서는 짧고 작은 시전 빛만 낸다(INBOX 2026-10-20
		# 17:45 ① 시전 단계). 착탄은 arrow.gd 의 embed(21:55)가 맡는다.
		# 서서히 옅어지면 느려 보인다(22:15 결함) → instant 로 0.05초(3프레임)
		# 다 보인 채 있다가 페이드 없이 바로 사라지게.
		"shuriken":
			_spawn_skill_fx("res://assets/fx/skill1/shuriken.png", 1, 0.05, Color.WHITE, 0.3, true)
			return
		# Lv12·20 스킬 공백 메우기(INBOX 2026-10-19 23:43) - 새 에셋 금지라
		# 기존 skill1 이미지를 색만 다르게 재사용한다.
		"shield_bash":
			_spawn_skill_fx("res://assets/fx/skill1/shield_charge.png", 1, 0.28, Color(1.0, 0.7, 0.3), 0.7)
			return
		"crush_blow":
			_spawn_skill_fx("res://assets/fx/skill1/warcry.png", 1, 0.28, Color(1.0, 0.4, 0.2), 0.8)
			return
		"frost_wave":
			_spawn_skill_fx("res://assets/fx/skill1/ice_spear.png", 1, 0.28, Color(0.6, 0.9, 1.0), 0.9)
			return
		"mana_shield":
			_spawn_skill_fx("res://assets/fx/skill1/mana_burst.png", 1, 0.28, Color(0.7, 0.5, 1.0), 0.7)
			return
		# 시전 FX(64px 별 텍스처)가 0.3 배로도 주인공 몸을 덮었다(INBOX
		# 2026-10-20 21:55 결함) → 손 앞 지름 10px 이내로 더 줄인다(0.15).
		# 표창과 같은 이유로 instant(22:15 결함).
		"poison_dart":
			_spawn_skill_fx("res://assets/fx/skill1/shuriken.png", 1, 0.05, Color(0.4, 0.9, 0.3), 0.15, true)
			return
		"shadow_slash":
			_spawn_skill_fx("res://assets/fx/skill1/stealth.png", 1, 0.28, Color(0.8, 0.2, 0.3), 0.7)
			return
		_:
			pass
	match skill_id:
		"slash", "strike", "double_strike":
			_spawn_slash(facing, Color(1.0, 0.9, 0.5), 1.6)
		"burst":
			_spawn_skill_fx("res://assets/fx/burst.png", 4, 0.06, Color(0.75, 0.9, 1.0), 1.4)
		"flame":
			_spawn_skill_fx("res://assets/fx/flame.png", 9, 0.05, Color.WHITE, 1.4)
		"heal":
			_spawn_skill_fx("res://assets/fx/heal.png", 4, 0.09, Color(0.5, 1.0, 0.6), 1.4)
		_:
			_spawn_slash(facing, Color(0.6, 0.85, 1.0), 1.6)


## 스킬 이펙트를 자신 위치 가운데에 재생한다. 방향과 무관하게 주위 전체에 낸다.
## instant 면 팝인·페이드 없이 곧장 다 보인 채 나타났다 바로 사라진다
## (표창·독침 시전 빛 — INBOX 2026-10-20 22:15: 적을 덮던 큰 별을 줄였더니
## 이번엔 서서히 옅어지는 게 느려 보였다, 사람 지시로 즉시 등장·즉시 소멸).
func _spawn_skill_fx(path: String, frames: int, frame_time: float, tint: Color, size_up := 1.0, instant := false) -> void:
	var fx: SkillFx = preload("res://scenes/skill_fx.tscn").instantiate()
	fx.global_position = global_position
	get_parent().add_child(fx)
	fx.play(path, frames, frame_time, tint, size_up, instant)


## 화면 전체 광역 연출. 전 지역 좌표에 낙하/섬광을 순차적으로 만들고,
## 시각 연출과 실제 피해는 한 번의 스킬에서만 처리한다.
func _spawn_world_skill_fx(kind: String) -> void:
	var bounds := World.pixel_size_of(GameState.current_map)
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() + get_instance_id()
	var count := 18 if kind == "meteor" else 26
	for index in count:
		var impact := Vector2(rng.randf_range(18.0, bounds.x - 18.0), rng.randf_range(24.0, bounds.y - 18.0))
		var delay := index * (0.035 if kind == "meteor" else 0.025)
		_spawn_world_impact.call_deferred(kind, impact, delay, index)


func _spawn_world_impact(kind: String, impact: Vector2, delay: float, index: int) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	var fx: SkillFx = preload("res://scenes/skill_fx.tscn").instantiate()
	fx.global_position = impact + (Vector2(0, -20) if kind == "meteor" else Vector2.ZERO)
	get_parent().add_child(fx)
	fx.play("res://assets/fx/skill2/%s.png" % ("elementalist_meteor" if kind == "meteor" else "elementalist_chain_lightning"), 1, 0.42 if kind == "meteor" else 0.18, Color.WHITE, 0.7 if kind == "meteor" else 0.55)
	if kind == "meteor":
		var tween := create_tween()
		tween.tween_property(fx, "global_position", impact, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(fx.queue_free)
	else:
		fx.modulate.a = 0.0
		var flash := create_tween()
		flash.tween_property(fx, "modulate:a", 1.0, 0.035)
		flash.tween_property(fx, "modulate:a", 0.0, 0.12)
		flash.tween_callback(fx.queue_free)


## 활은 화살을 날린다. 사거리는 길지만 날아가는 동안 피할 수 있다.
func _shoot_arrow() -> void:
	Audio.play_sfx("dodge")
	play_motion("attack", 0.42)
	# 근접보다 조금 느리게 쏜다. 사거리가 긴 대신이다.
	cooldown_time = attack_cooldown * 1.25
	var arrow := preload("res://scenes/arrow.tscn").instantiate()
	arrow.direction = facing.normalized()
	arrow.critical = _roll_critical()
	var power := _attack_power()
	arrow.damage = int(power * GameState.crit_damage_mult()) if arrow.critical else power
	arrow.global_position = global_position + facing.normalized() * 10.0
	get_parent().add_child(arrow)


## 표창 던지기(도적) 전용. 근접 화살과 같은 투사체를 재사용하되 스킬 배율을 곱한다.
## 맞으면 큰 착탄 FX 대신 적에게 박혀 0.3초 머문다(embed=true —
## INBOX 2026-10-20 21:55, "몬스터랑 겹쳐서 커지면 이상하다" 결함 수정).
func _shoot_skill_projectile(data: Dictionary) -> void:
	var arrow := preload("res://scenes/arrow.tscn").instantiate()
	arrow.direction = facing.normalized()
	arrow.critical = _roll_critical()
	var power := int(_attack_power() * float(data["damage"]))
	arrow.damage = int(power * GameState.crit_damage_mult()) if arrow.critical else power
	arrow.global_position = global_position + facing.normalized() * 10.0
	arrow.embed = true
	if str(data["id"]) == "poison_dart":
		arrow.sprite_path = "res://assets/items/proj_dart.png"
		arrow.rotation_offset = 0.0
	else:
		arrow.sprite_path = "res://assets/items/proj_shuriken.png"
		arrow.sprite_hframes = 4
		arrow.spin = true
	get_parent().add_child(arrow)


## 지금 고른 스킬을 쓴다. 스킬마다 마력·쿨타임·피해·범위가 다르다.
## 못 쓰는 이유가 있으면 문구로 돌려준다.
func cast_skill(index := -1) -> String:
	var slot := index if index >= 0 else skill_slot
	if not GameState.skill_unlocked(slot):
		return "아직 배우지 않은 기술이다."
	var data: Dictionary = GameState.active_skills()[slot]
	if skill_cooldowns[slot] > 0.0:
		return "%s 준비 중" % data["name"]
	if mana < int(data["cost"]):
		return "마력이 부족하다."
	if data.has("hp_cost_pct") and health <= 1:
		return "HP가 부족하다."
	skill_slot = slot
	Audio.play_sfx("skill")
	play_motion("skill", 0.56)
	mana -= int(data["cost"])
	mana_changed.emit(mana, max_mana)
	skill_cooldowns[slot] = float(data["cooldown"])
	skill_cooldown_maxes[slot] = skill_cooldowns[slot]
	# 방패 돌진: 이펙트보다 먼저 밀고 나가 도착 지점에서 이펙트가 뜨게 한다
	# (맞는 판정은 아래 범위 루프가 함께 담당. INBOX 답 2026-09-06 참고).
	if data.has("dash"):
		global_position += facing.normalized() * float(data["dash"])
		_clamp_to_bounds()

	_cast_skill_fx(str(data["id"]))

	# 자신에게 거는 효과(버프/무적/회복/은신)부터 처리한다.
	if data.has("buff"):
		var buff: Dictionary = data["buff"]
		_apply_buff(str(buff["stat"]), float(buff["value"]), float(buff["duration"]))
	if data.has("invuln"):
		invulnerability_time = maxf(invulnerability_time, float(data["invuln"]))
	if data.has("heal_pct") and float(data["heal_pct"]) > 0.0:
		health = mini(health + int(max_health * float(data["heal_pct"])), max_health)
		health_changed.emit(health, max_health)
	if data.get("stealth_crit", false):
		stealth_crit_pending = true

	# 마나 순환(마법사): HP를 소모해 마력을 회복한다. 물약은 HP만 채워 주고
	# 마력을 회복할 방법이 없었다("기력회복하는게 없어" 피드백)로 추가.
	if data.has("hp_cost_pct"):
		var hp_cost := maxi(int(max_health * float(data["hp_cost_pct"])), 1)
		health = maxi(health - hp_cost, 1)
		health_changed.emit(health, max_health)
		var mana_gain := int(max_mana * float(data.get("mana_restore_pct", 0.0)))
		mana = mini(mana + mana_gain, max_mana)
		mana_changed.emit(mana, max_mana)
		Audio.play_sfx("potion")
		return "%s  HP -%d, 마력 +%d" % [data["name"], hp_cost, mana_gain]

	var restore := int(data["heal"])
	if restore > 0:
		var before := health
		health = mini(health + restore, max_health)
		health_changed.emit(health, max_health)
		Audio.play_sfx("potion")
		return "%s  HP +%d" % [data["name"], health - before]

	# 표창 던지기: 투사체 하나만 날리고 끝(범위 피해 루프를 타지 않는다).
	if data.get("projectile", false):
		_shoot_skill_projectile(data)
		return str(data["name"])

	if data.get("heal_pct", 0.0) > 0.0 and float(data["damage"]) == 0.0 and float(data["radius"]) == 0.0:
		return str(data["name"])
	if data.has("buff") and float(data["damage"]) == 0.0:
		return str(data["name"])
	if data.has("invuln") and float(data["damage"]) == 0.0 and float(data["radius"]) == 0.0:
		return str(data["name"])

	var power := int(_attack_power() * float(data["damage"]))
	# 광전사 최후의 일격(low_hp_mult_max): 자신 HP비율이 낮을수록 배율 상승.
	# HP 100%→1.0배, HP 0%→low_hp_mult_max배로 선형 보간(가배치 근거는 SECOND_JOB_DESIGN.md 참고).
	if data.has("low_hp_mult_max"):
		var hp_ratio := float(health) / float(max_health)
		var mult := 1.0 + (1.0 - hp_ratio) * (float(data["low_hp_mult_max"]) - 1.0)
		power = int(power * mult)
	var repeats := int(data.get("multi_hit", 1))
	var single: bool = data.get("single_target", false)
	var targets: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() - enemy.body_radius() <= float(data["radius"]):
			targets.append(enemy)
	if single and targets.size() > 1:
		targets.sort_custom(func(a, b) -> bool:
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
		targets = [targets[0]]
	# 연쇄 번개(chain_count): "전 지역 곳곳에 무작위로 내리꽂히는" 낙뢰라
	# 화면 안 적 전부가 아니라 무작위로 최대 chain_count명만 맞는다.
	if data.has("chain_count") and targets.size() > int(data["chain_count"]):
		targets.shuffle()
		targets = targets.slice(0, int(data["chain_count"]))
	var hits := 0
	for enemy in targets:
		var offset: Vector2 = enemy.global_position - global_position
		# 처형(execute_pct): HP 비율이 기준 이하인 적은 즉시 처치한다.
		if data.has("execute_pct") and enemy.max_health > 0 and float(enemy.health) / float(enemy.max_health) <= float(data["execute_pct"]):
			enemy.take_damage(enemy.health + 99999, offset.normalized(), true)
			_apply_set_lifesteal(true, power)
			hits += 1
			continue
		for _i in repeats:
			var critical := _roll_critical()
			var final_power := int(power * GameState.crit_damage_mult()) if critical else power
			enemy.take_damage(final_power, offset.normalized(), critical)
			_apply_set_lifesteal(critical, final_power)
			# 영혼 흡수(heal_pct_on_hit): 입힌 피해의 일부만큼 HP와 마력을 회복한다.
			if data.has("heal_pct_on_hit"):
				var drain := int(final_power * float(data["heal_pct_on_hit"]))
				if drain > 0:
					health = mini(health + drain, max_health)
					health_changed.emit(health, max_health)
					mana = mini(mana + drain, max_mana)
					mana_changed.emit(mana, max_mana)
		if data.has("stun") and enemy.has_method("apply_stun"):
			enemy.apply_stun(float(data["stun"]))
		if data.has("slow") and enemy.has_method("apply_slow"):
			var slow: Dictionary = data["slow"]
			enemy.apply_slow(float(slow["pct"]), float(slow["duration"]))
		# 저주(dot/dot_duration): 명중한 적에게 지속 피해를 건다. dot은
		# damage와 같은 배율값이라 공격력 * dot을 초당 피해로 쓴다.
		if data.has("dot") and data.has("dot_duration") and enemy.has_method("apply_dot"):
			var dps := int(_attack_power() * float(data["dot"]))
			enemy.apply_dot(dps, float(data["dot_duration"]))
		hits += 1
	return "%s  %d체 명중" % [data["name"], hits] if hits > 0 else str(data["name"])


## 예전 이름. 스킬바와 테스트가 쓰던 진입점을 남겨 둔다.
func skill() -> void:
	cast_skill()


func add_potion() -> void:
	potions += 1
	potions = mini(potions, GameState.potion_cap())
	GameState.potions = potions
	potion_changed.emit(potions)


func try_use_potion() -> bool:
	if potions <= 0 or health >= max_health:
		return false
	var before := health
	Audio.play_sfx("potion")
	potions -= 1
	GameState.potions = potions
	# 고정 45는 후반 최대 체력 400에서 의미가 없다. 비율로 회복한다.
	health = mini(health + int(max_health * 0.35), max_health)
	health_changed.emit(health, max_health)
	potion_changed.emit(potions)
	potion_used.emit(health - before)
	modulate = Color(0.55, 1.0, 0.62)
	get_tree().create_timer(0.18).timeout.connect(func() -> void: modulate = Color.WHITE)
	return true


func take_damage(amount: int, knockback: Vector2, source := "melee") -> void:
	if invulnerability_time > 0.0:
		return
	last_hit_source = source
	# 방어를 그냥 빼면 후반에 모든 피해가 1이 되어 위험이 사라진다.
	# 감소율로 바꾸고 상한을 60%로 잡는다. 방어 1점이 늘 같은 값을 하지 않고
	# 쌓을수록 효율이 떨어지므로 후반에도 위험이 남는다.
	var guard := float(GameState.defense_bonus + GameState.perk_defense())
	var cut := minf(guard / (guard + 45.0), 0.6)
	var taken := maxi(int(round(amount * (1.0 - cut))), 1)
	# 수호자 철벽 태세(damage_reduction 버프): 방어 감소율과는 별개 축으로
	# 한 번 더 깎는다. buff만 걸어두고 여기서 안 읽으면 스킬이 아무 효과도
	# 없어 "숫자키로 써도 받는 피해가 그대로"인 버그가 된다.
	if _buff_value("damage_reduction") > 0.0:
		taken = maxi(int(round(taken * (1.0 - _buff_value("damage_reduction")))), 1)
	# 용기사 세트(제작템 4개 완성): 여기서 한 번 더 12% 깎는다. 위 감소율
	# 상한(60%)과는 별개 축이라 세트를 완성하면 상한을 넘어서도 계속 세진다.
	var special := GameState.active_set_special()
	if special == "boss_legacy":
		taken = maxi(int(round(taken * 0.88)), 1)
	# 천공 세트(탑 심연 난이도 제작템 4개): 위기 상황(체력 30% 이하)에서
	# 한 번 더 25% 깎는다. 게임에서 가장 늦게, 가장 힘들게 얻는 세트라
	# 특수효과도 가장 세야 한다는 요청.
	elif special == "skyward_grace" and health <= max_health * 0.3:
		taken = maxi(int(round(taken * 0.75)), 1)
	health = maxi(health - taken, 0)
	Hit.popup(get_parent(), global_position, taken)
	Hit.shake(4.0)
	Audio.play_sfx("hurt")
	play_motion("hit", 0.22)
	# 서리의 정령: 맞은 뒤 무적 시간이 조금 더 길다.
	invulnerability_time = 0.85 if GameState.spirit_effect() == "warding" else 0.65
	global_position += knockback.normalized() * 8.0
	health_changed.emit(health, max_health)
	if health == 0:
		# 되살릴지, 마을로 돌려보낼지는 main 이 정한다. 여기서 곧장 되살리지 않는다.
		play_motion("death", 0.9)
		died.emit()
		mana = max_mana
		mana_changed.emit(mana, max_mana)


func play_motion(name: String, duration: float) -> void:
	motion = name
	motion_duration = duration
	motion_time = duration
