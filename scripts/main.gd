extends Node2D

var boss_spawned := false
## 살아있는 중간보스를 지역별로 재입장까지 보관한다(area_id -> Array[Enemy]).
## `_spawn_area_enemies()` 참고 - "enemies" 그룹에는 항상 지금 지역 몹만
## 있어야 한다(spawned_kinds() 등 그룹 전체를 세는 검사·로직이 여럿이라
## 다른 지역 몹이 섞이면 안 됨). 그래서 자기 지역을 벗어난 중간보스는
## 그룹에서 빼고 여기 보관했다가 그 지역으로 돌아오면 되돌린다.
var _preserved_midbosses: Dictionary = {}
## 탑에서 이번 층에 남은 몬스터 수. 0이 되면 다음 층으로 넘어간다.
var tower_enemies_remaining := 0
var menu_open := false
var shop_open := false
## AUTOHUNT_DESIGN.md §10. 오토사냥(전투)과 별개 토글 - 마을⇄사냥터 이동과
## NPC 대화까지 자동으로 진행한다. 판단 빈도가 낮아도 되므로(§10.1) Timer로
## 매 물리 틱이 아니라 0.6초마다만 확인한다.
var quest_mode := false
var _quest_timer: Timer
## INBOX 지시(2026-10-20 00:09) 레벨업 축제 연출 전용 노드. 코드로만 만들어서
## main.tscn 노드 구조는 건드리지 않는다(규칙 8).
var _levelup_fx: LevelUpFx
## INBOX 지시(2026-10-20 00:10) 레벨 보상 상자 전용 노드 - 역시 코드로만 만든다.
## 한 레벨업에 여러 5단위 마일스톤을 한꺼번에 넘길 수 있어(한 번에 exp를
## 크게 주입하는 테스트·탑 보상 등) 큐로 하나씩 보여 준다.
var _level_reward_box: LevelRewardBox
var _level_reward_queue: Array[Dictionary] = []
## AUTOHUNT_DESIGN.md §10.7 후퇴. 같은 지역에서 연속 후퇴한 횟수를 센다
## (다른 지역에서 후퇴하면 그 지역으로 새로 센다).
var _quest_retreat_zone := ""
var _quest_retreat_streak := 0
## 후퇴 연속 GIVEUP_STREAK회로 지역을 포기했을 때, 다음에 마을에서 사냥터로
## 나갈 목표(한 티어 아래 지역). 비어 있으면 평소대로 동쪽 exit로 걸어 나간다.
var _quest_resume_zone := ""
## (INBOX 답, 2026-09-06 17:26) `_quest_resume_zone`을 소비해 그 지역으로
## 이동한 뒤에도 남겨 두는 값 - 이 지역에 있는 동안은 스토리 목표를 이미
## 채웠어도(goal_reached) 그냥 지나치지 않고 한 바퀴 소탕(사냥)하게 만든다.
## 살아있는 적이 0이 되면 비운다. 상수가 아니라 그때그때 정해지는 변수.
var _quest_grind_zone := ""
## (INBOX 답, 2026-09-07 00:45) 물약 조기 귀환(2602줄 부근) 전용 재개 지점.
## `_quest_resume_zone`(한 티어 아래·그라인드)과 의미가 달라 겹쳐 쓰지 않는다 -
## 이건 "방금 있던 그 자리로, 그라인드 없이" 복귀한다. 마을에서 물약을
## 채운 직후 소비하고, 사망·후퇴 포기 때는 비운다(그 경우 기존 재개 규칙이
## 우선).
var _quest_restock_zone := ""
## (INBOX 답, 2026-09-06 16:09) §10.5: 퀘스트모드 중 사망은 quest_mode를
## 끄지 않는다 - 단 킬이 하나도 안 늘며 GIVEUP_STREAK회 연속 사망하면 진짜
## 막힌 것으로 보고 OFF. `_quest_retreat_streak`(2577줄)와 같은 "연속" 관례.
var _quest_death_streak := 0
var _quest_kills_at_last_death := -1
## (INBOX 답, 2026-09-06 18:45 ③) `_quest_handle_death()`가 실제로 도는
## 경로에서 직접 센다 - `died` 신호를 밖에서 별도로 구독하는 프로브 쪽
## 카운터는 연결 시점에 따라 놓칠 수 있어 신뢰하지 않는다.
var quest_death_count := 0
const NPC_POSITION := Vector2(56, 108)
const MERCHANT_POSITION := Vector2(212, 108)
const SMITH_POSITION := Vector2(136, 108)
const INN_POSITION := Vector2(96, 108)
const KEEPER_POSITION := Vector2(172, 108)
const TALK_RANGE := 34.0
## 마을마다 퀘스트를 맡는 사람이 다르다. 챕터 전환 대사(Story.CHAPTERS)에서
## 이미 소개된 이름을 그대로 쓴다. 없으면 촌장(elder)이 기본이다.
## rift_camp(9장)은 대사상 새 인물이 소개되지 않아 8장의 정찰병(scout)이
## 계속 동행하는 것으로 취급한다.
const TOWN_QUEST_NPC := {
	"harbor": "captain",
	"frost_camp": "scout",
	"abyss": "survivor",
	"origin_camp": "scout",
	"remnant_village": "survivor",
	"driftwood_pier": "guide",
	"lantern_village": "acolyte",
	"waystation_camp": "scout",
	"rift_camp": "scout",
}
## 마을마다 담당이 다른데 말투는 전부 촌장 말투("-하게/-일세")로 고정돼 있던 문제.
## Story.CHAPTERS에서 이미 소개된 각자의 말투(수비대장=단호한 하대,
## 렌=정중한 존댓말, 노아=예스러운 "-오", 세인=상냥한 존댓말,
## 이든=긴장한 말줄임 존댓말)에 맞춰 상시 퀘스트 대사를 나눈다.
const TOWN_VOICE := {
	"elder": {
		"filler": "지금은 부탁할 일이 없네.\n물건은 상인에게, 장비는 대장장이에게 맡기게.",
		"class_change": "자네의 실력이 충분히 무르익었군.\n어떤 길을 걷겠나?",
		"bounty_done": "%s, 확인했네.\n%d골드와 %s를 받게.",
	},
	"captain": {
		"filler": "지금은 맡길 임무가 없다.\n물건은 상인에게, 장비는 대장장이에게 맡겨라.",
		"class_change": "실력이 무르익었다.\n어떤 길을 걷겠나?",
		"bounty_done": "%s, 확인했다.\n%d골드와 %s를 받아라.",
	},
	"survivor": {
		"filler": "지금은 따로 부탁드릴 일이 없습니다.\n물건은 상인에게, 장비는 대장장이에게 맡기시면 됩니다.",
		"class_change": "실력이 충분히 무르익었군요.\n어떤 길을 걷으시겠어요?",
		"bounty_done": "%s, 확인했습니다.\n%d골드와 %s를 받으세요.",
	},
	"guide": {
		"filler": "지금은 부탁할 일이 없다오.\n물건은 상인에게, 장비는 대장장이에게 맡기시오.",
		"class_change": "실력이 무르익었구려.\n어떤 길을 걷겠소?",
		"bounty_done": "%s, 확인했소.\n%d골드와 %s를 받으시오.",
	},
	"acolyte": {
		"filler": "지금은 부탁드릴 일이 없어요.\n물건은 상인에게, 장비는 대장장이에게 맡기세요.",
		"class_change": "실력이 충분히 무르익었어요.\n어떤 길을 걷으시겠어요?",
		"bounty_done": "%s, 확인했어요.\n%d골드와 %s를 받으세요.",
	},
	"scout": {
		"filler": "…지금은 딱히 없어요.\n물건은 상인에게, 장비는 대장장이에게 맡기시면 돼요.",
		"class_change": "…실력이 무르익었네요.\n어떤 길을 걷고 싶으세요?",
		"bounty_done": "%s… 확인했어요.\n%d골드와 %s를 받으세요.",
	},
}
## 지역 경계로 인정하는 여백. 이보다 가까우면 옆 지역으로 넘어간다.
const EDGE_MARGIN := 22.0
var transition_lock := 0.0
## 레벨업 메시지가 이 시각(Time.get_ticks_msec()/1000.0) 전까지는 퀘스트·픽업
## 메시지에 덮이지 않는다. (INBOX 2026-10-19 23:40 — 444가 레벨업을 무조건 덮던 버그)
var _message_lock_until := 0.0
## 낚시 재사용 대기시간. 없으면 E를 연타해서 순식간에 여러 마리를 낚는다.
var fish_cooldown := 0.0
const FISH_COOLDOWN_MAX := 1.4
var pause_open := false
var dialogue_open := false
var inventory_index := 0
## 인벤토리 탭: "items"(장비/물건) 또는 "materials"(제작·강화 재료 개수).
## "재료가 몇 개 있는지 보려고 매일 강화상인을 클릭하는 게 답답하다"(감독 2026-09-10).
var inventory_tab := "items"
var material_index := 0
## _refresh_inventory()가 그리는 실제 아이템 줄 수. 터치 판정
## (_on_inventory_gui_input)도 같은 값을 써야 화면에 보이는 줄과
## 눌러서 고르는 줄이 어긋나지 않는다.
const INVENTORY_WINDOW := 4
## _refresh_perk()가 그리는 "레벨 %d 달성! …\n──────────\n%s" 포맷대로
## 0~1번째 줄은 제목/구분선, 특성 목록은 2번째 줄부터 시작한다. 터치 판정
## (_on_perk_gui_input)도 같은 값을 써야 어긋나지 않는다(INVENTORY_WINDOW와
## 같은 이유).
const PERK_LIST_START_LINE := 2
## 특성 한 항목이 화면에서 차지하는 줄 수(이름 줄 + 설명 줄, _refresh_perk()
## 참고). _tapped_list_row()의 lines_per_row 인자로 넘긴다.
const PERK_LIST_LINES_PER_ROW := 2
## _refresh_tower_select()가 그리는 "심연의 탑 - 난이도 선택\n──────────\n%s"
## 포맷대로 0~1번째 줄은 제목/구분선, 난이도 목록은 2번째 줄부터(한 항목당
## 1줄) 시작한다. PERK_LIST_START_LINE과 같은 이유로 상수화.
const TOWER_SELECT_LIST_START_LINE := 2
## 캐릭터 창 세 탭(_refresh_character/_refresh_character_perks/
## _refresh_character_job())은 Info 텍스트 머리말 줄 수가 서로 달라
## 목록 시작 줄이 제각각이다. _on_character_gui_input()이 탭별로
## 골라 쓴다(PERK_LIST_START_LINE과 같은 이유로 상수화).
const CHARACTER_STATS_LIST_START_LINE := 3
const CHARACTER_PERKS_LIST_START_LINE := 4
const CHARACTER_JOB_LIST_START_LINE := 3
var world_map_open := false
var character_open := false
var skills_open := false
var quest_open := false
var guide_open := false
var guide_page := 0
## 탑 입구 난이도 선택 화면. 지도(M)에서 "tower"를 고르면 바로 입장하지
## 않고 이 화면이 먼저 뜬다.
var tower_select_open := false
var tower_select_index := 0
var stat_index := 0
## "stats"(능력치) 또는 "perks"(특성). ←→로 바꾼다. 전투 중에 강제로
## 뜨던 특성 선택 창을 없애고 여기서 안전할 때 고르게 했다.
var character_mode := "stats"
## 능력치/특성/전직 세 탭을 좌우로 순환한다.
const CHARACTER_MODES := ["stats", "perks", "job"]
var pending_map := ""

## 화면이 좁아 HUD 뭉치 크기를 취향대로 줄이고 키울 수 있게 한다.
## 저장 슬롯과 무관한 기기 설정이라 GameState 세이브와 따로 저장한다.
const UI_SETTINGS_PATH := "user://ui_settings.json"
const HUD_SCALE_MIN := 0.6
const HUD_SCALE_MAX := 1.1
const HUD_SCALE_STEP := 0.1
var hud_stat_scale := 1.0
var hud_skill_scale := 1.0
## 메뉴 탭(감독 2026-09-10, 피처폰 RPG식): 캐릭·가방·스킬·퀘스트·지도·가이드·설정
## 7창을 한 틀(8,26~284,232)에 넣고 위 탭줄(HUD/MenuTabs)로 오간다.
const MENU_TABS := ["character", "inventory", "skills", "quest", "map", "guide", "pause"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_load_ui_settings()
	_apply_hud_scale()
	$Player.health_changed.connect(_on_health_changed)
	$Player.died.connect(_on_player_died)
	$Player.potion_changed.connect(_on_potion_changed)
	$Player.mana_changed.connect(_on_mana_changed)
	$Player.potion_used.connect(_on_potion_used)
	$HUD/WorldMap/Graph.travel_requested.connect(_travel_to)
	for pair in [["VillageElder", "elder"], ["Merchant", "merchant"], ["Smith", "smith"], ["Innkeeper", "inn"], ["Keeper", "keeper"]]:
		_dress_npc(pair[0], pair[1])
	$HUD/WorldMap.gui_input.connect(_on_world_map_gui_input)
	$HUD/Inventory.gui_input.connect(_on_inventory_gui_input)
	$HUD/Forge.gui_input.connect(_on_forge_gui_input)
	$HUD/Forge/Detail.gui_input.connect(_on_forge_detail_gui_input)
	$HUD/Shop.gui_input.connect(_on_shop_gui_input)
	$HUD/Perk.gui_input.connect(_on_perk_gui_input)
	$HUD/TowerSelect.gui_input.connect(_on_tower_select_gui_input)
	$HUD/Character.gui_input.connect(_on_character_gui_input)
	$HUD/Guide.gui_input.connect(_on_guide_gui_input)
	$HUD/Dialogue.gui_input.connect(_on_dialogue_gui_input)
	for i in MENU_TABS.size():
		var tab: Button = $HUD/MenuTabs.get_node("Tab%d" % i)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_menu_open_tab.bind(MENU_TABS[i]))
	$HUD/MenuTabs/Prev.focus_mode = Control.FOCUS_NONE
	$HUD/MenuTabs/Next.focus_mode = Control.FOCUS_NONE
	$HUD/MenuTabs/Prev.pressed.connect(_menu_tab_step.bind(-1))
	$HUD/MenuTabs/Next.pressed.connect(_menu_tab_step.bind(1))
	_quest_timer = Timer.new()
	_quest_timer.wait_time = 0.6
	_quest_timer.timeout.connect(_quest_mode_tick)
	add_child(_quest_timer)
	_quest_timer.start()
	_levelup_fx = LevelUpFx.new()
	_levelup_fx.finished.connect(_on_levelup_fanfare_finished)
	add_child(_levelup_fx)
	_level_reward_box = LevelRewardBox.new()
	_level_reward_box.closed.connect(_on_level_reward_box_closed)
	add_child(_level_reward_box)
	$Player.potions = GameState.potions
	_change_map(GameState.current_map, false)
	_apply_equipment_to_player()
	_on_potion_changed($Player.potions)
	_update_quest_message()
	if GameState.pending_load:
		GameState.pending_load = false
		_load_current_game()
	elif GameState.quest_stage == 0 and GameState.kills == 0:
		# 새 게임이면 오프닝을 한 번 흘린다.
		_play_dialogue(Story.INTRO)


func _physics_process(delta: float) -> void:
	# 종료할 때 자동 로드가 먼저 해제되는데 이 노드는 PROCESS_MODE_ALWAYS 라
	# 그 뒤로도 한두 프레임이 더 돈다. 그때 GameState 는 Nil 이다.
	if not is_instance_valid(GameState):
		return
	_update_skill_bar()
	_sync_modal_hud_visibility()
	if get_tree().paused:
		return
	## AUTOHUNT_DESIGN.md §6: 이동/공격/대시 키를 사람이 누르면(AI는 이
	## Input 폴링을 거치지 않고 direction/attack()을 직접 호출하므로 안
	## 잡힘) 그 프레임에 오토를 끈다.
	if $Player.auto_hunt and (Input.is_action_just_pressed("move_left")
			or Input.is_action_just_pressed("move_right")
			or Input.is_action_just_pressed("move_up")
			or Input.is_action_just_pressed("move_down")
			or Input.is_action_just_pressed("attack")
			or Input.is_action_just_pressed("dash")):
		_toggle_auto_hunt()
	## AUTOHUNT_DESIGN.md §10.5: 퀘스트모드도 같은 방식으로 사람 입력 시 즉시 OFF.
	if quest_mode and (Input.is_action_just_pressed("move_left")
			or Input.is_action_just_pressed("move_right")
			or Input.is_action_just_pressed("move_up")
			or Input.is_action_just_pressed("move_down")
			or Input.is_action_just_pressed("attack")
			or Input.is_action_just_pressed("dash")):
		_toggle_quest_mode()
	transition_lock = maxf(transition_lock - delta, 0.0)
	fish_cooldown = maxf(fish_cooldown - delta, 0.0)
	if transition_lock > 0.0:
		return
	var bounds := World.pixel_size_of(GameState.current_map)
	var here: String = GameState.current_map
	var at: Vector2 = $Player.global_position
	## (감독 2026-09-09 2장 4단계 640분 정체 실측, qm2.log MAPCHG) 출구 판정이
	## 위치만 보므로 퀘스트모드가 가장자리 적을 쫓다(auto_hunt) 지역 끝에
	## 닿으면 의도 없이 옆 지역으로 넘어가고, 재진입마다 몹이 전부 리스폰돼
	## shore↔marsh 245회·marsh↔marsh_deep 165회 왕복했다. 퀘스트모드의
	## 의도된 지역 이동은 `_quest_east_exit_target()`(x=bounds.x-4)으로
	## 걷는 것뿐이므로 그때만 출구를 연다. 사람 조작·일반 오토는 그대로.
	if quest_mode and not ($Player.auto_walk_active and $Player.auto_walk_target.x >= bounds.x - EDGE_MARGIN):
		return
	if at.x >= bounds.x - EDGE_MARGIN:
		_try_exit(here, "e")
	elif at.x <= EDGE_MARGIN:
		_try_exit(here, "w")


## 모달 패널(인벤토리/상점/일시정지/대화/지도/캐릭터/스킬/퀘스트/도감/
## 탑선택/강화/창고/특성)이 하나라도 열려 있으면 지역 이름표·메시지를
## 숨긴다 - 창마다 따로 켜고 끄면 새 창을 추가할 때마다 잊어버리기 쉽다.
func _sync_modal_hud_visibility() -> void:
	var any_modal := menu_open or shop_open or pause_open or dialogue_open \
			or world_map_open or character_open or skills_open or quest_open \
			or guide_open or tower_select_open or forge_open or storage_open \
			or perk_open
	$HUD/Area.visible = not any_modal
	$HUD/Message.visible = not any_modal
	# 결함(2026-09-06 05:45): 모달 패널 뒤로 스킬바가 흐릿하게 비치고 4번
	# 칸은 패널 밖으로 삐져나왔다 - Skills 창은 자기 Row들을 따로 그리므로
	# HUD/SkillBar를 그대로 쓰지 않는다, 예외 없이 숨긴다.
	$HUD/SkillBar.visible = not any_modal
	# INBOX 보정(2026-09-06 17:50): 가이드는 화면 전체를 덮는 모달이라
	# 미니 StatBar가 필요 없고, 그 자리에 Info 텍스트 하단이 겹쳤다.
	# 다른 모달(상점 등)은 골드를 미니바로 보므로 guide_open만 따로 본다.
	# HUD 전수 점검(04:35, Skills): Skills 창도 6칸까지 차면 패널 하단이
	# StatBar 영역(y 198~)까지 내려와 같은 문제가 생겨 같이 숨긴다.
	# 메뉴 탭 창(캐릭·가방·스킬·퀘스트·지도·가이드·설정)은 한 틀이 y26~232로
	# StatBar(y198~) 자리를 덮으므로 탭이 열린 동안은 숨긴다. 상점·대장간·
	# 창고·특성은 골드를 미니바로 보니 그대로 둔다.
	var tab := _menu_current_tab()
	$HUD/StatBar.visible = tab == ""
	$HUD/MenuTabs.visible = tab != ""
	for i in MENU_TABS.size():
		$HUD/MenuTabs.get_node("Tab%d" % i).set_pressed_no_signal(MENU_TABS[i] == tab)


## 지금 열린 메뉴 탭 이름(MENU_TABS 중 하나), 탭 창이 아니면 "".
func _menu_current_tab() -> String:
	if character_open: return "character"
	if menu_open: return "inventory"
	if skills_open: return "skills"
	if quest_open: return "quest"
	if world_map_open: return "map"
	if guide_open: return "guide"
	if pause_open: return "pause"
	return ""


func _menu_close_current() -> void:
	match _menu_current_tab():
		"character": _toggle_character()
		"inventory": _toggle_inventory()
		"skills": _toggle_skills()
		"quest": _toggle_quest()
		"map": _toggle_world_map()
		"guide": _toggle_guide()
		"pause": set_pause_open(false)


## 탭 버튼/◀▶/[ ] 로 다른 메뉴 창으로 넘어간다. 각 창의 열고 닫기(_toggle_*)를
## 그대로 쓰므로 일시정지·SFX·HUD 동기화는 기존 흐름과 같다.
func _menu_open_tab(tab: String) -> void:
	if tab == _menu_current_tab():
		_sync_modal_hud_visibility()
		return
	if _menu_current_tab() != "":
		_menu_close_current()
	match tab:
		"character": _toggle_character()
		"inventory": _toggle_inventory()
		"skills": _toggle_skills()
		"quest": _toggle_quest()
		"map": _toggle_world_map()
		"guide": _toggle_guide()
		"pause": set_pause_open(true)


func _menu_tab_step(step: int) -> void:
	var current := _menu_current_tab()
	if current == "":
		return
	_menu_open_tab(MENU_TABS[wrapi(MENU_TABS.find(current) + step, 0, MENU_TABS.size())])


## 그 방향으로 나간다. 아직 열리지 않은 장이면 막고 이유를 알린다.
func _try_exit(here: String, direction: String) -> void:
	var target := World.exit_of(here, direction)
	if target == "":
		return
	if World.chapter_of(target) > GameState.chapter:
		$HUD/Message.text = "아직 갈 수 없는 길이다."
		transition_lock = 0.4
		return
	GameState.unlock_map(target)
	_change_map(target, true, _entry_spawn(target, World.OPPOSITE[direction]))


## NPC 스프라이트 줄 수를 시트 높이에 맞추고 발 아래 이름표(이름만)를 단다.
## npc_inn.png는 64x32(4x2)인데 씬은 vframes 7이라 세라가 세로로 눌려 땅에
## 박힌 것처럼 보였다(감독 지적). 이름표는 enemy.tscn의 Name 라벨과 같은 꼴.
func _dress_npc(node_name: String, key: String) -> void:
	var npc: Node2D = get_node(node_name)
	var spr: Sprite2D = npc.get_node("Sprite")
	spr.vframes = maxi(1, spr.texture.get_height() / 16)
	spr.frame = 0
	var tag: Label = npc.get_node_or_null("NameTag")
	if tag == null:
		tag = Label.new()
		tag.name = "NameTag"
		tag.offset_left = -22.0
		tag.offset_top = 9.0
		tag.offset_right = 22.0
		tag.offset_bottom = 20.0
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 7)
		tag.add_theme_color_override("font_color", Color(0.83, 0.82, 0.72))
		npc.add_child(tag)
	var full := Story.name_of(key)
	tag.text = full.get_slice(" ", full.get_slice_count(" ") - 1)


## 옆 지역에서 들어올 때 서는 자리. 들어온 반대편 가장자리다(동서만 있다).
func _entry_spawn(area: String, from_side: String) -> Vector2:
	var bounds := World.pixel_size_of(area)
	if from_side == "e":
		return Vector2(bounds.x - EDGE_MARGIN - 12.0, bounds.y * 0.5)
	return Vector2(EDGE_MARGIN + 12.0, bounds.y * 0.5)


func _east_spawn(area: String) -> Vector2:
	var bounds := World.pixel_size_of(area)
	return Vector2(bounds.x - EDGE_MARGIN - 12.0, World.path_row(area) * World.TILE + 8.0)


## 지역에 처음 들어설 때 서는 자리. 왼쪽 끝 길 위다.
func _west_spawn(area: String) -> Vector2:
	return Vector2(EDGE_MARGIN + 12.0, World.path_row(area) * World.TILE + 8.0)


func _on_health_changed(current: int, maximum: int) -> void:
	$HUD/StatBar/HP.max_value = maximum
	$HUD/StatBar/HP.value = current
	_update_stats()
	## INBOX 답(2026-09-06 11:20): 0.6초 `_quest_timer` 틱 사이 burst 피해로
	## 죽는 것을 막기 위해, 피격 등으로 체력이 바뀔 때마다도 후퇴 여부를
	## 즉시 재평가한다. 임계값은 그대로(숫자 변경 금지) - 판정 시점만 늘린다.
	## current == 0(사망 직전)이면 `_on_player_died()`가 처리할 몫이라 건너뛴다.
	## (INBOX 답, 2026-09-07 01:20 ②) `_quest_do_retreat()`가 auto_hunt/
	## auto_walk_active를 둘 다 false로 놓는데, 텔레포트 도착 지점이 몹과
	## 겹쳐 같은 프레임에 또 피격되면 여기서 또 후퇴를 재평가해 한 프레임
	## 안에 연쇄 후퇴가 일어난다(cave_deep→forest_w 직행 원인). 둘 중 하나가
	## 켜져 있을 때만(다음 `_quest_mode_tick`이 다시 켤 때까지) 재평가한다.
	if quest_mode and current > 0 and ($Player.auto_hunt or $Player.auto_walk_active) and _quest_should_retreat():
		## (감독 결함 조사, 2026-09-08) 이 신호는 피격 콜백(enemy_projectile
		## `_on_body_entered` 등 물리 플러시 중) 안에서 오므로 여기서 바로
		## `_change_map()`을 부르면 새 지역 스폰의 충돌체 설정이 "Can't change
		## this state while flushing queries"로 무시된다(10장 탐침 1017회 실측).
		## 연쇄 후퇴 방지 플래그는 지금 끄고 실제 후퇴만 프레임 끝으로 미룬다.
		$Player.auto_hunt = false
		$Player.auto_walk_active = false
		_quest_do_retreat.call_deferred()


func _on_mana_changed(current: int, maximum: int) -> void:
	$HUD/StatBar/MP.max_value = maximum
	$HUD/StatBar/MP.value = current
	_update_stats()


func _on_enemy_defeated(exp_reward: int, gold_reward: int, kind_id := "") -> void:
	Audio.play_sfx("defeat")
	GameState.record_kill(kind_id)
	var level_before := GameState.level
	var stat_points_before := GameState.stat_points
	var perk_picks_before := GameState.perk_picks
	if GameState.add_reward(exp_reward, gold_reward):
		Audio.play_sfx("levelup")
		Audio.play_sfx("coin", 1.4)
		# 결함(감독, 2026-10-20 01:30): HUD 위 레벨업 문구가 밝은 맵 배경과
		# 대비가 안 나고 두 줄로 넘쳐 지역 이름·≡버튼과 겹쳤다. 아래 증가치는
		# 이미 LevelUpFx 카드가 어두운 화면 위에 또렷이 보여 주므로, HUD 문구는
		# 연출이 끝날 때까지 통째로 숨긴다(지시 "연출 중 HUD 위쪽 문구는 숨긴다").
		$HUD/Message.visible = false
		_message_lock_until = Time.get_ticks_msec() / 1000.0 + 1.5
		var hp_before: int = $Player.max_health
		var atk_before: int = $Player.attack_damage
		_apply_equipment_to_player()
		$Player.health = $Player.max_health
		$Player.mana = $Player.max_mana
		$Player.health_changed.emit($Player.health, $Player.max_health)
		$Player.mana_changed.emit($Player.mana, $Player.max_mana)
		var milestone_rewards := GameState.claim_level_milestones(GameState.level)
		_play_levelup_fanfare(hp_before, atk_before, GameState.stat_points - stat_points_before,
			GameState.perk_picks > perk_picks_before)
		for reward in milestone_rewards:
			_queue_level_reward_box(reward)
	_set_hud_message("숲의 마물을 처치하라  %d/3" % mini(GameState.kills, 6) if GameState.kills < 6 else "임무 완료! 보스가 나타났다.")
	if GameState.kills >= 6 and GameState.current_map == "forest":
		_set_hud_message("숲 동쪽의 수호자 동굴로 가자")
	if GameState.kills == 3:
		GameState.add_item("철검")
		_set_hud_message("철검을 획득했다! I키로 장착")
	elif GameState.kills == 6:
		GameState.add_item("가죽 갑옷")
	if GameState.chapter == 2 and GameState.chapter_kills >= 10 and GameState.current_map == "ruins":
		_set_hud_message("검은 성채의 문이 열렸다.")
	if GameState.chapter == 3 and GameState.chapter_kills >= 12 and GameState.current_map == "snowfield":
		_set_hud_message("신전의 봉인이 풀렸다.")
	_update_stats()
	if GameState.tower_active:
		tower_enemies_remaining -= 1
		if tower_enemies_remaining <= 0:
			_advance_tower_floor()
		else:
			_update_tower_hud()


func _on_player_died() -> void:
	Audio.play_sfx("gameover")
	## (INBOX 답, 2026-09-06 16:09) §10.5 개정: 통과 중 회복 수단이 전혀
	## 없을 때(가 항목, _quest_should_retreat())의 진짜 출구는 사망 부활뿐이라
	## (사람 플레이어도 이 구간에선 죽어서 회복한다) quest_mode를 끄지 않고
	## 마을 부활 후 그대로 잇는다. 부활의 깃털(220골드, 사람 자원)은 자동
	## 소모하지 않으므로 대사창도 안 띄운다 - 옛 "mode==dialogue 예외" 우려는
	## 이 창을 아예 안 열게 되면서 저절로 없어졌다.
	if quest_mode:
		_quest_handle_death()
		return
	if GameState.revive_potions > 0:
		dialogue_choice_after = _on_revive_choice
		_play_dialogue([
			["", "쓰러졌다.\n부활의 깃털(%d개)을 쓰겠습니까?" % GameState.revive_potions, [
				["쓴다", "revive_yes"],
				["쓰지 않는다", "revive_no"],
			]],
		])
	else:
		_apply_death_penalty()


## §10.5(INBOX 답 16:09): 킬이 하나도 안 늘며 GIVEUP_STREAK회 연속 사망하면
## (감독 2026-09-09) quest_mode를 끄지 않고 재개 사냥터를 한 단계 아래(서쪽)로
## 내린다(같은 지역 반복 후퇴 GIVEUP과 같은 관례 - 처음 값과 같으면 streak+=1,
## 다르면 1로 리셋).
func _quest_handle_death() -> void:
	quest_death_count += 1
	if GameState.kills > _quest_kills_at_last_death:
		_quest_death_streak = 1
	else:
		_quest_death_streak += 1
	_quest_kills_at_last_death = GameState.kills
	## (INBOX 답, 2026-09-06 23:16) 통과 중(goal_reached) 사망 → 마을 부활 →
	## 같은 길 재진입 → 사망의 무한 순환을 끊는다. `_apply_death_penalty()`가
	## 부르는 `_change_map`은 call_deferred라 지금 시점의 `GameState.current_map`은
	## 아직 죽은 지역이다 - 후퇴 포기(`_quest_do_retreat` giveup 가지, 2732줄)와
	## 같은 방식으로 그 지역의 이전 지역을 재개 지점으로 남긴다. 이전이 마을이면
	## (예: hill에서 죽으면 prev=village) 재개할 사냥터가 아니므로 잡지 않는다.
	## (INBOX 답, 2026-09-07 00:45) 사망했으면 물약 조기 귀환의 "그 자리로"
	## 재개는 의미가 없다 - 기존 resume_zone 규칙이 우선한다.
	_quest_restock_zone = ""
	var prev := World.exit_of(GameState.current_map, "w")
	if prev != "" and GameState.unlocked_maps.has(prev) and not World.is_town(prev):
		_quest_resume_zone = prev
	_apply_death_penalty()
	if _quest_death_streak >= GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK:
		## (감독 2026-09-09) 예전엔 여기서 quest_mode를 껐다(5장 탐침 temple
		## 3연속 사망 = QUEST_MODE_OFF). 사용자가 켜 둔 오토가 저절로 꺼지면
		## "고장"으로 보인다 - 끄지 않고 재개 사냥터를 한 단계 아래(서쪽)로
		## 내려 거기서 성장한 뒤 다시 올라오게 한다(스탯·전직은 여전히 사용자 몫).
		var lower := World.exit_of(_quest_resume_zone if _quest_resume_zone != "" else GameState.current_map, "w")
		if lower != "" and GameState.unlocked_maps.has(lower) and not World.is_town(lower):
			_quest_resume_zone = lower
		$HUD/Message.text = "진행 없이 %d회 연속 사망 - 한 단계 아래에서 다시 성장" % _quest_death_streak
		_quest_death_streak = 0


## 부활의 깃털을 쓸지 답한 뒤. 쓰면 그 자리에서, 안 쓰면 마을로.
func _on_revive_choice(picked: String) -> void:
	if picked == "revive_yes":
		GameState.revive_potions -= 1
		$Player.health = maxi(int($Player.max_health * 0.5), 1)
		$Player.mana = $Player.max_mana
		$Player.invulnerability_time = 1.0
		$Player.motion = ""
		$Player.motion_time = 0.0
		$Player.health_changed.emit($Player.health, $Player.max_health)
		$Player.mana_changed.emit($Player.mana, $Player.max_mana)
		$HUD/Message.text = "부활의 깃털로 되살아났다."
	else:
		_apply_death_penalty()


## 전직 선택지("job_warrior"/"job_mage"/"job_rogue")를 고른 뒤. 실패 이유는
## 메시지로만 보여주고 대화를 끝낸다 - 레벨 미달·골드 부족은 change_job()이
## 문구로 돌려준다.
func _on_job_choice(picked: String) -> void:
	if not picked.begins_with("job_"):
		return
	var new_job := picked.trim_prefix("job_")
	var result := GameState.change_job(new_job)
	if result == "":
		$HUD/Message.text = "%s(으)로 전직했다!" % GameState.JOB_NAMES[new_job]
		_apply_equipment_to_player()
	else:
		$HUD/Message.text = result


## 진짜 죽음. 경험치를 잃고 마을에서 다시 시작한다.
func _apply_death_penalty() -> void:
	var lost := int(GameState.next_exp * 0.15)
	GameState.exp = maxi(GameState.exp - lost, 0)
	$Player.health = $Player.max_health
	$Player.mana = $Player.max_mana
	$Player.invulnerability_time = 1.0
	$Player.motion = ""
	$Player.motion_time = 0.0
	$Player.health_changed.emit($Player.health, $Player.max_health)
	$Player.mana_changed.emit($Player.mana, $Player.max_mana)
	# 사망은 대개 몬스터 접촉/투사체의 _on_body_entered(물리 콜백) 안에서
	# 걸린다 - 그 안에서 곧바로 _change_map(월드 다시 그리기)을 부르면
	# "Can't change this state while flushing queries" 에러와 함께 노드가
	# 샌다(엔진이 call_deferred를 쓰라고 직접 경고함). 한 프레임 미룬다.
	call_deferred("_change_map", "village", false)
	$HUD/Message.text = "쓰러졌다… 마을에서 다시 시작한다. EXP -%d" % lost
	_update_stats()


## 최대 체력·마력·공격력·속도를 계산하는 유일한 곳.
## 레벨, 투자한 능력치, 착용 장비 세 가지가 재료다.
## 예전에는 레벨업이 직접 더하고 여기서 다시 계산해 서로 덮어썼다.
func _apply_equipment_to_player() -> void:
	var previous: int = $Player.max_health
	$Player.max_health = 100 + (GameState.level - 1) * 15 + GameState.health_bonus + GameState.stat_health()
	$Player.max_mana = 60 + (GameState.level - 1) * 5 + GameState.stat_mana()
	$Player.attack_damage = 12 + (GameState.level - 1) * 2
	$Player.move_speed = 72.0 + GameState.speed_bonus + GameState.stat_speed()
	$Player.health = clampi($Player.health + ($Player.max_health - previous), 1, $Player.max_health)
	$Player.mana = mini($Player.mana, $Player.max_mana)
	$Player.health_changed.emit($Player.health, $Player.max_health)
	$Player.mana_changed.emit($Player.mana, $Player.max_mana)
	_update_stats()


## 레벨업을 "누가 봐도 레벨업"인 축제로(INBOX 2026-10-20 00:09). 배너·플래시·
## 증가치 카드는 LevelUpFx 가 그리고, 여긴 전투 쪽(히트스톱·빛기둥·주변 적
## 밀쳐내기)만 맡는다. hp_before/atk_before 는 `_apply_equipment_to_player()`
## 호출 전 값 - 실제 증가치를 보여 주려면 전후 비교가 필요하다.
func _play_levelup_fanfare(hp_before: int, atk_before: int, stat_gain: int, perk_gained := false) -> void:
	# `--headless` 로 도는 검사 스위트는 실제 프레임을 그리지 않는데, 레벨업이
	# 수백 번 나는 run_playthrough 에서 매번 0.12초 실시간 히트스톱을 기다리면
	# 검사 시간이 크게 늘어난다 - 화면이 있을 때만 느려진다.
	if DisplayServer.get_name() != "headless":
		_hitstop(0.12, 0.05)
	# 결함(감독, 2026-10-20 01:30): "발밑 고리"가 1px 선처럼 얇게 보였다.
	# 겹쳐 그리는 두 번째 링(크기·타이밍만 다름)으로 두껍게 보이게 한다 -
	# 새 외부 에셋 없이 기존 heal.png 재사용.
	var fx: SkillFx = preload("res://scenes/skill_fx.tscn").instantiate()
	fx.global_position = $Player.global_position
	add_child(fx)
	fx.play("res://assets/fx/heal.png", 4, 0.09, Color(1.0, 0.85, 0.3), 1.8)
	var fx2: SkillFx = preload("res://scenes/skill_fx.tscn").instantiate()
	fx2.global_position = $Player.global_position
	add_child(fx2)
	fx2.play("res://assets/fx/heal.png", 4, 0.09, Color(1.0, 0.78, 0.15, 0.7), 2.1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - $Player.global_position
		if offset.length() < 60.0:
			enemy.move_and_collide(offset.normalized() * 10.0)
	var next_milestone := GameState.next_level_milestone(GameState.level)
	var lines: Array[String] = [
		"Lv.%d" % GameState.level,
		"HP %d→%d" % [hp_before, $Player.max_health],
		"공격 %d→%d" % [atk_before, $Player.attack_damage],
		"능력치 점수 +%d" % stat_gain,
		"다음 보상: Lv%d (%d 남음)" % [next_milestone, next_milestone - GameState.level],
	]
	# 전투 중에 특성 고르기 창이 강제로 뜨면 그 사이 다른 몬스터에게 맞아
	# 죽을 수 있어서, 더는 자동으로 띄우지 않는다. 선택권만 카드에 적어
	# 두고 능력치 화면(C)에서 안전할 때 알아서 고르게 한다.
	if perk_gained:
		lines.append("특성 선택권 획득 (C키)")
	_levelup_fx.play(lines)


## 결함(감독, 2026-10-20 01:30) 복구: 연출 동안 숨겨 둔 HUD 상단 문구를
## 되살린다 - 그 사이 쌓인 퀘스트·픽업 문구가 보인다(잠금은 이미 풀렸음).
func _on_levelup_fanfare_finished() -> void:
	$HUD/Message.visible = true


## 레벨 보상 상자(INBOX 2026-10-20 00:10)를 큐에 넣는다. 한 번에 여러
## 마일스톤이 쏟아져도(예: 탑 보상으로 exp를 크게 받아 5→15 레벨을 한 번에
## 뛰는 경우) 한 상자씩 순서대로 보여 준다. LevelUpFx 배너·카드(약 1.8초)가
## 끝난 뒤에 띄운다 - 동시에 띄우면 같은 화면 위쪽 자리에서 글자가 겹친다
## (3층 캡처로 실제 확인, captures/tmp/level_reward_box_closed.png 첫 시도).
const LEVEL_REWARD_BOX_DELAY := 2.0


## title 을 바꾸면 같은 상자를 퀘스트 완료 배너로도 쓴다(INBOX 2026-10-20
## 00:10 나머지 절반 - "퀘스트 완료도 같은 배너로").
func _queue_level_reward_box(reward: Dictionary, title := "레벨 보상 상자!") -> void:
	var entry := {"reward": reward, "title": title}
	_level_reward_queue.append(entry)
	if _level_reward_queue.size() == 1:
		await get_tree().create_timer(LEVEL_REWARD_BOX_DELAY).timeout
		# 결함(감독, 2026-10-20 01:30): 상자가 NPC·HUD 문구와 겹쳐 보였다.
		# 상자가 떠 있는 동안은 HUD 위쪽 문구도 숨긴다(레벨업 연출과 같은 처리).
		$HUD/Message.visible = false
		_level_reward_box.show_reward(entry["reward"], entry["title"])


func _on_level_reward_box_closed() -> void:
	_level_reward_queue.pop_front()
	if not _level_reward_queue.is_empty():
		var entry: Dictionary = _level_reward_queue[0]
		_level_reward_box.show_reward(entry["reward"], entry["title"])
	else:
		$HUD/Message.visible = true


## `Engine.time_scale` 을 짧게 낮춰 타격감을 준다. 결함(감독, 2026-10-20
## 02:28): `create_timer(duration, true)` 는 2번째 인자가 `ignore_time_scale`
## 이 아니라 `process_always` 라 time_scale 0.05 에서 0.12초 타이머가 실제
## 2.4초(0.12/0.05) 걸렸다. 4번째 인자 `ignore_time_scale=true` 로도 이
## 헤드리스 엔진에서는 타이머가 첫 프레임에 즉시(실제 1ms 내) 터져 버리는
## 별도 결함이 있어(확인: tests/_scratch_timer_probe 실험, frame 1 delta
## 0.007초인데 time_left 0.12초 타이머가 바로 fire) `Time.get_ticks_msec()`
## 실제 시간을 직접 재는 폴링으로 바꿨다 - time_scale 과 무관하게 항상
## duration 만큼의 실제 시간이 지난다.
func _hitstop(duration: float, scale: float) -> void:
	Engine.time_scale = scale
	var start_ms := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start_ms) / 1000.0 < duration:
		await get_tree().process_frame
	Engine.time_scale = 1.0


## HP·MP·EXP 바와 그 위에 적는 숫자를 새로 그린다. 자세한 능력치는 C(능력) 창에서 본다.
## 탑 난이도를 100층까지 클리어할 때마다 별을 하나씩 이름 옆에 단다.
## 캐릭터 스프라이트 위 오버레이 대신 상태바 레벨 표시줄에 붙이는 쪽을
## 골랐다 - 카메라를 따라다니는 월드 오버레이보다 훨씬 단순하다.
func _title_stars() -> String:
	return " " + "★".repeat(GameState.tower_titles.size()) if not GameState.tower_titles.is_empty() else ""


func _update_stats() -> void:
	$HUD/StatBar/Level.text = "Lv %d%s  %dG" % [GameState.level, _title_stars(), GameState.gold]
	$HUD/StatBar/HP/Value.text = "%d/%d" % [$Player.health, $Player.max_health]
	$HUD/StatBar/MP/Value.text = "%d/%d" % [$Player.mana, $Player.max_mana]
	$HUD/StatBar/EXP.max_value = maxf(float(GameState.next_exp), 1.0)
	$HUD/StatBar/EXP.value = float(GameState.exp)
	$HUD/StatBar/EXP/Value.text = "EXP %d/%d" % [GameState.exp, GameState.next_exp]


func _load_ui_settings() -> void:
	if not FileAccess.file_exists(UI_SETTINGS_PATH):
		return
	var file := FileAccess.open(UI_SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	hud_stat_scale = clampf(float(data.get("hud_stat_scale", 1.0)), HUD_SCALE_MIN, HUD_SCALE_MAX)
	hud_skill_scale = clampf(float(data.get("hud_skill_scale", 1.0)), HUD_SCALE_MIN, HUD_SCALE_MAX)
	Audio.set_music_muted(bool(data.get("music_muted", false)))
	Audio.set_sfx_muted(bool(data.get("sfx_muted", false)))


func _save_ui_settings() -> void:
	var file := FileAccess.open(UI_SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"hud_stat_scale": hud_stat_scale, "hud_skill_scale": hud_skill_scale,
		"music_muted": Audio.music_muted, "sfx_muted": Audio.sfx_muted}))


## 일시정지 화면에서 음악/효과음을 켜고 끈다("음량 조절 수단이 없다" - HANDOFF.md).
func _toggle_audio_mute(which: String) -> void:
	if which == "music":
		Audio.set_music_muted(not Audio.music_muted)
	else:
		Audio.set_sfx_muted(not Audio.sfx_muted)
	_save_ui_settings()
	_refresh_pause_info()


func _apply_hud_scale() -> void:
	$HUD/StatBar.scale = Vector2.ONE * hud_stat_scale
	$HUD/SkillBar.scale = Vector2.ONE * hud_skill_scale
	# (감독 2026-09-10) 터치 버튼은 스킬바 칸의 실제(배율 적용) 자리를 그대로 따라간다.
	# 배율 1.1로 키우면 칸은 커지는데 버튼은 제자리라 2차 전직 스킬이 안 눌리던 원인.
	var mobile: Control = $HUD/MobileControls
	for pair in [["Skill0", "SkillTouch0"], ["Skill1", "SkillTouch1"], ["Skill2", "SkillTouch2"],
			["Skill3", "SkillTouch3"], ["Skill4", "SkillTouch4"], ["Skill5", "SkillTouch5"],
			["Attack", "Attack"], ["Dodge", "Dodge"], ["Potion", "Potion"], ["Scroll", "Scroll"]]:
		var slot_rect: Rect2 = $HUD/SkillBar.get_node(pair[0]).get_global_rect()
		var button: Control = mobile.get_node(pair[1])
		button.global_position = slot_rect.position
		button.size = slot_rect.size


## 일시정지 화면에서 체력바/스킬바 크기를 따로 줄이고 키운다.
func _adjust_hud_scale(which: String, step: float) -> void:
	if which == "stat":
		hud_stat_scale = clampf(hud_stat_scale + step, HUD_SCALE_MIN, HUD_SCALE_MAX)
	else:
		hud_skill_scale = clampf(hud_skill_scale + step, HUD_SCALE_MIN, HUD_SCALE_MAX)
	_apply_hud_scale()
	_save_ui_settings()
	_refresh_pause_info()


func _refresh_pause_info() -> void:
	## 터치 모드는 아래에 저장/타이틀/음악/효과음 버튼이 겹치는 자리라
	## 키보드 단축키 안내를 다 넣으면 버튼과 텍스트가 겹친다. 버튼이 있는
	## 화면에서는 키보드 안내를 빼고 상태 요약만 버튼 위 공간에 짧게 띄운다.
	if $HUD/MobileControls.visible:
		$HUD/Pause/Info.text = "일시정지\n음악 %s  효과음 %s\n체력바 %d%%  스킬바 %d%%" % [
			"켜짐" if not Audio.music_muted else "꺼짐", "켜짐" if not Audio.sfx_muted else "꺼짐",
			int(round(hud_stat_scale * 100)), int(round(hud_skill_scale * 100))]
		## 결함(2026-09-06, HUD 창 전수 점검 8/13): Info 박스가 데스크톱 9줄용
		## 152px 높이 그대로라 아래 절반이 Save/Title/ToggleControls/MusicMute/
		## SfxMute 버튼 위에 겹쳐 있었다. 모바일 3줄만 필요하니 줄인다.
		## 결함(2026-09-07, grow(4) 전수 점검): 버튼 전역 top=94인데 바닥을
		## 로컬 52(전역 92)로 두면 여백이 2px뿐이었다 - 4px 여백 확보하려면
		## 전역 90(로컬 50)까지 줄여야 한다.
		$HUD/Pause/Info.offset_bottom = 50.0
	else:
		$HUD/Pause/Info.text = "일시정지\n1 저장  2 타이틀로  9 게임 종료  7/8 음악·효과음(%s·%s)\n3/4 체력바 크기 -/+  (%d%%)\n5/6 스킬바 크기 -/+  (%d%%)\n[ ] 메뉴 탭 이동\nWASD 이동  J 공격  1~4 스킬  K 스킬설명  Q 돌진\nL 회복  I 가방  C 능력  M 지도  E 대화  B 퀘스트\nG 가이드(강화·소켓·세트·정령 인장·제작·낚시 설명)\nF 낚시(낚싯대 있고 연못 있는 지역에서)" % [
			"켜짐" if not Audio.music_muted else "꺼짐", "켜짐" if not Audio.sfx_muted else "꺼짐",
			int(round(hud_stat_scale * 100)), int(round(hud_skill_scale * 100))]
		$HUD/Pause/Info.offset_bottom = 152.0
	$HUD/MobileControls.set_pause_audio_labels(Audio.music_muted, Audio.sfx_muted)


func _connect_enemy(enemy: Node) -> void:
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.dropped.connect(_on_enemy_dropped)
	enemy.boss_fallen.connect(_on_boss_fallen)
	if enemy.has_signal("phase_changed"):
		enemy.phase_changed.connect(func(phase: int) -> void:
			$HUD/Message.text = "%s %d단계 돌입!" % [enemy.get_node("Name").text, phase + 1])


## 몬스터가 떨어뜨린 물건을 바닥에 놓는다. 플레이어가 밟으면 주워진다.
func _on_enemy_dropped(data: Dictionary, at: Vector2) -> void:
	var pickup := preload("res://scenes/pickup.tscn").instantiate()
	pickup.kind = data.get("kind", "potion")
	pickup.amount = int(data.get("amount", 0))
	pickup.item_name = str(data.get("item_name", ""))
	pickup.stone_id = str(data.get("stone_id", ""))
	pickup.tower_tier = str(data.get("tower_tier", ""))
	pickup.essence = str(data.get("essence", ""))
	pickup.drop_source = "boss" if bool(data.get("boss", false)) else "mob"
	pickup.position = $World.nearest_free_pos(GameState.current_map, at)
	pickup.collected.connect(_on_pickup_collected)
	add_child(pickup)


func _on_pickup_collected(pickup: Node) -> void:
	match pickup.kind:
		"gold": _set_hud_message("%d골드를 주웠다." % pickup.amount)
		"potion": _set_hud_message("회복약을 주웠다.")
		"chest": _set_hud_message("%s 획득! I키로 장착" % GameState.item_label(pickup.item_name, GameState.item_uid.back()))
		"key": _set_hud_message("열쇠를 주웠다. 잠긴 문을 열 수 있다.")
		"magic_stone":
			var stone_name := str(GameState.STONES.get(pickup.stone_id, {}).get("name", pickup.stone_id))
			_set_hud_message("마법돌 [%s]을(를) 주웠다. 대장간에서 소켓에 박자." % stone_name)
		"tower_material":
			var mat_name := GameState.tower_material_name(pickup.tower_tier)
			_set_hud_message("%s을(를) 주웠다. (%d개)" % [mat_name, int(GameState.tower_material_counts.get(pickup.tower_tier, 0))])
		"job_stone":
			_set_hud_message("%s을(를) 주웠다! (%d개)" % [pickup.stone_id, int(GameState.materials.get(pickup.stone_id, 0))])
		"essence":
			_set_hud_message("%s을(를) 주웠다! (%d개)" % [pickup.essence, int(GameState.materials.get(pickup.essence, 0))])
	_update_stats()


## 레벨업 > 장비 획득 > 퀘스트 우선순위. 레벨업 메시지가 뜬 직후
## _message_lock_until 전까지는 낮은 우선순위 메시지가 덮지 못한다.
func _set_hud_message(text: String) -> void:
	if Time.get_ticks_msec() / 1000.0 >= _message_lock_until:
		$HUD/Message.text = text


## 너무 쉽다는 피드백으로 체력·공격력을 계속 올렸다. 1~3장 보스는 그 장
## 보스 세트를 맨몸으로 잡을 수 있을 정도로만 벅차게 잡고, 최종 보스(4장)는
## "보스 세트를 +6 이상 강화하지 않으면 못 이긴다"는 생각으로 따로 크게
## 뛰게 잡았다 - 방어 감소율 상한이 60%라 방어를 많이 쌓아도 이 정도
## 공격력이면 위험하다. "보스의 파편"(제작 재료)은 확정으로 나오지만
## 개수는 매번 GameState.BOSS_FRAGMENT_MIN~MAX 사이 무작위다.
const BOSS_TIERS := {
	1: {"hp": 2600, "damage": 34, "exp": 90, "gold": 45},
	2: {"hp": 5400, "damage": 78, "exp": 170, "gold": 95},
	3: {"hp": 7800, "damage": 115, "exp": 280, "gold": 180},
	4: {"hp": 15000, "damage": 210, "exp": 420, "gold": 280},
	# 5장(유민의 땅)은 스토리 클리어 후 즉시 이어지는 엔드게임성 콘텐츠라
	# 4장 최종보스보다 세게 잡는다(HANDOFF 관례: 장이 오를수록 강해짐).
	# 단, 헤드리스 테스트(kill_boss)가 공격력 400으로 40회만 휘두르므로
	# 크리티컬 없이도 40회 안에 반드시 죽는 상한(16000) 아래로 잡는다.
	5: {"hp": 15600, "damage": 260, "exp": 620, "gold": 420},
	# 6장(파편의 바다) — 5장보다 세게. kill_boss() 테스트는 48회로 늘려
	# 부른다(48*400=19200 상한, HP는 그 아래로).
	6: {"hp": 18500, "damage": 300, "exp": 860, "gold": 560},
	# 7장(잊힌 성소) — 6장보다 세게. kill_boss() 테스트는 55회로 늘려
	# 부른다(55*400=22000 상한, HP는 그 아래로).
	7: {"hp": 21500, "damage": 340, "exp": 1150, "gold": 720},
	# 8장(침묵의 회랑) — 7장보다 세게. kill_boss() 테스트는 62회로 늘려
	# 부른다(62*400=24800 상한, HP는 그 아래로).
	8: {"hp": 24500, "damage": 385, "exp": 1500, "gold": 900},
	# 9장(역전의 탑) — 8장보다 세게. kill_boss() 테스트는 70회로 늘려
	# 부른다(70*400=28000 상한, HP는 그 아래로).
	9: {"hp": 27500, "damage": 430, "exp": 1900, "gold": 1100},
	# 10장 최종 보스. 자동 테스트의 처치 상한(40*400) 아래로 유지한다.
	# (결함 수정, 2026-10-20 INBOX 00:11 감독 05:30 재검수) 전조를 0.5초로
	# 올려도 `check_origin_death_cause.gd` 재실측 결과 5분 안 사망 수가
	# 그대로 5/5(수정 전 10051프레임=167.5초 / 수정 후 11007프레임=183.5초로
	# 10%만 늦춰짐)이고 보스 체력도 2.5%밖에 못 깎아 "전조만으로 풀렸다"는
	# 숫자가 없었다. damage 480은 9장(430)보다 세면서 player.take_damage의
	# 방어 감소율이 0(이 조건은 기어 없이 도달한 상태)이라 맨몸 844 HP가
	# 2타(480×2=960)에 죽는다 - 9장보다 쎄지 않게 430 밑으로 낮춘다.
	10: {"hp": 15800, "damage": 350, "exp": 2600, "gold": 1500},
}

## 장 보스를 쓰러뜨리면 바로 열리는 다음 장 지역(INBOX 2026-10-20 23:42).
## 10장(근원)은 마지막 장이라 다음이 없다.
const CHAPTER_NEXT_MAP := {
	1: "harbor", 2: "frost_camp", 3: "abyss", 4: "remnant_village",
	5: "driftwood_pier", 6: "lantern_village", 7: "waystation_camp",
	8: "rift_camp", 9: "origin_camp",
}


func _spawn_boss() -> void:
	# boss_defeated와 무관하게 재입장마다 새 보스를 만든다.
	boss_spawned = true
	var boss := preload("res://scenes/enemy.tscn").instantiate()
	boss.position = Vector2(216, 110)
	# 장이 오를수록 보스가 세진다.
	var tier: Dictionary = BOSS_TIERS.get(GameState.chapter, BOSS_TIERS[1])
	boss.max_health = int(tier["hp"])
	boss.health = boss.max_health
	boss.damage = int(tier["damage"])
	boss.speed = 25.0
	boss.exp_reward = int(tier["exp"])
	boss.gold_reward = int(tier["gold"])
	boss.is_boss = true
	boss.archetype = "boss"
	boss.area_id = GameState.current_map
	add_child(boss)
	_connect_enemy(boss)
	$HUD/Message.text = "경고! %s이(가) 나타났다." % boss.get_node("Name").text
	var boss_key: String = str(boss.kind.get("id", "guardian"))
	if Story.BOSS_MEET.has(boss_key):
		_play_dialogue(Story.BOSS_MEET[boss_key])
	Audio.play_sfx("boss")
	Audio.play_music("boss")


func _change_map(map_name: String, show_notice := true, spawn := Vector2.ZERO) -> void:
	GameState.current_map = map_name
	if spawn == Vector2.ZERO:
		spawn = _west_spawn(map_name)
	# 카메라와 플레이어 이동 범위를 지역 크기에 맞춘다.
	var bounds := World.pixel_size_of(map_name)
	var camera: Camera2D = $Player/Camera2D
	camera.limit_right = int(bounds.x)
	camera.limit_bottom = int(bounds.y)
	$Player.bounds = bounds
	GameState.unlock_map(map_name)
	transition_lock = 0.6
	_quest_pickup_skip.clear()
	$Player.global_position = spawn
	# 각 챕터의 마을에만 NPC를 배치한다. 사냥터에서는 상호작용할 NPC가 없고,
	# 마을에서는 촌장/상인/대장장이/여관/창고지기를 통해 다음 퀘스트를 진행한다.
	var town: bool = World.is_town(map_name)
	$VillageElder.visible = town
	$Merchant.visible = town
	$Smith.visible = town
	$Innkeeper.visible = town
	$Keeper.visible = town
	if town:
		$VillageElder.position = World.town_npc_position(map_name, "elder")
		$Merchant.position = World.town_npc_position(map_name, "merchant")
		$Smith.position = World.town_npc_position(map_name, "smith")
		$Innkeeper.position = World.town_npc_position(map_name, "inn")
		$Keeper.position = World.town_npc_position(map_name, "keeper")
		$VillageElder/Sprite.texture = load("res://assets/characters/npc_%s.png" % TOWN_QUEST_NPC.get(map_name, "elder"))
		_dress_npc("VillageElder", TOWN_QUEST_NPC.get(map_name, "elder"))
	else:
		$VillageElder.position = Vector2(56, 108)
		$Merchant.position = Vector2(212, 108)
		$Smith.position = Vector2(136, 108)
		$Innkeeper.position = Vector2(96, 108)
		$Keeper.position = Vector2(172, 108)

	$World.paint(map_name)
	Audio.play_music("boss" if boss_spawned else map_name)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup._despawn()
	for arrow in get_tree().get_nodes_in_group("arrows"):
		arrow.remove_from_group("arrows")
		arrow.queue_free()
	for proj in get_tree().get_nodes_in_group("enemy_projectiles"):
		proj.remove_from_group("enemy_projectiles")
		proj.queue_free()
	for door in get_tree().get_nodes_in_group("doors"):
		door.remove_from_group("doors")
		door.queue_free()
	if map_name == "tower":
		if not GameState.tower_active:
			# 난이도(tower_difficulty)는 _confirm_tower_select()에서 이미
			# 정해져 있다. 시작 층은 전투력 스킵(tower_entry_floor)이
			# 이미 깬 층 안에서 정해준 값을 그대로 쓴다.
			GameState.tower_active = true
			GameState.tower_floor = GameState.tower_entry_floor(GameState.tower_difficulty)
		_spawn_tower_floor()
	else:
		GameState.tower_active = false
		_spawn_area_enemies(map_name)
	_spawn_area_chests(map_name)
	_spawn_area_doors(map_name)
	GameState.record_visit(map_name)
	# 보스는 클리어 후에도 재입장하면 다시 나타난다. boss_defeated는
	# 스토리 보상/진행 기록이며, 보스의 존재 여부를 영구히 막지 않는다.
	var boss_chapter := World.boss_chapter_of(map_name)
	if boss_chapter > 0 and not boss_spawned:
		_spawn_boss()
	var is_dungeon: bool = AREA_DOORS.has(map_name)
	$HUD/Area.text = _tower_area_label() if map_name == "tower" \
		else ("[던전] %s" % World.title_of(map_name)) if is_dungeon \
		else World.title_of(map_name)
	if show_notice:
		if is_dungeon and not GameState.opened_doors.has(str(AREA_DOORS[map_name]["key"])):
			# 처음 이 던전에 들어설 때만 입구 안내를 따로 띄운다. 문을 이미
			# 열어 놨으면(재입장) 평범한 도착 메시지만 준다.
			$HUD/Message.text = "던전 입구다. %s 어딘가에 %s가 있다." % [
				World.title_of(map_name), str(AREA_DOORS[map_name]["label"])]
		else:
			$HUD/Message.text = "%s에 도착했다." % World.title_of(map_name)


func _on_potion_changed(count: int) -> void:
	GameState.potions = count
	$HUD/SkillBar/Potion/Count.text = str(count)
	_update_skill_bar()


func _on_potion_used(healed: int) -> void:
	$HUD/Message.text = "회복약 사용  HP +%d" % healed


func _update_skill_bar() -> void:
	var player := $Player
	_set_cooldown($HUD/SkillBar/Attack/Cooldown, player.cooldown_time, player.attack_cooldown)
	_set_cooldown($HUD/SkillBar/Dodge/Cooldown, player.dash_cooldown, player.dash_cooldown_max)
	$HUD/SkillBar/Dodge.modulate = Color.WHITE if GameState.dash_unlocked else Color(0.35, 0.35, 0.35)
	$HUD/SkillBar/Potion.modulate = Color.WHITE if player.potions > 0 else Color(0.35, 0.35, 0.35)
	$HUD/SkillBar/Scroll/Count.text = str(GameState.scrolls)
	$HUD/SkillBar/Scroll.modulate = Color.WHITE if GameState.scrolls > 0 else Color(0.35, 0.35, 0.35)
	# 5·6번 슬롯(2차 전직 전용)은 기본적으로 숨겨 두고 아래 루프에서만 켠다.
	if has_node("HUD/SkillBar/Skill4"):
		$HUD/SkillBar/Skill4.visible = false
	if has_node("HUD/SkillBar/Skill5"):
		$HUD/SkillBar/Skill5.visible = false
	# 스킬 네 칸(2차 전직 시 여섯 칸). 못 배웠으면 어둡게, 마력이 모자라면 MP! 로 알린다.
	for index in GameState.active_skills().size():
		if index >= 4 and not has_node("HUD/SkillBar/Skill%d" % index):
			continue
		var slot: TextureRect = $HUD/SkillBar.get_node("Skill%d" % index)
		slot.visible = true
		var data: Dictionary = GameState.active_skills()[index]
		# 전직하면 스킬 아이콘 자체가 바뀐다. 아이콘 경로가 캐시와 다를 때만 다시 불러온다
		# (매 프레임 load()를 부르면 낭비다).
		if slot.get_meta("icon_path", "") != str(data["icon"]):
			slot.set_meta("icon_path", str(data["icon"]))
			slot.texture = load(str(data["icon"]))
		var unlocked: bool = GameState.skill_unlocked(index)
		var ready: bool = unlocked and player.mana >= int(data["cost"]) and player.health > 1
		slot.modulate = Color.WHITE if ready else Color(0.4, 0.4, 0.44)
		if not unlocked:
			slot.get_node("Cost").text = "Lv%d" % int(data["level"])
		elif data.has("hp_cost_pct"):
			slot.get_node("Cost").text = "%d%%" % int(float(data["hp_cost_pct"]) * 100)
		else:
			slot.get_node("Cost").text = str(int(data["cost"]))
		slot.get_node("Cost").modulate = Color.WHITE if ready else Color(1.0, 0.6, 0.5)
		slot.get_node("Pick").visible = index == player.skill_slot
		_set_cooldown(slot.get_node("Cooldown"),
			player.skill_cooldowns[index], player.skill_cooldown_maxes[index])


func _set_cooldown(bar: ProgressBar, remaining: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = remaining
	bar.visible = remaining > 0.0


func _on_boss_fallen() -> void:
	# 죽은 보스는 queue_free()로 사라질 뿐 이 플래그를 안 건드린다. 리셋하지
	# 않으면 재입장해도 "이미 스폰했다"로 남아 다시는 안 나온다.
	boss_spawned = false
	var fragments := randi_range(GameState.BOSS_FRAGMENT_MIN, GameState.BOSS_FRAGMENT_MAX)
	GameState.add_boss_fragments(fragments)
	$HUD/Message.text = "보스의 파편 %d개 획득!" % fragments
	# 보스방은 재입장마다 다시 스폰한다(위 996~1002줄) - 그 장의 보스를 이미
	# 보상까지 받았거나(claimed_boss_rewards), 이미 지나간 장의 옛 보스방이면
	# (room_chapter != GameState.chapter) 재처치는 파편만, 진행·보상·대사는
	# 다시 안 준다 (결함 2026-10-20 19:50 — 무한 파밍·quest_stage 되감김).
	var room_chapter: int = World.boss_chapter_of(GameState.current_map)
	var first_kill: bool = room_chapter == GameState.chapter \
		and not GameState.claimed_boss_rewards.has(room_chapter)
	if not first_kill:
		$HUD/Message.text = _mob("이미 처치한 보스다. 파편만 얻었다.")
		return
	GameState.claimed_boss_rewards.append(room_chapter)
	# 아래 if/elif 체인이 끝에서 GameState.chapter 로 메시지를 고르므로,
	# 다음 장을 미리 여는 코드는 그 값이 바뀌기 전에 적어 둔다.
	var fallen_chapter: int = GameState.chapter
	# 5~10장 보스는 그 장의 정수도 준다(세트 제작 재료).
	var essence := GameState.chapter_essence(room_chapter)
	if essence != "":
		var ess_count := randi_range(GameState.ESSENCE_BOSS_MIN, GameState.ESSENCE_BOSS_MAX)
		GameState.add_essence(essence, ess_count)
		$HUD/Message.text += " %s %d개 획득!" % [essence, ess_count]
	var fell: Array = Story.boss_fall(str(GameState.BOSS_KEYS.get(GameState.chapter, "guardian")), GameState.choices)
	if not fell.is_empty():
		_play_dialogue(fell)

	if GameState.chapter == 1:
		# 예전에는 여기서 곧장 4단계로 넘기고 항구로 보냈다. 그래서 2·3단계인
		# 촌장의 보상 대화에 아무도 도달하지 못했다. 마을로 돌려보낸다.
		GameState.boss_defeated = true
		GameState.quest_stage = 2
		Audio.play_music(GameState.current_map)
		$HUD/Message.text = _mob("수호자를 쓰러뜨렸다. M키 지도로 마을에 돌아가자.")
	elif GameState.chapter == 2:
		GameState.quest_stage = 5
		GameState.dash_unlocked = true
		Audio.play_music(GameState.current_map)
		$HUD/Message.text = _mob("흑기사단장을 쓰러뜨렸다. M키 지도로 마을에 돌아가자.")
	elif GameState.chapter == 3:
		GameState.quest_stage = 7
		Audio.play_music(GameState.current_map)
		$HUD/Message.text = _mob("얼음 군주를 쓰러뜨렸다. M키 지도로 마을에 돌아가자.")
	elif GameState.chapter >= 4:
		GameState.quest_stage = 9
		Audio.play_music(GameState.current_map)
		$HUD/Message.text = _mob("심연의 군주를 쓰러뜨렸다. M키 지도로 마을에 돌아가자.")
		if GameState.chapter == 5:
			GameState.quest_stage = 19
			$HUD/Message.text = "태초의 심연을 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."
		elif GameState.chapter == 6:
			GameState.quest_stage = 29
			$HUD/Message.text = "파수꾼의 유해를 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."
		elif GameState.chapter == 7:
			GameState.quest_stage = 39
			$HUD/Message.text = "빛바랜 사제왕을 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."
		elif GameState.chapter == 8:
			GameState.quest_stage = 49
			$HUD/Message.text = "말없는 감독관을 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."
		elif GameState.chapter == 9:
			GameState.quest_stage = 59
			$HUD/Message.text = "역행자를 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."
		elif GameState.chapter == 10:
			GameState.quest_stage = 69
			GameState.boss_defeated = true
			$HUD/Message.text = "근원의 보스를 쓰러뜨렸다. 마을로 돌아가 결말을 확인하자."

	# 보스 격파 즉시 보상 + 장 전환 보상(INBOX 2026-10-20 23:42). 예전엔
	# 촌장에게 돌아가 두 번 말 걸어야(먼저 축하 대화, 그다음 장 전환 대화)
	# 다음 장 지역이 열렸다 - 그 자리에서 바로 보상을 주고 다음 장 지역을
	# unlocked_maps 에 넣는다(M 지도로 바로 갈 수 있게). GameState.chapter
	# 자체는 여기서 안 바꾼다 - `_spawn_boss()`가 재입장 보스 세기를
	# GameState.chapter 로 고르고(main.gd:915), check_boss_respawn.gd가
	# 보장하는 "처치 직후에도 boss_defeated 가 참으로 남는다" 가 그 값에
	# 달려 있어, 촌장과 말하지 않은 채 미리 chapter 를 올리면 아직 안 떠난
	# 보스 방을 다시 들어왔을 때 보스 숫자가 다음 장 것으로 뒤바뀌고
	# boss_defeated 도 거짓으로 되돌아간다(실측 - 이 바퀴에서 발견해 되돌림).
	# chapter·chapter_kills·boss_defeated 갱신은 그대로 촌장 귀환 대화(위
	# if/elif, Story.CHAPTERS)가 맡고, 그 대화는 이제 게이트가 아니라
	# "선택" - 안 가도 다음 장 지역엔 이미 들어갈 수 있다(unlock_map 은
	# 이미 있으면 건너뜀, 다시 가도 무해).
	var reward: Dictionary = GameState.boss_instant_reward(fallen_chapter)
	_queue_level_reward_box(
		{"item": reward["item"], "gold": int(reward["gold"]), "stones": int(reward["stones"]),
			"quest_label": "보스 격파"},
		"보스 격파 보상!")
	if CHAPTER_NEXT_MAP.has(fallen_chapter):
		GameState.unlock_map(str(CHAPTER_NEXT_MAP[fallen_chapter]))


## 연못이 있는 지역에서 낚싯대를 갖고 있으면 F로 낚시한다. 지역 하나에
## 자리를 딱 짚어 두는 대신, 그 지역에 연못이 있다는 정보(world.gd 의
## "pond" 키)를 그대로 재사용해서 새 마커를 안 늘려도 되게 했다.
func _try_fish() -> void:
	if fish_cooldown > 0.0:
		return
	if not World.AREAS.get(GameState.current_map, {}).has("pond"):
		$HUD/Message.text = "여기는 낚시할 물이 없다."
		return
	if not GameState.can_fish():
		$HUD/Message.text = "낚싯대가 있어야 낚시할 수 있다."
		return
	fish_cooldown = FISH_COOLDOWN_MAX
	var caught := GameState.roll_fish()
	if caught == "":
		return
	GameState.add_item(caught)
	Audio.play_sfx("accept")
	$HUD/Message.text = "%s을(를) 낚았다!" % caught


func _interact_npc() -> void:
	if not World.is_town(GameState.current_map):
		$HUD/Message.text = "상호작용할 대상이 없다."
		return
	# 상인은 따로 선다. 촌장 대화에 상점을 묶어 두면 의뢰가 있는 동안
	# 물건을 살 수 없다.
	# 마을에는 촌장·상인·대장장이·여관 주인·창고지기가 선다.
	# 가장 가까운 사람과 이야기한다.
	var here_pos: Vector2 = $Player.global_position
	var people := {
		"elder": here_pos.distance_to(World.town_npc_position(GameState.current_map, "elder")),
		"merchant": here_pos.distance_to(World.town_npc_position(GameState.current_map, "merchant")),
		"smith": here_pos.distance_to(World.town_npc_position(GameState.current_map, "smith")),
		"inn": here_pos.distance_to(World.town_npc_position(GameState.current_map, "inn")),
		"keeper": here_pos.distance_to(World.town_npc_position(GameState.current_map, "keeper")),
	}
	var who_near := "elder"
	for key in people:
		if people[key] < people[who_near]:
			who_near = key
	if people[who_near] > TALK_RANGE:
		$HUD/Message.text = "상호작용할 대상이 없다."
		return
	match who_near:
		"smith":
			if _maybe_chatter("smith"):
				return
			_toggle_forge()
			return
		"merchant":
			if _maybe_chatter("merchant"):
				return
			_open_shop()
			return
		"keeper":
			if _maybe_chatter("keeper"):
				return
			_toggle_storage()
			return
		"inn":
			_rest_at_inn()
			return
	# 퀘스트는 어느 마을에서든 이어진다. 한 마을에만 묶어 두면 장이 바뀔 때마다
	# 지도 반대편까지 되돌아가야 한다. 마을마다 퀘스트 담당이 따로 있다.
	var who_key: String = TOWN_QUEST_NPC.get(GameState.current_map, "elder")
	var who := Story.name_of(who_key)
	var voice: Dictionary = TOWN_VOICE.get(who_key, TOWN_VOICE["elder"])
	if GameState.quest_stage == 0:
		GameState.quest_stage = 1
		_play_dialogue([
			[who_key, "숲에서 마물이 내려오고 있네.\n셋만 솎아 주면 나머지는 물러갈 걸세."],
			[who_key, "그리고 그놈들을 이끄는 것이 있다면…\n그것까지 부탁하겠네."],
			["hero", "다녀오겠습니다."]])
	elif GameState.quest_stage == 2:
		GameState.quest_stage = 3
		GameState.gold += 100
		GameState.add_item("가죽 갑옷")
		_play_dialogue([
			[who_key, "무사히 돌아왔군. 정말 다행일세."],
			[who_key, "약속한 것일세. 100골드와 가죽 갑옷.\n부족하지만 받아 주게."]])
	elif GameState.quest_stage == 3:
		GameState.chapter = 2
		GameState.chapter_kills = 0
		GameState.quest_stage = 4
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("harbor")
		pending_map = "harbor"
		_play_dialogue(Story.CHAPTERS[2])
	elif GameState.quest_stage == 4:
		_play_dialogue([
			["captain", "성채로 가려면 잿빛 폐허를 지나야 한다."],
			["captain", "흑기사들은 말이 통하지 않아.\n베는 수밖에 없다."],
			["hero", "…그들도 원해서 저러는 건 아닐 겁니다."]])
	elif GameState.quest_stage == 5:
		GameState.chapter = 3
		GameState.chapter_kills = 0
		GameState.quest_stage = 6
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("frost_camp")
		pending_map = "frost_camp"
		_play_dialogue(Story.CHAPTERS[3])
	elif GameState.quest_stage == 7:
		GameState.chapter = 4
		GameState.chapter_kills = 0
		GameState.quest_stage = 8
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("abyss")
		pending_map = "abyss"
		_play_dialogue(Story.CHAPTERS[4])
	elif GameState.quest_stage == 9:
		# 예전엔 여기서 씬 전체를 ending.tscn으로 갈아엎어 게임이 끝나
		# 버렸다("최종보스 깨고 촌장 누르면 게임이 엔딩이 되어버린다"
		# 피드백). 스토리 클리어 후에도 탑 같은 엔드게임 콘텐츠를 계속
		# 해야 하니, 씬 전환 없이 마을에서 결말 대사만 보여주고 그대로
		# 이어서 플레이한다.
		GameState.complete_game($Player)
		_play_dialogue([
			[who_key, "자네가 이 땅을 구했네. 심연의 어둠은 걷혔어."],
			["", "최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, _mob("허나 아직 끝이 아닐세.\n심연의 탑이 남아 있다더군 - 지도(M)에서 들어가 보게.")],
		])
	elif GameState.quest_stage == 10:
		# 4장 클리어(complete_game) 이후 촌장에게 다시 말 걸면 5장(확장팩)이
		# 열린다. CHAPTER5_EXPANSION_DESIGN.md 1절: 탑 심층에서 균열을
		# 발견해 "유민의 땅"으로 떨어진다는 설정.
		GameState.chapter = 5
		GameState.chapter_kills = 0
		GameState.quest_stage = 11
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("remnant_village")
		pending_map = "remnant_village"
		_play_dialogue(Story.CHAPTERS[5])
	elif GameState.quest_stage == 19:
		# 5장 보스(태초의 심연) 처치 후 확장팩 결말.
		GameState.quest_stage = 20
		_play_dialogue([
			[who_key, "봉인이… 다시 굳게 닫혔군요."],
			["", "확장팩 최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "허나 파편은 어딘가로 흘러간 것 같습니다.\n바다 쪽에서 심상찮은 기운이 느껴진다는 소문이 있어요."],
		])
	elif GameState.quest_stage == 20:
		# 5장 클리어 후 촌장에게 다시 말 걸면 6장(파편의 바다)이 열린다.
		# CHAPTER6_10_MASTERPLAN.md 2절: 재봉인 후 흩어진 파편이 바다로
		# 가라앉았다는 설정.
		GameState.chapter = 6
		GameState.chapter_kills = 0
		GameState.quest_stage = 21
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("driftwood_pier")
		pending_map = "driftwood_pier"
		_play_dialogue(Story.CHAPTERS[6])
	elif GameState.quest_stage == 29:
		# 6장 보스(파수꾼의 유해) 처치 후 결말.
		GameState.quest_stage = 30
		_play_dialogue([
			[who_key, "파편들이… 다시 가라앉았구려."],
			["", "6장 최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "허나 이걸로 끝일 리 없소.\n더 오래된 무언가가 아직 남아 있다더이다."],
		])
	elif GameState.quest_stage == 30:
		# 6장 클리어 후 촌장에게 다시 말 걸면 7장(잊힌 성소)이 열린다.
		# CHAPTER6_10_MASTERPLAN.md 2절: 파편이 모여 오래전 무너진
		# 신전이 다시 빛을 낸다는 설정.
		GameState.chapter = 7
		GameState.chapter_kills = 0
		GameState.quest_stage = 31
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("lantern_village")
		pending_map = "lantern_village"
		_play_dialogue(Story.CHAPTERS[7])
	elif GameState.quest_stage == 39:
		# 7장 보스(빛바랜 사제왕) 처치 후 결말.
		GameState.quest_stage = 40
		_play_dialogue([
			[who_key, "빛이… 다시 잠잠해졌어요."],
			["", "7장 최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "신성조차 침식됐다면, 남은 곳은 얼마나 더 있을까요."],
		])
	elif GameState.quest_stage == 40:
		# 7장 클리어 후 촌장에게 다시 말 걸면 8장(침묵의 회랑)이 열린다.
		# CHAPTER6_10_MASTERPLAN.md 2절: 봉인을 지키던 최후의 수호
		# 기관 유적 -- 살아있는 정착민이 없어 마을 대신 무인 캠프로
		# 시작한다.
		GameState.chapter = 8
		GameState.chapter_kills = 0
		GameState.quest_stage = 41
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("waystation_camp")
		pending_map = "waystation_camp"
		_play_dialogue(Story.CHAPTERS[8])
	elif GameState.quest_stage == 49:
		# 8장 보스(말없는 감독관) 처치 후 결말.
		GameState.quest_stage = 50
		_play_dialogue([
			[who_key, "…적막이 걷혔어요."],
			["", "8장 최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "이 자들이 지키던 게… 대체 무엇이었을까요."],
		])
	elif GameState.quest_stage == 50:
		# 8장 클리어 후 다시 말 걸면 9장(역전의 탑)이 열린다.
		# CHAPTER6_10_MASTERPLAN.md 2절: 지나온 모든 곳의 잔향이 뒤섞여
		# 위아래·시간 순서가 뒤틀린 구조물 -- 마을 없이 캠프로 시작한다.
		GameState.chapter = 9
		GameState.chapter_kills = 0
		GameState.quest_stage = 51
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("rift_camp")
		pending_map = "rift_camp"
		_play_dialogue(Story.CHAPTERS[9])
	elif GameState.quest_stage == 61:
		_play_dialogue([[who_key, "근원으로 향할 준비가 되었네. 동쪽 문을 지나가게."]])
	elif GameState.quest_stage == 60:
		GameState.chapter = 10
		GameState.chapter_kills = 0
		GameState.quest_stage = 61
		GameState.boss_defeated = false
		boss_spawned = false
		GameState.unlock_map("origin_camp")
		pending_map = "origin_camp"
		_play_dialogue([[who_key, "역행자의 잔향이… 걷혔어요. 이제 근원으로 가셔야 해요."], ["hero", "모든 시작을 끝내겠습니다."]])
	elif GameState.quest_stage == 59:
		# 9장 보스(역행자) 처치 후 결말.
		GameState.quest_stage = 60
		_play_dialogue([
			[who_key, "…뒤틀린 시간이 풀렸어요."],
			["", "9장 최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "지나온 모든 잔향이… 걷혔네요. 이제 남은 건 근원뿐일까요."],
		])
	elif GameState.quest_stage == 69:
		# 10장(최종장) 보스(근원) 처치 후 결말. 10장 마을은 origin_camp
		# (근원의 야영지, 근원의 길 서쪽).
		GameState.quest_stage = 70
		_play_dialogue([
			[who_key, "…모든 기억이 제자리를 찾았어요."],
			["", "최종 기록\n레벨 %d   처치 %d   골드 %d" % [GameState.level, GameState.kills, GameState.gold]],
			[who_key, "근원이 잠들었으니 이제 정말 끝일까요.\n그래도 심연의 탑은 여전히 그대를 기다리고 있어요."],
		])
	elif GameState.bounty_done():
		var reward: Dictionary = GameState.claim_bounty()
		# 대화(불투명 전체 화면 창)가 상자 배너 자리를 덮으므로, 대화가
		# 끝난 뒤(after 콜백)에 띄운다 - 동시에 띄우면 대화 뒤에 숨어 안 보인다.
		_play_dialogue([[who_key, str(voice["bounty_done"]) % [
			reward["label"], int(reward["gold"]), reward["item"]]]],
			func(): _queue_level_reward_box(
				{"item": reward["item"], "gold": int(reward["gold"]), "quest_label": reward["label"]},
				"퀘스트 완료!"))
	elif not GameState.bounty_taken and not GameState.current_bounty().is_empty():
		var bounty: Dictionary = GameState.current_bounty()
		GameState.take_bounty()
		_play_dialogue([
			[who_key, str(bounty.get("desc", "의뢰가 있네."))],
			[who_key, "목표: %s\n보상: %d골드, %s" % [
				bounty["label"], int(bounty["gold"]), bounty["item"]]]])
	elif GameState.can_change_job() and GameState.job == "":
		# 레벨 15에 처음 도달하면 할 일(퀘스트·의뢰)이 없을 때 전직을 권한다.
		# 진행 중인 스토리·의뢰를 가로막지 않으려고 맨 마지막에 둔다.
		# 재전직은 캐릭터 화면(C)의 전직 탭에서 언제든 할 수 있다.
		dialogue_choice_after = _on_job_choice
		_play_dialogue([
			[who_key, str(voice["class_change"]), [
				["전사 - 강인한 근접 전투", "job_warrior"],
				["마법사 - 강력한 원소 마법", "job_mage"],
				["도적 - 빠른 연속 공격", "job_rogue"],
			]],
		])
	else:
		_play_dialogue([[who_key, str(voice["filler"])]])
	_update_quest_message()
	_update_stats()


## 그 사람의 잡담을 한 번씩 들려준다. 같은 진행도에서는 한 번만.
## 매번 들으면 성가시고, 한 번도 안 들으면 마을이 죽어 보인다.
var heard := {}


func _maybe_chatter(who: String) -> bool:
	var line: String = Story.chatter(who, GameState.quest_stage)
	if line == "":
		return false
	var key := "%s:%d" % [who, GameState.quest_stage]
	if heard.has(key):
		return false
	heard[key] = true
	var body: PackedStringArray = line.split("\n", true, 1)
	_play_dialogue([[who, body[1] if body.size() > 1 else line]])
	return true


## 여관. 골드를 내고 HP·마력을 채운다.
const INN_COST := 20


func _rest_at_inn() -> void:
	var player := $Player
	if player.health >= player.max_health and player.mana >= player.max_mana:
		_play_dialogue([["inn", "푹 쉬셨나 보네요. 지금은 쉴 필요 없어 보여요."]])
		return
	if GameState.gold < INN_COST:
		_play_dialogue([["inn", "하룻밤에 %d골드예요.\n골드가 모자라시네요." % INN_COST]])
		return
	GameState.gold -= INN_COST
	player.health = player.max_health
	player.mana = player.max_mana
	player.health_changed.emit(player.health, player.max_health)
	player.mana_changed.emit(player.mana, player.max_mana)
	Audio.play_sfx("potion")
	_update_stats()
	_play_dialogue([["inn", "%d골드 받았습니다.\n푹 주무셨죠? 몸이 개운할 거예요." % INN_COST]])


## 창고. 가방과 창고 사이로 물건을 옮긴다.
func _toggle_storage() -> void:
	storage_open = not storage_open
	Audio.play_sfx("accept" if storage_open else "cancel")
	$HUD/Storage.visible = storage_open
	$HUD/MobileControls.set_modal_mode("storage" if storage_open else "")
	get_tree().paused = storage_open
	_sync_modal_hud_visibility()
	if storage_open:
		storage_index = 0
		storage_side = "bag"
		_refresh_storage()


func _storage_list() -> Array[String]:
	return GameState.inventory if storage_side == "bag" else GameState.storage


func _storage_uid_list() -> Array[int]:
	return GameState.item_uid if storage_side == "bag" else GameState.storage_uid


func _refresh_storage() -> void:
	GameState.sync_uids()
	## 도움줄의 "넣기/꺼내기 버튼"과 버튼 글자를 맞춘다(옮기기라고 쓰여 있었다).
	$HUD/MobileControls.set_interact_label("넣기" if storage_side == "bag" else "꺼내기")
	var list := _storage_list()
	var uid_list := _storage_uid_list()
	storage_index = clampi(storage_index, 0, maxi(list.size() - 1, 0))
	# 4(원래 6, 07:55에 5로) - Notice/Help가 StatBar와 4px 여백을 확보하려면
	# Info.size.y가 더 줄어야 한다(INVENTORY_WINDOW/FORGE_WINDOW/SHOP_WINDOW와
	# 같은 이유) - Info.size.y(136px, 줄높이 17px) 안에 8줄(헤더 3 + 항목 4 +
	# 더 1)이 다 들어간다.
	const WINDOW := 4
	var start := clampi(storage_index - WINDOW / 2, 0, maxi(list.size() - WINDOW, 0))
	var tabs := "[가방]  창고" if storage_side == "bag" else " 가방  [창고]"
	var lines: Array[String] = []
	if list.is_empty():
		lines.append("   비어 있다.")
	for index in range(start, mini(start + WINDOW, list.size())):
		var item: String = list[index]
		var marker := "▶" if index == storage_index else "   "
		# 창고 쪽 물건은 애초에 착용 중일 수 없다(착용한 건 가방에만 있다).
		var worn := " [착용]" if (storage_side == "bag" and GameState.is_equipped_at(index)) else ""
		lines.append("%s %s%s" % [marker, GameState.item_label(item, uid_list[index]), worn])
	var more := _list_more_suffix(list.size(), start, WINDOW)
	$HUD/Storage/Info.text = "창고   가방 %d   창고 %d/%d\n%s\n──────────\n%s%s" % [
		GameState.inventory.size(), GameState.storage.size(), GameState.STORAGE_MAX,
		tabs, "\n".join(lines), more]
	$HUD/Storage/Help.text = _help("←→ 칸   ↑↓ 선택   E %s   I/Esc 닫기", "탭 가방↔창고   ▲▼ 선택   %s 버튼   ✕ 닫기") % (
		"넣기" if storage_side == "bag" else "꺼내기")


func _move_storage() -> void:
	var moved := GameState.store_item(storage_index) if storage_side == "bag" \
		else GameState.withdraw_item(storage_index)
	if moved:
		Audio.play_sfx("accept")
		$HUD/Storage/Notice.text = ""
	else:
		$HUD/Storage/Notice.text = "착용 중이거나 창고가 가득 찼다."
	_refresh_storage()


## 특성 선택. 레벨을 올릴 때마다 셋 중 하나를 고른다.
func _open_perk_choice() -> void:
	if GameState.perk_picks <= 0:
		return
	if GameState.perk_offer.is_empty():
		GameState.roll_perk_offer()
	perk_open = true
	perk_index = 0
	$HUD/Perk.visible = true
	$HUD/MobileControls.set_modal_mode("perk")
	get_tree().paused = true
	_sync_modal_hud_visibility()
	_refresh_perk()


func _refresh_perk() -> void:
	$HUD/Perk/Help.text = _help("↑↓ 선택   E 결정", "▲▼ 선택   결정 버튼 (줄 터치도 됨)")
	var offer := GameState.perk_offer
	perk_index = clampi(perk_index, 0, maxi(offer.size() - 1, 0))
	var lines: Array[String] = []
	for index in offer.size():
		var key: String = offer[index]
		var data: Dictionary = GameState.PERKS[key]
		var owned := int(GameState.perks.get(key, 0))
		var stack := "  (보유 %d)" % owned if owned > 0 else ""
		var marker := "▶" if index == perk_index else "   "
		lines.append("%s %s%s\n      %s" % [marker, data["name"], stack, data["desc"]])
	$HUD/Perk/Info.text = "레벨 %d 달성! 특성을 하나 고르자\n──────────\n%s" % [
		GameState.level, "\n".join(lines)]
	$HUD/MobileControls.set_interact_label("결정")


func _take_perk() -> void:
	var offer := GameState.perk_offer
	if offer.is_empty():
		return
	if GameState.take_perk(offer[perk_index]):
		Audio.play_sfx("levelup")
		_apply_equipment_to_player()
	perk_open = false
	$HUD/Perk.visible = false
	$HUD/MobileControls.set_modal_mode("")
	get_tree().paused = false
	_sync_modal_hud_visibility()
	# 남은 선택이 있으면 이어서 고른다.
	if GameState.perk_picks > 0:
		GameState.roll_perk_offer()
		_open_perk_choice()


## 특성 목록도 인벤토리와 같은 이유(_on_inventory_gui_input() 주석 참고)로
## 한 Label에 여러 줄을 그려 넣는 방식이라 HUD/Perk(ColorRect)의 gui_input으로
## 좌표를 항목 번호로 환산해 직접 선택한다. 골라야만 넘어가는 화면이라
## 폰에는 이 목록 탭과 Interact("결정") 버튼 말고는 넘어갈 방법이 없었다
## (2026-09-06 INBOX 결함 - 막다른 길).
func _on_perk_gui_input(event: InputEvent) -> void:
	if not perk_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var offer := GameState.perk_offer
	if offer.is_empty():
		return
	var info: Label = $HUD/Perk/Info
	var row := _tapped_list_row(info, tap_pos, PERK_LIST_START_LINE, offer.size(), PERK_LIST_LINES_PER_ROW)
	if row < 0:
		return
	get_viewport().set_input_as_handled()
	if row == perk_index:
		_take_perk()
	else:
		perk_index = row
		Audio.play_sfx("cancel")
		_refresh_perk()


func _open_shop() -> void:
	shop_open = true
	shop_index = 0
	shop_mode = "buy"
	Audio.play_sfx("accept")
	$HUD/Shop.visible = true
	$HUD/MobileControls.set_modal_mode("shop")
	get_tree().paused = true
	_sync_modal_hud_visibility()
	_refresh_shop()


## 여러 장면을 차례로 보여 준다. 한 장면은 [사람, 문장]이다.
var dialogue_pages: Array = []
var dialogue_page := 0
## 대화가 끝난 뒤 할 일. 장 전환처럼 이어지는 것이 있다.
var dialogue_after := Callable()
## 지금 장면의 선택지와 고르고 있는 줄.
var dialogue_choices: Array = []
var dialogue_choice := 0
var dialogue_choice_start := 0
const DIALOGUE_CHOICE_WINDOW := 3
## 선택지를 스토리 기록 대신 코드로 바로 처리하고 싶을 때 쓴다(부활 여부 등).
var dialogue_choice_after := Callable()


func _play_dialogue(pages: Array, after := Callable()) -> void:
	if pages.is_empty():
		if after.is_valid():
			after.call()
		return
	dialogue_pages = pages
	dialogue_page = 0
	dialogue_after = after
	dialogue_open = true
	Audio.play_sfx("accept")
	$HUD/Dialogue.visible = true
	$HUD/MobileControls.set_modal_mode("dialogue")
	$HUD/MobileControls.set_interact_label("대화")
	get_tree().paused = true
	_sync_modal_hud_visibility()
	_show_dialogue_page()


## 한 사람이 한 마디만 하는 흔한 경우.
func _open_dialogue(text: String, who := "") -> void:
	# 예전 형식("이름\n본문")도 받아 준다.
	var speaker := who
	var body := text
	if who == "" and text.contains("\n"):
		speaker = ""
		body = text
	_play_dialogue([[speaker, body]])


func _show_dialogue_page() -> void:
	var page: Array = dialogue_pages[dialogue_page]
	var who := str(page[0])
	# 세 번째 항목이 있으면 선택지 장면이다.
	dialogue_choices = page[2] if page.size() > 2 else []
	dialogue_choice = 0
	dialogue_choice_start = 0
	var face := Story.face_of(who)
	$HUD/Dialogue/Face.visible = face != "" and ResourceLoader.exists(face)
	if $HUD/Dialogue/Face.visible:
		$HUD/Dialogue/Face.texture = load(face)
	$HUD/Dialogue/Speaker.text = Story.name_of(who)
	$HUD/Dialogue/Text.text = str(page[1])
	_show_dialogue_choices()
	var last := dialogue_page >= dialogue_pages.size() - 1
	if not dialogue_choices.is_empty():
		$HUD/Dialogue/More.text = _help("↑↓ 고르기  E 결정", "▲▼ 고르기  대화 버튼 결정")
	else:
		$HUD/Dialogue/More.text = _help("E 닫기" if last else "E 다음  ▼", "대화 버튼 닫기" if last else "대화 버튼 다음  ▼")
	# 얼굴이 없으면 글을 왼쪽 끝까지 쓴다. 나레이션이 넓게 보인다.
	var left := 50.0 if $HUD/Dialogue/Face.visible else 10.0
	$HUD/Dialogue/Text.offset_left = left
	$HUD/Dialogue/Speaker.offset_left = left
	$HUD/Dialogue/Choices.offset_left = left


func _show_dialogue_choices() -> void:
	$HUD/Dialogue/Choices.visible = not dialogue_choices.is_empty()
	if dialogue_choices.is_empty():
		$HUD/MobileControls.set_modal_mode("dialogue")
		# 선택지가 없으면 글이 아래까지 내려온다.
		$HUD/Dialogue/Text.offset_bottom = 78.0
		$HUD/Dialogue/More.text = ""
		return
	# 선택지 자리를 비우려고 글을 위로 줄인다.
	$HUD/Dialogue/Text.offset_bottom = 58.0
	var visible_count := mini(DIALOGUE_CHOICE_WINDOW, dialogue_choices.size())
	if dialogue_choice < dialogue_choice_start:
		dialogue_choice_start = dialogue_choice
	elif dialogue_choice >= dialogue_choice_start + visible_count:
		dialogue_choice_start = dialogue_choice - visible_count + 1
	var end := mini(dialogue_choice_start + visible_count, dialogue_choices.size())
	var lines: Array[String] = []
	for index in range(dialogue_choice_start, end):
		var marker := "▶" if index == dialogue_choice else "   "
		lines.append("%s %s" % [marker, dialogue_choices[index][0]])
	$HUD/Dialogue/Choices.text = "\n".join(lines)
	var hint := "↑ 더 있음  " if dialogue_choice_start > 0 else ""
	if end < dialogue_choices.size():
		hint += "↓ 더 있음"
	$HUD/Dialogue/More.text = hint
	$HUD/MobileControls.set_modal_mode("dialogue")


func _move_dialogue_choice(step: int) -> void:
	if dialogue_choices.is_empty():
		return
	dialogue_choice = wrapi(dialogue_choice + step, 0, dialogue_choices.size())
	Audio.play_sfx("cancel")
	_show_dialogue_choices()


## 고른 답을 기록하고 보상이 있으면 준다.
func _confirm_dialogue_choice() -> void:
	var picked := str(dialogue_choices[dialogue_choice][1])
	dialogue_choices = []
	Audio.play_sfx("accept")
	if dialogue_choice_after.is_valid():
		var after := dialogue_choice_after
		dialogue_choice_after = Callable()
		_close_dialogue()
		after.call(picked)
		return
	GameState.remember_choice(picked)
	var reward: Dictionary = Story.CHOICE_REWARD.get(picked, {})
	if not reward.is_empty():
		GameState.add_item(str(reward["item"]))
		$HUD/Message.text = str(reward["note"])
	if dialogue_page < dialogue_pages.size() - 1:
		dialogue_page += 1
		_show_dialogue_page()
	else:
		_close_dialogue()


func _advance_dialogue() -> void:
	if not dialogue_choices.is_empty():
		_confirm_dialogue_choice()
		return
	if dialogue_page < dialogue_pages.size() - 1:
		dialogue_page += 1
		Audio.play_sfx("cancel")
		_show_dialogue_page()
		return
	_close_dialogue()


func _close_dialogue() -> void:
	dialogue_open = false
	Audio.play_sfx("cancel")
	dialogue_pages = []
	dialogue_choices = []
	$HUD/Dialogue.visible = false
	$HUD/MobileControls.set_modal_mode("")
	get_tree().paused = false
	_sync_modal_hud_visibility()
	_update_quest_message()
	if dialogue_after.is_valid():
		var after := dialogue_after
		dialogue_after = Callable()
		after.call()
	if pending_map != "":
		var next_map := pending_map
		pending_map = ""
		_change_map(next_map, true, _west_spawn(next_map))


func _toggle_inventory() -> void:
	menu_open = not menu_open
	Audio.play_sfx("accept" if menu_open else "cancel")
	$HUD/Inventory.visible = menu_open
	$HUD/MobileControls.set_modal_mode("inventory" if menu_open else "")
	get_tree().paused = menu_open
	_sync_modal_hud_visibility()
	if menu_open:
		inventory_index = clampi(inventory_index, 0, maxi(GameState.inventory.size() - 1, 0))
		_refresh_inventory()


func _close_shop() -> void:
	shop_open = false
	$HUD/Shop.visible = false
	$HUD/MobileControls.set_modal_mode("")
	get_tree().paused = false
	_sync_modal_hud_visibility()


func set_pause_open(open: bool) -> void:
	pause_open = open
	$HUD/Pause.visible = open
	$HUD/MobileControls.set_modal_mode("pause" if open else "")
	get_tree().paused = open
	_sync_modal_hud_visibility()
	if open:
		_refresh_pause_info()


## 캐릭터 화면. 레벨업으로 받은 점수를 능력치에 넣는다.
## 대장간. 가진 장비를 강화석과 골드로 한 단계씩 올린다.
func _toggle_forge() -> void:
	forge_open = not forge_open
	Audio.play_sfx("accept" if forge_open else "cancel")
	$HUD/Forge.visible = forge_open
	$HUD/MobileControls.set_modal_mode("forge" if forge_open else "")
	get_tree().paused = forge_open
	_sync_modal_hud_visibility()
	if forge_open:
		forge_index = 0
		forge_mode = "enhance"
		_refresh_forge()


## 인벤토리 칸 번호(인덱스)를 준다 - 이름만 주면 같은 이름 여분 장비를
## 강화/소켓할 때 어느 칸인지 구분할 수 없다.
func _forge_items() -> Array[int]:
	var list: Array[int] = []
	for i in GameState.inventory.size():
		if GameState.EQUIPMENT.has(GameState.inventory[i]):
			list.append(i)
	return list


func _forge_tabs_text() -> String:
	var labels := {"enhance": "강화", "socket": "소켓", "craft": "제작", "reroll": "옵션"}
	var parts: Array[String] = []
	for mode in FORGE_MODES:
		parts.append("[%s]" % labels[mode] if mode == forge_mode else labels[mode])
	return "  ".join(parts)


## 강화 탭(강화/소켓/제작) 전환. 키보드 ←→ 와 모바일 Sell("탭") 버튼
## (mobile_controls.gd _toggle_shop_tab)이 이 한 함수로 모인다(2026-09-06
## INBOX 결함 - 탭 전환이 ←→ 키만 있었다).
func _cycle_forge_mode(step: int) -> void:
	forge_mode = FORGE_MODES[wrapi(FORGE_MODES.find(forge_mode) + step, 0, FORGE_MODES.size())]
	Audio.play_sfx("cancel")
	_refresh_forge()


func _refresh_forge() -> void:
	GameState.sync_uids()
	$HUD/Forge/Help.text = _help("↑↓ 선택   ←→ 탭 전환\nE 강화   Z 확정   1-9 소켓   I/Esc 닫기", "▲▼ 선택   탭 전환\n강화 버튼   확정 버튼   소켓 줄 터치   ✕ 닫기")
	$HUD/MobileControls.set_forge_guaranteed_visible(forge_mode == "enhance")
	if forge_mode == "craft":
		_refresh_forge_craft()
		return
	# 소켓 탭은 숫자키로 마법돌을 고르는 방식이라 확정 동작이 없다 -
	# 모바일 확인 버튼을 아예 숨긴다(눌러도 하는 일이 없는 버튼을 없앰).
	var confirm_labels := {"enhance": "강화", "reroll": "재굴림"}
	$HUD/MobileControls.set_interact_label(str(confirm_labels.get(forge_mode, "")), confirm_labels.has(forge_mode))
	var items := _forge_items()
	forge_index = clampi(forge_index, 0, maxi(items.size() - 1, 0))
	var start := clampi(forge_index - FORGE_WINDOW / 2, 0, maxi(items.size() - FORGE_WINDOW, 0))
	var lines: Array[String] = []
	if items.is_empty():
		lines.append("   손볼 장비가 없다.")
	for pos in range(start, mini(start + FORGE_WINDOW, items.size())):
		var idx: int = items[pos]
		var marker := "▶" if pos == forge_index else "   "
		lines.append("%s %s" % [marker, GameState.item_label(GameState.inventory[idx], GameState.item_uid[idx])])
	# 강화석/GOLD/부적 세 값을 한 줄로 합쳤다("파괴 방지 부적"의 줄임말) -
	# "… N개 더" 줄이 늘어난 만큼 헤더에서 한 줄을 아껴야 8줄 안에 들어간다
	# (감독 2026-09-06 07:55). 최악 값(재료 999·골드 999999·부적 9)에서도
	# 140px로 패널 폭 150px 안에 든다(check_forge_info_clip.gd로 확인).
	var more := _list_more_suffix(items.size(), start, FORGE_WINDOW)
	$HUD/Forge/Info.text = "대장간   %s\n강화석 %d   GOLD %d   부적 %d개\n──────────\n%s%s" % [
		_forge_tabs_text(), GameState.materials[GameState.MATERIAL], GameState.gold, GameState.enhance_wards, "\n".join(lines), more]

	if items.is_empty():
		$HUD/Forge/Detail.text = ""
		$HUD/Forge/Icon.visible = false
		return
	var selected_idx: int = items[forge_index]
	var selected: String = GameState.inventory[selected_idx]
	var selected_uid: int = GameState.item_uid[selected_idx]
	$HUD/Forge/Icon.visible = true
	$HUD/Forge/Icon.texture = _item_icon(selected)
	if forge_mode == "enhance":
		_refresh_forge_enhance(selected, selected_uid)
	elif forge_mode == "reroll":
		_refresh_forge_reroll(selected, selected_uid)
	else:
		_refresh_forge_socket(selected, selected_uid)
	$HUD/Forge/Detail.modulate = GameState.display_color(selected)


## 제작은 가진 장비가 아니라 정해진 레시피 목록을 고르는 화면이라
## _forge_items() 대신 레시피 표를 그대로 목록으로 쓴다. 보스 파편
## 세트(용기사)와 탑 전용 "초월" 세트(20종) 레시피를 한 목록에 합친다.
func _craft_recipe_list() -> Array:
	return GameState.CRAFT_RECIPES.keys() + GameState.CHAPTER_CRAFT_RECIPES.keys() + GameState.TOWER_CRAFT_RECIPES.keys()


func _refresh_forge_craft() -> void:
	$HUD/MobileControls.set_interact_label("제작")
	var recipes := _craft_recipe_list()
	craft_index = clampi(craft_index, 0, maxi(recipes.size() - 1, 0))
	var start := clampi(craft_index - FORGE_WINDOW / 2, 0, maxi(recipes.size() - FORGE_WINDOW, 0))
	var lines: Array[String] = []
	for index in range(start, mini(start + FORGE_WINDOW, recipes.size())):
		var marker := "▶" if index == craft_index else "   "
		lines.append("%s %s" % [marker, recipes[index]])
	var more := _list_more_suffix(recipes.size(), start, FORGE_WINDOW)
	$HUD/Forge/Info.text = "대장간   %s\n파편 %d   강화석 %d   GOLD %d\n──────────\n%s%s" % [
		_forge_tabs_text(), GameState.materials[GameState.BOSS_FRAGMENT],
		GameState.materials[GameState.MATERIAL], GameState.gold, "\n".join(lines), more]

	if recipes.is_empty():
		$HUD/Forge/Detail.text = ""
		$HUD/Forge/Icon.visible = false
		return
	var item: String = recipes[craft_index]
	$HUD/Forge/Icon.visible = true
	$HUD/Forge/Icon.texture = _item_icon(item)
	var enough := GameState.can_craft(item)
	if GameState.CRAFT_RECIPES.has(item):
		var cost: Dictionary = GameState.CRAFT_RECIPES[item]
		var area_item_name := str(cost.get("area_item", ""))
		var area_line := ""
		if area_item_name != "":
			area_line = "   %s %s" % [area_item_name, "✓" if GameState.inventory.has(area_item_name) else "✗(필요)"]
		$HUD/Forge/Detail.text = "%s\n\n필요: 보스의 파편 %d   강화석 %d   %dG%s%s" % [
			GameState.item_summary(item, 0), int(cost["fragments"]), int(cost["stones"]), int(cost["gold"]),
			area_line, "" if enough else "\n(재료 부족)"]
	elif GameState.CHAPTER_CRAFT_RECIPES.has(item):
		var cost: Dictionary = GameState.CHAPTER_CRAFT_RECIPES[item]
		var essence := GameState.chapter_essence(int(cost["chapter"]))
		$HUD/Forge/Detail.text = "%s\n\n필요: %s %d/%d\n보스의 파편 %d   강화석 %d   %dG%s" % [
			GameState.item_summary(item, 0), essence, int(GameState.materials.get(essence, 0)), int(cost["essence"]),
			int(cost["fragments"]), int(cost["stones"]), int(cost["gold"]), "" if enough else "\n(재료 부족)"]
	else:
		var cost: Dictionary = GameState.TOWER_CRAFT_RECIPES[item]
		var tier := str(cost["tier"])
		var needs: Dictionary = cost["needs"]
		var need_parts: Array[String] = []
		for need_tier in needs:
			var mat_name := GameState.tower_material_name(str(need_tier))
			var have: int = int(GameState.tower_material_counts.get(need_tier, 0))
			need_parts.append("%s %d/%d" % [mat_name, have, int(needs[need_tier])])
		var lock_line := ""
		if not GameState.tower_tier_unlocked(tier):
			lock_line = "\n(%s 탑 해금 필요)" % str(GameState.TOWER_TIERS.get(tier, {}).get("name", tier))
		$HUD/Forge/Detail.text = "%s\n\n필요: %s\n강화석 %d   %dG%s%s" % [
			GameState.item_summary(item, 0), ", ".join(need_parts), int(cost["stones"]), int(cost["gold"]),
			lock_line, "" if enough else "\n(재료 부족)"]
	$HUD/Forge/Detail.modulate = GameState.display_color(item)


func _do_craft() -> void:
	var recipes := _craft_recipe_list()
	if recipes.is_empty():
		return
	var item: String = recipes[craft_index]
	if GameState.craft(item):
		Audio.play_sfx("accept")
		$HUD/Forge/Notice.text = "%s 제작 완료!" % item
	else:
		Audio.play_sfx("cancel")
	_refresh_forge()


## 키보드 interact와 터치/클릭 확정(_on_forge_gui_input)이 같은 동작을
## 하도록 공용으로 뺐다(인벤토리 _activate_selected_inventory_item()과 같은
## 이유). 소켓 탭은 확정이 아니라 숫자키로 마법돌을 고르는 방식이라 여기서는
## 아무것도 하지 않는다 - 키보드 interact 분기도 원래 그랬다.
func _activate_selected_forge_item() -> void:
	if forge_mode == "enhance":
		_do_enhance()
	elif forge_mode == "craft":
		_do_craft()
	elif forge_mode == "reroll":
		_do_reroll()


## 옵션 탭(감독 2026-09-08). 드랍 랜덤 옵션을 골드+강화석으로 다시 굴린다.
func _refresh_forge_reroll(selected: String, uid: int) -> void:
	var cost := GameState.reroll_cost(selected)
	$HUD/Forge/Detail.text = "%s\n\n옵션 재굴림   강화석 %d   %dG\n기존 ✦ 옵션은 사라지고\n새 옵션 1~3줄이 붙는다." % [
		GameState.item_summary(selected, uid), int(cost["stones"]), int(cost["gold"])]


func _do_reroll() -> void:
	GameState.sync_uids()
	var items := _forge_items()
	if items.is_empty():
		return
	var idx: int = items[forge_index]
	var item: String = GameState.inventory[idx]
	var uid: int = GameState.item_uid[idx]
	if GameState.reroll_affixes(item, uid):
		Audio.play_sfx("levelup")
		$HUD/Forge/Notice.text = "%s 옵션 재굴림!" % GameState.item_label(item, uid)
		_apply_equipment_to_player()
	else:
		Audio.play_sfx("cancel")
		$HUD/Forge/Notice.text = "강화석이나 골드가 부족하다."
	_refresh_forge()


## 목록형 창(인벤토리/창고/강화/상점)이 window 칸을 넘칠 때 마지막 줄에
## "… N개 더"를 붙인다. 넘치지 않으면 빈 문자열(감독 2026-09-06 07:55 —
## 창고 창에서 이 표기가 빠져 8개 중 6개만 보이고 나머지가 안 보였다).
func _list_more_suffix(count: int, start: int, window: int) -> String:
	return "\n   … %d개 더" % (count - start - window) if count > start + window else ""


## 창(인벤토리/강화/상점/특성) 목록에서 탭 좌표가 몇 번째 목록 항목(0부터)에
## 해당하는지 계산한다. 밖이면 -1. Label이 실제로 그리는 줄 간격은
## 글꼴 높이(get_line_height())만이 아니라 테마 상수 line_spacing(기본
## 3px)까지 더한 값이라, 이걸 빼먹으면 헤더 줄 수가 쌓일수록 오차가
## 누적돼 실제로 누른 줄보다 아래 줄이 골라진다(INBOX 2026-09-05 결함).
## lines_per_row: 항목 하나가 화면 줄 몇 개를 쓰는지(인벤토리/강화/상점은 1,
## 특성 선택(Perk)은 이름+설명 2줄 - _refresh_perk() 포맷 참고).
func _tapped_list_row(info: Label, tap_pos: Vector2, list_start_line: int, window: int, lines_per_row: int = 1) -> int:
	var local_in_info: Vector2 = tap_pos - info.position
	if local_in_info.x < 0 or local_in_info.y < 0 or local_in_info.x > info.size.x:
		return -1
	var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
	if line_height <= 0:
		return -1
	var line_index := int(local_in_info.y / line_height)
	var line_row := line_index - list_start_line
	if line_row < 0:
		return -1
	var row := line_row / lines_per_row
	if row >= window:
		return -1
	return row


## 안내문은 데스크톱(키 이름)과 모바일(버튼 이름)이 다르다. 가이드가 이미 쓰던
## 기준($HUD/MobileControls.visible)을 한 곳에 모았다(감독 2026-09-09).
func _help(desktop: String, mobile: String) -> String:
	return mobile if $HUD/MobileControls.visible else desktop


## 퀘스트 안내·메시지·가이드에 박힌 키 이름을 모바일 버튼 이름으로 바꾼다.
func _mob(text: String) -> String:
	if not $HUD/MobileControls.visible:
		return text
	return text.replace("M키 지도로", "이동주문서로").replace("E키로", "대화 버튼으로") \
		.replace("(C키에서 고르기)", "(메뉴 캐릭 탭)").replace("(C키)", "(메뉴 캐릭 탭)") \
		.replace("지도(M)", "이동주문서").replace("Z키:", "확정 버튼:")


## 대화 선택지 줄 터치: 첫 터치는 고르기, 고른 줄을 다시 터치하면 결정.
func _on_dialogue_gui_input(event: InputEvent) -> void:
	if not dialogue_open or dialogue_choices.is_empty():
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var visible_count := mini(DIALOGUE_CHOICE_WINDOW, dialogue_choices.size())
	var row := _tapped_list_row($HUD/Dialogue/Choices, event.position, 0, visible_count)
	if row < 0:
		return
	var index := dialogue_choice_start + row
	if index == dialogue_choice:
		_advance_dialogue()
	else:
		dialogue_choice = index
		Audio.play_sfx("cancel")
		_show_dialogue_choices()
	get_viewport().set_input_as_handled()


func _switch_storage_side(side: String) -> void:
	storage_side = side
	storage_index = 0
	Audio.play_sfx("cancel")
	_refresh_storage()


## 대장간 목록도 인벤토리와 같은 이유로 한 Label에 여러 줄을 그려 넣는
## 방식이라(_on_inventory_gui_input() 주석 참고) HUD/Forge(ColorRect)의
## gui_input으로 좌표를 줄 번호로 환산해 직접 선택한다.
func _on_forge_gui_input(event: InputEvent) -> void:
	if not forge_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var count := (_craft_recipe_list().size() if forge_mode == "craft" else _forge_items().size())
	if count == 0:
		return
	var info: Label = $HUD/Forge/Info
	var row := _tapped_list_row(info, tap_pos, FORGE_LIST_START_LINE, FORGE_WINDOW)
	if row < 0:
		return
	var current_index := craft_index if forge_mode == "craft" else forge_index
	var start := clampi(current_index - FORGE_WINDOW / 2, 0, maxi(count - FORGE_WINDOW, 0))
	var tapped_pos := start + row
	if tapped_pos >= count:
		return
	get_viewport().set_input_as_handled()
	if tapped_pos == current_index:
		_activate_selected_forge_item()
	else:
		if forge_mode == "craft":
			craft_index = tapped_pos
		else:
			forge_index = tapped_pos
		Audio.play_sfx("cancel")
		_refresh_forge()


func _refresh_forge_enhance(selected: String, uid: int) -> void:
	var step := GameState.enhance_of(selected, uid)
	if step >= GameState.MAX_ENHANCE:
		$HUD/Forge/Detail.text = "%s\n\n최대 강화 단계다." % GameState.item_summary(selected, uid)
		return
	var cost := GameState.enhance_cost(selected, uid)
	var chance := GameState.enhance_chance(selected, uid) * 100.0
	var risk_line: String
	if GameState.enhance_is_risky(selected, uid):
		if GameState.enhance_wards <= 0:
			risk_line = "⚠ 파괴 방지 부적이 없다! 실패하면 파괴된다 (파괴 확률 %d%%)" % int(GameState.ENHANCE_DESTROY_CHANCE * 100.0)
		else:
			risk_line = "실패하면 파괴 위험 %d%%  (부적 %d개, 실패 시 자동 소모)" % [
				int(GameState.ENHANCE_DESTROY_CHANCE * 100.0), GameState.enhance_wards]
	else:
		risk_line = "실패해도 파괴되지 않는다(하락만)"
	var guaranteed_cost := GameState.enhance_guaranteed_cost(selected, uid)
	$HUD/Forge/Detail.text = "%s\n+%d → +%d   성공 %d%%\n강화석 %d   %dG\n%s\n──────────\n확정강화(실패 없음)   강화석 %d   %dG" % [
		GameState.item_summary(selected, uid), step, step + 1, int(round(chance)),
		int(cost["stones"]), int(cost["gold"]), risk_line,
		int(guaranteed_cost["stones"]), int(guaranteed_cost["gold"])]


## 지금 갖고 있는 마법돌 목록. 순서가 곧 숫자키 순서라 항상 같은 순서로 준다.
func _owned_stones() -> Array[String]:
	var out: Array[String] = []
	for stone_id in GameState.STONES:
		if int(GameState.stone_inventory.get(stone_id, 0)) > 0:
			out.append(str(stone_id))
	return out


func _refresh_forge_socket(selected: String, uid: int) -> void:
	var total := GameState.socket_count(selected)
	if total <= 0:
		$HUD/Forge/Detail.text = "%s\n\n일반 등급은 소켓이 없다." % GameState.item_summary(selected, uid)
		return
	var owned := _owned_stones()
	var stone_lines: Array[String] = []
	if owned.is_empty():
		stone_lines.append("   가진 마법돌이 없다.")
	else:
		for index in owned.size():
			var stone_id: String = owned[index]
			var data: Dictionary = GameState.STONES[stone_id]
			stone_lines.append("%d. %s x%d" % [index + 1, data["name"], int(GameState.stone_inventory[stone_id])])
	$HUD/Forge/Detail.text = "%s\n\n소켓 %d/%d\n\n숫자키·줄 탭으로 박기\n%s" % [
		GameState.item_summary(selected, uid), GameState.sockets_used(selected, uid), total, "\n".join(stone_lines)]


## 소켓 탭의 마법돌 목록은 숫자키 전용이라 폰에서는 돌을 박을 길이 없었다
## (감독 2026-09-08). Detail 라벨의 돌 줄을 탭하면 그 번호 숫자키와 같게
## 박는다. 돌 줄은 항상 라벨의 마지막 N줄이라 (탭한 줄 - (전체 줄 - N))이
## 돌 번호다. 위치는 라벨 로컬 좌표(gui_input). 에뮬레이션 마우스는
## 뒤따르는 ScreenTouch 와 중복이라 버린다(_on_forge_gui_input 과 동일).
func _on_forge_detail_gui_input(event: InputEvent) -> void:
	if not forge_open or forge_mode != "socket" or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	var detail: Label = $HUD/Forge/Detail
	var line_height := detail.get_line_height() + detail.get_theme_constant("line_spacing")
	if line_height <= 0:
		return
	var owned := _owned_stones()
	var stone := int(event.position.y / line_height) - (detail.get_line_count() - owned.size())
	if stone < 0 or stone >= owned.size():
		return
	get_viewport().set_input_as_handled()
	_do_socket(stone)


func _do_socket(list_index: int) -> void:
	GameState.sync_uids()
	var items := _forge_items()
	if items.is_empty():
		return
	var idx: int = items[forge_index]
	var item: String = GameState.inventory[idx]
	var uid: int = GameState.item_uid[idx]
	var owned := _owned_stones()
	if list_index < 0 or list_index >= owned.size():
		return
	var stone_id: String = owned[list_index]
	if GameState.insert_stone(item, stone_id, uid):
		Audio.play_sfx("levelup")
		$HUD/Forge/Notice.text = "%s 에 %s 을(를) 박았다." % [GameState.item_label(item, uid), GameState.STONES[stone_id]["name"]]
		_apply_equipment_to_player()
	else:
		$HUD/Forge/Notice.text = "소켓이 꽉 찼거나 이 등급엔 소켓이 없다."
	_refresh_forge()


func _do_enhance() -> void:
	GameState.sync_uids()
	var items := _forge_items()
	if items.is_empty():
		return
	var idx: int = items[forge_index]
	var item: String = GameState.inventory[idx]
	var uid: int = GameState.item_uid[idx]
	match GameState.enhance(item, uid):
		"success":
			Audio.play_sfx("levelup")
			$HUD/Forge/Notice.text = "%s 강화 성공!" % GameState.item_label(item, uid)
			_apply_equipment_to_player()
			if GameState.enhance_of(item, uid) >= GameState.MAX_ENHANCE:
				_spawn_max_enhance_fx()
		"fail":
			Audio.play_sfx("cancel")
			$HUD/Forge/Notice.text = "강화 실패... %s (으)로 내려갔다." % GameState.item_label(item, uid)
			_apply_equipment_to_player()
		"warded":
			Audio.play_sfx("cancel")
			$HUD/Forge/Notice.text = "강화 실패했지만 부적으로 파괴는 막았다. %s" % GameState.item_label(item, uid)
			_apply_equipment_to_player()
		"destroyed":
			Audio.play_sfx("hurt")
			$HUD/Forge/Notice.text = "강화 실패... %s 이(가) 산산조각났다." % item
			_apply_equipment_to_player()
		"blocked":
			if GameState.enhance_of(item, uid) >= GameState.MAX_ENHANCE:
				$HUD/Forge/Notice.text = "더 올릴 수 없다."
			else:
				$HUD/Forge/Notice.text = "강화석이나 골드가 모자라다."
	_refresh_forge()


## 확정 강화. 실패·파괴 없이 강화석(+골드)만 더 내고 무조건 성공한다.
## "강화가 너무 어렵다, 확률 없이 강화석을 더 내면 되는 방법도 있어야
## 한다"는 사용자 요청으로 추가했다.
func _do_enhance_guaranteed() -> void:
	GameState.sync_uids()
	var items := _forge_items()
	if items.is_empty():
		return
	var idx: int = items[forge_index]
	var item: String = GameState.inventory[idx]
	var uid: int = GameState.item_uid[idx]
	match GameState.enhance_guaranteed(item, uid):
		"success":
			Audio.play_sfx("levelup")
			$HUD/Forge/Notice.text = "%s 확정 강화 성공!" % GameState.item_label(item, uid)
			_apply_equipment_to_player()
			if GameState.enhance_of(item, uid) >= GameState.MAX_ENHANCE:
				_spawn_max_enhance_fx()
		"blocked":
			if GameState.enhance_of(item, uid) >= GameState.MAX_ENHANCE:
				$HUD/Forge/Notice.text = "더 올릴 수 없다."
			else:
				$HUD/Forge/Notice.text = "확정 강화에 필요한 강화석이나 골드가 모자라다."
	_refresh_forge()


## 최대 강화(+10) 달성 순간 캐릭터 위에서 반짝이는 이펙트를 터뜨린다.
## 대장간 창이 열려 게임은 멈춰 있지만 파티클은 PROCESS_MODE_ALWAYS라
## 바로 재생되고, 창을 닫으면 남은 반짝임이 이어서 보인다.
func _spawn_max_enhance_fx() -> void:
	var fx: Node2D = preload("res://scenes/enhance_fx.tscn").instantiate()
	fx.global_position = $Player.global_position + Vector2(0, -10)
	$World.add_child(fx)


func _toggle_character() -> void:
	character_open = not character_open
	Audio.play_sfx("accept" if character_open else "cancel")
	$HUD/Character.visible = character_open
	$HUD/MobileControls.set_modal_mode("character" if character_open else "")
	get_tree().paused = character_open
	_sync_modal_hud_visibility()
	if character_open:
		# 화면과 HUD가 같은 값을 보이도록 열 때 한 번 다시 계산한다.
		_apply_equipment_to_player()
		_refresh_character()


## 스킬 이름·마력·재사용 대기시간·설명을 한 화면에서 본다. 스킬바 아이콘만
## 봐서는 뭘 하는 스킬인지 알 수 없다는 지적이 있었다.
func _toggle_skills() -> void:
	skills_open = not skills_open
	Audio.play_sfx("accept" if skills_open else "cancel")
	$HUD/Skills.visible = skills_open
	$HUD/MobileControls.set_modal_mode("skills" if skills_open else "")
	get_tree().paused = skills_open
	_sync_modal_hud_visibility()
	if skills_open:
		_refresh_skills()


func _refresh_skills() -> void:
	var job_label: String = GameState.JOB_NAMES.get(GameState.job, "무직")
	if GameState.second_job != "":
		job_label = "%s(%s)" % [job_label, GameState.second_job]
	$HUD/Skills/Title.text = "스킬 - %s" % job_label
	var total := GameState.active_skills().size()
	$HUD/Skills/Help.text = _help("1~%d 스킬 사용   ←→ 캐릭터 창   K/Esc 닫기", "하단 %d칸 스킬 사용   탭 캐릭터 창   ✕ 닫기") % total
	for index in 6:
		if not $HUD/Skills.has_node("Row%d" % index):
			continue
		var row := $HUD/Skills.get_node("Row%d" % index)
		if index >= total:
			row.visible = false
			continue
		row.visible = true
		var data: Dictionary = GameState.active_skills()[index]
		var unlocked := GameState.skill_unlocked(index)
		var icon: TextureRect = row.get_node("Icon")
		# 전직하면 스킬 자체가 바뀌는데 아이콘 그림은 그대로였다("K 설명창
		# 아이콘이 안 바뀐다" 피드백) - 스킬바(_update_skill_bar)에만 있던
		# 아이콘 갱신 로직이 여기 빠져 있었다. 캐시 방식도 그쪽과 맞춘다.
		if icon.get_meta("icon_path", "") != str(data["icon"]):
			icon.set_meta("icon_path", str(data["icon"]))
			icon.texture = load(str(data["icon"]))
		icon.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0.3)
		if unlocked:
			var cost_line := "HP %d%% 소모" % int(float(data.get("hp_cost_pct", 0.0)) * 100) if data.has("hp_cost_pct") else "마력 %d" % int(data["cost"])
			row.get_node("Text").text = "%d. %s   %s   재사용 %.1f초\n%s" % [
				index + 1, data["name"], cost_line, float(data["cooldown"]), data["desc"]]
		else:
			row.get_node("Text").text = "%d. %s   (레벨 %d 필요)" % [index + 1, data["name"], int(data["level"])]


## 퀘스트 현황. 위 한 줄 문구로는 의뢰 보상까지 안 보여서 따로 화면을 둔다.
func _toggle_quest() -> void:
	quest_open = not quest_open
	Audio.play_sfx("accept" if quest_open else "cancel")
	$HUD/Quest.visible = quest_open
	$HUD/MobileControls.set_modal_mode("quest" if quest_open else "")
	get_tree().paused = quest_open
	_sync_modal_hud_visibility()
	if quest_open:
		_refresh_quest()


func _refresh_quest() -> void:
	$HUD/Quest/Help.text = _help("[ ] 다른 탭   B/Esc 닫기", "위 탭줄 다른 창   ✕ 닫기")
	var bounty := GameState.current_bounty()
	var bounty_text: String
	if bounty.is_empty():
		bounty_text = "더 받을 수 있는 의뢰가 없다."
	elif not GameState.bounty_taken:
		bounty_text = "촌장에게 가서 받자: %s\n보상 %d골드, %s" % [
			bounty["label"], int(bounty["gold"]), bounty["item"]]
	else:
		bounty_text = "%s\n보상 %d골드, %s" % [
			GameState.bounty_progress_text(), int(bounty["gold"]), bounty["item"]]
	$HUD/Quest/Info.text = "퀘스트 현황\n──────────\n[이야기]\n%s\n\n[의뢰]\n%s" % [
		_mob(_quest_stage_text()), bounty_text]


## 강화·소켓·세트·정령 인장을 한 곳에서 설명하는 가이드. 게임 안에서
## 물어볼 사람이 없으니 규칙을 직접 화면에 적어 둔다. ←→ 로 쪽을 넘긴다.
const GUIDE_PAGE_COUNT := 18


func _guide_jobs_lines(job_ids: Array) -> String:
	var lines: Array[String] = []
	for job_id in job_ids:
		var skills: Array = GameState.SKILLS_BY_JOB[job_id]
		var skill_lines: Array[String] = []
		for skill in skills:
			skill_lines.append("%s(Lv%d): %s" % [skill["name"], int(skill["level"]), skill["desc"]])
		lines.append("[%s]\n%s" % [GameState.JOB_NAMES[job_id], " / ".join(skill_lines)])
	return "\n".join(lines)


## 8px 글꼴로 되돌리며(INBOX 17:50 보정) 안내문 4줄 + 직업 3개 스킬
## 설명이 한 페이지에 안 들어가 안내줄과 겹쳤다. 둘로 나눴다.
func _guide_page_jobs1() -> String:
	return "[직업·전직 1/2]\n레벨 %d부터 캐릭터창(C키) → 전직 탭에서 선택한다.\n처음 전직은 무료, 재전직 비용은 레벨×50골드.\n──────────\n%s" % [
		GameState.JOB_UNLOCK_LEVEL, _guide_jobs_lines(["warrior", "mage"])]


func _guide_page_jobs2() -> String:
	return "[직업·전직 2/2]\n" + _help("방향키로 선택하고 E로 확정한다. 전직하면 K키 스킬 설명과", "▲▼로 고르고 전직 버튼으로 확정한다. 전직하면 스킬 설명과") + "\n하단 스킬바가 현재 직업에 맞게 즉시 바뀐다.\n──────────\n%s" % _guide_jobs_lines(["rogue"])


func _guide_page_controls() -> String:
	return "[조작·상태효과]\n" + _help("K: 현재 직업 스킬 설명 / 1~4: 스킬 사용 / Q: 돌진 / C: 캐릭터창\nI: 가방(←→ 장비·재료 탭, 희귀도순) / G: 이 가이드 / M: 지도(이동주문서 1장 소모)", "하단 스킬 칸: 스킬 사용 / Q 버튼: 돌진 / ☰ 메뉴 → 캐릭 탭: 캐릭터창\n가방 탭: 가방(탭 버튼으로 장비·재료 전환) / 위 탭줄·◀▶로 창 이동") + "\n전사: 기절·공격력 버프·무적, 마법사: 슬로우·범위마법·회복,\n도적: 2연타·투사체·은신 확정 치명타·이동속도 버프.\n전직 직업 아이콘은 캐릭터 머리 위에 표시된다.\n상태효과는 스킬 사용 직후 이펙트와 함께 적용된다."

func _toggle_guide() -> void:
	guide_open = not guide_open
	Audio.play_sfx("accept" if guide_open else "cancel")
	$HUD/Guide.visible = guide_open
	$HUD/MobileControls.set_modal_mode("guide" if guide_open else "")
	get_tree().paused = guide_open
	_sync_modal_hud_visibility()
	if guide_open:
		_refresh_guide()


## 가이드 쪽넘김(←→)은 키보드 전용이었다 - 조이스틱은 move_left/right를
## Input.action_press로만 흘려보내 _unhandled_input의 is_action_pressed(event)에
## 안 잡히므로(virtual_joystick.gd:69 주석) 폰에서는 1쪽에서 못 넘어가는
## 막다른 길이었다(2026-09-06 INBOX 결함 08:40). 패널을 반으로 나눠 왼쪽
## 탭=이전 쪽, 오른쪽 탭=다음 쪽으로 책장 넘기듯 만든다.
func _on_guide_gui_input(event: InputEvent) -> void:
	if not guide_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	get_viewport().set_input_as_handled()
	if tap_pos.x < $HUD/Guide.size.x / 2.0:
		guide_page -= 1
	else:
		guide_page += 1
	Audio.play_sfx("cancel")
	_refresh_guide()


## 탑 입구 난이도 선택. TOWER_TIERS 순서(쉬움→심연) 그대로 보여주고,
## 해금 안 된 난이도는 골라도 입장이 막힌다.
func _toggle_tower_select() -> void:
	tower_select_open = not tower_select_open
	Audio.play_sfx("accept" if tower_select_open else "cancel")
	$HUD/TowerSelect.visible = tower_select_open
	$HUD/MobileControls.set_modal_mode("tower_select" if tower_select_open else "")
	get_tree().paused = tower_select_open
	_sync_modal_hud_visibility()
	if tower_select_open:
		_refresh_tower_select()


func _refresh_tower_select() -> void:
	var order: Array = GameState.TOWER_TIERS.keys()
	tower_select_index = clampi(tower_select_index, 0, order.size() - 1)
	var lines: Array[String] = []
	for index in order.size():
		var tier: String = str(order[index])
		var data: Dictionary = GameState.TOWER_TIERS[tier]
		var marker := "▶" if index == tower_select_index else "   "
		var progress: int = int(GameState.tower_progress.get(tier, 0))
		var status: String
		if not GameState.tower_tier_unlocked(tier):
			status = "[잠김]"
		elif progress >= GameState.TOWER_FLOOR_COUNT:
			status = "[클리어]"
		else:
			status = "[%d/%d층]" % [progress, GameState.TOWER_FLOOR_COUNT]
		lines.append("%s %s %s" % [marker, str(data["name"]), status])
	$HUD/TowerSelect/Info.text = "심연의 탑 - 난이도 선택\n──────────\n%s" % "\n".join(lines)
	var selected: String = str(order[tower_select_index])
	$HUD/MobileControls.set_interact_label("입장")
	if GameState.tower_tier_unlocked(selected):
		$HUD/TowerSelect/Help.text = _help("↑↓ 선택   Enter 입장   M/Esc 닫기", "▲▼ 선택   입장 버튼   ✕ 닫기")
	else:
		var requires := str(GameState.TOWER_TIERS[selected].get("requires", ""))
		var requires_name := str(GameState.TOWER_TIERS.get(requires, {}).get("name", ""))
		$HUD/TowerSelect/Help.text = "%s 탑을 100층까지 클리어해야 열림" % requires_name if requires != "" else "스토리를 클리어해야 열림"


func _confirm_tower_select() -> void:
	var order: Array = GameState.TOWER_TIERS.keys()
	var tier: String = str(order[tower_select_index])
	if not GameState.tower_tier_unlocked(tier):
		Audio.play_sfx("cancel")
		return
	GameState.tower_difficulty = tier
	# 전투력이 진행도보다 훨씬 앞서 있으면(장비를 다 맞춰놓고 낮은 층을
	# 다시 오르는 상황) 여기서 미리 몇 층을 건너뛰는지 계산해 보상을
	# 몰아준다. 실제 시작 층 배정은 _change_map -> tower_entry_floor가
	# 다시 계산하므로 여기서는 안내/보상용으로만 쓴다.
	var start_floor := GameState.tower_entry_floor(tier)
	var already := int(GameState.tower_progress.get(tier, 0))
	var skipped := maxi(start_floor - already - 1, 0)
	_toggle_tower_select()
	_change_map("tower", false)
	if skipped > 0:
		var reward := GameState.grant_tower_skip_reward(tier, skipped)
		$HUD/Message.text = "전투력 판정으로 %d층 스킵! %dG, 재료 %d개 획득" % [
			skipped, int(reward["gold"]), int(reward["material"])]


## 난이도 목록도 특성 선택(Perk)과 같은 이유로 폰에는 터치 경로가 없었다
## (2026-09-06 INBOX 결함 08:40 — TowerSelect도 확인·줄 터치 없이 막다른
## 길). _on_perk_gui_input()과 같은 방식으로 목록 줄을 탭 좌표로 환산한다.
func _on_tower_select_gui_input(event: InputEvent) -> void:
	if not tower_select_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var order: Array = GameState.TOWER_TIERS.keys()
	var info: Label = $HUD/TowerSelect/Info
	var row := _tapped_list_row(info, tap_pos, TOWER_SELECT_LIST_START_LINE, order.size())
	if row < 0:
		return
	get_viewport().set_input_as_handled()
	if row == tower_select_index:
		_confirm_tower_select()
	else:
		tower_select_index = row
		Audio.play_sfx("cancel")
		_refresh_tower_select()


## 캐릭터 창 목록 터치(2026-09-06 INBOX 결함, Perk/TowerSelect와 같은 부류).
## 탭(능력치/특성/전직)마다 _refresh_character_*()가 그리는 머리말 줄 수가
## 달라 목록 시작 줄이 다르다(CHARACTER_*_LIST_START_LINE 참고). 전직
## 탭은 2차 전직 목록 앞에 "2차 전직" 구분줄이 하나 끼어들어(항목이 아닌
## 화면 줄) _tapped_list_row()가 돌려주는 원시 줄 번호를 받아 직접
## job_index로 옮긴다.
func _on_character_gui_input(event: InputEvent) -> void:
	if not character_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var info: Label = $HUD/Character/Info
	if character_mode == "stats":
		var row := _tapped_list_row(info, tap_pos, CHARACTER_STATS_LIST_START_LINE, GameState.STAT_KEYS.size())
		if row < 0:
			return
		get_viewport().set_input_as_handled()
		if row == stat_index:
			if GameState.spend_stat(GameState.STAT_KEYS[stat_index]):
				Audio.play_sfx("levelup")
				_apply_equipment_to_player()
		else:
			stat_index = row
			Audio.play_sfx("cancel")
		_refresh_character()
	elif character_mode == "perks":
		if GameState.perk_picks <= 0 or GameState.perk_offer.is_empty():
			return
		var offer := GameState.perk_offer
		var row := _tapped_list_row(info, tap_pos, CHARACTER_PERKS_LIST_START_LINE, offer.size())
		if row < 0:
			return
		get_viewport().set_input_as_handled()
		if row == perk_index:
			_take_perk_from_character_screen()
		else:
			perk_index = row
			Audio.play_sfx("cancel")
		_refresh_character()
	elif character_mode == "job":
		if not GameState.can_change_job():
			return
		var jobs := GameState.JOB_NAMES.keys()
		var second_branches: Array = GameState.SECOND_JOB_BRANCHES.get(GameState.job, []) if GameState.job != "" else []
		var show_second := GameState.job != "" and GameState.can_change_second_job()
		var raw_count := jobs.size() + (1 + second_branches.size() if show_second else 0)
		var line_row := _tapped_list_row(info, tap_pos, CHARACTER_JOB_LIST_START_LINE, raw_count)
		if line_row < 0:
			return
		get_viewport().set_input_as_handled()
		if line_row == jobs.size():
			return
		var new_index := line_row if line_row < jobs.size() else line_row - 1
		if new_index == job_index:
			_change_job_from_character_screen()
		else:
			job_index = new_index
			Audio.play_sfx("cancel")
			_refresh_character()


func _guide_page_enhance() -> String:
	# 한 줄에 하나씩 적으면 10줄이나 돼서 화면 아래와 겹친다. 둘씩 묶는다.
	var lines: Array[String] = []
	var step := 0
	while step < GameState.ENHANCE_RATES.size():
		var parts: Array[String] = []
		for offset in 2:
			var s := step + offset
			if s >= GameState.ENHANCE_RATES.size():
				break
			parts.append("+%d→%d %d%%" % [s, s + 1, int(GameState.ENHANCE_RATES[s] * 100)])
		lines.append("  ".join(parts))
		step += 2
	return "[강화]  %s 소모, 최대 +%d\n실패시 한 단계 하락. +%d부터는 %d%% 확률로 파괴.\n'%s' 소지시 그 시도의 파괴만 막아 줌.\n대장간 강화 화면에서 Z키: 확정 강화(실패·파괴 없음, 재료 %d배 소모,\n+%d 이상은 %d배).\n──────────\n%s" % [
		GameState.MATERIAL, GameState.MAX_ENHANCE, GameState.ENHANCE_RISK_STEP,
		int(GameState.ENHANCE_DESTROY_CHANCE * 100), GameState.ENHANCE_WARD,
		GameState.ENHANCE_GUARANTEED_MULT, GameState.ENHANCE_RISK_STEP,
		GameState.ENHANCE_GUARANTEED_MULT * GameState.ENHANCE_GUARANTEED_RISK_MULT, "\n".join(lines)]


func _guide_page_sockets() -> String:
	var lines: Array[String] = []
	for stone_id in GameState.STONES:
		var data: Dictionary = GameState.STONES[stone_id]
		var stats: Array[String] = []
		for key in ["atk", "def", "hp", "spd", "crit"]:
			if data.has(key):
				stats.append("%s +%s" % [key, str(data[key])])
		lines.append("%s (%s)  %s" % [data["name"], data["rarity"], ", ".join(stats)])
	return "[소켓 · 마법돌]\n장비 등급별 소켓 수: 일반 %d, 레어 %d, 에픽 %d.\n마법돌을 박으면 고정 능력치가 붙는다. 뺄 수는 없다.\n──────────\n%s" % [
		GameState.SOCKETS_BY_RARITY.get("일반", 0), GameState.SOCKETS_BY_RARITY.get("레어", 0),
		GameState.SOCKETS_BY_RARITY.get("에픽", 0), "\n".join(lines)]


## 세트가 5개일 땐 한 페이지에 다 들어갔지만, 탑 세트 4개를 추가하며
## 10개가 되어 화면 아래로 넘쳤다("가이드에 세트 효과 안 나온다" 확인
## 중 발견). 드랍(스토리 보스)/제작(용기사·탑) 두 페이지로 나눴다.
func _guide_set_lines(set_ids: Array) -> String:
	var lines: Array[String] = []
	for set_id in set_ids:
		var data: Dictionary = GameState.SETS[set_id]
		var pieces: Array = data["pieces"]
		var bonus_parts: Array[String] = []
		for threshold in data["bonuses"]:
			var b: Dictionary = data["bonuses"][threshold]
			var stat_strs: Array[String] = []
			for key in b:
				stat_strs.append("%s+%s" % [key, str(b[key])])
			bonus_parts.append("%d조각: %s" % [int(threshold), ", ".join(stat_strs)])
		lines.append("%s: %s\n  %s" % [data["name"], "、".join(pieces), " / ".join(bonus_parts)])
	return "\n".join(lines)


func _guide_page_sets_story() -> String:
	return "[세트 효과 1/5 - 드랍]\n1~4장 보스 세트. 조각 중 둘은 그 보스가 확정으로 떨어뜨리고\n하나는 상점·퀘스트로 구한다.\n──────────\n%s" % _guide_set_lines(
		["guardian_set", "captain_set", "frost_set", "abyss_set"])


## 4조각 보너스는 스탯이 4개라 줄바꿈까지 되어 한 세트가 3줄을 먹는다.
## 5개를 한 페이지에 넣었더니 또 넘쳐서(3/4 페이지) 결국 셋씩 나눴다.
func _guide_page_sets_craft() -> String:
	return "[세트 효과 2/5 - 제작]\n대장간에서 재료를 모아 만드는 세트(제작 문서 참고).\n──────────\n%s" % _guide_set_lines(
		["boss_set", "tower_easy_set", "tower_normal_set"])


func _guide_page_sets_craft2() -> String:
	return "[세트 효과 3/5 - 제작]\n탑 세트는 난이도가 오를수록 세지며, 천공 세트가 최상위다.\n──────────\n%s" % _guide_set_lines(
		["tower_hard_set", "tower_hell_set", "tower_abyss_set"])


## 5~10장 초월 세트 6개. 4조각 보너스까지 3줄씩이라 셋씩 두 쪽.
func _guide_page_sets_high1() -> String:
	return "[세트 효과 4/5 - 5~7장]\n장별 정수+보스의 파편으로 제작(제작 3/3 참고). 보스는 검·투구를 준다.\n──────────\n%s" % _guide_set_lines(
		["primordial_set", "reef_set", "prelate_set"])


func _guide_page_sets_high2() -> String:
	return "[세트 효과 5/5 - 8~10장]\n근원 세트가 최상위(Lv%d).\n──────────\n%s" % [
		int(GameState.EQUIPMENT["근원의 검"]["level"]), _guide_set_lines(["warden_set", "reversal_set", "origin_set"])]


func _guide_page_spirit() -> String:
	var lines: Array[String] = []
	for item in GameState.EQUIPMENT:
		var data: Dictionary = GameState.EQUIPMENT[item]
		if str(data.get("slot", "")) == "spirit":
			var effect := str(data.get("spirit", ""))
			lines.append("%s: %s" % [item, GameState.SPIRIT_EFFECT_DESC.get(effect, "")])
	return "[정령 인장]\n5번째 장비 슬롯. 패시브 효과 하나를 켜 둔다. 장신구와 별도라 같이 낄 수 있다.\n──────────\n%s" % "\n".join(lines)


func _guide_craft_lines(items: Array) -> String:
	var lines: Array[String] = []
	for item in items:
		var cost: Dictionary = GameState.CRAFT_RECIPES[item]
		lines.append("%s\n  파편 %d, %s %d, %dG, %s" % [
			item, int(cost["fragments"]), GameState.MATERIAL, int(cost["stones"]), int(cost["gold"]),
			str(cost.get("area_item", ""))])
	return "\n".join(lines)


## 8px 글꼴로 되돌리며(INBOX 17:50 보정) 4개 레시피 전부 + 안내문이
## 한 페이지에 안 들어가 안내줄과 겹쳤다(check_guide_touch_page.gd 회귀).
## 둘씩 나눴다.
func _guide_page_craft1() -> String:
	var items := GameState.CRAFT_RECIPES.keys()
	return "[제작 1/3]\n보스를 잡으면 '%s'을(를) 확정으로 주지만 개수는 %d~%d개로 무작위다.\n동서남북 사냥터 몬스터가 낮은 확률로 떨어뜨리는 전용 아이템도 하나씩 필요하다.\n대장간 제작 탭에서 파편+강화석+골드+사냥터 아이템으로 전설 장비를 만든다.\n──────────\n%s" % [
		GameState.BOSS_FRAGMENT, GameState.BOSS_FRAGMENT_MIN, GameState.BOSS_FRAGMENT_MAX,
		_guide_craft_lines(items.slice(0, 2))]


func _guide_page_craft2() -> String:
	var items := GameState.CRAFT_RECIPES.keys()
	return "[제작 2/3]\n──────────\n%s" % _guide_craft_lines(items.slice(2))


## 5~10장 제작은 레시피가 24개라 나열 대신 규칙만 적는다.
func _guide_page_craft3() -> String:
	var essences: Array[String] = []
	for ch in GameState.CHAPTER_ESSENCES:
		essences.append("%d장 %s" % [int(ch), str(GameState.CHAPTER_ESSENCES[ch])])
	var sword: Dictionary = GameState.CHAPTER_CRAFT_RECIPES["근원의 검"]
	var seal: Dictionary = GameState.CHAPTER_CRAFT_RECIPES["근원의 인장"]
	return "[제작 3/3 - 5~10장 초월 세트]\n그 장 몬스터가 %d%% 확률로, 보스가 %d~%d개 떨어뜨리는 '정수'로 만든다.\n검·갑주·투구·인장 한 조각에 정수 %d~%d, 보스의 파편 %d~%d, %s %d~%d, %dG~.\n보유량은 %s.\n──────────\n%s\n장별 전설 장비 2종은 그 장 몬스터가 낮은 확률로 떨어뜨린다." % [
		int(GameState.ESSENCE_DROP_RATE * 100), GameState.ESSENCE_BOSS_MIN, GameState.ESSENCE_BOSS_MAX,
		int(seal["essence"]), int(sword["essence"]), int(seal["fragments"]), int(sword["fragments"]),
		GameState.MATERIAL, int(seal["stones"]), int(sword["stones"]),
		int(GameState.CHAPTER_CRAFT_RECIPES["태초의 인장"]["gold"]),
		_help("가방(I) ←→ 재료 탭에서 본다", "가방 → 탭 버튼 → 재료 탭에서 본다"), "\n".join(essences)]


func _guide_page_boss() -> String:
	return "[보스]\n보스는 체력이 줄면 2단계, 3단계로 바뀌며 '○○ N단계 돌입!'이 뜬다.\n단계마다 돌진·범위 공격·부하 소환·추적 투사체 같은 새 패턴이 붙는다.\n부하는 경험치·골드·처치 수를 주지 않는다.\n보스를 잡으면 보스의 파편(%d~%d개)과 그 장 세트 검·투구, 5장부터는 정수도 준다.\n한 번 잡은 보스는 다시 나오지 않는다." % [
		GameState.BOSS_FRAGMENT_MIN, GameState.BOSS_FRAGMENT_MAX]


func _guide_page_fishing() -> String:
	var lines: Array[String] = []
	for tier in GameState.FISH_LOOT:
		var names: Array[String] = []
		for entry in GameState.FISH_LOOT[tier]:
			names.append("%s(%dG)" % [entry["name"], int(entry["price"])])
		lines.append("%d장: %s" % [tier, ", ".join(names)])
	return "[낚시]\n상점에서 '%s'를 사면 연못 있는 지역 어디서나 F로 낚시.\n장이 오를수록 더 비싼 물고기가 나온다.\n──────────\n%s" % [
		GameState.FISHING_ROD, "\n".join(lines)]


func _guide_tower_lines(tiers: Array) -> String:
	var lines: Array[String] = []
	for tier in tiers:
		var data: Dictionary = GameState.TOWER_TIERS[tier]
		lines.append("%s (몬스터 x%.1f, 보상 x%.1f)" % [str(data["name"]), float(data["mob_mult"]), float(data["reward_mult"])])
	return "\n".join(lines)


## 8px 글꼴로 되돌리며(INBOX 17:50 보정) 안내문 6줄 + 난이도 5줄이 한
## 페이지에 안 들어가 안내줄과 겹쳤다. 둘로 나눴다.
func _guide_page_tower1() -> String:
	var tiers := GameState.TOWER_TIERS.keys()
	return "[탑 1/2]\n스토리를 클리어하면 지도(M) 개관도 아래에 '심연의 탑' 표식이 열린다.\n표식을 누르면(T키) 난이도 선택 화면이 뜨고, 고른 난이도로 1층부터 입장한다.\n10층마다 미니보스, 25/50/75/100층은 고정 보스급.\n한 난이도를 100층까지 클리어해야 그 위 난이도가 열린다.\n──────────\n%s" % _guide_tower_lines(tiers.slice(0, 3))


func _guide_page_tower2() -> String:
	var tiers := GameState.TOWER_TIERS.keys()
	return "[탑 2/2]\n탑 몬스터는 그 난이도 결정을 낮은 확률로 떨어뜨린다.\n제작엔 그 아래 난이도 결정도 필요하다(쉬움 1종~심연 5종+강화석).\n──────────\n%s" % _guide_tower_lines(tiers.slice(3))


func _refresh_guide() -> void:
	guide_page = ((guide_page % GUIDE_PAGE_COUNT) + GUIDE_PAGE_COUNT) % GUIDE_PAGE_COUNT
	var page_text: String
	match guide_page:
		0: page_text = _guide_page_enhance()
		1: page_text = _guide_page_sockets()
		2: page_text = _guide_page_sets_story()
		3: page_text = _guide_page_sets_craft()
		4: page_text = _guide_page_sets_craft2()
		5: page_text = _guide_page_sets_high1()
		6: page_text = _guide_page_sets_high2()
		7: page_text = _guide_page_spirit()
		8: page_text = _guide_page_craft1()
		9: page_text = _guide_page_craft2()
		10: page_text = _guide_page_craft3()
		11: page_text = _guide_page_boss()
		12: page_text = _guide_page_fishing()
		13: page_text = _guide_page_tower1()
		14: page_text = _guide_page_tower2()
		15: page_text = _guide_page_jobs1()
		16: page_text = _guide_page_jobs2()
		_: page_text = _guide_page_controls()
	$HUD/Guide/Info.text = _mob(page_text)
	if $HUD/MobileControls.visible:
		$HUD/Guide/Help.text = "◀ 왼쪽 탭 · 오른쪽 탭 ▶ %d/%d   ✕ 닫기" % [guide_page + 1, GUIDE_PAGE_COUNT]
	else:
		$HUD/Guide/Help.text = "←→ %d/%d   G/Esc 닫기" % [guide_page + 1, GUIDE_PAGE_COUNT]


## 캐릭터 탭(능력치/특성/전직) 전환. 키보드 ←→ 와 모바일 Sell("탭") 버튼
## (mobile_controls.gd _toggle_shop_tab)이 이 한 함수로 모인다(_cycle_forge_mode()와
## 같은 이유, 2026-09-06 INBOX 결함).
func _cycle_character_mode(step: int) -> void:
	var index := CHARACTER_MODES.find(character_mode) + step
	# 스킬 창(K)을 네 번째 탭으로 잇는다. 모바일엔 K가 없어 스킬 설명을 볼
	# 길이 없었다("스킬탭도 없네", 2026-09-08 감독).
	if index < 0 or index >= CHARACTER_MODES.size():
		_toggle_character()
		_toggle_skills()
		return
	character_mode = CHARACTER_MODES[index]
	Audio.play_sfx("cancel")
	_refresh_character()


## 스킬 탭에서 ←→/탭 버튼으로 캐릭터 창의 앞뒤 탭으로 돌아간다.
func _skills_to_character(step: int) -> void:
	_toggle_skills()
	character_mode = CHARACTER_MODES[0 if step > 0 else CHARACTER_MODES.size() - 1]
	_toggle_character()


func _refresh_character() -> void:
	if character_mode == "perks":
		_refresh_character_perks()
		return
	if character_mode == "job":
		_refresh_character_job()
		return
	var lines: Array[String] = []
	for index in GameState.STAT_KEYS.size():
		var key: String = GameState.STAT_KEYS[index]
		var marker := "▶" if index == stat_index else "   "
		lines.append("%s %s  %d" % [marker, GameState.STAT_NAMES[key], int(GameState.stats[key])])
	var tabs := "[능력치] 특성(%d) 전직 스킬" % GameState.perk_picks
	var job_label: String = GameState.JOB_NAMES.get(GameState.job, "무직")
	$HUD/Character/Info.text = "%s\nLV %d   %s\n──────────\n%s\n\n남은 점수  %d" % [
		tabs, GameState.level, job_label, "\n".join(lines), GameState.stat_points]
	var key: String = GameState.STAT_KEYS[stat_index]
	$HUD/Character/Detail.text = "%s\n%s\n\nHP %d/%d\n마력 %d/%d\n공격 %d\n방어 %d\n속도 %d\n치명타 확률 %d%%\n치명타 피해 %d%%" % [
		GameState.STAT_NAMES[key], GameState.STAT_EFFECTS[key],
		$Player.health, $Player.max_health, $Player.mana, $Player.max_mana,
		$Player.attack_damage + GameState.attack_bonus + GameState.stat_attack(),
		GameState.defense_bonus, int($Player.move_speed),
		int(round(GameState.crit_chance() * 100.0)), int(round(GameState.crit_damage_mult() * 100.0))]
	$HUD/Character/Help.text = _help("↑↓ 선택   E 투자   C/Esc 닫기", "▲▼ 선택   투자 버튼   탭 전환   ✕ 닫기")
	$HUD/MobileControls.set_interact_label("투자")


## 특성 탭. 전투 중에 강제로 뜨던 창을 없앤 대신 여기서 안전하게 고른다.
func _refresh_character_perks() -> void:
	var tabs := "능력치 [특성(%d)] 전직 스킬" % GameState.perk_picks
	if GameState.perk_picks <= 0:
		$HUD/Character/Info.text = "%s\nLV %d\n──────────\n남은 특성 선택권이 없다.\n레벨업하면 선택권이 쌓인다." % [
			tabs, GameState.level]
		$HUD/Character/Detail.text = ""
		$HUD/Character/Help.text = _help("C/Esc 닫기", "탭 전환   ✕ 닫기")
		$HUD/MobileControls.set_interact_label("", false)
		return
	if GameState.perk_offer.is_empty():
		GameState.roll_perk_offer()
	var offer := GameState.perk_offer
	perk_index = clampi(perk_index, 0, maxi(offer.size() - 1, 0))
	var lines: Array[String] = []
	for index in offer.size():
		var pkey: String = offer[index]
		var data: Dictionary = GameState.PERKS[pkey]
		var owned := int(GameState.perks.get(pkey, 0))
		var stack := "  (보유 %d)" % owned if owned > 0 else ""
		var marker := "▶" if index == perk_index else "   "
		lines.append("%s %s%s" % [marker, data["name"], stack])
	$HUD/Character/Info.text = "%s\nLV %d\n──────────\n선택권 %d개 남음\n%s" % [
		tabs, GameState.level, GameState.perk_picks, "\n".join(lines)]
	var chosen: Dictionary = GameState.PERKS[offer[perk_index]]
	$HUD/Character/Detail.text = _mob("%s\n%s\n\nE키로 선택") % [chosen["name"], chosen["desc"]]
	$HUD/Character/Help.text = _help("↑↓ 선택   E 선택   C/Esc 닫기", "▲▼ 선택   선택 버튼   탭 전환   ✕ 닫기")
	$HUD/MobileControls.set_interact_label("선택")


## 전직 탭. 레벨 15 미만이면 아직 잠겼다는 안내만 보여준다.
## 이미 1차 전직했고 레벨 40+4장 조건을 채우면 목록 아래에 2차 전직
## 갈래(직업당 2개)가 이어 붙는다. 위/아래로 통합 목록을 오가고 E로 확정.
func _refresh_character_job() -> void:
	var tabs := "능력치 특성(%d) [전직] 스킬" % GameState.perk_picks
	if not GameState.can_change_job():
		$HUD/Character/Info.text = "%s\nLV %d\n──────────\n레벨 %d부터 전직할 수 있다." % [
			tabs, GameState.level, GameState.JOB_UNLOCK_LEVEL]
		$HUD/Character/Detail.text = ""
		$HUD/Character/Help.text = _help("C/Esc 닫기", "탭 전환   ✕ 닫기")
		$HUD/MobileControls.set_interact_label("", false)
		return
	var jobs := GameState.JOB_NAMES.keys()
	var second_branches: Array = GameState.SECOND_JOB_BRANCHES.get(GameState.job, []) if GameState.job != "" else []
	var show_second := GameState.job != "" and GameState.can_change_second_job()
	var total := jobs.size() + (second_branches.size() if show_second else 0)
	job_index = clampi(job_index, 0, maxi(total - 1, 0))
	var lines: Array[String] = []
	for index in jobs.size():
		var jkey: String = jobs[index]
		var marker := "▶" if index == job_index else "   "
		var current := "  (현재)" if jkey == GameState.job else ""
		lines.append("%s %s%s" % [marker, GameState.JOB_NAMES[jkey], current])
	if show_second:
		lines.append("2차 전직")
		for offset in second_branches.size():
			var skey: String = second_branches[offset]
			var index2 := jobs.size() + offset
			var marker2 := "▶" if index2 == job_index else "   "
			var current2 := "  (현재)" if skey == GameState.second_job else ""
			lines.append("%s %s%s" % [marker2, GameState.SECOND_JOB_NAMES[skey], current2])
	var current_label: String = GameState.JOB_NAMES.get(GameState.job, "무직")
	var second_label := (" → %s" % GameState.SECOND_JOB_NAMES[GameState.second_job]) if GameState.second_job != "" else ""
	$HUD/Character/Info.text = "%s\nLV %d   현재 직업: %s%s\n──────────\n%s" % [
		tabs, GameState.level, current_label, second_label, "\n".join(lines)]
	$HUD/Character/Help.text = _help("↑↓ 선택   E 전직   C/Esc 닫기", "▲▼ 선택   전직 버튼   탭 전환   ✕ 닫기")
	$HUD/MobileControls.set_interact_label("전직")
	if job_index < jobs.size():
		var target := str(jobs[job_index])
		var cost := GameState.job_change_cost()
		var cost_line := "무료 (첫 전직)" if GameState.job == "" else "비용 %d골드" % cost
		if target == GameState.job:
			$HUD/Character/Detail.text = "%s\n이미 이 직업이다." % GameState.JOB_NAMES[target]
		else:
			$HUD/Character/Detail.text = _mob("%s로 전직\n%s\n\nE키로 확정") % [GameState.JOB_NAMES[target], cost_line]
	else:
		var target2 := str(second_branches[job_index - jobs.size()])
		if target2 == GameState.second_job:
			$HUD/Character/Detail.text = "%s\n이미 이 직업이다." % GameState.SECOND_JOB_NAMES[target2]
		else:
			var stone := GameState.second_job_stone_type()
			var have := int(GameState.materials.get(stone, 0))
			$HUD/Character/Detail.text = _mob("%s로 2차 전직\n%s %d/%d개, 비용 %d골드\n\nE키로 확정") % [
				GameState.SECOND_JOB_NAMES[target2], stone, have, GameState.SECOND_JOB_STONE_COST, GameState.level * GameState.SECOND_JOB_GOLD_MULT]


func _take_perk_from_character_screen() -> void:
	if GameState.perk_picks <= 0 or GameState.perk_offer.is_empty():
		return
	if GameState.take_perk(GameState.perk_offer[perk_index]):
		Audio.play_sfx("levelup")
		_apply_equipment_to_player()
	if GameState.perk_picks > 0:
		GameState.roll_perk_offer()
		perk_index = 0


## 전직 탭에서 E로 확정. job_index가 1차 직업 목록 범위면 GameState.change_job(),
## 그 뒤(2차 전직 갈래)면 GameState.change_second_job()을 부른다. 레벨 미달·재료
## 부족이면 이유를 문구로 돌려주고, 성공하면 스킬이 그 직업 것으로 바로 바뀐다.
func _change_job_from_character_screen() -> void:
	var jobs := GameState.JOB_NAMES.keys()
	if job_index < jobs.size():
		var target := str(jobs[job_index])
		var result := GameState.change_job(target)
		if result == "":
			Audio.play_sfx("levelup")
			$HUD/Message.text = "%s(으)로 전직했다!" % GameState.JOB_NAMES[target]
			_apply_equipment_to_player()
		else:
			Audio.play_sfx("cancel")
			$HUD/Message.text = result
	else:
		var second_branches: Array = GameState.SECOND_JOB_BRANCHES.get(GameState.job, [])
		var target2 := str(second_branches[job_index - jobs.size()])
		var result2 := GameState.change_second_job(target2)
		if result2 == "":
			Audio.play_sfx("levelup")
			$HUD/Message.text = "%s(으)로 2차 전직했다!" % GameState.SECOND_JOB_NAMES[target2]
			_apply_equipment_to_player()
		else:
			Audio.play_sfx("cancel")
			$HUD/Message.text = result2
	_refresh_character()


## AUTOHUNT_DESIGN.md §5. 데스크톱 키(T)·모바일 Auto 버튼·모달 강제 OFF가
## 전부 이 함수 하나로 모인다. HUD 상시 라벨(§8 다음 체크박스)은 아직 없음.
func _toggle_auto_hunt() -> void:
	$Player.auto_hunt = not $Player.auto_hunt
	Audio.play_sfx("accept" if $Player.auto_hunt else "cancel")
	$HUD/Message.text = "자동사냥 켜짐" if $Player.auto_hunt else "자동사냥 꺼짐"
	$HUD/MobileControls.sync_auto_button()


## AUTOHUNT_DESIGN.md §10.4. 데스크톱 키(Y)·모바일 Quest 버튼·모달 강제
## OFF(§10.5)가 전부 이 함수 하나로 모인다(_toggle_auto_hunt()와 같은 패턴).
func _toggle_quest_mode() -> void:
	quest_mode = not quest_mode
	Audio.play_sfx("accept" if quest_mode else "cancel")
	$HUD/Message.text = "퀘스트모드 켜짐" if quest_mode else "퀘스트모드 꺼짐"
	$HUD/MobileControls.sync_quest_button()
	## 결함(감독, 2026-09-07 "퀘스트모드 다시 누르면 꺼져야 하는데 안 꺼짐"):
	## 퀘스트모드 틱이 켜 둔 auto_hunt/auto_walk는 이 함수가 끄지 않아
	## "꺼짐" 메시지 뒤에도 캐릭터가 계속 자동으로 걷고 싸웠다. auto_walk는
	## 퀘스트모드만 켜므로(player.gd 273줄) 여기서 같이 끄는 것이 유일한 OFF 지점.
	if not quest_mode:
		$Player.auto_hunt = false
		$Player.auto_walk_active = false
		_quest_walk_target = Vector2.ZERO
		$HUD/MobileControls.sync_auto_button()


## AUTOHUNT_DESIGN.md §10.3. 새 전투/대화 시스템 없이 기존
## _interact_npc()/_travel_to()/_advance_dialogue()를 순서대로 트리거만
## 한다. UI 토글 버튼은 아직 없음(§10.7 다음 체크박스).
##
## §10.7 통합 테스트로 발견한 gap(2026-09-05): 마을에서 이미 의뢰를 받은
## 뒤(예: quest_stage==1, "숲의 마물 처치")는 촌장이 더 할 말이 없는데도
## 원래 코드가 매번 촌장 옆으로 걸어가 말을 걸려고만 해서 마을을 벗어나지
## 못하고 멈췄다. `_quest_stage_text()`에 "처치"가 있으면(사냥 단계) 마을
## 동쪽 exit로 걸어 나가고, 없으면(대화 단계) 촌장에게 간다. 사냥터에서도
## 지역 몹을 다 잡고 나면(사냥터는 전부 마을→서→동 한 줄 사슬,
## `grep -n '"exits":' scripts/world.gd`로 전 지역 확인) 다음 지역으로
## 계속 동쪽 exit를 향해 걸어가게 했다 - 안 그러면 그 지역 몹을 다 잡은 뒤
## 다음 지역(보스방 포함)으로 못 넘어가고 제자리에 멈춘다.
##
## §10.7 통합 테스트 2차 gap(2026-09-05, 생존성): 물약 0개로 다수의 적에
## 둘러싸여 사망(hp tick=3000 potions=0 enemies_near=11 → tick=3100
## health=5 → 사망). 오토사냥 전투 AI 자체를 바꾸는 대신(candidate a는
## 퀘스트모드 아닌 플레이어에게도 영향이 커 범위가 크다) 후보 (b)를 택함
## - potions<=0이면 즉시 안전한 홈 마을로 `_travel_to`(보스 처치 후 귀환과
## 같은 패턴, 맵 전환이 순간적이라 다수의 적에게 둘러싸여도 안전) 하고,
## 마을에 도착하면 상점 UI를 열지 않고 `GameState.buy()`를 바로 호출해
## 물약을 채운다(가격은 `SHOP_STOCK`의 "회복약" 항목에서 조회 - 새 숫자
## 하드코딩 없음). 골드가 모자라 못 사면 그 자리에서 재시도만 반복(죽는
## 것보다는 낫다).
## 이 귀환이 새로 드러낸 버그 두 개(둘 다 실제로 겪고 고침):
## (1) `_travel_to()`(2265줄 부근)는 첫 줄에서 사람이 M키로 이미 지도를
## 연 상태라고 가정하고 `_toggle_world_map()`을 한 번만 불러 지도를
## 닫는데, 퀘스트모드는 지도를 연 적이 없어 그 토글이 거꾸로 지도를 열고
## `get_tree().paused=true`를 건 채 끝나 게임이 완전히 멈췄다(§10.7
## 3차 실측: potions=0으로 귀환한 뒤 화면이 마을에서 그대로 정지). 처음엔
## 지도를 먼저 열어 사람이 하는 순서를 흉내 내 고쳤으나, 그 경로는
## `set_modal_mode("map")`을 거쳐 스스로 quest_mode를 꺼 버리는 새 문제를
## 낳았다(INBOX 13:25 보정) - `_quest_travel_home()`이 지도 UI를 아예
## 거치지 않고 `_change_map()`을 직접 부르도록 다시 고침(2549줄 부근).
## (2) kills>=6이 되면 `_quest_stage_text()`가 "…처치"
## 대신 "…가자"로 바뀌는데(2305줄), 마을 판정은 "처치"만 찾고 있어 사냥
## 목표를 채운 뒤 potions=0으로 귀환하면 그 뒤로 "처치"가 안 보여 그냥
## 촌장에게 말을 걸러 가 버렸다(정작 quest_stage는 그대로라 촌장이 할
## 말이 없다) - "가자"도 함께 찾도록 고침.
func _quest_mode_tick() -> void:
	if not quest_mode:
		return
	if dialogue_open:
		_advance_dialogue()
		return
	if World.is_town(GameState.current_map):
		var price := _quest_potion_price()
		if GameState.potions <= 0 and GameState.gold >= price:
			_quest_buy_potions(price)
		if GameState.QUEST_STAGE_KIND.get(GameState.quest_stage) == "HUNT":
			## (INBOX 답, 2026-09-07 00:45) 물약 조기 귀환으로 온 것이면 그
			## 자리(그라인드 없음)로 바로 되돌아간다 - `_quest_resume_zone`
			## 소비보다 앞서 처리해 두 의미가 섞이지 않게 한다.
			if _quest_restock_zone != "" and GameState.potions > 0 and GameState.unlocked_maps.has(_quest_restock_zone):
				var restock := _quest_restock_zone
				_quest_restock_zone = ""
				_quest_travel_home(restock)
				return
			## §10.7 후퇴: 지역을 포기하고 돌아온 뒤에는 처음부터 걸어 나가는
			## 대신 한 티어 아래(포기한 지역의 이전 지역)로 바로 이동한다.
			if _quest_resume_zone != "" and GameState.unlocked_maps.has(_quest_resume_zone):
				var resume := _quest_resume_zone
				_quest_resume_zone = ""
				_quest_grind_zone = resume
				_quest_travel_home(resume)
				return
			$Player.auto_hunt = false
			_quest_set_auto_walk(_quest_east_exit_target(GameState.current_map))
			return
		var who_key: String = TOWN_QUEST_NPC.get(GameState.current_map, "elder")
		var target := World.town_npc_position(GameState.current_map, who_key)
		if $Player.global_position.distance_to(target) <= TALK_RANGE:
			$Player.auto_walk_active = false
			_interact_npc()
		else:
			_quest_set_auto_walk(target)
	else:
		if GameState.QUEST_STAGE_KIND.get(GameState.quest_stage) == "RETURN":
			$Player.auto_walk_active = false
			$Player.auto_hunt = true
			var home := _quest_home_town()
			if home != "" and GameState.unlocked_maps.has(home):
				_quest_travel_home(home)
			return
		## (INBOX 답, 2026-09-06 14:20) 물약 0개여도 물약값을 못 살 돈이면
		## 귀환하지 않고 계속 사냥한다 - 안 그러면 tier1 골드 보상(6)이
		## 물약값(20)보다 낮아 3킬 이내에 다 쓴 뒤 사냥터↔마을을 216틱
		## 주기로 영원히 왕복하며 전투를 한 번도 못 해 골드가 늘지 않는
		## 결함이 있었다(15:10 질문 실측). 위험해지면 `_quest_should_retreat()`
		## (HP 40%·근접 4마리)가 여전히 후퇴를 걸어 준다.
		if GameState.potions <= 0 and GameState.gold >= _quest_potion_price():
			$Player.auto_hunt = false
			$Player.auto_walk_active = false
			var home := _quest_home_town()
			if home != "" and GameState.unlocked_maps.has(home):
				## (INBOX 답, 2026-09-07 00:45) 물약을 채운 직후 그라인드 없이
				## 이 자리로 되돌아오기 위해 지금 있던 지역을 기억해 둔다.
				_quest_restock_zone = GameState.current_map
				_quest_travel_home(home)
			return
		if _quest_should_retreat():
			_quest_do_retreat()
			return
		## (감독 2026-09-09 "퀘스트모드도 예전 오토처럼 아이템을 안 먹는다")
		## 줍기는 `_auto_hunt_tick()`(auto_hunt)에만 있고, 퀘스트모드는 적이
		## 사거리 밖이거나 목표를 채운 뒤엔 `_quest_set_auto_walk()`(A*)로
		## 걸어 드랍을 두고 떠났다. 근접 적이 없으면 드랍부터 줍는다.
		if _quest_collect_nearby_pickup():
			return
		## (INBOX 답, 2026-09-07 02:50 ①) goal_reached는 그 지역 몹 킬
		## 목표만 보므로, cave_deep처럼 동쪽 출구가 없는 막다른 보스방에서는
		## 잡몹만 다 잡으면 보스가 멀리 살아있어도 통과 취급돼
		## `_quest_east_exit_target()`이 없는 동쪽 출구를 향해 걷다 지역 끝에서
		## 영원히 멈췄다(§10.7 실측). 통과 여부와 무관하게 그 지역에 살아있는
		## 보스가 있으면 거리 제한 없이 쫓는다(`_auto_hunt_tick()`이 가장 가까운
		## 적을 고르므로 잡몹부터 정리되고 마지막에 보스로 감) - 보스는
		## 재입장마다 리스폰되므로(`_spawn_boss()`) `GameState.boss_defeated`
		## (1장 전용 플래그, 10:05 답 ②)는 보지 않는다. RETURN 단계 귀환
		## 판정(2611줄)이 이 분기보다 앞이라 보스 처치 직후엔 다시 안 걸린다.
		if World.boss_chapter_of(GameState.current_map) > 0 and _quest_has_live_boss(GameState.current_map):
			## (INBOX 결함 11:13 검증 중 발견) 보스방은 이미 `check_autohunt_boss_room.gd`가
			## 확인하는 대로 직선 접근+회피만으로 충분하다(막힌 담을 도는 문제가 아니라
			## 방 안 근접전) - `_quest_engage_nearest_enemy()`(A* 원거리 접근용)를 여기까지
			## 적용하면 `walk_waypoints()`가 보스방을 못 짚어 전진이 아예 멈춘다(start_dist=436.4
			## 그대로, RESULT FAIL 실측). 원래 직접 auto_hunt 그대로 유지.
			$Player.auto_walk_active = false
			$Player.auto_hunt = true
			return
		## (STATUS "다음에 할 것", 2026-09-06 §10.7 새 블로커) 스토리 킬
		## 목표(예: 1장 hill 6마리)를 채운 뒤에도 이 판정이 "그 지역에
		## 살아있는 적이 하나라도 있으면 계속 auto_hunt"로만 봐서, 사냥터를
		## `_change_map()`으로 재진입할 때마다 몹이 처음 수(hill=9)로
		## 리스폰돼 결코 다 잡지 못하고 동쪽 출구(hill_ridge)로 못 나가는
		## 무한 왕복이 있었다(auto_quest_probe 실측, kills=6에서 정지).
		## 마을 판정(2441줄)과 같은 신호(_quest_stage_text()의 "가자")로
		## 스토리 목표 달성 여부를 먼저 보고, 채웠으면 적이 남아 있어도
		## 동쪽 출구로 걸어 나간다.
		var goal_reached := _quest_effective_goal_reached()
		var has_live_enemy := false
		if not goal_reached:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.health > 0:
					has_live_enemy = true
					break
		## (INBOX 답, 2026-09-07 00:12 ①) 통과 중(goal_reached)에는 사거리
		## 안 적만 때리고 추격을 안 해 40마리 밀집 지역(forest_w)에서 몹이
		## 계속 따라붙어 맞다가 물약이 바닥나 조기 귀환하는 순환의 원인이었다
		## (§10.7 forest_w 정체 실측). `_quest_should_retreat()`와 같은 반경
		## (near_dist = attack_range*2.5, 새 숫자 없음) 안에 살아있는 적이
		## 있으면 그 적을 쫓는다(auto_hunt=true, `_auto_hunt_tick()`이 가장
		## 가까운 적을 고름) - 먼 적은 그대로 안 쫓으므로 5b8da29가 막은
		## 재리스폰 무한 왕복은 재발하지 않는다.
		if goal_reached and not has_live_enemy and _quest_transit_nearby_enemy():
			_quest_engage_nearest_enemy()
		elif has_live_enemy:
			_quest_engage_nearest_enemy()
		else:
			if GameState.current_map == _quest_grind_zone:
				_quest_grind_zone = ""
			$Player.auto_hunt = false
			_quest_set_auto_walk(_quest_east_exit_target(GameState.current_map))
			_quest_transit_engage()


## AUTOHUNT_DESIGN.md §10.7(INBOX 10:05 ①): `_quest_stage_text()`가 처치
## 목표를 채웠는지 판정하는 것과 같은 숫자를 텍스트 매칭 없이 그대로 쓴다
## (표는 `GameState.QUEST_HUNT_TARGETS`, 새 숫자 없음). 목표 카운터가 없는
## 단계(8)는 진입 즉시 통과로 본다.
## (INBOX 답, 2026-09-07 02:50 ①) 그 지역에 살아있는 보스가 있는지 - 잡몹
## 판정(`enemies` 그룹)과 같은 방식, `area_id`로 다른 지역 보스와 구분한다.
func _quest_has_live_boss(map_name: String) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.area_id == map_name and enemy.is_boss and enemy.health > 0:
			return true
	return false


func _quest_hunt_goal_reached(stage: int) -> bool:
	if GameState.QUEST_STAGE_KIND.get(stage) != "HUNT":
		return false
	var cfg = GameState.QUEST_HUNT_TARGETS.get(stage)
	if cfg == null:
		return true
	var count: int = GameState.kills if cfg["field"] == "kills" else GameState.chapter_kills
	return count >= cfg["target"]


## (INBOX 답, 2026-09-06 19:20) 18:45 이후 근접·HP 두 규칙을 조건 없이
## 통합했더니 새 정체가 생겼다: 통과 중이든 아니든 물약·골드가 모두
## 없으면(can_recover=false) 근접 0마리에서도 HP<=40% 하나만으로 후퇴가
## 걸려 회복·전투·사망 없이 마을⇄사냥터를 영원히 반복했다(INBOX 19:15
## 질문 실측). 후퇴는 위협을 벗어나 "회복하러 가는" 행동이므로, 회복
## 수단이 아예 없으면 후퇴는 문(정지)일 뿐이다 - HP 규칙에만 `can_recover`
## 게이트를 되살린다(근접 규칙은 회복 여부와 무관하게 그대로 유지). 회복
## 수단이 없을 때는 §10.5대로 그대로 밀고 나간다: 근접 <4면 싸운다 →
## 1킬이면 골드+6으로 물약값을 넘겨 기존 물약 귀환 규칙(14:20)이 회복시키고,
## 죽으면 마을 부활 전체 회복이며 킬이 사망 연속을 끊는다 - 어느 쪽이든
## 진행이다. 18:45 ④의 둘째 케이스(목표 달성·물약 0·골드 부족·근접
## 1마리·HP 30% → 후퇴 true)는 사람이 오판으로 철회했다 - false가 맞다.
func _quest_can_recover() -> bool:
	return GameState.potions > 0 or GameState.gold >= _quest_potion_price()


## (INBOX 답, 2026-09-07 01:20 ①) 근접 마릿수는 더 이상 단독 후퇴 사유가
## 아니다 - §10.5 표 근거("11마리 조우에서 health 69→5")는 마릿수가 아니라
## 그로 인한 HP 급락이 위험이었다. HP>임계면 근접 수와 무관하게 후퇴 없음.
## HP≤임계일 때는 그 아래 로직(근접 규칙·`_quest_can_recover()` 게이트·물약
## 시도)이 전부 그대로다 - 근접≥N이면 회복 여부와 무관하게 즉시 후퇴(물약
## 시도 안 함, 18:45 ④와 동일), 근접<N이면 게이트를 본 뒤 물약을 먼저
## 시도하고 실패해야 후퇴한다(14:55/19:20 방식). 새 조건문 하나만 추가.
func _quest_should_retreat() -> bool:
	var hp_ratio := float($Player.health) / float($Player.max_health)
	if hp_ratio > GameState.AUTOHUNT_RETREAT_HP_RATIO:
		return false
	var enemies_near := 0
	var near_dist: float = $Player.attack_range * 2.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health > 0 and $Player.global_position.distance_to(enemy.global_position) <= near_dist:
			enemies_near += 1
	## (감독 2026-09-09 검증 실측) 모든 지역을 한 화면(1x1)으로 합치면서 몹
	## 밀도가 올라(forest_w 40마리) 근접≥4는 "위험"이 아니라 평소 상태가
	## 됐고, 물약 20개를 들고도 근접 규칙이 물약 시도보다 앞서 195/196회
	## 후퇴해 1장 1단계에서 136분·2장 4단계에서 500분+ 정체됐다(qm.log).
	## 물약이 있으면 마릿수와 무관하게 먼저 마신다 - 근접 규칙은 물약이
	## 없거나 못 마실 때만 남는다.
	if GameState.potions > 0 and $Player.try_use_potion():
		return false
	if enemies_near >= GameState.AUTOHUNT_RETREAT_ENEMIES:
		return true
	return _quest_can_recover()


## (INBOX 답, 2026-09-06 17:26) `_quest_hunt_goal_reached()`를 그대로 쓰면
## 포기 후 재개 지역(`_quest_grind_zone`)에서도 스토리 목표가 이미 채워져
## 있어 통과만 하고 사냥을 안 해 §10.7 포기 규칙("한 티어 아래에서 사냥
## 재개")이 한 번도 실행되지 않았다. 지금 있는 지역이 재개 지역이면
## 목표를 아직 안 채운 것으로 본다 - 그 지역 적을 한 바퀴(스폰 수만큼)
## 소탕할 때까지 기존 비목표 사냥 분기(추격)를 그대로 탄다.
func _quest_effective_goal_reached() -> bool:
	if GameState.current_map == _quest_grind_zone:
		return false
	return _quest_hunt_goal_reached(GameState.quest_stage)


## (INBOX 답, 2026-09-06 16:50) 통과 중(goal_reached, 스토리 목표를 채우고
## 동쪽 출구로 걸어 나가는 중) 응전: 추격(auto_hunt)은 켜지 않아
## auto_walk_active를 그대로 유지하되(5b8da29가 막은 재리스폰 무한 왕복
## 재발 없음), 이미 공격 사거리 안에 들어온 적만 attack()의 판정식
## (player.gd:589, offset.length() - body_radius() <= attack_range)과 같은
## 기준으로 찾아 그 자리에서 때린다 - 사람 플레이어도 통과 구간에서 옆에
## 붙은 적은 치면서 지나간다. 새 상수·새 함수 인자 없음.
func _quest_transit_engage() -> void:
	if $Player.cooldown_time > 0.0:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health <= 0:
			continue
		var offset: Vector2 = enemy.global_position - $Player.global_position
		if offset.length() - enemy.body_radius() <= $Player.attack_range:
			$Player.facing = offset.normalized()
			$Player.attack()
			return


## 바닥 드랍이 있고 근접(attack_range*2.5) 적이 없으면 가장 가까운 드랍으로
## 간다. 반경 안이면 auto_hunt(줍기 포함)에 맡기고, 밖이면 A* 이동 - 적
## 접근(`_quest_engage_nearest_enemy`)과 같은 구조. 줍기 자체는 Pickup의
## body_entered가 한다(새 줍기 로직 없음). 밟아도 안 줍히는 드랍(막힌 곳)은
## `_quest_set_auto_walk()` 정체 포기 뒤 `_quest_pickup_skip`에 넣어 다시
## 안 쫓는다.
func _quest_collect_nearby_pickup() -> bool:
	if _quest_transit_nearby_enemy():
		return false
	var near_dist: float = $Player.attack_range * 2.5
	var nearest: Node2D = null
	var nearest_dist := INF
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if _quest_pickup_skip.has(pickup.get_instance_id()):
			continue
		# 소품 충돌체 안 칸에 놓인 아이템은 닿을 수 없다 - 바로 건너뛴다.
		var cell := Vector2i((pickup.global_position / World.TILE).floor())
		if $World.walk_grid_solid_near(GameState.current_map, cell, 0)[cell]:
			_quest_pickup_skip[pickup.get_instance_id()] = true
			continue
		var d: float = $Player.global_position.distance_to(pickup.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = pickup
	if nearest == null:
		return false
	# (감독 2026-09-09 hill FREEZE) 가까운 아이템도 `_auto_hunt_tick`의 직선
	# 접근에 맡기지 않는다 - 나무 담 뒤 아이템을 향해 영원히 벽을 밀었다.
	# 거리와 무관하게 A*(`_quest_set_auto_walk`)로 가고, 재계획을 거듭해도
	# 못 닿으면(포기) 그 아이템은 이 지역에서 다시 보지 않는다.
	_quest_set_auto_walk(nearest.global_position)
	if not $Player.auto_walk_active:
		_quest_pickup_skip[nearest.get_instance_id()] = true
		return false
	$Player.auto_hunt = true
	return true


## (INBOX 답, 2026-09-07 00:12 ①) `_quest_should_retreat()`와 같은 반경
## (attack_range*2.5, 새 숫자 없음) 안에 살아있는 적이 하나라도 있는지만
## 본다 - 있으면 통과 중에도 그 적을 쫓게(auto_hunt) 하는 판정에 쓴다.
func _quest_transit_nearby_enemy() -> bool:
	var near_dist: float = $Player.attack_range * 2.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health > 0 and $Player.global_position.distance_to(enemy.global_position) <= near_dist:
			return true
	return false


## (INBOX 결함, 2026-09-07 10:34) `auto_hunt=true`만 켜 두면 `_auto_hunt_tick()`이
## 지도 전체에서 가장 가까운 살아있는 적을 향해 직선으로 접근하다 담(계단형
## 지형 등)에 막혀 무한 정지한다(hill_ridge/dungeon 재현, "hunt=true
## enemies_near=0" 로그). 가장 가까운 적이 `_quest_transit_nearby_enemy()`와
## 같은 반경(attack_range*2.5) 밖이면 `_quest_set_auto_walk()`로 A* 웨이포인트
## 접근을 먼저 시키고(player.gd에서 auto_walk가 auto_hunt보다 이동 우선이라
## 그대로 동작), 반경 안이면 auto_walk_active=false로 사냥에 넘긴다.
func _quest_engage_nearest_enemy() -> void:
	var near_dist: float = $Player.attack_range * 2.5
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health <= 0:
			continue
		var d: float = $Player.global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest != null and nearest_dist > near_dist:
		_quest_set_auto_walk(nearest.global_position)
	else:
		$Player.auto_walk_active = false
	$Player.auto_hunt = true


## 홈 텔레포트(물약 바닥, 3c18b54)와 역할이 겹치지 않도록 위험 후퇴는
## 이전 지역("w" 방향, `World.exit_of`)으로 한 칸만 물러난다. 같은 지역에서
## GIVEUP_STREAK회 연속 후퇴하면 그 지역을 포기하고 홈으로 돌아가, 다음에
## 사냥터로 나갈 때는 그 지역의 이전 지역(한 티어 아래)에서 다시 시작한다.
func _quest_do_retreat() -> void:
	## (INBOX 13:45 답) 후퇴는 `auto_hunt=false`로 전환하는데, HP 회복은
	## `player._auto_hunt_tick()`(물약 자동 사용)이 auto_hunt일 때만 돌아
	## 후퇴 중에는 영원히 회복이 안 돼 hill↔village를 무한 왕복하는 결함이
	## 있었다(INBOX 13:25 보정 실측). 새 회복 수단을 만들지 않고 기존
	## `try_use_potion()`을 후퇴 진입 시 한 번 그대로 재사용한다.
	$Player.try_use_potion()
	var area := GameState.current_map
	if area == _quest_retreat_zone:
		_quest_retreat_streak += 1
	else:
		_quest_retreat_zone = area
		_quest_retreat_streak = 1
	$Player.auto_hunt = false
	$Player.auto_walk_active = false
	var prev := World.exit_of(area, "w")
	if _quest_retreat_streak >= GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK:
		_quest_retreat_zone = ""
		_quest_retreat_streak = 0
		## (INBOX 답, 2026-09-07 00:45) 포기했으면 물약 조기 귀환의 "그
		## 자리로" 재개는 의미가 없다 - 한 티어 아래 재개(resume_zone)가
		## 우선한다.
		_quest_restock_zone = ""
		_quest_resume_zone = prev
		var home := _quest_home_town()
		if home != "" and GameState.unlocked_maps.has(home):
			_quest_travel_home(home)
	elif prev != "" and GameState.unlocked_maps.has(prev):
		## (INBOX 답, 2026-09-06 18:45 ②) 포기(giveup)까지 안 가는 매 후퇴도
		## 도착한 지역을 grind_zone으로 잡아 한 바퀴 소탕하게 한다 - 안 그러면
		## 스토리 목표를 이미 채운 지역(area)으로 되돌아가자마자 다시
		## goal_reached=true라 몹을 안 잡고 그대로 동쪽으로 재진입 →
		## 같은 위험에 다시 걸려 후퇴 → 재진입을 무한 반복한다(6740fea와
		## 같은 메커니즘 재사용, 새 상태 없음).
		_quest_grind_zone = prev
		_quest_travel_home(prev)


## 지금 장(chapter)의 홈 마을 이름. 없으면 "".
## (INBOX 10:05③) 3·4·10장은 설계상 마을이 없으므로, 정확히 일치하는 장이
## 없으면 직전에 풀린(chapter_of <= 현재 chapter) 마을 중 가장 최근 것을 쓴다.
func _quest_home_town() -> String:
	var best := ""
	var best_chapter := -1
	for t in World.TOWNS:
		var c: int = World.chapter_of(t)
		if c == GameState.chapter:
			return t
		if c <= GameState.chapter and c > best_chapter:
			best = t
			best_chapter = c
	return best


## (INBOX 13:25 보정) `_travel_to()`를 그대로 부르면 `_toggle_world_map()`이
## 지도를 열고 `set_modal_mode("map")`을 거치는데, 이 함수는 `mode != "dialogue"`
## and `game.quest_mode`일 때 스스로 `_toggle_quest_mode()`를 불러 퀘스트모드를
## 꺼 버린다(mobile_controls.gd:285) - 귀환·후퇴 포기·재개마다 quest_mode가
## 꺼지는 원인이었다(§10.7 실측: 마을에서 멈춘 채 진행 없음). 사람이 지도를
## 여는 경로(M키→위치 클릭)와 `set_modal_mode` 규칙은 그대로 두고, 퀘스트모드는
## 지도 UI를 아예 거치지 않도록 `_travel_to()` 안의 실제 이동 부분만 직접 호출한다.
func _quest_travel_home(home: String) -> void:
	Audio.play_sfx("accept")
	_change_map(home, false, Vector2(42, 135))
	$HUD/Message.text = "%s(으)로 이동했다." % World.title_of(GameState.current_map)


## 상점 UI를 열지 않고 `SHOP_STOCK`(2830줄 부근)의 "회복약" 항목 가격을
## 그대로 조회한다 - 가격은 상점과 한 곳(SHOP_STOCK)에만 있어야 하므로
## 여기서 새로 정하지 않는다.
func _quest_potion_price() -> int:
	for entry in SHOP_STOCK:
		if str(entry["item"]) == "회복약":
			return int(entry["price"])
	return 20


## 물약이 가득 차거나 골드가 모자랄 때까지 `GameState.buy()`를 반복
## 호출한다(상점 UI를 열지 않음 - `_buy_shop_item()`이 하는 일과 같은
## 상태 갱신만 그대로 재사용).
## (감독 2026-09-08) 능력치 점수·특성·전직은 사용자가 직접 한다 - 퀘스트모드가
## 대신 쓰던 `_quest_auto_grow`는 사용자 지시로 제거.
func _quest_buy_potions(price: int) -> void:
	while GameState.potions < GameState.potion_cap() and GameState.gold >= price:
		GameState.buy("회복약", price)
	$Player.potions = GameState.potions
	_on_potion_changed($Player.potions)


## 지역 동쪽 exit 경계 너머로 목표를 잡아 `_try_exit`(§「지역 전환」,
## 165~175줄)의 `at.x >= bounds.x - EDGE_MARGIN` 판정을 반드시 지나가게
## 한다. `_east_spawn()`(201줄)은 그 경계 12px 안쪽이라 그대로 쓰면 딱
## 멈춰 서서 못 넘어간다.
## (INBOX 답, 2026-09-06 20:15) 예전엔 목표 y를 `World.path_row(area)`
## (지역 세로 중앙 고정값)로 잡아 직선으로 걸었는데, 길은 `PATH_BEND_PERIOD`
## (4칸)마다 굽이쳐서 그 직선이 길 밖 바위 지대를 지나 박히는 정지(STALL)가
## 있었다(20:10 질문 실측). 매 호출(0.6초 `_quest_mode_tick`)마다 플레이어의
## 지금 열에서 몇 칸 앞선 열의 실제 길 행(`World.path_row_at`)을 목표로
## 다시 잡는다. 굽이가 바뀔 때마다 목표가 따라가므로 직선이 아니라 길을
## 따라가게 된다. 회피 로직(player.gd `_auto_avoid_obstacle`)은 코너 소품용
## 으로 그대로 둔다.
## (INBOX 보정, 2026-09-06 22:08) x까지 지역 끝(`bounds.x - 4`)으로 고정하면
## 남은 거리가 멀 때(예: 20열에서 60열 끝까지) 그 먼 목표까지 직선으로 가
## 버려 y 굽이 보정이 희석돼 여전히 길 밖으로 나갔다(20:15 수정의 재발).
## x도 앞내다본 열(`look`칸 앞)로 잡아 중간 목표가 되게 하고, 그 열이
## 이미 지역 끝을 넘었을 때만 진짜 동쪽 경계로 향한다.
## (INBOX 23:31 STALL 후속) 먼 앞선 열까지 대각선으로 곧장 가기 전에, 지금
## 서 있는 열 기준으로 길에서 너무 멀면(`QUEST_OFF_PATH_MARGIN`) 그 열의
## 길로 먼저 돌아오는 것부터 목표로 삼는다 - 세로 한 방향으로만 움직이므로
## 옆걸음 회피(player.gd `_auto_avoid_obstacle`)가 뚫어야 할 소품 지대
## 폭이 대각선 직행보다 훨씬 좁아진다.
## (INBOX 답, 2026-09-07 08:10) 목표만 던지던 자리를 이 함수로 모아
## `World.walk_waypoints()`(AStarGrid2D)로 실제 경로를 구해 같이 세팅한다.
## `auto_walk_target`은 그대로 최종 목표를 담아 기존 검사(예:
## check_quest_transit_chase.gd)의 직접 비교와 호환된다.
## (INBOX 결함, 2026-09-07 11:50/12:35) marsh cell(34,22) 등에서 격자는
## 걷기 가능이라 봤는데 실제 물리 충돌체가 막아 auto_walk가 웨이포인트를
## 향해 영원히 미는 경우가 실측됐다 - auto_hunt의 무진행 포기(player.gd
## `_AUTO_HUNT_GIVEUP_STUCK`, 새 숫자 아님 재사용)와 같은 보호를 여기도
## 둔다. 이 함수는 매 퀘스트틱(0.6초)마다 호출되므로 같은 목표로 부른
## 횟수를 시간 대신 세어 판정한다(tick 수 * 0.6초 ≈ 초).
## 격자를 다시 지어도 무진행이 반복되면(격자-물리 불일치처럼 재계획으로
## 못 고치는 원인) 이 횟수만큼 재시도한 뒤 완전히 포기한다.
const _QUEST_WALK_STUCK_CYCLES_GIVEUP := 2
## 정체 포기한 드랍의 instance id. 지역을 바꾸면 노드가 사라지므로 그때 비운다.
var _quest_pickup_skip := {}
var _quest_walk_target := Vector2.ZERO
var _quest_walk_best_dist := INF
var _quest_walk_stuck_ticks := 0
var _quest_walk_stuck_cycles := 0
const _QUEST_MODE_TICK_SEC := 0.6 ## _quest_timer.wait_time(165줄)과 같은 값.

func _quest_set_auto_walk(target: Vector2) -> void:
	var dist: float = $Player.global_position.distance_to(target)
	if target != _quest_walk_target:
		_quest_walk_target = target
		_quest_walk_best_dist = dist
		_quest_walk_stuck_ticks = 0
		_quest_walk_stuck_cycles = 0
	elif dist < _quest_walk_best_dist - 4.0:
		_quest_walk_best_dist = dist
		_quest_walk_stuck_ticks = 0
		_quest_walk_stuck_cycles = 0
	else:
		_quest_walk_stuck_ticks += 1
		if _quest_walk_stuck_ticks * _QUEST_MODE_TICK_SEC >= $Player._AUTO_HUNT_GIVEUP_STUCK:
			_quest_walk_stuck_ticks = 0
			_quest_walk_best_dist = dist
			_quest_walk_stuck_cycles += 1
			if _quest_walk_stuck_cycles >= _QUEST_WALK_STUCK_CYCLES_GIVEUP:
				## 재계획을 거듭해도 못 벗어난다 - 이 틱의 auto_walk를 접어
				## 상태머신이 다음 틱에 목표를 다시 고르게 한다(사냥 포기와
				## 같은 흐름, player.gd `_auto_hunt_tick`의 blacklist 참고).
				_quest_walk_stuck_cycles = 0
				_quest_walk_target = Vector2.ZERO
				$Player.auto_walk_active = false
				return
			$World.invalidate_walk_grid()
	$Player.auto_walk_target = target
	$Player.auto_walk_waypoints = $World.walk_waypoints(GameState.current_map, $Player.global_position, target)
	$Player.auto_walk_active = true


func _quest_east_exit_target(area: String) -> Vector2:
	## (감독 2026-09-08, 10장 탐침 marsh_deep 305분 STALL) 앞내다본 열의
	## `path_row_at`(그 열 길 행의 평균)은 세로 3화면 지역에서 길이 같은
	## 열을 두 번 지나면 길 밖 중간 행으로 떨어지고, 그리로 가다 보면
	## `nearest_path_row_at` 기준으로는 "길 밖"이라 다시 원래 행으로 되돌리는
	## 목표가 잡혀 두 목표 사이를 영원히 왕복했다(y=584↔376). 위 앞내다보기·
	## 길 복귀는 직선 이동 시절의 보정이고 지금은 `_quest_set_auto_walk()`가
	## A*(`World.walk_waypoints`)로 실제 경로를 구하므로, 목표는 동쪽 출구
	## 하나로 고정한다. citadel_gate cell(14,16)처럼 길 행 위에 소품이 있어
	## "길 복귀" 목표 자체가 충돌체 안이던 STALL도 같이 사라진다.
	var bounds := World.pixel_size_of(area)
	var size := World.size_of(area)
	return Vector2(bounds.x - 4.0, $World.path_row_at(area, size.x - 1) * World.TILE + 8.0)


func _toggle_world_map() -> void:
	world_map_open = not world_map_open
	$HUD/WorldMap.visible = world_map_open
	$HUD/MobileControls.set_modal_mode("map" if world_map_open else "")
	get_tree().paused = world_map_open
	_sync_modal_hud_visibility()
	if world_map_open:
		_refresh_world_map()


func _refresh_world_map() -> void:
	$HUD/MobileControls.set_interact_label("이동")
	$HUD/WorldMap/Graph.focus_current()


## 지도에서 고른 곳으로 바로 이동한다. 보스를 잡고 촌장에게 돌아갈 때
## 지역을 하나씩 걸어서 지나가야 했던 것을 없앤다.
func _travel_to(map_name: String) -> void:
	_toggle_world_map()
	Audio.play_sfx("accept")
	if map_name == "tower":
		_toggle_tower_select()
		return
	# 이동주문서 1장 소모. 0장이면 world_map.try_travel()이 먼저 거절하므로 여기까지 오지 않는다.
	GameState.scrolls = maxi(GameState.scrolls - 1, 0)
	_change_map(map_name, false, Vector2(42, 135))
	_update_skill_bar()
	$HUD/Message.text = "%s(으)로 이동했다. (이동주문서 %d장 남음)" % [World.title_of(GameState.current_map), GameState.scrolls]


## 진행 중인 의뢰가 있으면 본 퀘스트 안내 뒤에 함께 붙인다.
func _bounty_note() -> String:
	var note: String = GameState.bounty_progress_text()
	return "   " + note if note != "" else ""


func _update_quest_message() -> void:
	_set_quest_message()
	$HUD/Message.text += _bounty_note()


## 장 진행 문구. HUD 한 줄과 퀘스트 현황 화면이 같은 문구를 쓴다.
## (INBOX 답, 2026-09-06 16:09 ③) `_quest_stage_text()`의 처치 목표 숫자가
## `GameState.QUEST_HUNT_TARGETS`와 따로 적혀 있던 것(3e2f8ff 잔여)을 정리 -
## 숫자는 그 표 한 곳에만 있고 여기는 조회만 한다(규칙③).
func _quest_hunt_target(stage: int) -> int:
	return int(GameState.QUEST_HUNT_TARGETS[stage]["target"])


func _quest_stage_text() -> String:
	match GameState.quest_stage:
		0: return "촌장에게 다가가 E키로 대화"
		1: return "숲의 마물 처치  %d/%d" % [mini(GameState.kills, _quest_hunt_target(1)), _quest_hunt_target(1)] if GameState.kills < _quest_hunt_target(1) else "숲 동쪽 수호자 동굴로 가자"
		2: return "M키 지도로 마을에 돌아가 보상을 받자"
		3: return "촌장과 다시 대화하면 2장 시작"
		4: return "잿빛 폐허의 흑기사 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(4)), _quest_hunt_target(4)] if GameState.chapter_kills < _quest_hunt_target(4) else "검은 성채로 진입하자"
		5: return "M키 지도로 마을에 돌아가 다음 이야기를 듣자"
		6: return "서리벌 설원의 마물 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(6)), _quest_hunt_target(6)] if GameState.chapter_kills < _quest_hunt_target(6) else "얼어붙은 신전으로 들어가자"
		7: return "M키 지도로 마을에 돌아가 다음 이야기를 듣자"
		8: return "잿불 황야를 지나 심연의 왕좌로"
		9: return "M키 지도로 마을에 돌아가 결말을 확인하자"
		10: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 5장 시작"
		11: return "유민의 땅 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(11)), _quest_hunt_target(11)] if GameState.chapter_kills < _quest_hunt_target(11) else "근원의 균열로 들어가자"
		19: return "M키 지도로 마을에 돌아가 확장팩 결말을 확인하자"
		20: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 6장 시작"
		21: return "파편의 바다 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(21)), _quest_hunt_target(21)] if GameState.chapter_kills < _quest_hunt_target(21) else "파수꾼의 암초로 들어가자"
		29: return "M키 지도로 마을에 돌아가 6장 결말을 확인하자"
		30: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 7장 시작"
		31: return "잊힌 성소 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(31)), _quest_hunt_target(31)] if GameState.chapter_kills < _quest_hunt_target(31) else "빛바랜 성소로 들어가자"
		39: return "M키 지도로 마을에 돌아가 7장 결말을 확인하자"
		40: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 8장 시작"
		41: return "침묵의 회랑 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(41)), _quest_hunt_target(41)] if GameState.chapter_kills < _quest_hunt_target(41) else "감독관의 방으로 들어가자"
		49: return "M키 지도로 마을에 돌아가 8장 결말을 확인하자"
		50: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 9장 시작"
		51: return "역전의 탑 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(51)), _quest_hunt_target(51)] if GameState.chapter_kills < _quest_hunt_target(51) else "역전의 옥좌로 들어가자"
		59: return "M키 지도로 마을에 돌아가 9장 결말을 확인하자"
		60: return "M키 지도로 마을에 돌아가 촌장과 다시 대화하면 10장 시작"
		61: return "근원 몬스터 처치  %d/%d" % [mini(GameState.chapter_kills, _quest_hunt_target(61)), _quest_hunt_target(61)] if GameState.chapter_kills < _quest_hunt_target(61) else "근원의 옥좌로 들어가자"
		69: return "M키 지도로 마을에 돌아가 결말을 확인하자"
		_: return "게임 클리어"


func _set_quest_message() -> void:
	$HUD/Message.text = _mob(_quest_stage_text())


## 지역별 몬스터 배치. 지역에 들어갈 때마다 이 표대로 새로 깔린다.
## tier 가 높을수록 체력·공격·보상이 함께 오른다.
const AREA_SPAWNS := {
	"village": [], "harbor": [], "frost_camp": [], "abyss": [], "origin_camp": [],
	"frost_ridge": [{"kind": "panda", "tier": 6, "count": 6}, {"kind": "owl", "tier": 6, "count": 5}],
	"ash_hollow": [{"kind": "cyclope", "tier": 6, "count": 8}, {"kind": "flam", "tier": 6, "count": 7},
		{"kind": "skull", "tier": 6, "count": 5}],
	"hill": [{"kind": "beast", "tier": 1, "count": 5}, {"kind": "snake", "tier": 1, "count": 4}],
	# 사냥터. 이야기와 무관하게 잡기만 하러 가는 곳이라 같은 장에서 한 단계 더 세다.
	"hill_ridge": [{"kind": "beast", "tier": 2, "count": 6}, {"kind": "snake", "tier": 2, "count": 5}],
	# 동서남북 던전(현재는 부모 지역의 landmarks/scatter로 흡수됐지만,
	# 그 구역 전용 몬스터는 부모 스폰 목록에 그대로 추가해 유지한다).
	"glade": [{"kind": "mushroom", "tier": 1, "count": 5}, {"kind": "beast", "tier": 1, "count": 4},
		{"kind": "eye", "tier": 3, "count": 4}, {"kind": "skull", "tier": 3, "count": 3}],
	# 옛 forest_w/forest_n/forest_e 3개 지역의 스폰을 한 목록으로 합쳤다(INBOX D).
	"forest_w": [{"kind": "beast", "tier": 1, "count": 6}, {"kind": "mushroom", "tier": 1, "count": 5},
		{"kind": "snake", "tier": 1, "count": 4}, {"kind": "mushroom", "tier": 1, "count": 6},
		{"kind": "beast", "tier": 2, "count": 4}, {"kind": "beast", "tier": 2, "count": 6},
		{"kind": "snake", "tier": 2, "count": 5}, {"kind": "mushroom", "tier": 2, "count": 4}],
	"dungeon": [{"kind": "bat", "tier": 2, "count": 7}, {"kind": "slime", "tier": 2, "count": 6},
		{"kind": "skull", "tier": 2, "count": 5}],
	"cave_deep": [{"kind": "skull", "tier": 3, "count": 5}, {"kind": "bat", "tier": 3, "count": 4}],
	"shore": [{"kind": "octopus", "tier": 2, "count": 6}, {"kind": "kappa", "tier": 2, "count": 5}],
	"marsh": [{"kind": "kappa", "tier": 3, "count": 6}, {"kind": "slime", "tier": 3, "count": 5},
		{"kind": "spirit", "tier": 3, "count": 4}],
	"marsh_deep": [{"kind": "kappa", "tier": 4, "count": 6}, {"kind": "slime", "tier": 4, "count": 5},
		{"kind": "spirit", "tier": 4, "count": 4}, {"kind": "mollusc", "tier": 5, "count": 4},
		{"kind": "octopus", "tier": 5, "count": 3}],
	# 옛 ruins_w/watchtower/ruins_e 3개 지역의 스폰을 한 목록으로 합쳤다(INBOX D).
	"ruins_w": [{"kind": "knight", "tier": 3, "count": 7}, {"kind": "spirit", "tier": 3, "count": 5},
		{"kind": "skull", "tier": 3, "count": 5}, {"kind": "knight", "tier": 3, "count": 5},
		{"kind": "spirit", "tier": 4, "count": 4}, {"kind": "knight", "tier": 4, "count": 6},
		{"kind": "skull", "tier": 4, "count": 5}, {"kind": "flam", "tier": 4, "count": 4}],
	"citadel_gate": [{"kind": "knight", "tier": 4, "count": 6}, {"kind": "cyclope", "tier": 4, "count": 4}],
	"citadel": [{"kind": "knight", "tier": 4, "count": 6}, {"kind": "flam", "tier": 4, "count": 5},
		{"kind": "cyclope", "tier": 4, "count": 5}],
	"snowfield": [{"kind": "panda", "tier": 5, "count": 6}, {"kind": "larva", "tier": 5, "count": 6},
		{"kind": "owl", "tier": 5, "count": 5}],
	"frost_gorge": [{"kind": "panda", "tier": 6, "count": 6}, {"kind": "owl", "tier": 6, "count": 5},
		{"kind": "frostbear", "tier": 7, "count": 4}],
	"frozen_falls": [{"kind": "larva", "tier": 6, "count": 6}, {"kind": "owl", "tier": 6, "count": 5},
		{"kind": "panda", "tier": 6, "count": 4}],
	"blizzard_plain": [{"kind": "panda", "tier": 6, "count": 6}, {"kind": "larva", "tier": 6, "count": 5},
		{"kind": "owl", "tier": 6, "count": 5}],
	"glacier": [{"kind": "larva", "tier": 5, "count": 7}, {"kind": "owl", "tier": 5, "count": 5},
		{"kind": "panda", "tier": 6, "count": 4}],
	"temple": [{"kind": "owl", "tier": 6, "count": 5}, {"kind": "larva", "tier": 6, "count": 5},
		{"kind": "spirit", "tier": 6, "count": 5}],
	"ash_ridge": [{"kind": "cyclope", "tier": 6, "count": 6}, {"kind": "flam", "tier": 6, "count": 5},
		{"kind": "dragon", "tier": 9, "count": 3}, {"kind": "spirit", "tier": 9, "count": 3}],
	"ember_valley": [{"kind": "flam", "tier": 6, "count": 6}, {"kind": "skull", "tier": 6, "count": 5},
		{"kind": "cyclope", "tier": 6, "count": 5}],
	"charred_corridor": [{"kind": "skull", "tier": 6, "count": 6}, {"kind": "cyclope", "tier": 6, "count": 5}],
	"ash_marsh": [{"kind": "spirit", "tier": 6, "count": 6}, {"kind": "flam", "tier": 6, "count": 5},
		{"kind": "skull", "tier": 6, "count": 5}],
	"throne": [{"kind": "cyclope", "tier": 6, "count": 5}, {"kind": "flam", "tier": 6, "count": 5},
		{"kind": "knight", "tier": 6, "count": 5}],
	# --- 5장 유민의 땅 ---
	"remnant_village": [],
	"collapsed_spires": [{"kind": "wraith_soldier", "tier": 7, "count": 6},
		{"kind": "floating_shard", "tier": 7, "count": 5}],
	"eroded_plaza": [{"kind": "floating_shard", "tier": 7, "count": 6},
		{"kind": "wraith_soldier", "tier": 7, "count": 5}],
	"cracked_statue": [{"kind": "wraith_soldier", "tier": 7, "count": 6},
		{"kind": "rampaging_golem", "tier": 7, "count": 5}],
	"hall_of_afterimages": [{"kind": "wraith_soldier", "tier": 8, "count": 6},
		{"kind": "corruptor", "tier": 8, "count": 5}],
	"twisted_sanctum": [{"kind": "corruptor", "tier": 8, "count": 6},
		{"kind": "shard_watcher", "tier": 8, "count": 5}],
	"rift_of_origin": [{"kind": "shard_watcher", "tier": 8, "count": 5},
		{"kind": "corruptor", "tier": 8, "count": 5}, {"kind": "rampaging_golem", "tier": 8, "count": 5}],
	# --- 6장 파편의 바다 ---
	"driftwood_pier": [],
	"sunken_causeway": [{"kind": "tideclaw", "tier": 9, "count": 6},
		{"kind": "depth_eye", "tier": 9, "count": 5}],
	"tideglass_shallows": [{"kind": "depth_eye", "tier": 9, "count": 6},
		{"kind": "tideclaw", "tier": 9, "count": 5}],
	"current_maw": [{"kind": "driftghoul", "tier": 9, "count": 6},
		{"kind": "coral_sentinel", "tier": 9, "count": 5}],
	"coral_wreckage": [{"kind": "coral_sentinel", "tier": 10, "count": 6},
		{"kind": "tidecaster", "tier": 10, "count": 5}],
	"abyssal_trench": [{"kind": "tidecaster", "tier": 10, "count": 6},
		{"kind": "driftghoul", "tier": 10, "count": 5}],
	"the_watcher_reef": [{"kind": "tidecaster", "tier": 10, "count": 5},
		{"kind": "coral_sentinel", "tier": 10, "count": 5}, {"kind": "depth_eye", "tier": 10, "count": 5}],
	# --- 7장 잊힌 성소 ---
	"lantern_village": [],
	"sunbleached_stair": [{"kind": "faded_acolyte", "tier": 11, "count": 6},
		{"kind": "relic_eye", "tier": 11, "count": 5}],
	"vow_terrace": [{"kind": "gilded_wraith", "tier": 11, "count": 6},
		{"kind": "faded_acolyte", "tier": 11, "count": 5}],
	"gilded_cloister": [{"kind": "choir_caster", "tier": 11, "count": 6},
		{"kind": "relic_eye", "tier": 11, "count": 5}],
	"hollow_nave": [{"kind": "bell_golem", "tier": 11, "count": 6},
		{"kind": "gilded_wraith", "tier": 11, "count": 5}],
	"ashen_reliquary": [{"kind": "choir_caster", "tier": 11, "count": 6},
		{"kind": "bell_golem", "tier": 11, "count": 5}],
	"sanctum_of_light": [{"kind": "choir_caster", "tier": 11, "count": 5},
		{"kind": "bell_golem", "tier": 11, "count": 5}, {"kind": "relic_eye", "tier": 11, "count": 5}],
	# --- 8장 침묵의 회랑 ---
	"waystation_camp": [],
	"threshold_stair": [{"kind": "muted_stalker", "tier": 12, "count": 6},
		{"kind": "echo_wraith", "tier": 12, "count": 5}],
	"muted_gallery": [{"kind": "warden_scribe", "tier": 12, "count": 5},
		{"kind": "grey_sentinel", "tier": 12, "count": 5}],
	"silent_archive": [{"kind": "echo_wraith", "tier": 12, "count": 6},
		{"kind": "muted_stalker", "tier": 12, "count": 5}],
	"hollow_barracks": [{"kind": "silence_golem", "tier": 12, "count": 6},
		{"kind": "warden_scribe", "tier": 12, "count": 5}],
	"grey_reservoir": [{"kind": "grey_sentinel", "tier": 12, "count": 6},
		{"kind": "silence_golem", "tier": 12, "count": 5}],
	"chamber_of_wardens": [{"kind": "warden_scribe", "tier": 12, "count": 5},
		{"kind": "silence_golem", "tier": 12, "count": 5}, {"kind": "grey_sentinel", "tier": 12, "count": 5}],
	# --- 9장 역전의 탑 ---
	"rift_camp": [],
	"inverted_stair": [{"kind": "twisted_knight", "tier": 13, "count": 6},
		{"kind": "twisted_beast", "tier": 13, "count": 5}],
	"echo_of_forest": [{"kind": "twisted_beast", "tier": 13, "count": 6},
		{"kind": "reversed_wisp", "tier": 13, "count": 5}],
	"echo_of_captain": [{"kind": "twisted_knight", "tier": 13, "count": 6},
		{"kind": "seam_walker", "tier": 13, "count": 5}],
	"echo_of_frost": [{"kind": "paradox_caster", "tier": 13, "count": 6},
		{"kind": "reversed_wisp", "tier": 13, "count": 5}],
	"echo_of_abyss": [{"kind": "seam_walker", "tier": 13, "count": 6},
		{"kind": "twisted_knight", "tier": 13, "count": 5}],
	"the_seam": [{"kind": "paradox_caster", "tier": 13, "count": 6},
		{"kind": "seam_walker", "tier": 13, "count": 5}],
	"throne_of_reversal": [{"kind": "twisted_knight", "tier": 13, "count": 5},
		{"kind": "paradox_caster", "tier": 13, "count": 5}, {"kind": "seam_walker", "tier": 13, "count": 5}],	# 10장 근원의 길(합친 지역). 옥좌 앞 마지막 사냥터라 9장 옥좌와 같은 셋.
	"origin_gate": [{"kind": "paradox_caster", "tier": 13, "count": 6},
		{"kind": "seam_walker", "tier": 13, "count": 6}, {"kind": "twisted_knight", "tier": 13, "count": 5}],
}


## 등급별 기본 수치. 몬스터를 늘릴 때 숫자를 일일이 적지 않아도 된다.
## 7~9는 동서남북 던전(특히 동쪽 심연 너머, 클리어 후 도전하는 곳)을
## 위해 늘렸다. 6까지의 곡선을 그대로 이어간다.
const TIERS := {
	1: {"hp": 95, "damage": 14, "speed": 31.0, "exp": 10, "gold": 6},
	2: {"hp": 155, "damage": 20, "speed": 35.0, "exp": 15, "gold": 10},
	3: {"hp": 235, "damage": 28, "speed": 38.0, "exp": 21, "gold": 14},
	4: {"hp": 310, "damage": 36, "speed": 40.0, "exp": 28, "gold": 19},
	5: {"hp": 390, "damage": 46, "speed": 42.0, "exp": 38, "gold": 26},
	6: {"hp": 470, "damage": 58, "speed": 44.0, "exp": 50, "gold": 34},
	7: {"hp": 570, "damage": 72, "speed": 45.0, "exp": 65, "gold": 44},
	8: {"hp": 690, "damage": 88, "speed": 46.0, "exp": 84, "gold": 56},
	9: {"hp": 840, "damage": 108, "speed": 47.0, "exp": 108, "gold": 72},
	# 6장(파편의 바다)용으로 이어서 늘린다.
	10: {"hp": 1010, "damage": 130, "speed": 48.0, "exp": 138, "gold": 92},
	# 7장(잊힌 성소)용으로 이어서 늘린다.
	11: {"hp": 1210, "damage": 156, "speed": 49.0, "exp": 175, "gold": 116},
	# 8장(침묵의 회랑)용으로 이어서 늘린다.
	12: {"hp": 1440, "damage": 186, "speed": 50.0, "exp": 220, "gold": 148},
	# 9장(역전의 탑)용으로 이어서 늘린다.
	13: {"hp": 1720, "damage": 222, "speed": 51.0, "exp": 275, "gold": 188},
}


## 잠긴 문과 열쇠. 문은 길을 막고, 열쇠는 그 지역 어딘가에 떨어져 있다.
## 던전이 그냥 지나가는 통로가 아니라 한 번은 훑어야 하는 곳이 된다.
const AREA_DOORS := {
	"dungeon": {"key": "dungeon_key", "label": "녹슨 열쇠"},
	"ruins_w": {"key": "ruins_key", "label": "흑철 열쇠"},
	"glacier": {"key": "glacier_key", "label": "성에 낀 열쇠"},
	"ash_hollow": {"key": "abyss_key", "label": "잿빛 열쇠"},
}


## 문을 지역 가운데 길목에 세우고, 열쇠는 멀찍이 떨어뜨린다.
func _spawn_area_doors(map_name: String) -> void:
	var entry: Dictionary = AREA_DOORS.get(map_name, {})
	if entry.is_empty():
		return
	var door_id := str(entry["key"])
	var size := World.size_of(map_name)
	var row := World.path_row(map_name)
	if not GameState.opened_doors.has(door_id):
		var door := preload("res://scenes/door.tscn").instantiate()
		door.door_id = door_id
		door.span = 3
		# 길이 지나는 자리를 가로막는다. 가운데보다 조금 뒤쪽.
		door.position = Vector2(int(size.x * 0.62) * World.TILE, (row - 1) * World.TILE)
		door.opened.connect(_on_door_opened)
		door.refused.connect(_on_door_refused.bind(str(entry["label"])))
		add_child(door)
	if not GameState.has_key(door_id) and not GameState.opened_doors.has(door_id):
		var rng := RandomNumberGenerator.new()
		rng.seed = World._seed_of(map_name) + 211
		var cell := Vector2i.ZERO
		for tries in 80:
			cell = Vector2i(rng.randi_range(3, int(size.x * 0.5)), rng.randi_range(3, size.y - 4))
			if $World.walkable(map_name, cell) and not $World.walk_grid_solid_near(map_name, cell, 0)[cell]:
				break
		var key := preload("res://scenes/pickup.tscn").instantiate()
		key.kind = "key"
		key.key_id = door_id
		key.position = Vector2(cell) * World.TILE + Vector2(8, 8)
		key.collected.connect(_on_pickup_collected)
		add_child(key)


func _on_door_opened(_door_id: String) -> void:
	Audio.play_sfx("accept")
	$HUD/Message.text = "문이 열렸다."


func _on_door_refused(_door_id: String, label: String) -> void:
	$HUD/Message.text = "잠겨 있다. %s가 필요하다." % label


## 지역에 숨겨진 보물상자. 한 번 열면 다시 나오지 않는다.
const AREA_CHESTS := {
	"hill": [{"id": "hill_a", "item": "가죽 모자"}],
	"forest_w": [{"id": "forest_a", "item": "구리 반지"}, {"id": "forest_n_a", "item": "사냥꾼의 활"},
		{"id": "forest_e_a", "item": "철검"}],
	"glade": [{"id": "glade_a", "item": "가죽 갑옷"}],
	"dungeon": [{"id": "dungeon_a", "item": "철 투구"}, {"id": "dungeon_b", "item": "강철 대검"}],
	"cave_deep": [{"id": "cave_a", "item": "사슬 갑옷"}],
	"shore": [{"id": "shore_a", "item": "수정 목걸이"}],
	"marsh": [{"id": "marsh_a", "item": "서리 단검"}],
	"ruins_w": [{"id": "ruins_a", "item": "파수병 흉갑"}, {"id": "watch_a", "item": "파수병 투구"},
		{"id": "ruins_e_a", "item": "정령의 부적"}],
	"citadel_gate": [{"id": "gate_a", "item": "흑기사 갑주"}],
	"citadel": [{"id": "citadel_a", "item": "수호자의 검"}],
	"snowfield": [{"id": "snow_a", "item": "서리왕관"}],
	"glacier": [{"id": "glacier_a", "item": "설원의 망토"}, {"id": "glacier_b", "item": "영혼 사수의 활"}],
	"temple": [{"id": "temple_a", "item": "빙결의 창"}],
	"ash_hollow": [{"id": "abyss_a", "item": "정령의 부적"}],
	"throne": [{"id": "throne_a", "item": "수호자의 검"}],
}


func _spawn_area_chests(map_name: String) -> void:
	var size := World.size_of(map_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = World._seed_of(map_name) + 97
	for entry in AREA_CHESTS.get(map_name, []):
		var cell := Vector2i.ZERO
		for tries in 80:
			cell = Vector2i(rng.randi_range(3, size.x - 4), rng.randi_range(3, size.y - 4))
			# 소품 칸(나무 담 등)에 놓인 상자는 아무도 못 줍고 퀘스트모드가
			# 영원히 민다(hill_a FREEZE, 2026-09-09) - 걷기 격자 기준 빈 칸만.
			if $World.walkable(map_name, cell) and not $World.walk_grid_solid_near(map_name, cell, 0)[cell]:
				break
		if GameState.opened_chests.has(entry["id"]):
			continue
		var chest := preload("res://scenes/pickup.tscn").instantiate()
		chest.kind = "chest"
		chest.item_name = str(entry["item"])
		chest.chest_id = str(entry["id"])
		chest.position = Vector2(cell) * World.TILE + Vector2(8, 8)
		chest.collected.connect(_on_pickup_collected)
		add_child(chest)


## 지역 크기에 맞춰 몬스터 자리를 만든다. 표에는 종류와 등급만 적고
## 위치는 걸어 다닐 수 있는 칸 중에서 고른다. 맵이 넓어져 손으로 다 적을 수 없다.
## 사냥터(스토리 진행과 무관한 파밍 전용 지역) 중 중간보스가 나오는 곳.
## 각 장(1~4장)의 대표 사냥터 하나씩. 그 지역 스폰 목록에서 3번째·6번째
## 몬스터가 중간보스로 바뀐다. "사냥터 1장에 6개 있으면 3번째 6번째에
## 중간보스를 끼워넣는다" 요청 그대로 반영. 처치 시 전직의 돌 확정 드랍.
const MIDBOSS_AREAS := ["hill_ridge", "marsh_deep", "frost_ridge", "ash_hollow", "cracked_statue", "hall_of_afterimages",
	"current_maw", "abyssal_trench", "gilded_cloister", "ashen_reliquary", "silent_archive", "grey_reservoir",
	"echo_of_captain", "the_seam", "origin_gate"]
## 몇 번째 스폰 자리(0-index)를 중간보스로 바꿀지. 3번째=index 2, 6번째=index 5.
const MIDBOSS_SLOTS := [2, 5]


func _area_spawn_points(map_name: String) -> Array:
	var roster: Array = AREA_SPAWNS.get(map_name, [])
	if roster.is_empty():
		return []
	var size := World.size_of(map_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = World._seed_of(map_name) + 31
	var points: Array = []
	## (감독 2026-09-09 "몬스터가 겹쳐서 빠르게 움직이는 것처럼 보인다") 같은
	## 칸에 두 마리가 깔리면 CharacterBody2D 둘이 매 프레임 서로 밀어내며
	## 떨린다(1x1 통합으로 한 지역 40마리가 되자 자주 겹침). 쓴 칸은 다시
	## 안 쓴다(`tests/check_spawn_points_unique.gd`).
	var taken := {}
	for entry in roster:
		for i in int(entry.get("count", 1)):
			var cell := Vector2i.ZERO
			for tries in 60:
				cell = Vector2i(rng.randi_range(3, size.x - 4), rng.randi_range(3, size.y - 4))
				# walkable()은 소품을 모른다 - 소품 칸에 깔린 몹은 닿을 수 없어
				# 퀘스트/오토사냥이 영원히 민다(1x1 통합 뒤 실제 발생). 걷기
				# 격자(소품 포함) 기준으로 빈 칸만 받는다.
				if not taken.has(cell) and $World.walkable(map_name, cell) and not $World.walk_grid_solid_near(map_name, cell, 0)[cell]:
					break
			taken[cell] = true
			points.append({"kind": entry["kind"], "tier": entry["tier"],
				"at": Vector2(cell) * World.TILE + Vector2(8, 8)})
	if MIDBOSS_AREAS.has(map_name):
		for slot in MIDBOSS_SLOTS:
			if slot < points.size():
				points[slot]["midboss"] = true
	return points


## 지역의 잡몹을 새로 깐다. 자기 지역의 보스는 건드리지 않는다.
## (INBOX 결함, 2026-09-07 §10.7 5시드 프로브) 중간보스는 `is_boss`가
## 아니라서 이 함수가 실행될 때마다(재입장 포함) 살아있어도 치우고 새로
## 풀피로 다시 깠다 - 후퇴해 물약을 채우고 돌아오면 중간보스 체력이
## 매번 리셋돼, hill_ridge 서쪽 입구 근처에서 5시드 전부 영구 정체를
## 냈다(auto_quest_probe 재현, 근거 AUTOHUNT_DESIGN.md §10.7).
## **첫 시도(area_id==map_name 일 때만 group에 남기고 보존)는 실패 두 번**:
## (1) 후퇴는 반드시 다른 맵(마을)을 거치는데, 그 맵을 스폰할 때
## `map_name`이 "village"라 hill_ridge 중간보스는 area_id 불일치로 그대로
## 치워졌다(check_midboss_persist_on_reentry ③). (2) 지역과 무관하게 그룹에
## 남긴 채 안 보이게만 하자(visible=false 등) integration_test 의
## `spawned_kinds()`처럼 "enemies" 그룹 전체를 세는 검사·로직이 다른 지역의
## 비활성 중간보스까지 섞어 세어 "몹 없음"이어야 할 마을 없는 캠프에서 FAIL이
## 났다. 그래서 `_preserved_midbosses`(area_id -> Array)에 별도 보관 - 자기
## 지역을 벗어나면 그룹에서 완전히 빼 숨겨 두고, 그 지역으로 돌아오면 그룹에
## 되돌린다.
## (감독 2026-09-08, 10장 탐침 2장 성채 110분 보스 미처치) 장 보스(`is_boss`)는
## 위 중간보스와 똑같은 결함이 그대로 남아 있었다 - 방을 벗어나면 치우고
## `boss_spawned=false`로 되돌려 재입장마다 `_spawn_boss()`가 풀피(2장 5400)
## 보스를 새로 만들었다. 퀘스트모드는 보스 넉백(8px/타)에 서쪽 출구 밖으로
## 밀려나거나 물약 귀환으로 1.5분마다 방을 나갔다 와, 보스를 982까지 깎고도
## 매번 5400으로 되돌아가 영원히 못 잡았다(check_quest_citadel_repro 실측).
## 살아있는 보스는 중간보스와 같은 보관함에 넣어 두고 돌아오면 그대로
## 되돌린다(`boss_spawned=true`로 되살려 `_change_map()`이 겹쳐 안 깔게).
## 죽은 보스(health 0, queue_free 대기)는 그대로 치워 재입장 시 새로 깐다
## (check_boss_respawn 규칙 유지).
func _spawn_area_enemies(map_name: String) -> void:
	# 보관 중 해제된 노드(죽은 뒤 queue_free 처리)는 건너뛴다.
	var stashed: Array = _preserved_midbosses.get(map_name, []).filter(
		func(e): return is_instance_valid(e))
	_preserved_midbosses.erase(map_name)
	var preserved_midboss := 0
	for enemy in stashed:
		if enemy.is_midboss:
			preserved_midboss += 1
	for enemy in get_tree().get_nodes_in_group("enemies"):
		# health<=0 은 같은 프레임에 죽어 queue_free 대기 중인 놈 - 보관하면
		# 프레임 끝에 해제돼 재입장 때 'previously freed' 에러가 난다(8장 프로브).
		if (enemy.is_midboss or enemy.is_boss) and enemy.health > 0:
			if enemy.area_id == map_name:
				if enemy.is_midboss:
					preserved_midboss += 1
				continue
			if enemy.is_boss:
				boss_spawned = false
			# 다른 지역 중간보스는 치우지 않고 숨겨서 보관한다(위 주석 (2)).
			enemy.visible = false
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.get_node("CollisionShape2D").disabled = true
			enemy.remove_from_group("enemies")
			if not _preserved_midbosses.has(enemy.area_id):
				_preserved_midbosses[enemy.area_id] = []
			_preserved_midbosses[enemy.area_id].append(enemy)
			continue
		if enemy.area_id == map_name and enemy.is_boss:
			continue
		# 보스도 자기 지역을 벗어나면 치운다. 안 그러면 동굴에서 만난 수호자가
		# 항구·폐허까지 따라온다.
		if enemy.is_boss:
			boss_spawned = false
		# queue_free 는 프레임 끝에 처리된다. 그때까지 그룹에 남아 있으면
		# 이전 지역 몬스터가 공격 판정과 수 세기에 섞인다. 먼저 뺀다.
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	for enemy in stashed:
		enemy.visible = true
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		enemy.get_node("CollisionShape2D").disabled = false
		enemy.add_to_group("enemies")
		if enemy.is_boss:
			boss_spawned = true
	for entry in _area_spawn_points(map_name):
		var is_mid: bool = entry.get("midboss", false)
		if is_mid and preserved_midboss > 0:
			preserved_midboss -= 1
			continue
		var tier: Dictionary = TIERS[int(entry["tier"])]
		var enemy := preload("res://scenes/enemy.tscn").instantiate()
		enemy.position = entry["at"]
		# 중간보스는 같은 등급 몹보다 훨씬 강하게 - 사냥터 보스급 존재감을
		# 준다. 장별 보스보다는 약하다. 배율은 GameState.MIDBOSS_*_MULT
		# (규칙 ③: 밸런스 숫자는 game_state.gd에만).
		enemy.max_health = int(tier["hp"] * (GameState.MIDBOSS_HP_MULT if is_mid else 1.0))
		enemy.health = enemy.max_health
		enemy.damage = int(tier["damage"] * (GameState.MIDBOSS_DAMAGE_MULT if is_mid else 1.0))
		enemy.speed = float(tier["speed"])
		enemy.exp_reward = int(tier["exp"] * (GameState.MIDBOSS_REWARD_MULT if is_mid else 1.0))
		enemy.gold_reward = int(tier["gold"] * (GameState.MIDBOSS_REWARD_MULT if is_mid else 1.0))
		enemy.area_id = map_name
		enemy.archetype = str(entry["kind"])
		enemy.is_midboss = is_mid
		add_child(enemy)
		_connect_enemy(enemy)


## 탑 층 스폰. 일반 지역과 달리 맵은 하나뿐이라 손으로 배치하지 않고,
## GameState.tower_floor·tower_difficulty로 몬스터 수·종류·능력치를
## 절차적으로 정한다. 자세한 공식: TOWER_DESIGN.md.
func _spawn_tower_floor() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	var floor_num: int = GameState.tower_floor
	var tier: String = GameState.tower_difficulty
	var stats := GameState.tower_floor_stats(floor_num, tier)
	var count := 5 + floor_num / 10
	var kinds := GameState.tower_floor_monster_kinds(floor_num, tier, count)
	tower_enemies_remaining = kinds.size()
	var size := World.size_of("tower")
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_num * 131 + tier.hash()
	var reward_mult := GameState.tower_reward_mult(tier)
	# 같은 칸에 두 마리가 겹쳐 스폰되면 뒤쪽 몬스터가 완전히 가려져
	# "남은 몬스터 수는 남았는데 화면엔 안 보인다"는 버그가 난다.
	# walkable만 보고 뽑던 걸 이미 쓴 칸(occupied)도 피하도록 고친다.
	# 랜드마크(탑 건물)가 차지한 칸은 처음부터 점유된 것으로 친다 - 그 위에
	# 스폰하면 충돌체에 밀려 다른 몬스터와 겹치는 칸으로 떠밀린다.
	var occupied: Dictionary = $World.landmark_cells("tower")
	for kind_id in kinds:
		var cell := Vector2i.ZERO
		var found := false
		for tries in 60:
			cell = Vector2i(rng.randi_range(3, size.x - 4), rng.randi_range(3, size.y - 4))
			if $World.walkable("tower", cell) and not occupied.has(cell):
				found = true
				break
		if not found:
			# 60회 추첨으로 빈 칸을 못 찾으면(밀집 고층) 전체 칸을 선형 탐색해
			# 겹쳐 스폰되는 것을 막는다.
			for y in range(3, size.y - 3):
				for x in range(3, size.x - 3):
					var candidate := Vector2i(x, y)
					if $World.walkable("tower", candidate) and not occupied.has(candidate):
						cell = candidate
						found = true
						break
				if found:
					break
		occupied[cell] = true
		var enemy := preload("res://scenes/enemy.tscn").instantiate()
		enemy.position = Vector2(cell) * World.TILE + Vector2(8, 8)
		enemy.max_health = int(stats["hp"])
		enemy.health = enemy.max_health
		enemy.damage = int(stats["damage"])
		enemy.defense = int(stats["defense"])
		enemy.speed = 34.0
		enemy.exp_reward = int(10 * reward_mult)
		enemy.gold_reward = int(6 * reward_mult)
		enemy.area_id = "tower"
		enemy.archetype = kind_id
		add_child(enemy)
		_connect_enemy(enemy)
	var tier_name := str(GameState.TOWER_TIERS.get(tier, {}).get("name", tier))
	# 10/25/50/75층 마일스톤 재료 획득 메시지(_advance_tower_floor가 방금
	# 띄운 것)를 이 함수가 곧바로 "탑 N층" 안내로 덮어써 버려 사람 눈에
	# 안 보이는 문제가 있었다("탑 콘텐츠도 좀 손 보고" 검증 중 스크린샷으로
	# 확인) - 마일스톤 층이면 두 안내를 한 줄로 합쳐서 덮어쓴다.
	var milestone := GameState.tower_milestone_material(floor_num - 1)
	if milestone > 0:
		$HUD/Message.text = "%s %d개 획득! 탑 %d층 (%s)" % [
			GameState.tower_material_name(tier), milestone, floor_num, tier_name]
	else:
		$HUD/Message.text = "탑 %d층 (%s)" % [floor_num, tier_name]
	_update_tower_hud()


## 지역 이름표(HUD/Area)에 층수·남은 몬스터를 계속 띄운다. 예전엔 층이
## 넘어가도 화면에 아무 안내가 없어서("몇 층인지도 안 보이고 다음층
## 이동도 안 보인다" 피드백) 몬스터만 계속 잡는 것처럼 느껴졌다.
func _tower_area_label() -> String:
	var tier_name := str(GameState.TOWER_TIERS.get(GameState.tower_difficulty, {}).get("name", GameState.tower_difficulty))
	return "심연의 탑 %d층 (%s)   남은 몬스터 %d" % [GameState.tower_floor, tier_name, tower_enemies_remaining]


func _update_tower_hud() -> void:
	if GameState.tower_active:
		$HUD/Area.text = _tower_area_label()


## 그 층의 몬스터를 다 잡았을 때. 진행도를 저장하고 다음 층으로,
## 100층이면 탑을 나가 마을로 돌아간다.
func _advance_tower_floor() -> void:
	var tier: String = GameState.tower_difficulty
	var cleared_floor := GameState.tower_floor
	GameState.tower_progress[tier] = maxi(int(GameState.tower_progress.get(tier, 0)), cleared_floor)
	var tier_name := str(GameState.TOWER_TIERS.get(tier, {}).get("name", tier))
	var milestone := GameState.tower_milestone_material(cleared_floor)
	if milestone > 0:
		GameState.add_tower_material(tier, milestone)
	if GameState.tower_floor >= GameState.TOWER_FLOOR_COUNT:
		var had_title := GameState.tower_titles.has(tier)
		GameState.add_tower_title(tier)
		$HUD/Message.text = "%s 탑 100층 클리어! 별 획득 (%d/%d)" % [
			tier_name, GameState.tower_titles.size(), GameState.TOWER_TIERS.size()] if not had_title else "%s 탑 100층 클리어!" % tier_name
		GameState.tower_active = false
		_change_map("village", false)
		_update_stats()
		return
	if milestone > 0:
		$HUD/Message.text = "%d층 클리어! %s %d개 획득" % [
			cleared_floor, GameState.tower_material_name(tier), milestone]
	else:
		$HUD/Message.text = "%d층 클리어!" % cleared_floor
	GameState.tower_floor += 1
	_spawn_tower_floor()


## 상점 재고. 지역이 열릴수록 좋은 물건이 들어온다.
## 원본처럼 진행도에 맞춰 살 수 있는 등급이 올라가게 한다.
## 벌어들이는 골드(퀘스트 보상·보스 처치금)에 비해 장비가 너무 싸다는
## 피드백으로 전반적으로 1.7~2배 올렸다. 소모품은 덜 올렸다.
const SHOP_STOCK := [
	{"item": "회복약", "price": 20, "chapter": 1},
	{"item": "이동주문서", "price": 60, "chapter": 1},
	{"item": "낚싯대", "price": 50, "chapter": 1},
	{"item": "부활의 깃털", "price": 220, "chapter": 2},
	{"item": "파괴 방지 부적", "price": 320, "chapter": 2},
	{"item": "철검", "price": 130, "chapter": 1},
	{"item": "가죽 갑옷", "price": 140, "chapter": 1},
	{"item": "가죽 모자", "price": 80, "chapter": 1},
	{"item": "구리 반지", "price": 95, "chapter": 1},
	{"item": "사냥꾼의 활", "price": 220, "chapter": 1},
	{"item": "질풍의 활", "price": 560, "chapter": 2},
	{"item": "사슬 갑옷", "price": 330, "chapter": 2},
	{"item": "철 투구", "price": 190, "chapter": 2},
	{"item": "수정 목걸이", "price": 400, "chapter": 2},
	{"item": "파수병 흉갑", "price": 520, "chapter": 2},
	{"item": "파수병 투구", "price": 450, "chapter": 2},
	{"item": "서리 단검", "price": 430, "chapter": 2},
	{"item": "숲의 정령 인장", "price": 220, "chapter": 2},
	{"item": "바람의 정령 인장", "price": 220, "chapter": 2},
	{"item": "불꽃의 정령 인장", "price": 480, "chapter": 3},
	{"item": "서리의 정령 인장", "price": 480, "chapter": 3},
	# (감독 2026-09-08) 2차 전직 재료. 중간보스 드랍만으로는 200개 모으기
	# 어려워 4장(SECOND_JOB_UNLOCK_CHAPTER)부터 개당 100G에 판다 - 200개
	# 20,000G는 4장 자동사냥 골드 속도(≈350G/분)로 약 1시간.
	{"item": "전직의 돌(전사)", "price": 100, "chapter": 4},
	{"item": "전직의 돌(마법사)", "price": 100, "chapter": 4},
	{"item": "전직의 돌(도적)", "price": 100, "chapter": 4},
	# 묶음(qty). 200개를 한 개씩 200번 누르지 않게 10개 묶음도 판다(감독 지시).
	{"item": "전직의 돌(전사)", "price": 10000, "chapter": 4, "qty": 100},
	{"item": "전직의 돌(마법사)", "price": 10000, "chapter": 4, "qty": 100},
	{"item": "전직의 돌(도적)", "price": 10000, "chapter": 4, "qty": 100},
]


## 상점 목록·안내에 쓰는 이름. 묶음이면 "×10"을 붙인다.
func _shop_label(entry: Dictionary) -> String:
	var qty := int(entry.get("qty", 1))
	return "%s×%d" % [entry["item"], qty] if qty > 1 else str(entry["item"])

var shop_index := 0
## 상점 탭. "buy" 또는 "sell".
var shop_mode := "buy"
var forge_open := false
var forge_index := 0
## "enhance"(강화) · "socket"(마법돌 박기) · "craft"(제작). 좌우로 바꾼다.
var forge_mode := "enhance"
const FORGE_MODES := ["enhance", "socket", "craft", "reroll"]
var craft_index := 0
## _refresh_forge()/_refresh_forge_craft()가 그리는 실제 목록 줄 수와
## 목록이 시작하는 줄 번호(0부터). 터치 판정(_on_forge_gui_input)도 같은
## 값을 써야 화면에 보이는 줄과 눌러서 고르는 줄이 어긋나지 않는다
## (INVENTORY_WINDOW와 같은 이유).
## 4(원래 5) - "… N개 더" 줄이 늘어난 만큼, 헤더도 한 줄 합쳐(강화석/GOLD와
## 부적 개수를 한 줄로) 항목 칸을 하나 줄여야 Info.size.y(142px, 줄높이
## 17px) 안에 8줄(헤더 3 + 항목 4 + 더 1)이 들어간다(감독 2026-09-06 07:55).
const FORGE_WINDOW := 4
const FORGE_LIST_START_LINE := 3
## _refresh_shop()가 그리는 실제 목록 줄 수와 목록이 시작하는 줄 번호(0부터).
## 터치 판정(_on_shop_gui_input)도 같은 값을 써야 그리기와 판정이 어긋나지
## 않는다(INVENTORY_WINDOW/FORGE_WINDOW와 같은 이유).
## 4(원래 5) - "… N개 더" 줄이 늘어난 만큼 한 칸 줄여야 Info.size.y(142px,
## 줄높이 17px) 안에 8줄(헤더 3 + 항목 4 + 더 1)이 들어간다(감독 2026-09-06 07:55).
const SHOP_WINDOW := 4
const SHOP_LIST_START_LINE := 3
var storage_open := false
var storage_index := 0
## 창고 화면에서 보고 있는 칸. "bag" 또는 "box".
var storage_side := "bag"
var perk_open := false
var perk_index := 0
## 전직 탭에서 지금 골라 둔 직업(0=전사, 1=마법사, 2=도적).
var job_index := 0


## 지금 살 수 있는 물건만 남긴다.
func _shop_goods() -> Array:
	var goods: Array = []
	for entry in SHOP_STOCK:
		if int(entry["chapter"]) <= GameState.chapter:
			goods.append(entry)
	return goods


## 판매 탭에서 다루는 목록. 착용 중인 장비는 팔 수 없으니 표시만 다르게 한다.
func _shop_sell_list() -> Array[String]:
	return GameState.inventory


func _refresh_shop() -> void:
	GameState.sync_uids()
	var buying := shop_mode == "buy"
	$HUD/MobileControls.set_interact_label("구매" if buying else "판매")
	var count := _shop_goods().size() if buying else _shop_sell_list().size()
	shop_index = clampi(shop_index, 0, maxi(count - 1, 0))
	var start := clampi(shop_index - SHOP_WINDOW / 2, 0, maxi(count - SHOP_WINDOW, 0))
	var tabs := "[구매]  판매" if buying else " 구매  [판매]"
	var lines: Array[String] = []
	var selected := ""
	var selected_uid := 0

	if count == 0:
		lines.append("   팔 물건이 없다.")
	for index in range(start, mini(start + SHOP_WINDOW, count)):
		var marker := "▶" if index == shop_index else "   "
		if buying:
			var entry: Dictionary = _shop_goods()[index]
			var afford := "" if GameState.gold >= int(entry["price"]) else " (부족)"
			# ×100 묶음(10000G)은 "10000G"로 쓰면 ▶+(부족)까지 붙은 줄이 Info 폭을
			# 넘어 접힌다(check_shop_job_stone) - 만 단위 값은 "1만G"로 줄인다.
			var price := int(entry["price"])
			var price_text := ("%d만" % (price / 10000)) if price >= 10000 and price % 10000 == 0 else str(price)
			lines.append("%s %s  %sG%s" % [marker, _shop_label(entry), price_text, afford])
			if index == shop_index:
				selected = str(entry["item"])
				selected_uid = 0
		else:
			var item: String = _shop_sell_list()[index]
			var worn := " [착용]" if GameState.is_equipped_at(index) else ""
			lines.append("%s %s  %dG%s" % [marker, item, GameState.sell_price(item), worn])
			if index == shop_index:
				selected = item
				selected_uid = GameState.item_uid[index]

	var more := _list_more_suffix(count, start, SHOP_WINDOW)
	$HUD/Shop/Info.text = "상인   GOLD %d\n%s\n──────────\n%s%s" % [
		GameState.gold, tabs, "\n".join(lines), more]
	$HUD/Shop/Help.text = _help("←→ 탭  ↑↓ 선택  E %s  I/Esc 닫기", "탭 전환  ▲▼ 선택  %s 버튼  ✕ 닫기") % ("구매" if buying else "판매")

	$HUD/Shop/Icon.visible = selected != "" and selected != "회복약" and selected != "부활의 깃털" and selected != GameState.SCROLL_ITEM \
		and selected != GameState.ENHANCE_WARD and not (selected in GameState.JOB_STONES)
	if selected == "":
		$HUD/Shop/Detail.text = ""
		return
	if selected == "회복약":
		$HUD/Shop/Detail.text = "회복약\nHP 35% 회복"
	elif selected == GameState.SCROLL_ITEM:
		$HUD/Shop/Detail.text = "이동주문서\n지도에서 가 본 지역으로 이동(1장 소모)\n보유 %d / 최대 %d" % [GameState.scrolls, GameState.MAX_SCROLLS]
	elif selected == "부활의 깃털":
		$HUD/Shop/Detail.text = "부활의 깃털\n죽을 때 물어보고 그 자리에서 되살린다"
	elif selected == GameState.ENHANCE_WARD:
		$HUD/Shop/Detail.text = "파괴 방지 부적\n강화 +6 이상에서 실패해도 파괴 대신 하락으로 막는다"
	elif selected in GameState.JOB_STONES:
		$HUD/Shop/Detail.text = "%s\n2차 전직 재료\n보유 %d / 필요 %d" % [selected,
			int(GameState.materials.get(selected, 0)), GameState.SECOND_JOB_STONE_COST]
	else:
		$HUD/Shop/Detail.text = GameState.item_summary(selected, selected_uid)
	$HUD/Shop/Detail.modulate = GameState.display_color(selected)
	if $HUD/Shop/Icon.visible:
		$HUD/Shop/Icon.texture = _item_icon(selected)


func _switch_shop_tab(mode: String) -> void:
	if shop_mode == mode:
		return
	shop_mode = mode
	shop_index = 0
	Audio.play_sfx("cancel")
	_refresh_shop()


## 고른 물건을 판다. 착용 중이면 거절한다.
func _sell_shop_item(index: int) -> void:
	var price := GameState.sell_at(index)
	if price > 0:
		Audio.play_sfx("coin")
		$HUD/Shop/Notice.text = "%dG에 판매했다." % price
		_update_stats()
	else:
		$HUD/Shop/Notice.text = "착용 중인 장비는 팔 수 없다."
	_refresh_shop()


## 모바일 버튼은 화면에 보이는 줄만 누른다. 목록이 밀려 있으면 실제 번호가 다르다.
func _shop_visible_index(row: int) -> int:
	var count := _shop_goods().size() if shop_mode == "buy" else _shop_sell_list().size()
	var start := clampi(shop_index - SHOP_WINDOW / 2, 0, maxi(count - SHOP_WINDOW, 0))
	return start + row


func _move_shop_cursor(step: int) -> void:
	var count := _shop_goods().size() if shop_mode == "buy" else _shop_sell_list().size()
	if count == 0:
		return
	shop_index = wrapi(shop_index + step, 0, count)
	Audio.play_sfx("cancel")
	_refresh_shop()


func _buy_shop_item(index: int) -> void:
	var goods := _shop_goods()
	if index < 0 or index >= goods.size():
		return
	var entry: Dictionary = goods[index]
	if GameState.buy(str(entry["item"]), int(entry["price"]), int(entry.get("qty", 1))):
		Audio.play_sfx("coin")
		$Player.potions = GameState.potions
		_on_potion_changed($Player.potions)
		$HUD/Shop/Notice.text = "%s 구매 완료" % _shop_label(entry)
	else:
		# buy()가 거절하는 이유는 골드 부족 아니면 보유 상한 둘뿐이다.
		$HUD/Shop/Notice.text = "골드가 부족하다." if GameState.gold < int(entry["price"]) else "더 못 가진다."
	_refresh_shop()
	_update_stats()


## 키보드 interact와 터치/클릭 확정(_on_shop_gui_input)이 같은 동작을
## 하도록 공용으로 뺐다(강화 _activate_selected_forge_item()과 같은 이유).
func _activate_selected_shop_item() -> void:
	if shop_mode == "buy":
		_buy_shop_item(shop_index)
	else:
		_sell_shop_item(shop_index)


## 상점 목록도 인벤토리·강화와 같은 이유로 한 Label에 여러 줄을 그려 넣는
## 방식이라(_on_forge_gui_input() 주석 참고) HUD/Shop(ColorRect)의 gui_input
## 으로 좌표를 줄 번호로 환산해 직접 선택한다.
func _on_shop_gui_input(event: InputEvent) -> void:
	if not shop_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var count := _shop_goods().size() if shop_mode == "buy" else _shop_sell_list().size()
	if count == 0:
		return
	var info: Label = $HUD/Shop/Info
	var row := _tapped_list_row(info, tap_pos, SHOP_LIST_START_LINE, SHOP_WINDOW)
	if row < 0:
		return
	var start := clampi(shop_index - SHOP_WINDOW / 2, 0, maxi(count - SHOP_WINDOW, 0))
	var tapped_pos := start + row
	if tapped_pos >= count:
		return
	get_viewport().set_input_as_handled()
	if tapped_pos == shop_index:
		_activate_selected_shop_item()
	else:
		shop_index = tapped_pos
		Audio.play_sfx("cancel")
		_refresh_shop()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _menu_current_tab() != "" and (_is_key(event, KEY_BRACKETLEFT) or _is_key(event, KEY_BRACKETRIGHT)):
		_menu_tab_step(-1 if _is_key(event, KEY_BRACKETLEFT) else 1)
		get_viewport().set_input_as_handled()
		return
	if dialogue_open:
		if _nav_up(event) and not dialogue_choices.is_empty():
			_move_dialogue_choice(-1)
		elif _nav_down(event) and not dialogue_choices.is_empty():
			_move_dialogue_choice(1)
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_advance_dialogue()
		elif event.is_action_pressed("ui_cancel") and dialogue_choices.is_empty():
			# 선택지 장면은 건너뛸 수 없다. 답을 골라야 넘어간다.
			_close_dialogue()
		get_viewport().set_input_as_handled()
		return
	if perk_open:
		if _nav_up(event):
			perk_index = maxi(perk_index - 1, 0)
			Audio.play_sfx("cancel")
			_refresh_perk()
		elif _nav_down(event):
			perk_index = mini(perk_index + 1, maxi(GameState.perk_offer.size() - 1, 0))
			Audio.play_sfx("cancel")
			_refresh_perk()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_take_perk()
		get_viewport().set_input_as_handled()
		return
	if storage_open:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_toggle_storage()
		elif _nav_left(event):
			_switch_storage_side("bag")
		elif _nav_right(event):
			_switch_storage_side("box")
		elif _nav_up(event):
			storage_index = maxi(storage_index - 1, 0)
			_refresh_storage()
		elif _nav_down(event):
			storage_index = mini(storage_index + 1, maxi(_storage_list().size() - 1, 0))
			_refresh_storage()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_move_storage()
		get_viewport().set_input_as_handled()
		return
	if forge_open:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_toggle_forge()
		elif _nav_up(event):
			if forge_mode == "craft":
				craft_index = maxi(craft_index - 1, 0)
			else:
				forge_index = maxi(forge_index - 1, 0)
			Audio.play_sfx("cancel")
			_refresh_forge()
		elif _nav_down(event):
			if forge_mode == "craft":
				craft_index = mini(craft_index + 1, maxi(_craft_recipe_list().size() - 1, 0))
			else:
				forge_index = mini(forge_index + 1, maxi(_forge_items().size() - 1, 0))
			Audio.play_sfx("cancel")
			_refresh_forge()
		elif _nav_left(event):
			_cycle_forge_mode(-1)
		elif _nav_right(event):
			_cycle_forge_mode(1)
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_activate_selected_forge_item()
		elif forge_mode == "enhance" and _is_key(event, KEY_Z):
			_do_enhance_guaranteed()
		elif forge_mode == "socket":
			for digit in 9:
				if _is_key(event, KEY_1 + digit):
					_do_socket(digit)
					break
		get_viewport().set_input_as_handled()
		return
	if character_open:
		if event.is_action_pressed("character") or event.is_action_pressed("ui_cancel"):
			_toggle_character()
		elif _nav_left(event) or _nav_right(event):
			_cycle_character_mode(-1 if _nav_left(event) else 1)
		elif _nav_up(event):
			if character_mode == "perks":
				perk_index = maxi(perk_index - 1, 0)
			elif character_mode == "job":
				var jobs_n := GameState.JOB_NAMES.size()
				var second_arr: Array = GameState.SECOND_JOB_BRANCHES.get(GameState.job, [])
				var second_n := second_arr.size() if (GameState.job != "" and GameState.can_change_second_job()) else 0
				job_index = wrapi(job_index - 1, 0, jobs_n + second_n)
			else:
				stat_index = wrapi(stat_index - 1, 0, GameState.STAT_KEYS.size())
			Audio.play_sfx("cancel")
			_refresh_character()
		elif _nav_down(event):
			if character_mode == "perks":
				perk_index = mini(perk_index + 1, maxi(GameState.perk_offer.size() - 1, 0))
			elif character_mode == "job":
				var jobs_n2 := GameState.JOB_NAMES.size()
				var second_arr2: Array = GameState.SECOND_JOB_BRANCHES.get(GameState.job, [])
				var second_n2 := second_arr2.size() if (GameState.job != "" and GameState.can_change_second_job()) else 0
				job_index = wrapi(job_index + 1, 0, jobs_n2 + second_n2)
			else:
				stat_index = wrapi(stat_index + 1, 0, GameState.STAT_KEYS.size())
			Audio.play_sfx("cancel")
			_refresh_character()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			if character_mode == "perks":
				_take_perk_from_character_screen()
			elif character_mode == "job":
				_change_job_from_character_screen()
			elif GameState.spend_stat(GameState.STAT_KEYS[stat_index]):
				Audio.play_sfx("levelup")
				_apply_equipment_to_player()
			_refresh_character()
		get_viewport().set_input_as_handled()
		return
	if skills_open:
		if event.is_action_pressed("skills") or event.is_action_pressed("ui_cancel"):
			_toggle_skills()
		elif _nav_left(event) or _nav_right(event):
			_skills_to_character(-1 if _nav_left(event) else 1)
		get_viewport().set_input_as_handled()
		return
	if quest_open:
		if event.is_action_pressed("quest") or event.is_action_pressed("ui_cancel"):
			_toggle_quest()
		get_viewport().set_input_as_handled()
		return
	if guide_open:
		if event.is_action_pressed("guide") or event.is_action_pressed("ui_cancel"):
			_toggle_guide()
		elif _nav_left(event):
			guide_page -= 1
			Audio.play_sfx("cancel")
			_refresh_guide()
		elif _nav_right(event):
			guide_page += 1
			Audio.play_sfx("cancel")
			_refresh_guide()
		get_viewport().set_input_as_handled()
		return
	if world_map_open:
		var graph := $HUD/WorldMap/Graph
		if event.is_action_pressed("world_map") or event.is_action_pressed("ui_cancel"):
			_toggle_world_map()
		elif _nav_up(event):
			graph.move_cursor(-1)
			Audio.play_sfx("cancel")
		elif _nav_down(event):
			graph.move_cursor(1)
			Audio.play_sfx("cancel")
		elif _nav_left(event):
			graph.change_chapter(-1)
			Audio.play_sfx("cancel")
		elif _nav_right(event):
			graph.change_chapter(1)
			Audio.play_sfx("cancel")
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") or event.is_action_pressed("interact"):
			var refusal: String = graph.try_travel()
			if refusal != "":
				$HUD/WorldMap/Graph/Hint.text = refusal
		elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_T or event.physical_keycode == KEY_T):
			# 심연의 탑은 장 목록에 없다(개관도 표식). 키보드는 T로 바로 간다.
			var refusal: String = graph.try_travel_tower()
			if refusal != "":
				$HUD/WorldMap/Graph/Hint.text = refusal
		get_viewport().set_input_as_handled()
		return
	if tower_select_open:
		if event.is_action_pressed("world_map") or event.is_action_pressed("ui_cancel"):
			_toggle_tower_select()
		elif _nav_up(event) or _nav_left(event):
			tower_select_index = wrapi(tower_select_index - 1, 0, GameState.TOWER_TIERS.size())
			Audio.play_sfx("cancel")
			_refresh_tower_select()
		elif _nav_down(event) or _nav_right(event):
			tower_select_index = wrapi(tower_select_index + 1, 0, GameState.TOWER_TIERS.size())
			Audio.play_sfx("cancel")
			_refresh_tower_select()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") or event.is_action_pressed("interact"):
			_confirm_tower_select()
		get_viewport().set_input_as_handled()
		return
	if menu_open:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_toggle_inventory()
		elif inventory_tab == "materials" and (_nav_up(event) or _nav_down(event)):
			material_index = wrapi(material_index + (1 if _nav_down(event) else -1), 0, _material_rows().size())
			_refresh_inventory()
		elif _nav_up(event) and not GameState.inventory.is_empty():
			inventory_index = wrapi(inventory_index - 1, 0, GameState.inventory.size())
			_refresh_inventory()
		elif _nav_down(event) and not GameState.inventory.is_empty():
			inventory_index = wrapi(inventory_index + 1, 0, GameState.inventory.size())
			_refresh_inventory()
		elif _nav_left(event) or _nav_right(event):
			_switch_inventory_tab()
		elif event.is_action_pressed("interact") and inventory_tab == "items":
			_activate_selected_inventory_item()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not shop_open and not menu_open:
		set_pause_open(not pause_open)
		return
	if pause_open:
		if _is_key(event, KEY_1):
			GameState.save_game($Player)
			$HUD/Pause/Info.text = "일시정지\n저장 완료"
		elif _is_key(event, KEY_2):
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		elif _is_key(event, KEY_3):
			_adjust_hud_scale("stat", -HUD_SCALE_STEP)
		elif _is_key(event, KEY_4):
			_adjust_hud_scale("stat", HUD_SCALE_STEP)
		elif _is_key(event, KEY_5):
			_adjust_hud_scale("skill", -HUD_SCALE_STEP)
		elif _is_key(event, KEY_6):
			_adjust_hud_scale("skill", HUD_SCALE_STEP)
		elif _is_key(event, KEY_7):
			_toggle_audio_mute("music")
		elif _is_key(event, KEY_8):
			_toggle_audio_mute("sfx")
		elif _is_key(event, KEY_9):
			get_tree().quit()
		return
	if shop_open:
		if _nav_up(event):
			_move_shop_cursor(-1)
		elif _nav_down(event):
			_move_shop_cursor(1)
		elif _nav_left(event):
			_switch_shop_tab("buy")
		elif _nav_right(event):
			_switch_shop_tab("sell")
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_activate_selected_shop_item()
		elif event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_close_shop()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("world_map"):
		_toggle_world_map()
	elif event.is_action_pressed("character"):
		_toggle_character()
	elif event.is_action_pressed("skills"):
		_toggle_skills()
	elif event.is_action_pressed("quest"):
		_toggle_quest()
	elif event.is_action_pressed("guide"):
		_toggle_guide()
	elif event.is_action_pressed("fish"):
		_try_fish()
	elif event.is_action_pressed("interact"):
		_interact_npc()
	elif _is_key(event, KEY_1) or _is_key(event, KEY_2) or _is_key(event, KEY_3) or _is_key(event, KEY_4) or _is_key(event, KEY_5) or _is_key(event, KEY_6):
		if $Player.auto_hunt:
			_toggle_auto_hunt()
		if quest_mode:
			_toggle_quest_mode()
		var slot := 0
		if _is_key(event, KEY_2): slot = 1
		elif _is_key(event, KEY_3): slot = 2
		elif _is_key(event, KEY_4): slot = 3
		elif _is_key(event, KEY_5): slot = 4
		elif _is_key(event, KEY_6): slot = 5
		var note: String = $Player.cast_skill(slot)
		if note != "":
			$HUD/Message.text = note
	elif event.is_action_pressed("potion"):
		if not $Player.try_use_potion():
			$HUD/Message.text = "HP가 가득 찼다." if $Player.health >= $Player.max_health else "회복약이 없다."
	elif event.is_action_pressed("quick_save"):
		$HUD/Message.text = "저장 완료" if GameState.save_game($Player) else "저장 실패"
	elif event.is_action_pressed("quick_load"):
		_load_current_game()
	elif event.is_action_pressed("auto_hunt"):
		_toggle_auto_hunt()
	elif event.is_action_pressed("quest_mode"):
		_toggle_quest_mode()


func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and (event.keycode == key or event.physical_keycode == key)


## 메뉴 커서 이동. ui_* 는 방향키만 잡혀 있어서 이동에 쓰는 move_* 도 같이 받는다.
## WASD 로 걷다가 메뉴 열었을 때 손을 화살표로 옮기지 않아도 되게 한다.
func _nav_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")


func _nav_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")


func _nav_left(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")


func _nav_right(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")


func _load_current_game() -> void:
	if GameState.load_game($Player):
		$Player.potions = GameState.potions
		$Player.health_changed.emit($Player.health, $Player.max_health)
		$Player.mana_changed.emit($Player.mana, $Player.max_mana)
		_on_potion_changed($Player.potions)
		$HUD/Message.text = "불러오기 완료"
		_change_map(GameState.current_map, false, $Player.global_position)
		_apply_equipment_to_player()
		# 옛 세이브(레벨 보상 상자 기능 전에 저장됨) 소급 1회. claimed_level_milestones
		# 가 이미 있으면 여기서 나오는 보상은 0개(중복 지급 아님).
		for reward in GameState.claim_level_milestones(GameState.level):
			_queue_level_reward_box(reward)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		set_pause_open(not pause_open)


## 장비 종류에 맞는 그림. 예전엔 무기/방어구 딱 두 장을 전부 돌려썼는데,
## 갑옷·투구·장신구·인장이 다 같은 그림이라 뭘 고르는지 알기 어려웠다.
## 무기는 손 그림(sword/katana/...)을 그대로 아이콘으로 재사용한다.
func _item_icon(item: String) -> Texture2D:
	if GameState.fish_price(item) >= 0:
		return load("res://assets/items/icon_fish.png")
	if not GameState.EQUIPMENT.has(item):
		return load("res://assets/items/icon_misc.png")
	# 장비마다 전용 아이콘이 있다(GameState.ITEM_ICONS). 아래 슬롯·등급별
	# 대체 아이콘은 표에 없는 장비가 새로 추가됐을 때만 쓰인다.
	var own := str(GameState.ITEM_ICONS.get(item, ""))
	if own != "":
		return load("res://assets/items/%s.png" % own)
	var data: Dictionary = GameState.EQUIPMENT[item]
	var slot: String = data["slot"]
	# 용기사 세트(제작템 4개)는 슬롯 아이콘을 그냥 쓰면 다른 갑옷/투구들과
	# 똑같아 보인다. 전용으로 새로 그린 용 테마 아이콘을 따로 쓴다.
	if str(data.get("set", "")) == "boss_set":
		return load("res://assets/items/icon_boss_%s.png" % slot)
	# 탑 전용 "초월" 등급 20종도 전용 아이콘(하늘빛 테마)을 쓴다.
	if str(data.get("rarity", "")) == "초월":
		return load("res://assets/items/icon_tower_%s.png" % slot)
	if slot == "weapon":
		if str(data.get("kind", "")) == "bow":
			return load("res://assets/items/icon_bow.png")
		# 손에 든 그림(assets/items/hand/*)은 6~12px짜리라 인벤토리 칸 크기로
		# 늘리면 깨져 보인다. 따로 24x24로 그린 아이콘을 쓴다.
		var hand := str(data.get("hand", ""))
		if hand != "" and ResourceLoader.exists("res://assets/items/icon_%s.png" % hand):
			return load("res://assets/items/icon_%s.png" % hand)
		return load("res://assets/items/icon_weapon.png")
	if slot == "helmet" or slot == "trinket" or slot == "spirit":
		return load("res://assets/items/icon_%s.png" % slot)
	return load("res://assets/items/icon_armor.png")


## 인벤토리는 왼쪽에 목록, 오른쪽에 고른 물건의 그림과 능력치를 보여 준다.
## 목록이 다섯 줄을 넘으면 고른 줄이 가운데 오도록 창을 민다.
## 화면에 보이는 순서를 실제 GameState.inventory 인덱스로 바꾼 목록.
## 가방은 항상 희귀도 높은 것부터(같은 등급은 주운 순) 보여준다(감독
## 2026-09-10 "누르는 거 만들지 말고 들어가면 무조건 희귀순"). 정렬은
## 보여주기용일 뿐 실제 배열 순서는 안 바꾼다 - 착용 판정(is_equipped_at)이
## 배열 안에서의 첫 번째 자리를 보기 때문이다.
func _inventory_order() -> Array[int]:
	var order: Array[int] = []
	order.assign(range(GameState.inventory.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := GameState.rarity_rank(GameState.inventory[a])
		var rb := GameState.rarity_rank(GameState.inventory[b])
		return ra > rb if ra != rb else a < b)
	return order


## 재료 탭 아이콘. 파일은 tools/build_material_icons.py 가 만든다.
const MATERIAL_ICONS := {
	"강화석": "mat_enhance", "보스의 파편": "mat_fragment", "파괴 방지 부적": "mat_ward",
	"전직의 돌(전사)": "mat_job_warrior", "전직의 돌(마법사)": "mat_job_mage", "전직의 돌(도적)": "mat_job_rogue",
	"파수의 결정": "mat_tower_easy", "심판의 결정": "mat_tower_normal", "종언의 결정": "mat_tower_hard",
	"겁화의 결정": "mat_tower_hell", "천공의 결정": "mat_tower_abyss",
	"홍옥": "mat_stone_ruby", "벽옥": "mat_stone_jade", "자수정": "mat_stone_amethyst", "황옥": "mat_stone_topaz",
	"홍염석": "mat_stone_flame", "서리결정": "mat_stone_frost", "용의눈": "mat_stone_dragoneye",
	"태초의 정수": "mat_essence_primordial", "심해의 정수": "mat_essence_reef", "성광의 정수": "mat_essence_prelate",
	"침묵의 정수": "mat_essence_warden", "역행의 정수": "mat_essence_reversal", "근원의 정수": "mat_essence_origin",
}


## 재료 탭 한 줄 = {name, count, icon, desc}. 강화석·파편·부적·전직의 돌은
## GameState 카운터, 탑 결정·마법돌은 각자 표, 지역 제작 아이템 4종은
## 장비라서 인벤토리 배열에서 센다.
func _material_rows() -> Array:
	var rows: Array = []
	var add := func(name: String, count: int, desc: String, icon: Texture2D = null) -> void:
		var tex: Texture2D = icon
		if tex == null:
			tex = load("res://assets/items/%s.png" % MATERIAL_ICONS[name])
		rows.append({"name": name, "count": count, "desc": desc, "icon": tex})
	add.call(GameState.MATERIAL, GameState.materials[GameState.MATERIAL], "장비 강화 재료. 몬스터가 떨어뜨린다.")
	add.call(GameState.BOSS_FRAGMENT, GameState.materials[GameState.BOSS_FRAGMENT], "보스 확정 드랍. 대장간에서 전설 장비 제작.")
	add.call(GameState.ENHANCE_WARD, GameState.enhance_wards, "+6 이상 강화 실패 시 파괴 대신 하락.")
	for stone in GameState.JOB_STONES:
		add.call(stone, GameState.materials[stone], "2차 전직 재료. 사냥터 중간보스가 떨어뜨린다.")
	for tier in GameState.TOWER_MATERIALS:
		add.call(GameState.TOWER_MATERIALS[tier], GameState.tower_material_counts[tier],
			"%s 탑 몬스터 드랍. 초월 장비 제작 재료." % GameState.TOWER_TIERS[tier]["name"])
	for ch in GameState.CHAPTER_ESSENCES:
		var ess: String = GameState.CHAPTER_ESSENCES[ch]
		add.call(ess, int(GameState.materials.get(ess, 0)),
			"%d장 몬스터·보스 드랍. %s 제작 재료." % [ch, GameState.SETS[GameState.EQUIPMENT[GameState.BOSS_DROPS[GameState.BOSS_KEYS[ch]]]["set"]]["name"]])
	for sid in GameState.STONES:
		var data: Dictionary = GameState.STONES[sid]
		var bonus: Array[String] = []
		for key in ["atk", "def", "hp", "spd"]:
			if data.has(key):
				bonus.append("%s+%d" % [key.to_upper(), data[key]])
		if data.has("crit"):
			bonus.append("치명+%d%%" % int(data["crit"] * 100))
		add.call(sid, GameState.stone_inventory.get(sid, 0), "소켓 마법돌(%s) %s" % [data["rarity"], " ".join(bonus)])
	for area in GameState.AREA_ITEM_DROPS:
		var item: String = GameState.AREA_ITEM_DROPS[area]
		add.call(item, GameState.inventory.count(item), "제작 재료 겸 장비. 착용은 [장비] 탭에서.", _item_icon(item))
	return rows


func _switch_inventory_tab() -> void:
	inventory_tab = "materials" if inventory_tab == "items" else "items"
	Audio.play_sfx("cancel")
	_refresh_inventory()


func _inventory_tab_line() -> String:
	if inventory_tab == "materials":
		return " 장비  [재료]"
	return "[장비]  재료"


func _refresh_material_tab() -> void:
	$HUD/Inventory/Help.text = _help("↑↓ 선택   ←→ 탭   I 닫기", "▲▼ 선택   탭 버튼   ✕ 닫기")
	var rows := _material_rows()
	material_index = clampi(material_index, 0, rows.size() - 1)
	var start := clampi(material_index - INVENTORY_WINDOW / 2, 0, maxi(rows.size() - INVENTORY_WINDOW, 0))
	var lines: Array[String] = []
	for pos in range(start, mini(start + INVENTORY_WINDOW, rows.size())):
		var marker := "▶" if pos == material_index else "   "
		lines.append("%s %s  %d개" % [marker, rows[pos]["name"], rows[pos]["count"]])
	$HUD/Inventory/Info.text = "인벤토리   GOLD %d\n%s\n──────────\n%s%s" % [
		GameState.gold, _inventory_tab_line(), "\n".join(lines), _list_more_suffix(rows.size(), start, INVENTORY_WINDOW)]
	var row: Dictionary = rows[material_index]
	$HUD/Inventory/Icon.visible = true
	$HUD/Inventory/Icon.texture = row["icon"]
	$HUD/Inventory/Detail.text = "%s\n보유 %d개\n%s" % [row["name"], row["count"], row["desc"]]
	$HUD/Inventory/Detail.modulate = Color.WHITE
	# 재료는 쓸 수 있는 동작이 없다 - 착용 버튼을 숨긴다.
	$HUD/MobileControls.set_interact_label("착용", false)


func _refresh_inventory() -> void:
	GameState.sync_uids()
	if inventory_tab == "materials":
		_refresh_material_tab()
		return
	$HUD/Inventory/Help.text = _help("↑↓ 선택   E 착용   ←→ 탭", "▲▼ 선택   착용 버튼   탭 버튼")
	var count := GameState.inventory.size()
	$HUD/Inventory/Icon.visible = count > 0
	if count == 0:
		$HUD/Inventory/Info.text = "인벤토리   GOLD %d\n%s\n──────────\n\n가진 물건이 없다." % [GameState.gold, _inventory_tab_line()]
		$HUD/Inventory/Detail.text = ""
		$HUD/MobileControls.set_interact_label("착용")
		return

	inventory_index = clampi(inventory_index, 0, count - 1)
	var order := _inventory_order()
	var start := clampi(inventory_index - INVENTORY_WINDOW / 2, 0, maxi(count - INVENTORY_WINDOW, 0))
	var lines: Array[String] = []
	for pos in range(start, mini(start + INVENTORY_WINDOW, count)):
		var index: int = order[pos]
		var item: String = GameState.inventory[index]
		var marker := "▶" if pos == inventory_index else "   "
		var mark := ""
		if GameState.is_equipped_at(index):
			mark = " [착용]"
		elif not GameState.can_equip(item):
			mark = " [Lv%d]" % int(GameState.item_data(item).get("level", 1))
		lines.append("%s %s%s" % [marker, GameState.item_label(item, GameState.item_uid[index]), mark])
	var more := _list_more_suffix(count, start, INVENTORY_WINDOW)
	$HUD/Inventory/Info.text = "인벤토리   GOLD %d\n%s\n──────────\n%s%s" % [
		GameState.gold, _inventory_tab_line(), "\n".join(lines), more]

	var selected_index: int = order[inventory_index]
	var selected: String = GameState.inventory[selected_index]
	var selected_uid: int = GameState.item_uid[selected_index]
	$HUD/Inventory/Icon.texture = _item_icon(selected)
	$HUD/Inventory/Detail.text = "%s\n판매 %dG" % [GameState.item_summary(selected, selected_uid), GameState.sell_price(selected)]
	$HUD/Inventory/Detail.modulate = GameState.display_color(selected)
	$HUD/MobileControls.set_interact_label("해제" if GameState.is_equipped_at(selected_index) else "착용")


## 키보드 interact와 터치/클릭 확정(_on_inventory_gui_input)이 같은 동작을
## 하도록 공용으로 뺐다 - 원래는 interact 입력 분기 안에만 있었다.
func _activate_selected_inventory_item() -> void:
	if GameState.inventory.is_empty():
		_refresh_inventory()
		return
	GameState.sync_uids()
	var index := _inventory_order()[inventory_index]
	var item := GameState.inventory[index]
	# 착용 판정은 이름이 아니라 이 칸(index)로 본다 - 같은 이름 여분
	# 장비가 있을 때 착용 안 한 사본을 골라도 착용한 사본이 벗겨지는 걸 막는다.
	if GameState.is_equipped_at(index):
		# 이미 낀 물건을 다시 고르면 벗는다(토글) - 예전엔 갈아 끼우는
		# 것만 되고 그냥 벗기는 방법이 없었다.
		GameState.unequip(GameState.equipped_slot_of(item))
		Audio.play_sfx("cancel")
		$HUD/Inventory/Notice.text = "%s 해제" % item
		_apply_equipment_to_player()
	elif GameState.equip(item, GameState.item_uid[index]):
		Audio.play_sfx("accept")
		$HUD/Inventory/Notice.text = "%s 착용" % item
		_apply_equipment_to_player()
	elif not GameState.EQUIPMENT.has(item):
		# 낚싯대·물고기처럼 애초에 장비가 아닌 물건. 레벨 문구를 붙이면
		# "레벨 1 이상 필요"처럼 말이 안 되는 소리가 나온다.
		$HUD/Inventory/Notice.text = "착용할 수 없는 물건이다"
	else:
		$HUD/Inventory/Notice.text = "레벨 %d 이상 필요" % int(GameState.item_data(item).get("level", 1))
	_refresh_inventory()


## 대륙 이동도 터치 처리. 왼쪽 목록은 인벤토리와 같은 방식
## (_on_inventory_gui_input() 참고)으로 줄을 골라 커서를 옮기고, 이미
## 커서가 있는 줄을 다시 탭하면 이동을 시도한다. 탭 줄("≪ N장 / M장 ≫")은
## 누른 쪽 절반(좌/우)으로 챕터를 바꾼다. 오른쪽 미니맵은
## world_atlas.gd의 area_at()으로 지역을 찾아 커서를 옮기거나(이미
## 선택돼 있으면 이동), 지역 점 근처가 아니면 대륙만 바꾼다
## (INBOX 2026-09-07 12:40).
func _on_world_map_gui_input(event: InputEvent) -> void:
	if not world_map_open:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var graph: Control = $HUD/WorldMap/Graph
	var info: Label = graph.get_node("Info")
	var hint: Label = graph.get_node("Hint")
	# 탭 줄은 목록 위 1번째 줄이다(world_map.gd _refresh()의
	# "대륙 이동도\n%s\n──────────\n%s%s" 포맷 참고).
	var local_in_info: Vector2 = tap_pos - info.position
	if local_in_info.x >= 0 and local_in_info.y >= 0 and local_in_info.x <= info.size.x:
		var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
		if line_height > 0 and int(local_in_info.y / line_height) == 1:
			get_viewport().set_input_as_handled()
			# 좌/우 기준은 라벨 폭이 아니라 탭 글자 폭의 절반이다. 글자가 58px인데
			# 라벨 절반(74px)으로 나누면 "≫"를 눌러도 이전 장으로 갔다(감독 2026-09-09).
			var tab_line: String = info.text.get_slice("\n", 1)
			var tab_width: float = info.get_theme_default_font().get_string_size(
				tab_line, HORIZONTAL_ALIGNMENT_LEFT, -1, info.get_theme_font_size("font_size")).x
			graph.change_chapter(-1 if local_in_info.x < tab_width / 2.0 else 1)
			Audio.play_sfx("cancel")
			return
	var count: int = graph.order_for_chapter(graph.chapter).size()
	if count > 0:
		var row := _tapped_list_row(info, tap_pos, 3, graph.WINDOW)
		if row >= 0:
			var start := clampi(graph.cursor - graph.WINDOW / 2, 0, maxi(count - graph.WINDOW, 0))
			var tapped_pos := start + row
			if tapped_pos < count:
				get_viewport().set_input_as_handled()
				if tapped_pos == graph.cursor:
					var refusal: String = graph.try_travel()
					if refusal != "":
						hint.text = refusal
				else:
					graph.move_cursor(tapped_pos - graph.cursor)
					Audio.play_sfx("cancel")
				return
	var atlas: Control = graph.atlas
	var local_in_atlas: Vector2 = tap_pos - atlas.position
	if local_in_atlas.x < 0 or local_in_atlas.y < 0 or local_in_atlas.x > atlas.size.x or local_in_atlas.y > atlas.size.y:
		return
	if atlas.tower_hit(local_in_atlas):
		# 심연의 탑 표식은 커서 없이 한 번에 간다(감독 2026-09-10 "바로 눌러서").
		get_viewport().set_input_as_handled()
		var tower_refusal: String = graph.try_travel_tower()
		if tower_refusal != "":
			hint.text = tower_refusal
		return
	var area: String = atlas.area_at(local_in_atlas)
	if area == "":
		return
	get_viewport().set_input_as_handled()
	var chapter: int = World.chapter_of(area)
	var idx: int = graph.order_for_chapter(chapter).find(area)
	if chapter == graph.chapter and idx == graph.cursor:
		var refusal: String = graph.try_travel()
		if refusal != "":
			hint.text = refusal
	else:
		if chapter != graph.chapter:
			graph.change_chapter(chapter - graph.chapter)
		graph.move_cursor(idx - graph.cursor)
		Audio.play_sfx("cancel")


## 인벤토리 목록은 한 Label에 여러 줄을 그려 넣는 방식이라 줄마다 따로
## Control 노드가 없다(실기 아이폰 테스트: 터치해도 선택이 안 됨). 대신
## HUD/Inventory(ColorRect, mouse_filter 기본값 STOP)가 클릭/터치를
## 이미 가로채고 있던 걸 gui_input으로 받아, 좌표를 줄 번호로 환산해
## 그 줄을 직접 선택한다 - 이미 선택된 줄을 한 번 더 누르면 확정(착용/해제).
func _on_inventory_gui_input(event: InputEvent) -> void:
	if not menu_open:
		return
	# 터치→마우스, 마우스→터치 에뮬레이션이 둘 다 켜져 있어 실제 손가락/
	# 클릭 한 번에 원본 이벤트 + 에뮬레이션 복제 이벤트가 같이 들어온다
	# (device == DEVICE_ID_EMULATION). 복제本을 걸러내지 않으면 첫 이벤트가
	# 선택을 옮기고 두 번째(복제)가 "이미 선택된 줄 재탭"으로 판정돼 한 번
	# 탭에 선택+착용까지 확정돼 버린다.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var tap_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	else:
		return
	var info: Label = $HUD/Inventory/Info
	# 1번째 줄(탭 이름)을 누르면 탭 전환.
	if _tapped_list_row(info, tap_pos, 1, 1) == 0:
		get_viewport().set_input_as_handled()
		_switch_inventory_tab()
		return
	# 0~2번째 줄은 제목/탭/구분선, 항목 줄은 3번째부터 시작한다
	# (_refresh_inventory()의 "인벤토리 …\n%s\n──────────\n%s%s" 포맷 참고).
	var row := _tapped_list_row(info, tap_pos, 3, INVENTORY_WINDOW)
	if row < 0:
		return
	if inventory_tab == "materials":
		var rows := _material_rows().size()
		var mat_start := clampi(material_index - INVENTORY_WINDOW / 2, 0, maxi(rows - INVENTORY_WINDOW, 0))
		if mat_start + row >= rows:
			return
		get_viewport().set_input_as_handled()
		material_index = mat_start + row
		Audio.play_sfx("cancel")
		_refresh_inventory()
		return
	var count := GameState.inventory.size()
	if count == 0:
		return
	var start := clampi(inventory_index - INVENTORY_WINDOW / 2, 0, maxi(count - INVENTORY_WINDOW, 0))
	var tapped_pos := start + row
	if tapped_pos >= count:
		return
	get_viewport().set_input_as_handled()
	if tapped_pos == inventory_index:
		_activate_selected_inventory_item()
	else:
		inventory_index = tapped_pos
		Audio.play_sfx("cancel")
		_refresh_inventory()
