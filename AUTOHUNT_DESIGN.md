# 자동사냥(오토 모드) 기획서

새 세션에서 이 문서만 읽고 이어서 작업할 수 있도록 결정 사항과 진행 상태를
전부 여기 남긴다. 코드가 이 문서와 다르면 **코드가 맞다** — 구현하며 수치가
바뀌면 이 문서도 그 자리에서 같이 고친다.

## 0. 요청 원문 (2026-09-05)

> 자동사냥 기능도 이제 만들어볼까? 오토모드로 사냥하다가 내가 오토모드 끄면
> 다시 사용자가 진행할 수 있게 오토 버튼 만들어서 자동사냥. 스킬도 턴마다
> 순서 매겨서 자동으로 쓰고 그러던데.

핵심 요구 3가지:
1. 켜고 끄는 **오토 버튼** 하나 (HUD 상시 노출, 모바일/데스크톱 공용).
2. 켜져 있는 동안: 이동 → 가장 가까운 적 탐지 → 접근 → 사거리 내에서 공격.
3. 스킬도 **순서(우선순위)를 정해 자동으로** 사용(쿨타임·마나 되는 대로).
4. 오토 끄면 **즉시** 그 프레임부터 사용자 입력이 그대로 먹힌다(꼬임/지연 없음).

## 1. 범위와 원칙

- 기존 `player.gd`/`enemy.gd`/`main.gd`/`mobile_controls.gd`의 이동·공격·
  스킬 로직은 **재사용**한다. 새 전투 시스템을 만들지 않는다 — 오토 모드는
  "누가 입력을 만드는가"만 바꾼다(사람의 키/터치 대신 AI가 같은 액션을
  누른다). 이게 핵심 설계 원칙이다: `attack()`/`cast_skill()`/`try_dodge()`/
  `try_use_potion()`을 그대로 호출한다. 데미지 공식, 쿨타임, 마나 소모 등은
  전혀 건드리지 않는다.
- 오토 모드는 **필드 사냥터에서만** 켤 수 있다(마을/탑/보스방은 스토리
  대사·연출이 끼어 있어 오작동 위험 — 1차 구현 범위 밖). 마을 진입, 대화
  시작, 상점/인벤토리 등 모달이 열리면 자동으로 꺼진다(다음 절 참고).
- 사람이 이동키/공격키/스킬키/조이스틱 중 **아무거나 입력하면 그 즉시 오토
  꺼짐** — "내가 오토모드 끄면 다시 사용자가 진행" 요구를 버튼 클릭 없이도
  만족시킨다(버튼은 켤 때와, 손 안 대고 끌 때 둘 다 필요).

## 2. 상태 관리 — 어디에 둘 것인가

- `GameState`에 저장하지 않는다(세이브에 남기면 재접속 시 의도치 않게
  자동으로 싸우기 시작함 — 항상 꺼진 채로 시작해야 안전).
- `Player`(`player.gd`)에 `var auto_hunt := false`로 둔다. 이유: 오토가
  만드는 "가짜 입력"이 실제로 실행되는 곳이 `_physics_process`이고, 이미
  `direction`/`attack()`/`cast_skill()` 전부 이 스크립트 안에 있다 — 새
  노드/오토로드를 만들 이유가 없다(불필요한 추상화 금지, Ponytail 원칙).
- `main.gd`는 오토 버튼 UI 토글과 "모달 열림 시 강제 OFF"만 담당한다.

## 3. AI 행동 로직 (매 `_physics_process` 틱)

`player.gd`의 기존 `_physics_process` 맨 위, 사용자 입력을 읽기 **전에**
분기한다:

```
if auto_hunt:
    var ai_direction := _auto_hunt_tick(delta)
    direction = ai_direction   # 기존 direction 변수 그대로 재사용
else:
    direction = Input.get_vector(...)   # 기존 코드
```

`_auto_hunt_tick(delta) -> Vector2`:

1. **타겟 선정**: `get_tree().get_nodes_in_group("enemies")` 중 살아있는
   (`health > 0`) 적 중 최단 거리 하나. 없으면 `Vector2.ZERO` 반환하고 대기
   (제자리 idle 애니메이션 — 다음 틱에 다시 탐색).
2. **스킬 우선순위 확인** (이동보다 먼저 확인 — 사거리 안이면 이동 없이 바로
   씀): §4의 우선순위 리스트를 위에서부터 순회하며 조건이 맞는 첫 스킬을
   즉시 사용. **정정(2026-09-05, 구현하며 발견)**: `cast_skill()`은
   `scripts/player.gd:510`부터 `grep -n "return"`으로 대조한 결과 성공·실패
   모두 사람이 읽는 문구를 돌려주고 빈 문자열을 돌려주는 경로가 하나도
   없다 — 반환값으로 성공 여부를 구분할 수 없었다. 대신 `cast_skill()` 안의
   실패 검사(배움 여부/쿨타임/마력/HP)를 그대로 복제한
   `_auto_skill_ready(slot)`로 호출 **전에** 미리 걸러 성공이 보장된 슬롯만
   호출한다. 남발 방지를 위해 **타겟과의 거리가 해당 스킬의 유효 사거리
   안일 때만** 시도한다(즉발 자힐/버프류는 거리 무관, 투사체/범위 공격류는
   `attack_range`의 2.5배 또는 `data.radius`).
3. **기본 공격**: 스킬을 못 썼고 타겟이 `attack_range` 안이고 `facing`이
   맞으면(자동이니 `facing`을 타겟 방향으로 강제) `attack()` 호출.
4. **접근 이동**: 타겟이 사거리 밖이면 `(target.global_position -
   global_position).normalized()`를 반환해 그 방향으로 이동 — 기존
   `velocity = direction * _current_move_speed()` 로직이 그대로 처리한다.
5. **회피 판단(최소 기능)**: `enemy`가 `charging`(돌진 예고) 중이고 거리가
   가까우면 `try_dodge()` 시도. 너무 복잡한 회피 AI(투사체 예측 등)는 1차
   범위 밖 — 사람이 하던 정교한 회피까지 흉내내지 않는다(과설계 금지).
6. **물약**: `health < max_health * 0.4`이고 `potions > 0`이면 이동/공격보다
   **최우선**으로 `try_use_potion()`.

## 4. 스킬 자동 순서 — "턴마다 순서 매겨서 자동으로 쓴다"

요청에서 말한 "턴"은 이 게임엔 없다(실시간 액션이지 턴제가 아님) → 매
틱마다 정해진 **우선순위 리스트를 위에서부터** 검사해 가장 먼저 조건이
맞는 스킬 하나를 쓰는 방식으로 해석한다(액션 RPG 오토배틀 장르 관례).

우선순위 규칙(고정 하드코딩, 설정 UI는 1차 범위 밖):

```
1순위: 회복류(heal_pct > 0, 즉 힐 스킬) — 단 health < max_health * 0.6 일 때만
2순위: 버프류(data.has("buff")) — 버프가 안 걸려 있을 때만(active_buffs 확인)
3순위: 광역/투사체 공격 스킬 — 적이 2마리 이상 뭉쳐 있으면 우선
4순위: 나머지 공격 스킬(슬롯 순서대로)
```

구현은 `GameState.active_skills()` 배열을 순회하며 각 항목의 `data`
딕셔너리(`heal_pct`, `buff`, `radius`, `damage` 키)로 분류 — 이미
`cast_skill()` 안에서 쓰는 것과 같은 키라 새 데이터 정의가 필요 없다.

## 5. UI — 오토 버튼

- **데스크톱**: 새 키 액션 `auto_hunt`를 `project.godot`의 `[input]`에
  추가(빈 슬롯 확인 필요 — `T` 또는 `Tab` 후보, 기존 액션과 충돌 안 함을
  `grep -n "physical_keycode"`로 재확인 후 결정).
- **모바일**: `mobile_controls.gd`의 `ACTIONS` 상수 옆에 별도 버튼
  `Auto`를 `main.tscn`의 `HUD/MobileControls` 아래 추가(기존 `Attack`/
  `Dodge`/`Potion` 버튼과 같은 크기, 스킬 터치 버튼들과 겹치지 않는 빈
  자리 확보 — 320x240 좁은 화면이라 배치 우선 확인 필요).
- 버튼은 **토글**(누를 때마다 on/off, 눌린 상태는 `button_pressed = true`로
  시각 구분 — 색 반전 or 테두리).
- HUD에 작은 라벨("AUTO")을 상시 표시해 지금 오토 상태인지 화면에서 바로
  보이게 한다(사용자가 "이거 오토였나?" 헷갈리지 않게).

## 6. 오토 강제 해제 조건 (안전장치)

다음 중 하나라도 발생하면 그 프레임에 `auto_hunt = false`:

- 이동/공격/대시/스킬 키 중 하나라도 **사람이** 누름(`Input.is_action_
  just_pressed(...)`이지만 오토가 만든 가짜 입력과 구분해야 함 — AI는
  `Input` 이벤트를 통하지 않고 `direction`/`attack()`을 직접 호출하므로
  실제 `Input` 폴링에는 안 잡힌다. 즉 사람이 물리 키/터치를 누르는 순간만
  감지되고 AI 자체 행동과 충돌하지 않는다).
- 아무 모달이 열림(`menu_open`/`shop_open`/`dialogue_open`/`pause_open`
  등 — `main.gd`가 이미 이 변수들을 갖고 있다. `set_modal_mode`가 호출될
  때 `mode != ""`이면 오토 OFF).
- 씬 전환(마을 진입, 지역 이동, 사망/리스폰).
- 사망 시(`died` 시그널) 당연히 OFF — 부활 직후 자동으로 다시 싸우기
  시작하면 위험.

## 7. 테스트 계획

`tests/run_validation.sh` 패턴을 따라 헤드리스 통합 테스트 추가:

- `tests/integration_test.gd`에 시나리오 추가: 사냥터 씬 로드 → 적 스폰 →
  `player.auto_hunt = true` 설정 → N틱 시뮬레이션 → 적 HP가 감소했는지
  (공격이 실제로 나갔는지) 확인 → 물리 키 입력 이벤트 주입 → `auto_hunt ==
  false`로 꺼졌는지 확인.
- 모바일 버튼 클릭 경로 테스트: `check_joystick_touch_input.gd`처럼
  `Auto` 버튼을 실제 클릭 이벤트로 눌러 `auto_hunt` 토글 확인.
- 회귀: 기존 전체 `run_validation.sh`가 그대로 통과해야 한다(오토 로직은
  `if auto_hunt` 분기 안에만 있어 평소 수동 플레이 경로에 영향 없어야
  함 — 이게 안전하게 구현됐는지의 핵심 지표).

## 8. 진행 상태

- [x] `player.gd`: `auto_hunt` 변수, `_auto_hunt_tick()` 구현 (2026-09-05)
- [x] `project.godot`: 데스크톱 오토 토글 키 추가 (2026-09-05, `T`키 =
      `physical_keycode 84`, 기존 액션과 충돌 없음을 `grep -n
      "physical_keycode"`로 재확인. `main.gd`에 `_toggle_auto_hunt()` 추가해
      비모달 상태에서만 토글되게 함 — 모달 열림 분기들이 그 전에 전부
      `return`하므로 자동으로 안전)
- [x] `main.tscn`/`mobile_controls.gd`: Auto 버튼 추가, 모달 열림 시 강제 OFF (2026-09-05)
- [x] HUD AUTO 라벨 표시 (2026-09-05, `10a837c`)
- [x] 사람 입력 감지 시 강제 OFF (2026-09-05, `main.gd`: `_physics_process`에서
      이동/공격/대시 액션의 `is_action_just_pressed`를 폴링, `_unhandled_input`
      스킬키(1~6) 분기에서 `_toggle_auto_hunt()` 호출)
- [x] 통합 테스트 추가, `run_validation.sh` 통과 (2026-09-05,
      `tests/integration_test.gd` - forest_w 지역 몹을 전부 지우고 통제된
      몹 하나만 새로 놓은 뒤 오토 ON으로 240틱까지 시뮬레이션해 실제
      이동+공격이 나가는지, 실제 Input 싱글톤 경로 키 입력으로 강제 OFF가
      되는지 확인)
- [x] 실제 게임 실행(GUI) 스크린샷으로 오토 사냥 동작 확인 (2026-09-05,
      `tests/shot_auto_hunt_combat.gd/.tscn` - forest_w에 몹 하나만 통제해
      두고 T키로 오토 ON, `--headless` 없이 직접 띄워 전/후 스크린샷 2장을
      저장. HUD "AUTO" 라벨/"자동사냥 켜짐" 메시지/초록 AUTO 버튼이 실제로
      렌더링되고, 두 번째 스크린샷에서 몹 체력(200→92)이 줄고 베기
      이펙트가 몹에 겹쳐 보임을 눈으로 확인)

## 9. 미정 사항 (구현하며 정하고 여기 기록)

- 데스크톱 오토 토글 키: `T`키(`physical_keycode 84`)로 확정(2026-09-05).
- 모바일 Auto 버튼 위치(2026-09-05 확정): `main.tscn`의
  `HUD/MobileControls/Auto`, 우측 버튼 열(x 288~312) 아래쪽 빈 칸
  `offset_top=206, offset_bottom=230`(Sell 158~182과 SkillTouch0~3
  178~202 아래, Quit 등 pause 전용 버튼과도 안 겹침 — 다른 버튼과 겹치지
  않는 빈 자리인지 main.tscn 좌표를 전부 읽어 직접 확인함).
  `toggle_mode = true`로 눌린 상태(`button_pressed`)가 시각 구분을
  대신하고, 실제 상태는 `mobile_controls.gd:sync_auto_button()`이
  `Player.auto_hunt`와 항상 맞춘다(키보드 T·모바일 버튼·모달 강제
  OFF 세 경로 전부 `main.gd:_toggle_auto_hunt()` 하나로 모여 이 함수를
  부른다). 모달 강제 OFF는 새 훅을 추가하지 않고
  `mobile_controls.gd:set_modal_mode(mode)`에 로직을 넣었다 — 이 함수가
  이미 모든 모달 열림/닫힘 경로(`main.gd`의 20곳 가까운 호출 지점)의
  유일한 공통 지점이라(§6에서 예상한 그대로).
- **시각 구분 버그(스크린샷으로 발견, 2026-09-05)**: `toggle_mode = true`만
  주고 `pressed` 스타일을 따로 안 주면 Godot 기본 테마의 on/off 색 차이가
  RGB 몇 단위 수준이라 사람 눈에는 안 보인다(`tests/shot_mobile_auto_button.gd`
  스크린샷을 픽셀 diff로 비교해서 확인 — 코드상 `button_pressed`는 정확히
  뒤집히고 있었지만 화면에서는 안 보이는 버그였다). `main.tscn`에
  `StyleBoxFlat_auto_on`(초록 배경 + 흰 테두리)을 `Auto` 버튼의
  `theme_override_styles/pressed`로 추가해 켜짐 상태가 눈에 띄게
  바뀌도록 고쳤다.

## 10. 퀘스트모드 설계 (2026-09-05, INBOX 보강 지시)

요청 원문: 사람이 마을 NPC와 직접 대화하지 않아도 `GameState.quest_stage`가
요구하는 다음 행동(사냥터 이동→몹 사냥→마을 복귀→NPC 대화)을 자동으로
계속 진행시키는 모드. 오토사냥(전투)과는 **별도 토글**.

### 10.1 원칙

- 오토사냥과 같은 대원칙: 새 전투/대화 시스템을 만들지 않는다. 기존
  `main.gd:_interact_npc()`(703줄)·`main.gd:_travel_to(map_name)`(2039줄,
  **정정**: INBOX 지시는 `world_map.gd:_travel_to()`라고 적었지만
  `grep -n "func _travel_to"`로 확인한 결과 실제 위치는 `main.gd`다.
  `world_map.gd`엔 `signal travel_requested(map_name)`만 있고, 그 신호를
  `$HUD/WorldMap/Graph.travel_requested.connect(_travel_to)`로 `main.gd`의
  함수에 연결해 쓴다)·`main.gd:_advance_dialogue()`(1234줄)를 그대로 호출만
  자동으로 트리거한다.
- 퀘스트모드는 "무엇을 할지 정하는" 상태머신이라 오토사냥(전투 AI, 매
  물리 틱)과 다르게 **낮은 빈도**(예: 0.5~1초 `Timer`)로 판단해도 충분하다.
  즉시 반응이 필요 없다(사냥 자체는 오토사냥에 위임하므로).
- 오토사냥과 마찬가지로 `GameState`에 저장하지 않는다(항상 꺼진 채 시작).

### 10.2 상태 변수는 어디 둘 것인가

- `main.gd`에 `var quest_mode := false`를 둔다. 이유: 이 상태머신이 건드는
  함수(`_interact_npc`, `_travel_to`, `_advance_dialogue`, `world_map_open`)가
  전부 `main.gd` 소속이라 `Player`에 둘 이유가 없다(오토사냥은 반대로
  `Player._physics_process`가 만드는 이동/공격이라 `Player`에 뒀던 것과 같은
  "그 로직이 실제로 도는 파일에 상태를 둔다" 원칙).
- 마을에서 NPC에게 걸어가는 이동은 오토사냥의 전투 AI가 아니라 "특정 좌표로
  이동"이라 별개다. `Player`에 `var auto_walk_target: Vector2 = Vector2.ZERO`,
  `var auto_walk_active := false`를 새로 추가하고 `_physics_process`에서
  `auto_hunt`보다 먼저 확인한다(`auto_walk_active`면 §3의 "4. 접근 이동"과
  같은 방식으로 `direction`을 목표 방향으로 강제, 도착하면 `main.gd`가
  `auto_walk_active`를 꺼야 하므로 `main.gd`가 매 틱 거리 확인 후 처리).

### 10.3 상태머신 (Timer 콜백, `GameState.current_map`/`quest_stage` 기준)

```
if not quest_mode:
    return
if dialogue_open:
    _advance_dialogue()               # 대사창이 이미 떠 있으면 그냥 넘긴다
    return
if World.is_town(GameState.current_map):
    var who_key: String = TOWN_QUEST_NPC.get(GameState.current_map, "elder")
    var target := World.town_npc_position(GameState.current_map, who_key)
    if $Player.global_position.distance_to(target) <= TALK_RANGE:
        $Player.auto_walk_active = false
        _interact_npc()
    else:
        $Player.auto_walk_target = target
        $Player.auto_walk_active = true
else:
    # 사냥터: 오토사냥에 맡긴다. 보스 처치는 §「보스 처치」기존 로직
    # (_on_boss_fallen, 630줄)이 이미 quest_stage를 올려 준다.
    $Player.auto_hunt = true
    if GameState.boss_defeated:
        var home := ""                # chapter_of(town) == chapter 인 마을
        for t in World.TOWNS:
            if World.chapter_of(t) == GameState.chapter:
                home = t
                break
        if home != "" and GameState.unlocked_maps.has(home):
            _travel_to(home)
```

- "마을에서 어느 NPC에게 갈지"는 이미 `_interact_npc()` 안의
  `TOWN_QUEST_NPC.get(GameState.current_map, "elder")`(747줄)과 완전히
  같은 조회라 새 테이블이 필요 없다. 단, `_interact_npc()`가 실제로 여는
  대상은 "가장 가까운 사람"(710~723줄, 상인/대장장이/여관 주인도 포함)
  이므로 목표 좌표를 반드시 `TOWN_QUEST_NPC`가 가리키는 사람으로 잡아야
  퀘스트 담당자가 아닌 상인/대장장이 앞에서 멈춰 상점을 여는 일을 막는다.
- `World.town_npc_position(map, role)`(world.gd:22)은 마을 이름과 무관하게
  역할별 고정 좌표(예: `elder` → `(56,108)`)를 돌려준다 — 이미 확인함.
- 사냥터→마을 복귀 시점 판단은 `GameState.boss_defeated`를 쓴다(1장은
  `_on_boss_fallen`에서 `boss_defeated = true`로 세팅, 641~678줄 확인).
  **주의**: 이 값은 챕터마다 세팅 여부가 다르다(1장·10장만 확인됨,
  2~9장은 `quest_stage`만 바뀌고 `boss_defeated`는 안 건드리는 코드가
  보인다 — 구현 시 재확인 필요, 챕터별로 다르면 "quest_stage가 해당
  챕터의 보스클리어 값(5/7/9/19/29/39/49/59/69) 이상"으로 판단 기준을
  바꿀 것).

### 10.4 UI — 퀘스트 버튼

오토사냥 Auto 버튼과 같은 패턴(§5, §9)을 그대로 재사용:

- 모바일: `main.tscn`의 `HUD/MobileControls`에 `Quest` 버튼을 Auto 버튼
  옆 빈 칸에 추가(좌표는 구현 시 `main.tscn`을 다시 읽어 겹치지 않는 자리
  확인 — Auto 버튼도 그렇게 잡았다).
- 데스크톱: 빈 키 슬롯 하나 확인 후 토글 키 배정(`grep -n
  "physical_keycode"`로 충돌 확인).
- `toggle_mode = true` + Auto 버튼에서 발견했던 시각 구분 버그(§9)를
  반복하지 않도록 처음부터 `pressed` 스타일(다른 색, 예: 파랑 계열로
  Auto의 초록과 구분)을 같이 넣는다.
- HUD 상시 라벨: "AUTO" 라벨 옆에 "QUEST" 라벨 추가(같은 자리 패턴).

### 10.5 강제 해제 조건 (§6과 동일 원칙 + 추가)

- 사람이 이동/공격/스킬 키 등 아무 입력이나 하면 즉시 OFF(§6과 동일 감지
  방식 재사용 — `main.gd`가 이미 갖고 있는 감지 지점에 `quest_mode = false`
  한 줄만 추가).
- 사망 시 OFF(§6과 동일).
- 퀘스트모드 자신이 여는 대화창(마을 NPC)은 예외지만, 그 외 모달(상점/
  인벤토리/일시정지 등 **사람이 직접 연** 경우)이 열리면 OFF. 단
  `_interact_npc()`가 상인/대장장이 앞에서 자동으로 상점을 여는 것은
  10.3에서 "목표를 반드시 퀘스트 NPC로 고정"해 애초에 발생하지 않게
  막았으므로 이 경우의 별도 처리는 불필요.

### 10.6 미정 사항 / 알려진 한계 (구현하며 정할 것)

- **(2026-09-06 확인 완료)** 대화 중 선택지가 있으면 `_advance_dialogue()`
  는 `_confirm_dialogue_choice()`를 호출해 현재 선택된 인덱스
  (`dialogue_choice`)를 그대로 확정한다. `scripts/main.gd:1148`에서
  `dialogue_choice := 0`으로 선언되고, 새 선택지 페이지가 뜰 때마다
  `scripts/main.gd:1187`(`_play_dialogue`류 진행 함수 안)이 매번
  `dialogue_choice = 0`으로 되돌린다(`grep -n "dialogue_choice = 0"`로
  확인, 커서를 남겨두지 않음) — 즉 퀘스트모드는 항상 정확히 **첫 번째
  선택지**를 고르게 된다("마지막으로 커서가 남은" 쪽 가능성은 없음).
  이건 완전 방치 플레이 장르 관례상 허용 범위로 보되, 선택에 따라
  보상(`Story.CHOICE_REWARD`)이나 스토리 분기가 갈리는 지점이면 사람이
  원치 않는 선택(=첫 번째)이 자동으로 확정될 수 있다는 한계는 여전히
  남는다. 필요하면 사람이 INBOX에 "선택지는 항상 N번째를 고르게 하라"
  같은 규칙을 줄 수 있다.
- **(2026-09-06 확인 완료)** `GameState.boss_defeated`는 2~10장 전체
  챕터 전환 지점(`scripts/main.gd`의 촌장 대화 분기, `quest_stage`가
  3→4/5→6/7→8/10→11/20→21/30→31/40→41/50→51/60→61로 넘어가는 9곳
  전부) 각각에서 `boss_defeated = false`로 리셋된다(`grep -n
  "boss_defeated = false" scripts/main.gd`로 9곳 전부 직접 대조,
  누락 없음) — 챕터마다 빠짐없이 세팅되므로 별도 수정 불필요.
- **(2026-09-06 확인 완료)** `_auto_hunt_tick()`(`scripts/player.gd:218`)
  의 타겟 선택은 `get_tree().get_nodes_in_group("enemies")` 전체를
  거리 비교만으로 훑어 가장 가까운 살아있는 적을 고른다 — 탐색
  반경(사거리) 제한이 코드 어디에도 없다. 즉 "목표 몹이 타겟팅 범위
  밖(먼 구석)이라 못 찾는" 경우는 애초에 발생할 수 없다(그 지역 안에
  있기만 하면 아무리 멀어도 결국 그쪽으로 걸어간다). 우려 해소.

### 10.7 진행 상태

- [x] `main.gd`: `quest_mode` 변수, Timer 기반 상태머신 함수 추가
      (`_quest_mode_tick()`, 0.6초 `Timer`)
- [x] `player.gd`: `auto_walk_target`/`auto_walk_active` 추가, 목표 좌표로
      이동하는 로직을 `_physics_process`에 삽입(오토사냥보다 먼저 확인)
- [x] `main.tscn`/모바일·데스크톱 UI: Quest 토글 버튼 + HUD 라벨 (2026-09-05,
      데스크톱 키 `Y`(`physical_keycode 89`, 기존 액션과 충돌 없음을
      `grep -n "physical_keycode"`로 재확인) = `quest_mode` 액션,
      모바일 `HUD/MobileControls/Quest` 버튼은 Auto 버튼(288~312, 206~230) 바로
      위 빈 칸(288~312, 182~206 - Sell 158~182 아래, Auto 위, 다른 버튼과
      안 겹침을 main.tscn 좌표로 직접 확인)에 배치. 시각 구분은 Auto의 초록
      대신 파란 `StyleBoxFlat_quest_on`으로 처음부터 넣어 §9의 시각 구분
      버그를 반복하지 않음. HUD 라벨은 `AutoLabel` 바로 아래
      `QuestLabel`(파란 글자, "QUEST")).
- [x] 강제 해제 조건(§10.5) 연결 (2026-09-05, `main.gd`의 §6 감지 지점
      3곳(물리 이동/공격/대시 폴링, 스킬 1~6키, `_toggle_auto_hunt()`와
      같은 구조의 `_toggle_quest_mode()`)에 그대로 추가하고,
      `mobile_controls.gd:set_modal_mode()`의 모달 강제 OFF에도 추가하되
      `mode == "dialogue"`는 예외 처리(퀘스트모드 자신이 여는 NPC 대화와
      구분이 안 되므로 §10.5 원문대로). 이 예외 때문에 사망 시 뜨는 부활
      확인 대사창도 mode=="dialogue"라 그냥 두면 안 꺼지는 문제를 발견해
      `_on_player_died()`에 별도로 `quest_mode = false`를 추가함(구현 중
      발견, §10.6에 없던 내용).
- [ ] 통합 테스트: `quest_mode = true` 설정 후 N틱 시뮬레이션으로 최소
      1개 장(1장) 클리어까지 자동 진행되는지 확인 — **진행 중, 아직 미완료**
      (2026-09-05). `tests/auto_quest_probe.gd`(마을에서 시작, `quest_mode
      = true` 후 4000틱 시뮬레이션, `quest_stage >= 4` 도달을 통과 조건으로
      함)로 처음 돌려 보니 **`_quest_mode_tick()`이 마을을 벗어나지도
      못했다** - 원인 두 가지를 찾아 고침:
      1. 마을 분기가 항상 촌장에게 걸어가 말을 거는 것만 했다. `quest_stage`가
         "숲의 마물 처치"(사냥 단계, 촌장은 더 할 말이 없음)인데도 매번
         촌장 옆에 서서 `_interact_npc()`를 반복 호출해 아무 진행 없이
         멈춰 있었다. `_quest_stage_text()`에 "처치"가 있으면(사냥 단계)
         마을 동쪽 exit로 걸어 나가고, 없으면(대화 단계) 촌장에게 가도록
         분기를 나눴다.
      2. 사냥터 분기는 그 지역 몹을 다 잡고 나면(보스 처치 전) 다음 갈 곳이
         없어 제자리에 멈췄다 - `grep -n '"exits":' scripts/world.gd`로
         전 지역을 확인한 결과 모든 장은 마을→...→보스방까지 "w"/"e"만
         쓰는 한 줄 사슬이라, 지역 안에 살아있는 몹이 없으면(`get_nodes_
         in_group("enemies")`에 `health > 0`인 것이 없으면) 다음 지역의
         동쪽 exit로 계속 걸어가게 했다(`_quest_east_exit_target()` 신설
         - `_east_spawn()`은 exit 경계 12px 안쪽이라 그대로 쓰면 경계를
         못 넘고 멈춘다는 걸 실제로 겪고 알았다).
      고친 뒤 재실행: 마을 → `hill` → `hill_ridge`까지 실제로 자동 이동해
      몹 9마리를 잡는 데까지는 성공(이전엔 0마리, 마을 밖으로 전혀 못
      나갔다). 하지만 **새 문제 발견**: `hill_ridge`에서 물약 2개(시작
      기본값)를 다 쓰고도 HP가 69→5→0으로 떨어져 사망(`hp tick=3000`
      `health=69/115 potions=0 enemies_near=11` → `hp tick=3100 health=5`,
      곧 사망 → `_on_player_died()`가 `quest_mode = false`로 안전
      강제해제해 그 뒤로 아무 진행 없이 4000틱을 채움). 그 시점 화면 안에
      살아있는 적이 11마리 동시 존재 - 오토사냥(`player.gd
      ._auto_hunt_tick()`)은 가장 가까운 적 하나만 상대하고 물러나거나
      피하는 로직이 없어 다수의 적에 둘러싸이면 물약이 떨어진 뒤 속수무책
      으로 죽는다. 이건 퀘스트모드 자체의 버그가 아니라 **기존 오토사냥
      전투 AI의 생존성 한계**(사람이 자동사냥만 켜고 오래 방치해도 같은
      식으로 죽을 수 있다는 뜻)로 보인다.
      **다음 바퀴가 먼저 할 것**: 이 생존성 문제를 어떻게 다룰지 정하고
      나서 통합 테스트를 마저 통과시킬 것. 후보: (a) 오토사냥에 "여러
      적에 둘러싸이면 물러난다" 회피 로직 추가, (b) 퀘스트모드가 물약이
      떨어지면 마을 상인에게 들러 보충하고 다시 나가게 하기(`_open_shop()`
      옆 구매 로직 재사용), (c) 사람에게 "방치 플레이 중 가끔 죽는 것은
      정상 동작으로 둘지" 질문하고 답에 따라 통합 테스트의 통과 조건
      자체를 "죽어도 마을에서 자동으로 되살아나 이어간다"로 낮추기.
      `tests/auto_quest_probe.gd`/`.tscn`은 아직 통과하지 못해 커밋하지
      않았다(작업 트리에 그대로 남겨 둠) - 다음 바퀴는 이 파일을 그대로
      이어서 쓸 것(4000틱 안에서 `hp tick=` 로그로 사망 지점을 바로 재현
      가능).
  - **이어서 한 바퀴 더 (2026-09-05, 커밋 예정)**: 후보 (b)를 택해
    `main.gd`에 구현(`_quest_home_town()`/`_quest_potion_price()`/
    `_quest_buy_potions()`/`_quest_travel_home()` 추가, 사냥터 분기에
    `potions<=0`이면 즉시 홈 마을로 귀환하는 조건 추가, 마을 분기에
    도착 즉시 `GameState.buy("회복약", …)`를 상점 UI 없이 직접 호출).
    이 과정에서 원래 있던 버그 두 개를 추가로 찾아 고쳤다(§10.3 새 코드가
    아니라 §10.7 앞 체크박스에서 이미 구현된 코드에 있던 버그):
    (1) `_travel_to()`는 "사람이 M키로 이미 지도를 연 상태"를 가정해
    `_toggle_world_map()`을 한 번만 부르는데, 퀘스트모드가 지도를 연 적
    없이 이 함수를 직접 부르면 그 토글이 거꾸로 지도를 열고
    `get_tree().paused=true`를 건 채 끝나 게임이 완전히 멈췄다(실측:
    potions=0 귀환 직후 화면이 마을에서 그대로 정지, health/enemies_near
    로그가 다시는 안 바뀜) - `_quest_travel_home()`이 지도를 먼저 연
    뒤에만 `_travel_to()`를 부르도록 고쳐 사람이 하는 순서를 그대로
    흉내 냄. (2) `_quest_stage_text()`는 사냥 목표(`kills`)를 채우면
    "…처치"에서 "…가자"로 문구가 바뀌는데(2305줄 등), 마을 판정은
    "처치"만 찾고 있어 채운 뒤 potions=0으로 귀환하면 그 뒤로 계속
    촌장에게 말을 걸러 가 버렸다(quest_stage는 그대로라 촌장이 할 말이
    없어 제자리에 멈춤) - "가자"도 함께 찾도록 고침.
    검증: `tests/auto_quest_probe.gd`(4000틱)로 재실행 - 사망 없음(이전:
    tick~3100 사망), 정지 없음(이전: tick 2210 이후 화면 고정), `village
    → hill → hill_ridge`까지 왕복하며 진행하는 것을 `hp tick=`/`tick=`
    로그로 확인. `bash tests/run_validation.sh` → `PROJECT_VALIDATION_OK`
    (회귀 없음).
    **그런데도 여전히 통과하지 못함** - 새로 발견한 문제: `hill_ridge`
    (몹 11마리, tier 2)에 도착할 때마다 물약이 금방 바닥나 **몹을 단
    한 마리도 못 잡고** 귀환한다(로그: 도착 시 `kills=9`(=`hill` 몫
    전부) → hill_ridge 체류 중 `enemies_near`가 11에서 안 줄어듦 → 귀환
    후 다시 가도 `kills=9` 그대로, 두 바퀴 연속 순증가 0). potions
    회복(§10.7 이번 항목)은 **사망은 막았지만 진행 정체는 못 고쳤다** -
    후보 (b)만으로는 부족하고, 후보 (a)(오토사냥 회피/카이팅 로직 또는
    "적이 N마리 넘게 붙으면 그 지역을 포기하고 다음 지역/이전 지역으로"
    같은 판단)가 실제로 필요해 보인다. **다음 바퀴가 먼저 할 것**: 후보
    (a) 설계(오토사냥 AI를 어떻게 바꿀지 - 새 밸런스 숫자가 필요하면
    선례대로 INBOX에 질문으로 남길 것) 또는 "이 지역은 건너뛰고 다음/
    이전 지역으로" 같은 퀘스트모드 자체 로직을 정하고 구현한 뒤
    `tests/auto_quest_probe.gd`(이번에도 아직 커밋 안 함, 계속 이어서
    씀)를 마저 통과시킬 것.
- [x] 실제 GUI 실행 스크린샷으로 확인 (2026-09-05,
      `tests/shot_mobile_quest_button.gd/.tscn` 신설 - `--headless` 없이
      직접 띄워 Quest 버튼을 실제 마우스 클릭(`push_input`)으로 눌러
      전/후 스크린샷 2장 저장. 직접 눈으로 확인: Auto 버튼 바로 위에
      Quest 버튼이 다른 버튼과 안 겹치게 보이고, 누르기 전엔 어두운
      기본색, 누른 뒤엔 파란 `StyleBoxFlat_quest_on`으로 확실히 바뀌며
      우상단에 "퀘스트모드 켜짐" 메시지가 뜬다. `button_pressed=true`도
      로그로 확인. 이 스크린샷 스크립트는 기존 `shot_*` 관례대로
      `run_validation.sh`에는 안 넣음).
- [x] 위험 후퇴(2026-09-06, INBOX 답 09:30/보정 10:20) — 가배치, 근거:

  | 상수(`game_state.gd`) | 값 | 근거 |
  | --- | --- | --- |
  | `AUTOHUNT_RETREAT_HP_RATIO` | 0.4 | 실측(위 §10.7 항목)에서 HP 60%대에서 이미 다수의 적에 둘러싸여 위험 신호였고, 오토사냥류 봇은 보통 HP 30~40%에서 이탈하는 것이 장르 관례 — 안전 쪽으로 40% 선택. |
  | `AUTOHUNT_RETREAT_ENEMIES` | 4 | 실측(hill_ridge)에서 동시 감당 가능한 적은 2~3마리였고 그 이상(11마리 조우)에서 health 69→5로 급락 — 여유를 두어 4마리부터 후퇴. |
  | `AUTOHUNT_RETREAT_GIVEUP_STREAK` | 3 | 후퇴 동작 자체는 물약 바닥 귀환(§10.7 앞 항목)과 역할을 분리하기 위해 "홈 귀환"이 아니라 "이전 지역으로 한 칸 물러남"으로 정함. 같은 지역에서 이 물러남이 반복되면(3회) 그 지역은 아직 무리로 보고 홈 귀환 + 한 티어 아래 지역 재개로 전환. |

  이어서(INBOX 답 11:20) 0.6초 `_quest_timer` 폴링 사이 burst 피해로
  죽는 문제(아래 §10.7 사망 로그 참고)에 대해서는 임계값을 올리지 않고
  판정 시점만 늘렸다 — `_on_health_changed()`에서도 매번
  `_quest_should_retreat()`를 재평가(`main.gd`). 검증:
  `tests/check_autohunt_retreat.gd` (1)~(4) 전부 PASS(피격 한 번으로
  같은 프레임 후퇴 포함). `tests/auto_quest_probe.tscn`(1장, 3900틱)
  재실행 결과 **사망 0**(이전엔 tick~3100 부근 사망) - `LOWHP tick=871
  health=50 near_proximity=2` 이후로도 최저 health 36/100까지만 내려가고
  더는 안 죽음. 다만 진행 자체는 tick=1656에 마을 귀환(`_quest_travel_home`,
  물약 3개 남은 상태·`boss_defeated=false` - 그 지역 사냥터 분기(`_quest_
  mode_tick()`, `scripts/main.gd:2458`)에서 홈으로 가는 경로는 `boss_
  defeated`(아니었음)·`potions<=0`(아니었음)·`_quest_do_retreat()`의
  `GIVEUP_STREAK`(3) 도달 세 가지뿐이라, 소거법으로 같은 지역에서 3회
  연속 후퇴 뒤 포기 귀환이 걸린 것 - 설계대로 동작)한 뒤 `quest_mode=false`
  로 꺼진 채 tick=3900까지 진행 없이 멈춰 있었다 - **§10.7 새 사실**:
  `_quest_travel_home()`이 귀환을 위해 `_toggle_world_map()`을 거치는데,
  그 안에서 `set_modal_mode("map")`을 부르고(`scripts/main.gd:2587`),
  `mobile_controls.gd:285`(`set_modal_mode()`)가 `mode != "dialogue" and
  game.quest_mode`면 `_toggle_quest_mode()`를 불러 꺼 버린다(§10.5 강제
  해제 조건이 퀘스트봇 자신의 지도 호출과 사람의 M키 호출을 구분 못함 -
  예외는 `mode == "dialogue"`뿐). 09:30 답의
  삭제 조건(hill_ridge kills 순증가 2바퀴 연속)은 **이 문제 때문에 아직
  확인 못함** - 다음 바퀴가 먼저 `_quest_travel_home`/`_quest_do_retreat`
  가 여는 지도 호출에서 `quest_mode`가 꺼지지 않게 고칠 것(10:05 지시
  항목 ③ "귀환 뒤 마을에서 멈춤"과 같은 원인일 가능성이 높음).
- [x] 골드 고갈 무한 왕복(2026-09-06, INBOX 답 14:20, 커밋 8156516) —
  가배치, 근거: `_quest_mode_tick()` 사냥터 분기의 `potions<=0` 즉시
  귀환 판정에 `and GameState.gold >= _quest_potion_price()` 조건을 더해,
  물약이 없어도 물약값을 못 살 만큼 가난하면 귀환하지 않고 계속 사냥
  하도록 함(위험해지면 기존 후퇴 규칙(HP 40%·근접 4마리)이 여전히
  건다). 근거: tier1 hill 몹 골드 보상(6) < 물약 가격(20)이라 3킬
  이내에 potions=0이 되면 그 즉시 귀환→구매 실패(골드 부족)→재출발→
  즉시 재귀환을 216틱 주기로 무한 반복해 전투를 한 번도 못 하고 골드도
  안 늘던 결함(15:10 질문 실측, kills=3에서 완전 정지)의 근본 원인
  수정 - 새 숫자·밸런스 변경 없음(기각된 후보 (b)(c)와 달리 조건 하나만
  추가). 검증: `check_autohunt_retreat.gd` (6) 케이스(potions=0·gold<가격
  → 귀환 안 함 / potions=0·gold>=가격 → 귀환) PASS, `bash tests/
  run_validation.sh` 전체 스위트 `PROJECT_VALIDATION_OK`.
  `tests/auto_quest_probe.tscn`(1장, 3900틱) 재실행 결과: **kills가
  0→6까지 순증가**(이전엔 tick=1794에서 potions=0 이후 kills=3에서
  완전 정지, 이번엔 tick=3155에 kills=6 도달 - 이전 블로커 해소 확인),
  **사망 0회**(HP가 51까지 내려가지만 후퇴로 방어). 다만 **새 블로커
  발견**: kills=6(스토리 목표 달성, stage_text가 "…처치 5/6"에서
  "숲 동쪽 수호자 동굴로 가자"로 바뀜) 이후에도 `map=hill`↔`village`를
  계속 왕복하며 `enemies_near`가 매번 정확히 9로 리셋된다(tick=3370,
  3835 둘 다 9) - `_change_map()`으로 지역을 다시 들어갈 때마다 스폰된
  몹이 처음 수(9마리)로 되돌아오는 것으로 보이고, 사냥터 분기의
  `has_live_enemy` 루프(그 지역에 살아있는 적이 하나라도 있으면 계속
  `auto_hunt`)가 스토리 킬 목표 달성 여부를 안 보고 "그 방문에서 스폰된
  몹을 전부 잡을 때까지" 무한정 싸우게 만들어, 매번 새로 리스폰된 9마리
  때문에 결코 다 잡지 못하고 동쪽 출구(hill_ridge)로 못 나간다.
  `FINAL stage=1 map=hill chapter=1 passed=false`(3900틱 소진, 보스
  미처치·hill_ridge 미진입) - 14:20 답 검증 ②의 "보스 처치, hill_ridge
  진입 확인"은 이 새 블로커 때문에 아직 못 채웠으므로 INBOX 15:10/14:20
  항목은 그대로 열어 둔다(10:05 지시가 다룰 "정지" 부류이나, 위치가
  아니라 "스토리 킬 목표는 채웠는데 그 지역을 못 떠남" 형태라 10:05
  항목 ④의 위치 고정 감지로는 못 잡는다 - 다음에 이 조각을 집는 바퀴가
  참고할 것).
- [x] 몹 재리스폰 무한 왕복(2026-09-06, 커밋 5b8da29) — 위 블로커의
  고침: 사냥터 분기에서 `_quest_stage_text()`가 "가자"를 포함하면
  (`goal_reached`) `has_live_enemy` 판정 자체를 건너뛰고 곧장 동쪽
  출구로 걷게 함(새 숫자 없음, 마을 판정과 같은 신호 재사용). `tests/
  auto_quest_probe.tscn`을 8000틱으로 늘리고 `gold` 필드를 추가해
  재실행한 결과: kills=6 도달 뒤 실제로 hill(35.1,239.5 재진입 없이)을
  가로질러 **hill_ridge에 진입했다**(tick=3528, `enemies_near=11`) -
  이전 블로커는 확인상 해소. 다만 **새 블로커 발견**: hill_ridge 안에서
  `_quest_should_retreat()`가 `enemies_near>=4`(11마리 조우)로 즉시
  발동해 이전 지역(hill)으로 후퇴(tick=3803) → hill도 몹 9마리 근접이라
  다시 후퇴 → village까지 밀려나고, village에서는 `goal_reached`가 여전히
  참이라 다시 hill 방향으로 걸어 나가 hill 입구(35.1,239.5)에서 또
  `enemies_near>=4`로 즉시 후퇴 → village. 216틱 주기 hill⇄village 왕복이
  kills=6에서 무한 반복(`FINAL stage=1 map=village passed=false`, HP는
  26/100에서 안 죽고 고정 - 후퇴가 데미지는 막지만 회복은 없음, 걷는
  동안 `auto_hunt=false`라 `player.gd:219`의 물약 자동 사용이 안 돎).
  **원인**: 사냥터 분기 순서가 `_quest_should_retreat()`(2482줄)를
  `goal_reached` 판정(2494줄)보다 먼저 보게 돼 있어, 이미 스토리 목표를
  채우고 "그냥 지나가는" 상황에서도 위험 후퇴(전투 지속을 전제로 만든
  규칙)가 그대로 걸린다. **후보(사람 결정 필요, 질문으로 상신)**: (a)
  `goal_reached`일 때는 `_quest_should_retreat()` 자체를 건너뛰고 곧장
  출구로 걷게 한다 - 다만 `_on_player_died()`가 `quest_mode=false`로
  끄므로(319줄) hill_ridge를 무방비로 가로지르다 죽으면 자동 진행이
  아예 멈춘다(사람이 Quest 버튼을 다시 눌러야 함 - 이게 "안전망"으로
  받아들일 만한 수준인지는 판단 필요). (b) `goal_reached` 상태에서도
  `auto_hunt=true`를 유지해(전투는 계속하되 목표 갱신 없이) 몹을 뚫으며
  나아가게 한다 - 그러면 원래 블로커(재리스폰)가 되돌아올 수 있어
  "출구 방향으로 걸으면서도 근접한 적만 반격" 같은 새 이동 로직이
  필요할 수 있다(§ 후퇴 규칙과 다른 새 로직 도입 여부 판단 필요). (c)
  하드 존(hill_ridge 등 `MIDBOSS_AREAS`)에서는 `AUTOHUNT_RETREAT_ENEMIES`
  임계값을 지역 성격에 맞게 다르게 적용한다 - 밸런스 숫자라 기획서
  근거 없이 임의로 못 바꿈. 자세한 로그는 `/tmp/auto_quest_probe2.log`
  (재현 파일, 저장소 밖). INBOX에 질문으로 상신.
- [x] 위 질문 (a) 채택 + QUEST_STAGE_KIND 표(2026-09-06, INBOX 14:55 답·
  15:05 승인·15:15 답, 커밋 3e2f8ff) — `_quest_should_retreat()`에서
  통과 중(goal_reached)이면 `enemies_near` 조건은 건너뛰고 HP<=40% 조건만
  본다(먼저 물약 사용 시도, 실패하면 그때 후퇴). 문구 판정
  (`contains("가자")`/`contains("처치")`, 2441·2494·`_quest_should_retreat()`
  세 곳)은 10:05 지시대로 `GameState.QUEST_STAGE_KIND`
  (0~69 단계 → DIALOGUE/HUNT/RETURN 분류)와 `GameState.QUEST_HUNT_TARGETS`
  (단계별 목표 필드·수치, 기존 `_quest_stage_text()` 문구가 쓰던 숫자
  그대로 재사용 - 새 숫자 없음)로 전부 교체, `_quest_hunt_goal_reached()`
  로 일원화. 중간에 15:15 답이 요구한 "HP<=40%도 물약>0 or 골드>=물약값
  일 때만" 게이트를 넣어 봤으나, `auto_quest_probe` 8000틱 재실행에서
  forest_w 통과 중 물약 0·골드 16(<20)으로 게이트가 후퇴를 막아 HP
  50→12로 실제 사망이 나왔다 - 이 후퇴는 마을 쇼핑이 아니라 한 칸
  물러남뿐이라 골드가 애초에 불필요했던 것으로 판단, 게이트를 빼고
  HP 조건만 남김(근거는 `scripts/main.gd:2524` 주석). 검증:
  `check_autohunt_retreat.gd` 11케이스(신규 2개: 물약0·골드부족도
  HP40%면 후퇴 / auto_walk 회피 중 재차 막히면 회피 방향 반전) PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
- [ ] **새 블로커(2026-09-06, 위 수정 반영한 HEAD 3e2f8ff로 재확인,
  로그 `/tmp/probe_new.log`) — 통과 중(kills=6 goal_reached 이후)
  물약 0·골드가 물약값 미만이면 챕터1이 영구 정지한다(사망은 아님).**
  실측: tick=3096 kills=6 도달(potions=1, gold=1) → hill 통과 중
  potions 1→0(물약 소모, 회복 성공) → HP가 68→32까지 떨어져
  tick=3646에 첫 후퇴(village로) → 이후 tick=3875부터 8000틱 끝까지
  216틱 주기로 `map=hill`↔`village`를 무한 반복, HP 32/gold 1/potions 0
  에서 완전히 고정(`FINAL stage=1 map=village chapter=1 passed=false`).
  원인: `_quest_do_retreat()`의 3연속 포기→홈 귀환+티어 하향 로직이
  걸려도 `World.exit_of("hill","w")`가 곧 홈 마을(village, 챕터1 마을이
  hill의 바로 이전 지역)이라 "포기 귀환"이 사실상 이미 서 있는 자리와
  같아 아무 것도 바뀌지 않는다. 통과 중에는 전투를 하지 않으므로
  (`auto_hunt=false`) 골드가 더 늘 방법이 없고, 물약도 못 사(20골드
  필요, 보유 1골드) 회복 수단이 전혀 없다 - 15:15 답이 예상한 "통과 중
  사망" 대신 "통과 중 영구 정지"로 나타난 것으로, 뿌리는 같다(회복
  수단 없이 거는 후퇴는 무의미). 기존 기각 후보들이 이 경우에도
  그대로 적용되는지 판단이 필요해 새로 상신하지 않고 우선 이 사실만
  기록 - 다음 순번 질문에서 사람 판단을 구한다(아래 §10.7 끝 또는
  INBOX 참고).
- [x] 위 질문 (e) 채택 + HP 게이트 복원(2026-09-06, INBOX 16:09 답,
  `_quest_handle_death()`/`can_recover` 게이트) — hill↔village 216틱
  무한 반복은 해소됐다(검증: `check_autohunt_retreat.gd` 13케이스 PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`). 단 구현 커밋 전
  `var can_recover := $Player.potions > 0 or ...`가 Variant 비교라
  타입 추론 실패로 프로젝트가 아예 안 열리는 파싱 에러가 있었다(`: bool =`
  로 명시해 고침) - 전 바퀴가 이 상태로 커밋 없이 끊겼던 것으로 보인다.
- [ ] **새 블로커(2026-09-06, 위 수정 반영 후 `auto_quest_probe` 8000틱
  재실측, 로그 `/tmp/probe_new2.log`, 저장소 밖) — forest_w(1장 통과
  구간)를 8000틱 안에 못 지나가 `passed=false`.** hill_ridge 진입(tick
  4265, 6187)까지는 정상 진행되고 hill↔village 반복도 없다. forest_w는
  총 몬스터 수가 많은 지역이고(로그 `enemies_near`=씬 전체 그룹 크기,
  근접 카운트 아님) 통과 중엔 `auto_hunt=false`라 전투 없이 걸어서만
  지나가는데, 그동안 접촉 피해만 누적돼 HP가 급락한다(두 시도 모두
  HP 26/100→6/100 부근까지). 회복 수단(물약·물약값 골드)이 없어 위
  게이트가 후퇴 대신 "밀어붙임"을 선택하고 그대로 버티다 사망 → 마을
  부활 → hill→hill_ridge→forest_w 전체 경로(약 700~900틱)를 처음부터
  다시 걸어야 하는데, 통과 중 전투가 없어 레벨도 골드도 안 늘어(gold=3
  고정) 매 시도가 똑같은 확률로 다시 죽는다. 8000틱 안엔 통과 못 했고
  로그가 3번째 hill_ridge 진입(tick 7699) 중간에 끊긴다 - 킬 진전 없이
  사망이 계속되면 결국 3연속 GIVEUP으로 quest_mode가 꺼질 전망(§10.5
  나). 근본 원인은 5b8da29(통과 중 `auto_hunt` 유지는 재리스폰 무한
  왕복 위험으로 기각)가 막아 둔 "통과 중 전투 금지"와 forest_w 몬스터
  밀도가 레벨1 기준으로는 맞물려 생존이 사실상 불가능해지는 것 —
  밸런스(몬스터 밀도 하향, 통과 중 제한적 전투 허용, 통과 중 무적 프레임
  등)는 새 숫자·새 메커니즘이라 규칙③상 임의로 못 정함. INBOX에 질문
  상신.
- [x] 위 질문 답 채택 + 통과 중 응전(2026-09-06, INBOX 16:50 답,
  `_quest_transit_engage()`) — 추격(`auto_hunt`)은 켜지 않고
  `auto_walk_active`를 유지한 채, 이미 `attack()`의 판정식(offset.length()
  - body_radius() <= attack_range)과 같은 기준으로 사거리 안에 든 적만
  그 자리에서 때린다. 검증: `check_autohunt_retreat.gd` (14)(15) 케이스
  (사거리 안 → HP 감소·추격 없음 / 사거리 밖 → 무반응) PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **`auto_quest_probe` 8000틱 재실측(로그 `/tmp/probe_16_50.log`,
  저장소 밖) — 여전히 `passed=false`, 그러나 성격이 바뀌었다: forest_w에는
  한 번도 도달하지 못했고(로그에 `map=forest_w` 0회), 병목이 그 앞
  `hill_ridge`(11마리)로 옮겨졌다.** 응전으로 hill 통과 중에는 꾸준히
  1마리씩 잡히지만(예: tick 5475→5724 kills 6→7, tick 5962→6664
  kills 7→8, 매번 hill 재통과 중 1킬), hill_ridge에서는 응전이 한 번도
  안 먹혔다 - 진입(tick 4678, kills=6) 후 HP가 82(tick4900)→58(5000)→
  14(5200)로 300틱 만에 급락해(11마리 근접이 계속 붙어 있어 접촉
  피해가 응전보다 훨씬 빠름) HP 40% 게이트가 걸리기 전에 이미 위험
  수위를 넘고, 결국 물약·골드 없이 후퇴(village, tick5253, kills 그대로
  6)한다. 이 hill↔village↔hill_ridge 왕복이 8000틱 내내 반복되며
  hill에서만 느리게 kills가 6→8로 오르고(gold도 8~16 사이를 오르내림),
  hill_ridge는 한 번도 못 뚫는다. 사망은 이번엔 0회(이전 블로커였던
  forest_w 사망 루프는 사라짐 - 진행이 막힐 뿐 퇴보하지는 않음).
  **결론: hill_ridge 밀도(11마리 동시 근접)가 응전만으로는 뚫리지 않는
  수준 - 밸런스(밀도 하향 등)는 규칙③상 임의로 못 정해 INBOX에 새
  질문으로 상신, 이 조각은 여기서 멈춘다.**
- [x] 위 질문 답 채택 + 포기 후 재개(2026-09-06, INBOX 17:26 답,
  `_quest_grind_zone`) — 밀도(11마리)는 손대지 않는다. 실제 원인은
  §10.7 포기 규칙("한 티어 아래에서 사냥 재개")이 구현에서 한 번도
  안 돌던 것: `_quest_do_retreat()`가 3연속 포기로 정한
  `_quest_resume_zone`(예: hill)을 마을이 소비해 그 지역으로 순간이동
  까지는 하지만, 도착하자마자 `_quest_hunt_goal_reached()`가 이미
  참(kills=6)이라 사냥(추격) 없이 그대로 응전만 하며 동쪽 출구로
  다시 걸어 나가 "한 바퀴 소탕"이 실행되지 않았다. 고침: 마을에서
  `_quest_resume_zone`을 소비할 때 같은 지역 이름을 `_quest_grind_zone`
  (새 변수, 상수 아님)에 남겨 두고, 사냥 분기에서
  `GameState.current_map == _quest_grind_zone`이면
  `_quest_hunt_goal_reached()`를 무시하고(새 헬퍼
  `_quest_effective_goal_reached()`, `_quest_mode_tick()`과
  `_quest_should_retreat()` 양쪽에서 공유) 기존 비목표 사냥 분기(적이
  있으면 추격)를 그대로 태운다. 그 지역 살아있는 적이 0이 되면(재진입
  리스폰은 `_change_map()`에서만 일어나므로 한 바퀴 = 스폰 수)
  `_quest_grind_zone=""`으로 지우고 동쪽 출구로 걷는다. 새 숫자 0개.
  검증: `check_autohunt_retreat.gd` (16)(17) 케이스(재개 지역에 적
  있음 → goal_reached 무시하고 추격·grind_zone 유지 / 적 전멸 →
  grind_zone 비우고 동쪽 출구) PASS, 전체 17케이스 PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **`auto_quest_probe` 8000틱 재실측(로그 `/tmp/probe_1726.log`,
  저장소 밖) — 뚜렷한 개선은 있으나 여전히 `passed=false`.** 이전
  블로커(hill_ridge를 한 번도 못 뚫음)는 해소 확인: hill_ridge 진입
  2회(tick=4208 kills=6, tick=6443 kills=8) 모두 그 뒤 **forest_w까지
  실제로 진입**했다(tick=4767, tick=7027 — 16:50 답 실측 때는
  `map=forest_w` 0회였다). hill(재개 지역) 그라인드가 매 사이클 kills를
  1씩 늘려 소량이나마 진전이 있고(6→7→8), 사망은 0회. 다만: (1)
  forest_w에서 매번 접촉 피해로 HP가 크게 깎여(관측 구간 100틱 단위
  샘플 기준 최저 30/100, 17/100 부근) 결국 3연속 포기로 village까지
  밀려나며 forest_w 다음 지역("이끼 빈터")에는 한 번도 도달하지 못했다.
  (2) 8000틱 동안 hill→hill_ridge→forest_w→village 왕복 사이클이 2번
  돌았고 사이클당 kills 순증가가 딱 1이라(그라인드 중 물약 구매차 조기
  귀환·재출발이 잦아 그 지역 몹을 끝까지 못 쓸어버리고 나가는 경우가
  많음), 이 속도로는 챕터1 완주(이끼 빈터→수호자의 동굴→수호자의
  제단 보스)까지 8000틱으로는 어림도 없다. (3) 레벨이 8000틱 내내
  `level=1`에서 한 번도 오르지 않았다(`TIERS[1].exp`=10, `next_exp`=80
  이라 산술상 8킬이면 딱 맞아떨어져야 하는데 hill_ridge/forest_w 몹의
  실제 tier가 섞여 있어 오차가 있어 보인다 - 확인은 안 함). 결론:
  포기 후 재개는 이제 실제로 사냥을 하지만, 밀도·회복 경제 전반이
  레벨1 파티가 8000틱 안에 챕터1을 끝내기엔 너무 무겁다 - 밀도·경제
  조정은 규칙③상 임의로 못 정해 위 숫자 그대로 INBOX에 새 질문으로
  상신(사람이 판단할 때까지 이 조각은 멈춘다).
- [x] **프로브 시계 교정(2026-09-06, INBOX 18:05 답, 0.6초 주기·
  `--fixed-fps 60`·30게임분)** — 위 8000틱 실측들은 전부 측정 오류였다.
  `auto_quest_probe.gd`가 `_quest_mode_tick()`을 매 물리 프레임(1/60초)
  마다 불렀는데, 실제 게임은 `_quest_timer`(main.gd:165, wait_time=0.6)
  주기로만 부른다 - 8000틱은 게임 시간 2분 13초에 불과했다. 고침:
  `_quest_mode_tick()`을 36 물리 프레임(=0.6초)마다 한 번만 호출하고,
  `--fixed-fps 60`으로 띄워 실시간 동기 없이 최대 속도로 시뮬레이션
  (실측: 게임 30분 분량이 벽시계 약 30초). 예산을 게임 시간 30분
  (물리 프레임 108,000·퀘스트 틱 3,000)으로, 통과 기준은 그대로
  `quest_stage >= 4`로 두었다. 정체 감시(kills·map·stage·level 네
  값이 게임 5분(18,000프레임) 무변화면 `STALL`) 추가. 30게임분 안에
  못 끝나면 고치지 않고 숫자만 보고하는 (6) 규칙대로 처리.
  **재실측(1장, `--fixed-fps 60`, 로그 `/tmp/probe_calibrated.log`
  저장소 밖) 결과 — `FINAL passed=false`(정체 아님, `STALL` 미발생.
  지역 순환은 계속되지만 킬이 안 늚):**
  - `exp`/`level` 산식은 버그 없음 - 킬당 exp=10, `next_exp`=80에서
    정확히 8킬째 레벨2(`next_exp`=104)로 전환됨을 로그로 확인(18:10
    질문의 "레벨이 안 오른다" 의심은 근거 없음, 이 항목으로 기각).
  - 게임 12.71분(kills=10, level=2) 시점까지는 hill→hill_ridge→
    forest_w 왕복으로 꾸준히 진행하다가, 그 뒤 **게임 30분 끝까지
    (17분 이상) kills=10에서 완전히 고정**된 채 village↔hill↔
    hill_ridge↔forest_w 왕복만 반복한다(각 지역 도달은 계속되므로
    `STALL` 조건(네 값 다 무변화)에는 안 걸림 - `current_map`만 계속
    바뀜). 사망 0회, boss_defeated 전환 0회(주 보스 앞엔 가보지도
    못함).
  - 게임 30분 종료 시 지역별 누적 체류(`ZONE_TIME`): village=3.32분,
    hill=8.62분, hill_ridge=6.88분, forest_w=11.18분. `KILLS_PER_MIN`
    =0.33(전체 30분 평균 - 실제로는 초반 12.71분에 몰려 있고 후반
    17분은 0).
  - 결론: 그라인드 사이클(§10.7 `_quest_grind_zone`)이 물약 사러
    조기 귀환하느라 그 지역을 끝까지 못 쓸어버리는 문제가 8000틱
    실측 때 추정한 그대로 재확인됐고, 게임 시간으로도(30분) 챕터1을
    못 끝낸다 - 밀도·경제 조정은 규칙③상 임의로 못 정해 이 숫자를
    그대로 INBOX에 새 질문으로 올린다(사람 판단 대기, 이 조각은
    여기서 멈춘다).
- [x] **후퇴 규칙 통합 + 매 후퇴 grind_zone(2026-09-06, INBOX 18:45 답,
  ①②③④) — 3연속 사망 결함은 고쳤으나 새 정체(HP 고정 왕복)를 찾았다.**
  18:35 질문의 실측(`/tmp/probe_calibrated.log`)에서 드러난 진짜 원인:
  "통과 중(goal_reached)엔 근접 규칙을 안 보고 HP 규칙도 회복 수단
  (`can_recover` = 물약>0 또는 골드≥물약값)이 있을 때만 켠다"는 그동안의
  게이트(14:55→15:15→16:09)가, 골드가 물약값보다 낮은 구간에서는 후퇴
  자체를 막아 죽을 때까지 그대로 전진하게 만들었다 - 그 결과 3연속 사망
  → `_quest_handle_death()`가 규칙대로 quest_mode를 껐다. 고침(새 숫자
  없음): `_quest_should_retreat()`을 목표 달성 여부와 무관하게 같은 두
  규칙(근접 ≥`AUTOHUNT_RETREAT_ENEMIES` 또는 HP ≤`AUTOHUNT_RETREAT_HP_RATIO`)
  만 보도록 통합하고, `can_recover`/`try_use_potion()` 호출은 판단
  함수에서 완전히 제거해 `_quest_do_retreat()`(회복 시도)에만 맡겼다.
  ② 포기(giveup)까지 안 가는 매 후퇴도 도착한 지역(prev)을 `_quest_grind_zone`
  으로 잡아 한 바퀴 소탕하게 함(6740fea 메커니즘 재사용, 새 상태 없음) -
  안 그러면 목표를 이미 채운 지역으로 되돌아가자마자 재진입→재후퇴를
  무한 반복한다. ③ 프로브(`tests/auto_quest_probe.gd`)에 `quest_mode`가
  꺼지는 즉시 FAIL하는 조기 종료를 추가하고, 사망 카운터를 프로브 자체
  `died` 신호 구독 대신 `main.gd`에 새로 둔 `quest_death_count`(
  `_quest_handle_death()`가 실제로 도는 경로에서 직접 증가)로 바꿨다.
  ④ `tests/check_autohunt_retreat.gd`에 케이스 (7)~(10b) 갱신/추가 -
  통과 중이어도 근접 임계값 이상이면 후퇴, 통과 중·물약 0·골드 부족·
  HP≤40%면 그래도 후퇴, 목표 달성·물약 0·골드 부족 상태에서 근접
  4마리/근접 1마리·HP 30% 모두 후퇴. 검증: 17→19케이스 전부 PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **`auto_quest_probe` 재실행(1장, `--fixed-fps 60`, 로그
  `/tmp/probe1.log`/`/tmp/probe2.log`, 저장소 밖) — 3연속 사망은 실제로
  사라졌다(두 번 다 `deaths=0`, `quest_mode=true` 유지, `QUEST_MODE_OFF`
  없음). 하지만 게임 30분 내내 `passed=false`로 새로운 정체를 찾았다:**
  kills=3(hill, 목표 6 미달성)에서 완전히 고정된 채 `map=hill`↔`village`
  를 216틱 주기로 영원히 반복한다(`ZONE_TIME`: village=29.4분,
  hill=0.58분). 원인: 어느 시점 전투로 HP가 34/100(<40% 임계값)까지
  깎인 뒤로 다시는 안 오른다(마을엔 자연 회복이 없고 potions=0·
  gold=18<물약값 20이라 살 수도 없음, 레벨업·사망 전체회복 둘 다 없음).
  이 상태에서 마을→hill로 걸어 나가자마자(전투를 시작하기도 전에)
  `_quest_should_retreat()`가 HP≤40%만으로 즉시 true를 반환해
  `_quest_do_retreat()`가 그 자리에서 바로 village로 돌려보낸다 - 근접
  적 유무·전투 진행 여부와 무관하게 매 사이클 똑같이 반복돼 추가 피해도,
  회복도, 사망(→마을 부활 전체회복)도 전혀 일어나지 않는 영구 정지다.
  이건 16:09/16:20이 우려하던 "회복 수단 없이 후퇴만 하는 영구 정지"와
  같은 부류지만, 이번엔 **적이 하나도 근처에 없는데도** HP 규칙 하나만
  으로 후퇴가 걸린다는 점이 다르다(위험이 실재하지 않는데 방어적으로
  후퇴함) - 즉 "후퇴"가 위협에서 벗어나는 행동이 아니라 그냥 진행을
  막는 문으로 작동한다. 밀도·경제와 마찬가지로 규칙③상 새 숫자·새 조건을
  임의로 못 만들어 INBOX에 새 질문으로 올린다(사람 판단 대기, 이
  조각은 여기서 멈춘다 - 다음 바퀴는 §10.7을 더 건드리기 전에 이 질문의
  답부터 기다릴 것).
- [x] **HP 후퇴 규칙에 `can_recover` 게이트 복원(2026-09-06, INBOX 19:20
  답) — 위 항목이 찾은 "적 0마리인데 HP 규칙만으로 영구 정지"를 고쳤다.**
  근접 규칙(적 ≥`AUTOHUNT_RETREAT_ENEMIES`)은 회복 수단과 무관하게 그대로
  두고, HP 규칙(HP ≤`AUTOHUNT_RETREAT_HP_RATIO`)에만 `_quest_can_recover()`
  (물약>0 또는 골드≥물약값) 게이트를 되살렸다 — 회복 수단이 아예 없으면
  "후퇴"는 회복하러 갈 곳이 없는 문(정지)일 뿐이므로 그 경우엔 후퇴하지
  않고 §10.5대로 그대로 밀고 나간다(근접<4면 싸운다 → 1킬로 골드+6이면
  기존 물약 귀환 규칙이 회복시키고, 죽으면 마을 부활 전체회복 — 어느
  쪽이든 진행). 회복 수단이 있을 때(potions>0)는 `_quest_should_retreat()`
  가 `try_use_potion()`을 먼저 시도해 성공하면 후퇴하지 않는다(14:55
  방식 복원 — 회복됐는데 한 칸 물러나 소탕까지 도는 낭비 방지).
  18:45 ④ 둘째 케이스(목표 달성·물약 0·골드 부족·근접 1마리·HP 30% →
  후퇴 true)는 사람이 오판으로 철회 — false로 뒤집었다. `check_autohunt_retreat.gd`
  (2)(4)(9)(9b)(9c)(10)(10b) 갱신·추가, 19케이스 전부 PASS,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **`auto_quest_probe` 재실행(`--fixed-fps 60`, 로그 `/tmp/probe1.log`,
  저장소 밖) — 19:15가 잡은 "적 0마리·HP 고정·216틱 hill↔village 영구
  반복"은 재현되지 않는다(kills가 0→여러 킬로 늘어나며 hill 안에서
  전투가 실제로 진행됨).** 다만 게임 30분 안에 4단계(1장 완료)까지는
  못 갔다: game_min≈1에 HP 53/100·potions 1·gold 36·enemies_near=3(4마리
  미만이라 근접 규칙 미발동, HP도 40% 초과라 HP 규칙 미발동)에서
  `pos`가 (410, 291)~(410, 298) 사이를 벗어나지 못한 채 `walk=true
  hunt=false`로 게임 5분(`STALL_FRAMES`) 그대로 고정 → STALL 판정
  (tick=19766). `deaths=0`, `quest_mode=true` 유지(19:15/19:20이 다루던
  결함과는 무관 — QUEST_MODE_OFF 없음). `ZONE_TIME`: village=0.08분,
  hill=5.41분. `KILLS_PER_MIN`=1.09. 이 새 정체는 후퇴 판정과 무관한
  별개 결함으로, 10:05 지시 ④가 이미 짚어 둔 것과 같은 부류다("`auto_walk`
  (마을 이동·동쪽 출구 이동)에는 회피가 아예 안 붙어 있다" — `_auto_avoid_obstacle()`
  이 `auto_hunt=true`일 때만 붙어 있어 `auto_walk` 경로 이동 중엔 장애물
  회피가 아예 동작하지 않는다). 새 숫자·새 회복 수단 없이 고쳤으므로
  이 항목은 여기서 완료 — 다음 순번은 10:05 지시(그중에서도 ④ auto_walk
  회피 결함이 §10.7 완주 검증의 선결 조건).
- (2026-09-06, INBOX 19:50 지시 처리) 10:05 ④를 `player.gd`
  `_auto_track_stuck()`에 0.5초 창(`_AUTO_STUCK_WINDOW`) 순 이동
  판정을 넣어 고쳤다 — 매 프레임 판정은 장애물 모서리에서 위아래로
  미세 진동하면(프레임당 이동량은 기준치를 넘지만 누적 순 이동은
  0에 가까움) `_auto_stuck_time`이 매 프레임 0으로 리셋돼 영원히
  트리거되지 않았다. `check_autohunt_retreat.gd` (18) 케이스로
  hill (410,291)~(410,298) 진동을 재현해 회귀 고정, 20케이스 전부
  PASS, `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **`auto_quest_probe --fixed-fps 60` 재실행(로그
  `/tmp/auto_quest_probe_1940.log`, 저장소 밖) — 위치 진동 자체는
  풀렸다(같은 지점에 완전히 고정되지는 않고 (405~411, 291~301)
  범위 안에서 계속 움직임). 그러나 STALL은 그대로 재현**: game_min 1~5
  내내 `walk=true hunt=false`·HP 63/100 고정·`enemies_near=3`·gold
  46·potions 2(변화 없음) — 근접 규칙(4마리 미만)도 HP 규칙(40%
  초과)도 안 걸리는데 게임 5분 진행 없음 → STALL(tick=19613).
  `ZONE_TIME`: village=0.08분, hill=5.37분. `KILLS_PER_MIN`=1.10(초반
  전투 몫, 이후 0). `deaths=0`, `quest_mode=true` 유지, level=1
  그대로. 원인 추정(코드 대조, `main.gd:2605~2621`): 1장 스토리 목표
  (6킬)를 채운 뒤 `goal_reached=true`가 되면 `has_live_enemy` 판정을
  건너뛰어(2607줄 `if not goal_reached:`) 살아있는 적이 있어도
  무조건 `auto_walk`로 동쪽 출구를 향해 걷는다 — 이때 남은 적
  (여기서는 3마리, 후퇴 임계 4 미만)이 출구 경로를 물리적으로
  막고 있으면 `_auto_avoid_obstacle()`은 정적 장애물(벽)과 살아
  움직이는 적을 구분하지 않아 회피→다시 막힘→반전→다시 막힘을
  반복할 뿐 뚫고 나가지 못한다(플레이어는 `auto_hunt=false`라 공격도
  안 함). 10:05 ④(장애물 회피 부재)와는 다른 결함 — 회피 로직 자체는
  도는데, "목표 달성 후에는 싸우지 않고 걷기만 한다"는 정책이 살아있는
  적으로 막힌 좁은 지형과 충돌한다. 새 숫자 없이 어떻게 뚫을지(예:
  일정 시간 이상 막히면 그 앞의 적만 공격해서 치우기)는 사람 판단이
  필요해 INBOX에 질문으로 올림 — 다음 바퀴는 이 질문에 답이 오기
  전까지 §10.7을 더 건드리지 않는다.
- (2026-09-06, INBOX 23:00 보정 처리) `tests/check_autohunt_path_walk.gd`의
  52개 전이 지역 FAIL(51fe132)은 게임 결함이 아니라 검사 하네스
  결함이었다. `player._physics_process(DT)`를 물리 프레임 밖 동기
  루프에서 직접 부르면 `move_and_slide()`가 idle 프레임 delta(≈0)를
  써서 velocity가 있어도 거의 안 움직인다. 프로브와 같은 방식
  (`--fixed-fps 60` + `await get_tree().physics_frame`, 36프레임=0.6초
  마다 목표 재설정)으로 바꾸니 52개 전부 `RESULT PASS`(6fc3687).
  `run_validation.sh`에 같은 플래그로 편입, 전체 `PROJECT_VALIDATION_OK`.
  이어서 22:08 (3) `auto_quest_probe --fixed-fps 60` 재실행(로그
  `/tmp/auto_quest_probe_2306.log`, 저장소 밖, wall_ms=26735):
  **`FINAL passed=false`, `stalled=false`** — 지형 STALL은 사라졌고
  village↔hill↔hill_ridge↔forest_w를 게임 30분 내내 계속 순환하지만
  `stage=1`에서 끝까지 못 벗어난다. `kills=98`(stage 1 목표는
  `_quest_hunt_target(1)`로 6 안팎, 이미 한참 전에 `goal_reached=true`
  였을 값인데도 "숲 동쪽 수호자 동굴로 가자" 전환이 안 됨),
  `chapter_kills=98`, `level=3`, `exp=105/135`, **`deaths=40`**(30게임분
  동안 40회 사망 — 이전 로그들의 0~1회와 차원이 다르다). `ZONE_TIME`:
  village=4.80분, hill=15.06분, hill_ridge=5.25분, forest_w=4.90분.
  `KILLS_PER_MIN`=3.27. 원인 미조사(이번 조각은 하네스 수정 범위) —
  18:45 답 (2)의 `_quest_grind_zone`(매 후퇴마다 직전 지역을 한 바퀴
  소탕 후 전진) 로직이 후퇴가 잦아지면 전진 자체를 막아 무한 순환을
  만드는 것으로 의심되나 확인 안 됨. INBOX에 질문으로 올림.
- (2026-09-06, INBOX 23:16 답 처리) `_quest_handle_death()`가
  `_apply_death_penalty()` 호출 전에 죽은 지역의 이전 지역
  (`World.exit_of(GameState.current_map, "w")`)을 `_quest_resume_zone`으로
  잡도록 고쳤다(prev가 미해금이거나 마을이면 안 잡음) - 후퇴 포기
  재개 메커니즘 재사용, 새 상수·상태 없음(`main.gd` `_quest_handle_death()`,
  커밋 a74bb42). `check_quest_death_resume.gd` 3케이스(이전 지역 재개·
  미해금 시 미재개·마을이면 미재개) 신설, `run_validation.sh` 편입,
  전체 `PROJECT_VALIDATION_OK`. `auto_quest_probe.gd`에 `DEATH` 로그
  (사망 순간 map/level/hp_max/potions/gold/enemies_near, 1분 샘플
  근사가 아니라 `quest_death_count` 증가 순간 직접 찍음)와
  `stage2_reached` 표기를 추가하고 예산을 30->60게임분(`BUDGET_FRAMES`
  216000)으로 올렸다(커밋 b2a6967). **재실행(로그
  `/tmp/auto_quest_probe_2333.log`, 저장소 밖, `--fixed-fps 60`,
  wall_ms=3868): `FINAL passed=false stalled=true deaths=0
  game_min=5.46 stage2_reached=false`** - 사망 순환은 확실히 사라졌다
  (30게임분 40회 -> 60게임분 예산에서 0회, `DEATH` 로그 한 줄도 안 찍힘).
  대신 게임 5분 만에 새(사실은 기존에 이미 알려진) 정체로 `STALL`:
  `tick=19660`, `map=hill`, `pos=(410.9996, 300.924)`, `walk=true
  hunt=false`, HP 53/100 고정, `enemies_near=0`(근접 규칙이 걸릴 대상이
  없음 - 즉 18:45가 고친 "통과 중 응전" 몫이 아니라 순수 지형 문제),
  `gold=36`·`potions=2`(자원도 안 변함). `hp` 라인이 game_min=1~5
  내내 정확히 같은 좌표(410.9247~410.9996, 291.00~300.92) 근방에
  갇혀 있다. `ZONE_TIME`: village=0.08분, hill=5.38분.
  `KILLS_PER_MIN`=1.10. 원인은 04:35/10:05 ④가 이미 짚어 둔 것과
  같은 부류로 강하게 의심된다 - `_auto_avoid_obstacle()`이
  `auto_hunt=true`일 때만 호출되고(`player.gd`), 스토리 목표 달성 후
  동쪽 출구로 걸어 나가는 `auto_walk` 경로(`walk=true hunt=false`)에는
  회피가 아예 안 붙는다. 19:50 처리분은 "모서리에서 위아래로 미세
  진동"만 잡았을 뿐 "auto_walk 자체에 회피가 없다"는 근본 원인은 그대로
  남아 있었다(같은 hill 지역, 좌표만 다름 - 그때는 (405~411,291~301),
  10:05 ④ 원본 제보는 (554.9, 323.0)). **결론: 60게임분으로도 stage 2에
  못 갔지만, 원인은 새 밸런스 판단이 필요한 사망 순환이 아니라 이미
  스펙이 나와 있는 auto_walk 회피 부재(10:05 ④)다** - 새 질문을 올리지
  않고 10:05 ④를 다음 순번 최우선으로 올린다(STATUS "다음에 할 것"
  참고). 23:15 질문·23:16 답은 이 항목으로 대체되어 INBOX에서 삭제.
- (2026-09-07, 10:05 ④ 후속 — 위 STALL의 진짜 원인 규명 + 고침,
  커밋 ce43b6d) hill (410.9996, 300.924)를 헤드리스 프로브로 직접
  재현해보니 "auto_walk에 회피가 없다"는 진단은 틀렸다 - 그 회피는
  이미 90ed569(10:05 ④ 1차 대응)에서 붙어 있었다. 실제로 그 좌표에
  플레이어를 두고 `_quest_east_exit_target("hill")`을 그대로 써서
  3600 물리프레임(60초)을 돌려보니 x=391~411 사이만 왕복하며 진행이
  전혀 없었다. 원인: 그 열의 길은 y=216~232인데 플레이어는 y=291~300
  (약 60~85px 벗어남, 전투로 끌려간 것으로 추정) - `_quest_east_exit_
  target()`은 이 거리를 무시하고 몇 칸 앞선 열의 길 지점까지 대각선
  목표를 그대로 잡는데, 그 대각선 경로 위 소품 덩어리가 옆걸음 회피
  거리(`_AUTO_AVOID_CLEAR_DIST` 18px)보다 넓어 좌우 어느 쪽으로 비켜도
  다시 막혀 반전만 반복했다(장애물 폭이 회피 폭보다 넓은 코너 - 04:35/
  10:05 ④가 다루던 "모서리 미세 진동"과는 다른 종류의 실패).
  고침(새 이동 시스템 없이 기존 `path_row_at`/`_quest_east_exit_target`
  재사용): `_quest_east_exit_target()`이 먼저 "지금 서 있는 열" 기준으로
  플레이어가 길에서 `QUEST_OFF_PATH_MARGIN`(24px, 1.5칸 - 회피 옆걸음
  거리 18px보다 넉넉히 크게 잡아 회피가 끝난 정상 위치를 오탐하지
  않게 함, 근거는 기존 관례치 조합이라 새 밸런스 숫자 아님) 넘게
  벗어나 있으면, 먼 목표 대신 "그 열의 길로 먼저 돌아오기"(x는 그대로,
  y만 길 행)를 목표로 삼는다 - 이러면 뚫어야 할 소품 폭이 대각선
  직행보다 훨씬 좁아 기존 회피(반전 포함)로 충분히 뚫린다. 되돌아온
  뒤(margin 안)에는 기존 앞내다보기 로직 그대로.
  **부가 발견(전수 재실행 중, marsh_deep 회귀)**: `World.path_row_at()`
  은 그 열에 있는 모든 길 타일 행의 **평균**을 돌려주는데, 세로로 긴
  지역(marsh_deep, 3화면=720px)에서 같은 열을 길이 굽이치며 두 번
  지나면 평균이 그 사이(둘 다 아닌 바위 지대)로 떨어질 수 있다 - 이
  함수를 그대로 써서 위 고침을 처음 만들었을 때 marsh_deep에서 새
  STALL이 났다. `World.nearest_path_row_at(area, col, near_row)`를
  새로 두어(같은 열의 길 타일 중 `near_row`에 가장 가까운 것을 그대로
  고름, 평균 없음) 이 고침에서만 쓰고 `path_row_at()`(앞내다보기용,
  기존 52개 통과 실적 그대로 둠)은 손대지 않았다.
  검증: `tests/check_autohunt_path_walk.gd`에 이 좌표(hill, 3600프레임
  예산)를 회귀 케이스로 추가 - 서쪽 스폰 52개 전이 지역 + 이 케이스
  모두 `RESULT PASS`(고침 전에는 이 케이스만 FAIL, marsh_deep 포함
  52개는 항상 PASS였다가 1차 고침에서 일시 회귀했던 것도 함께 확인).
  `bash tests/run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  10:05 지시의 ①(quest_stage 분류표)·②(귀환 판정)·③(장별 홈 마을
  해금)은 아직 손대지 않았다 - 다음 순번은 `auto_quest_probe --fixed-fps
  60` 60게임분 재실행으로 이 STALL이 실전에서도 풀리고 `stage2_reached`
  까지 가는지 먼저 확인한 뒤 ①②③으로 이어간다.
- (2026-09-07, 위 60게임분 재확인 — STALL은 고쳐졌으나 forest_w 밀도
  때문에 1장이 여전히 못 끝남, 코드 변경 없음) `auto_quest_probe
  --fixed-fps 60`을 다시 돌렸다(로그 `/tmp/auto_quest_probe_0907.log`,
  저장소 밖). **`FINAL stage=1 map=hill_ridge passed=false stalled=false
  deaths=7 level=12 exp=697/1417 game_min=60.00 stage2_reached=false`.**
  `stalled=false`로 ce43b6d의 위치 고정 STALL은 재현되지 않았다 - 그
  대신 한 지점에 갇히지 않고 계속 움직이면서도 60게임분 내내 `glade`를
  한 번도 못 열었다(`unlocked` 목록이 처음부터 끝까지
  `["village","hill","hill_ridge","forest_w"]` 그대로, `BOSS_LOG` 완전
  공백). `ZONE_TIME`: village=4.03, hill=27.34, hill_ridge=10.33,
  forest_w=18.31(분). forest_w 로그 84줄 중 62줄이 서쪽 스폰 좌표
  `x=35.19989` 그대로이고, 이 지역에서 도달한 최대 x는 929.3px
  (지역 너비 `World.pixel_size_of("forest_w").x`=2560px, 동쪽 경계
  목표는 그 중 2556px)로 전체 폭의 약 36%까지밖에 못 갔다. 사망 7회는
  전부 game_min 1.20~16.36 사이(레벨 1~6 저레벨 구간)에 몰려 있고, 그
  뒤 44분(레벨 6~12)은 사망 0인데도 여전히 forest_w를 못 뚫는다 - 즉
  "덜 자라서 죽는다"가 아니라 레벨이 올라도 못 넘는 구조적 밀도
  문제다. **이건 새 결함이 아니라 INBOX 2026-09-06 18:35 질문/18:45
  답 스레드("forest_w 40마리가 통과 지역 밀도로 과한지는 감독이 별도
  판단, 손대지 마라")가 이미 짚은 문제와 같은 것으로 보인다** - 그
  스레드의 (a)(b)(c) 후보에 대한 답이 아직 안 왔으므로 이 조각은 더
  건드리지 않는다. 10:05 지시의 ①②③은 이 밀도 문제가 먼저 풀려야
  `stage2_reached`를 검증할 수 있어 계속 대기.
- (2026-09-07, INBOX 00:12 ①②④ 완료 — 통과 중 근접 추격 도입, 커밋
  0cf53d2) 위 밀도 진단은 절반만 맞았다 - 감독이 직접 60게임분을 다시
  실측(`/tmp/auto_quest_probe_0006_director.log`)해 보니 진짜 병목은
  forest_w 밀도 자체가 아니라 `_quest_mode_tick()`이 통과 중(goal_reached)
  에는 이미 사거리 안에 들어온 적만 때리고 추격을 안 해, 40마리가 있는
  forest_w에서 몹이 계속 따라붙어 맞다가 물약이 0이 되고 → 골드도
  부족(gold=12<물약값 20)해서 회복 못 함 → HP가 죽을 때까지 깎이는
  것이었다(`_quest_should_retreat()` 목표 달성 분기가 근접 규칙을 아예
  안 봄). 고침: `_quest_should_retreat()`와 같은 반경(near_dist=
  attack_range*2.5, 새 숫자 없음) 안에 살아있는 적이 있으면 통과 중에도
  `auto_hunt=true`로 그 적을 쫓게 했다(`_quest_transit_nearby_enemy()`
  신설). 먼 적은 그대로 안 쫓으므로 5b8da29가 막은 재리스폰 무한 왕복은
  재발하지 않는다. 검증: `check_quest_transit_chase.gd`(3케이스) 신설 +
  `check_autohunt_retreat.gd` (14)(15)를 새 동작에 맞게 갱신, 전부
  `run_validation.sh` 편입, `PROJECT_VALIDATION_OK`.
  **60게임분 재실행 결과(로그 `/tmp/auto_quest_probe_0007_director.log`,
  저장소 밖) - 고침 전/후 비교:**

  | 지표 | 고침 전(23:16, `_2306.log`) | 고침 후(0007) |
  |---|---|---|
  | kills | 98 | 782 |
  | deaths | 40 | 1 |
  | level | 3 | 14 |
  | 도달한 최고 지역 | forest_w(36%까지) | dungeon(cave_deep 문턱) |
  | unlocked_maps | village/hill/hill_ridge/forest_w | +glade, +dungeon |
  | stage2_reached | false | false |

  forest_w 정체(진입→village 순환)는 확실히 풀렸다 - 사망이 40→1로
  줄고, 이전엔 한 번도 못 연 `glade`·`dungeon`까지 열렸다. **그러나
  60게임분이 끝나도 여전히 `stage=1`, `stage2_reached=false` - 새로운
  병목을 찾았다.** 챕터1 보스는 `cave_deep`(`World.AREAS`, `dungeon`의
  동쪽 exit)에 있는데(`world.gd:160` `"boss": 1`), 60분 내내
  `unlocked_maps`에 `cave_deep`이 한 번도 추가되지 않았고 `BOSS_LOG`도
  완전 공백이다. 로그를 보면 `village→hill→hill_ridge→forest_w→glade→
  dungeon→village`를 반복하는데(예: 48.43→48.49→48.77→49.09→49.90→
  50.44(hill_ridge, `grind=`로 사냥 재개)... `dungeon`에 도달할 때마다
  물약이 0 근처가 되고(예: 48.43 `map=village potions=0`, 48.49
  `map=hill potions=9`(방금 삼) 직후 라운드마다 반복), 물약이 0이 되면
  `_quest_mode_tick()`의 사냥터 분기(2602줄, INBOX 14:20 답)가 그
  자리에서 `_quest_travel_home()`으로 마을로 순간이동시킨다 - 이때
  `_quest_resume_zone`을 세팅하지 않으므로(그 분기는 사망·후퇴포기
  분기와 다름) 다음 출발은 항상 마을 exit(`_quest_east_exit_target
  ("village")`, 즉 `hill`)부터 다시 시작한다. 즉 **매 왕복이 hill부터
  다시 시작해 dungeon까지 가는 동안 물약을 다 써서, dungeon 문턱에서
  다시 마을로 돌아가는 것을 무한 반복**한다(예측: 물약 소비 속도가
  거의 일정하므로 이 지점 근처에서 계속 귀환이 걸린다 - 밀도·경제
  숫자를 바꾸지 않아도 되는 구조 문제로 보인다). 후보(밸런스 숫자
  변경 없음): 물약 조기 귀환(2602줄)도 후퇴 포기(`_quest_do_retreat`
  giveup)·사망(`_quest_handle_death`)과 같은 방식으로 귀환 직전
  `GameState.current_map`을 `_quest_resume_zone`에 기억해 뒀다가,
  다음 마을 출발 때 처음(hill)부터가 아니라 그 지역부터 재개하게 한다
  (이미 있는 resume_zone 메커니즘 재사용, 새 상태 없음 - 단, 후퇴
  giveup의 resume_zone은 "한 티어 아래"이고 이건 "방금 있던 그 자리"라
  의미가 달라 같은 변수를 겹쳐 쓰면 안 섞이는지 확인 필요). 코드
  읽기로 확인한 가설일 뿐 아직 고치지 않았다 - 다음 바퀴가 이어받을
  것: 이 가설을 실제로 검증(물약 조기 귀환 시 `_quest_resume_zone`
  미설정이 dungeon→cave_deep 진입 실패의 원인이 맞는지 로그로 재확인)
  하고 맞으면 고친 뒤 60게임분 재실행. INBOX 00:12 항목은 이 결과와
  함께 삭제하고, 새 관찰을 STATUS "다음에 할 것"에 넘긴다.
- (2026-09-07, INBOX 00:45 답 완료 — 새 변수 `_quest_restock_zone` 도입,
  커밋 200cd7c) 위 가설이 맞았다. 물약 조기 귀환 직전 있던 지역을
  `_quest_restock_zone`에 기억해 뒀다가(`_quest_resume_zone`과 겹치지
  않는 새 변수), 마을에서 물약을 채운 직후 그라인드 없이 그 자리로
  바로 돌아가게 했다. `check_quest_restock_return.gd`(3케이스) 신설,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **60게임분 재실행 결과(로그 `/tmp/auto_quest_probe_0007_restock.log`,
  저장소 밖) - 고침 전/후 비교:**

  | 지표 | 고침 전(0007, 위 항목) | 고침 후(restock) |
  |---|---|---|
  | kills | 782 | 723(레벨 15 도달로 `chapter_kills` 리셋 아님, 최종 시점) |
  | deaths | 1 | 0 |
  | level | 14 | 15 |
  | 도달한 최고 지역 | dungeon(cave_deep 문턱, 미진입) | **cave_deep 진입(47.03분, 1회)** |
  | unlocked_maps | +glade, +dungeon | +cave_deep |
  | stage2_reached | false | false |
  | wall_ms | (미기록) | 62944 |

  ZONE_TIME(게임분, 최종): village=1.01, hill=8.87, hill_ridge=21.55,
  forest_w=20.55, glade=4.76, dungeon=3.19, **cave_deep=0.07**.
  BOSS_LOG는 여전히 공백(보스 처치·재도전 로그 없음).

  물약 조기 귀환 순환(가설)은 확실히 풀렸다 - dungeon→cave_deep 문턱을
  넘어 실제로 보스 지역에 들어갔다(이전엔 60분 내내 0회). **그러나
  cave_deep 체류가 0.07게임분(약 4초, 246프레임)뿐이고 이후 남은
  13게임분 동안 cave_deep에 다시 들어가지 않았다 - 새로운 병목.**
  로그(`tick=169313`, cave_deep 진입 직후 `potions=8`)에서
  `tick=169559`(0.07분 뒤)에 이미 `map=forest_w`로 바뀌어 있다 -
  cave_deep 서쪽(`dungeon`)이 아니라 그보다 더 서쪽인 forest_w로
  건너뛴 것으로 보이는데, `_quest_do_retreat()`의 일반 후퇴(prev=
  `exit_of(area,"w")`)로는 cave_deep→dungeon 한 칸만 물러나야 하고
  포기(giveup)라면 홈(village)을 거쳐야 해 forest_w로 직행하는 경로가
  코드 읽기로는 바로 안 보인다 - cave_deep 진입 시점의 `_quest_retreat_zone`
  ·`_quest_grind_zone` 값이 이미 이전 사이클(예: forest_w 그라인드)에서
  세팅돼 있었을 가능성이 있으나 이 로그 포맷(전이 줄만 찍음, 그 사이
  개별 `_quest_mode_tick()` 판정은 안 보임)으로는 확정 못 함. 코드
  읽기로 세운 가설일 뿐 검증 안 됨 - 다음 바퀴가 이어받을 것: 전이 줄
  사이 개별 틱 판정(`_quest_should_retreat()`/`_quest_do_retreat()`
  진입·탈출 시점의 `_quest_retreat_zone`/`_quest_grind_zone`/근접 적
  수)을 별도로 찍는 임시 로그를 추가해 cave_deep→forest_w 직행 경로를
  재현하고, 보스(tier3 skull×5·bat×4 + 보스 1마리)가 레벨15 플레이어
  기준 상대가 되는지(체력/공격력 대비)도 같이 살펴야 한다 - 이건
  밸런스 숫자라 감독 확인 필요. INBOX 00:45 답/00:40 질문 항목은 이
  결과와 함께 삭제하고, 새 관찰을 질문으로 다시 올린다.
- (2026-09-07, INBOX 01:20 답 ①②③ 완료, 커밋 ccfbe09) 감독이 코드로
  확정한 연쇄 후퇴 원인(근접≥4마리 단독 후퇴 규칙 + 피격 즉시 재평가가
  겹쳐 후퇴 도착 프레임에 또 피격→또 후퇴가 한 프레임에 연쇄)을 고쳤다.
  `_quest_should_retreat()`: 근접 마릿수는 더 이상 단독 후퇴 사유가
  아니고 `HP<=AUTOHUNT_RETREAT_HP_RATIO`일 때만 본다(HP>40%면 근접 수와
  무관하게 후퇴 없음). `_on_health_changed()`: 후퇴 재평가를
  `auto_hunt`/`auto_walk_active` 중 하나가 켜져 있을 때만 하도록 게이트
  추가 - `_quest_do_retreat()`가 둘 다 꺼 놓으므로 후퇴 직후 도착
  프레임의 피격은 다음 `_quest_mode_tick()`(0.6초)까지 무시된다. 숫자
  변경 없음, 새 상태 변수도 0개(감독이 예상한 `_quest_retreat_pending`은
  필요 없었다 - auto_hunt/auto_walk_active 게이트만으로 충분). 검증:
  `check_autohunt_retreat.gd`에 세 경계(i)~(iii)·연쇄 차단(iv) 추가,
  `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`. 검증 중 테스트
  하네스 버그도 발견해 같이 고쳤다 - (18)번 케이스가 모서리 벽 옆
  (410,291)에 플레이어를 남겨 둬서 다음 조각의 근접 스폰이 그 벽
  너머로 밀려나 거리 판정이 어긋났다(`spawn_pos` 복원으로 고침, 새
  로직 버그 아님).
  **④ 60게임분 프로브 재실행 결과(`--fixed-fps 60`, 로그
  `/tmp/auto_quest_probe_0009.log` 저장소 밖) - `stage2_reached`는
  여전히 false, 그러나 이번엔 cave_deep 근처에도 못 갔다:**
  `FINAL stage=1 map=glade passed=false stalled=true deaths=0 level=9
  exp=568/646 game_min=23.20 wall_ms=20191`. `ZONE_TIME`: village=0.15,
  hill=1.36, hill_ridge=10.28, forest_w=3.45, glade=7.34, dungeon=0.62.
  `KILLS_PER_MIN`=6.72(직전 restock 프로브 대비 크게 향상 - 연쇄 후퇴로
  날아가던 물약 낭비가 없어진 영향으로 보임). game_min 18부터 23.20까지
  `pos=(501.076, 300.9991)` 부근에 완전히 고정된 채 `hunt=true
  enemies_near=0`이 반복되다 `STALL`(게임 5분 kills/map/stage/level
  무변화)로 끊겼다 - `near_props`에 `rock_s`(cell 32,18)가 찍힘. **이건
  01:20 항목이 고친 연쇄 후퇴와 무관한 새 결함이다**: `hunt=true`인데
  `enemies_near=0`이면 오토사냥이 죽었거나 사라진 적을 향해 계속
  `auto_hunt` 상태를 유지한 채 `rock_s` 장애물에 막혀 못 움직이는
  것으로 보인다(코드 읽기로 세운 가설, 미검증 - `player.gd`
  `_auto_hunt_tick()`이 타겟 소실 시 `auto_hunt`를 안 끄는지, 또는
  회피(`_auto_avoid_obstacle`)가 `auto_hunt` 이동에도 걸리는지 확인
  필요). cave_deep 연쇄는 이번 실행에서 재현되지 않았다(애초에 그
  근처까지 못 갔다) - (b) 재상신은 보스전이 실제로 벌어져야 하는데
  이번엔 dungeon(0.62분 체류)조차 제대로 못 뚫었으니 아직 이르다.
  다음 바퀴가 이어받을 것: (1) glade `hunt=true·enemies_near=0` 정지를
  `check_autohunt_retreat.gd`나 새 검사로 재현(재현 좌표
  (501.076, 300.9991) 부근, `rock_s` cell 32,18 - 04:35 지시가 이미
  정한 "정지 감지"(120틱 위치 변화 <4px인데 velocity!=0) 패턴 재사용),
  (2) 원인 확정 후 고침(밸런스 숫자 아님, 새 이동 시스템 금지 - 기존
  회피·타겟 소실 로직 보강), (3) 60게임분 재실행. INBOX 01:15/01:20
  항목은 ①②③ 완료·검증 근거로 삭제하고, 새 관찰은 질문으로 올린다.
- (2026-09-07, INBOX 02:16 지시 완료, 커밋 4b2fcb5) glade `rock_s` 정지
  결함의 진짜 원인은 "회피가 못 뚫는 소품 크기"가 아니라 "막힌 목표를
  계속 추격"이었다: `_auto_hunt_tick()`에 접근 정체 판정을 추가해,
  같은 적을 향해 `_AUTO_HUNT_GIVEUP_STUCK`(2.5)초 동안 거리가
  `best_dist_seen`보다 4px 이상 줄지 않으면(전투 중 사거리 안은 제외)
  그 적을 `_AUTO_HUNT_BLACKLIST_TIME`(6)초 블랙리스트에 넣고 다른 적을
  고른다(`scripts/player.gd`). 소품 뭉치 크기·모양을 몰라도 되므로 새
  회피 숫자 없음. `tests/check_autohunt_obstacle_stall.gd`(재현 좌표
  (501.076, 300.9991) 고정, 정지 감지 600틱 임계) 신설,
  `run_validation.sh`에 `--fixed-fps 60`으로 편입(이전 바퀴가 빠뜨렸던
  것). 단독 실행 결과 `worst_streak=127`(<600, 통과), 1분 안 kills
  0→7. 전체 스위트 `PROJECT_VALIDATION_OK`.
  **60게임분 프로브 재실행 결과 - glade 정지는 확인상 재발하지 않았고
  (경로상 그 근처를 지날 때 안 멈춤), `stage2_reached`는 여전히
  false다. 새 STALL, 이번엔 전혀 다른 원인(코드 읽기로 확정, 검증
  스크립트로는 미검증):** `FINAL stage=1 map=cave_deep passed=false
  stalled=true deaths=1 level=11 exp=37/1090 game_min=32.65
  wall_ms=28968`. `ZONE_TIME`: hill_ridge=17.12, forest_w=5.62,
  dungeon=2.67, cave_deep=5.39(직전 restock 프로브의 0.07분보다 훨씬
  길게 버팀 - 조기 귀환 순환은 여전히 안 재발). STALL 시점
  `pos=(630.0, 248.x)` walk=true hunt=false enemies_near=0
  near_props=[]로 game_min 28~32 내내 완전히 고정. 원인:
  `world.gd`의 `cave_deep` 항목은 `"exits": {"w": "dungeon"}`뿐이고
  `"boss": 1`이 붙은 막다른 보스방인데(`main.gd` `_spawn_boss()`가 보스를
  고정 좌표 (216,110)에 스폰), `_quest_mode_tick()`의 통과 판정
  (`_quest_effective_goal_reached()` → `_quest_hunt_goal_reached()`)은
  그 지역 몹 킬 목표(스폰표 skull×5·bat×4)만 보고 보스 생존 여부는
  안 본다 - 몹을 다 잡으면 `goal_reached=true`가 되고, 그 시점에 보스가
  아직 살아있어도 (216,110)에서 멀리 떨어져 있으면
  `_quest_transit_nearby_enemy()`(반경 attack_range*2.5)가 못 잡아
  `_quest_east_exit_target()`으로 동쪽 출구를 향해 걷는데, cave_deep엔
  "e" 출구가 없어 지역 끝(`bounds.x-4`)에 도착한 뒤 그 자리에 영원히
  선다(다음 틱마다 같은 목표를 다시 계산해 같은 좌표를 돌려주므로
  이동할 이유가 없음). 즉 "몹 킬 목표 완료 = 그 지역 통과 완료"라는
  전제가 보스방에는 안 맞는다. 고칠 방향(다음 바퀴, 미검증 가설):
  보스 챕터 지역(`World.boss_chapter_of(area) > 0`)이고 아직
  `GameState.boss_defeated`가 안 됐으면, 몹 킬 목표 달성 여부와
  무관하게 살아있는 보스(`enemy.is_boss`)를 `_quest_transit_nearby_enemy`
  거리 제한 없이 추격하도록 `_quest_mode_tick()` 사냥터 분기에 조건을
  추가한다(새 숫자 없음, `is_boss` 플래그는 이미 있음). 검증: cave_deep
  같은 서쪽 전용 출구 보스방에서 몹을 먼저 다 잡고 보스가 먼 곳에 남는
  상황을 고정해 `check_autohunt_retreat.gd`류에 케이스 추가하거나 새
  `check_autohunt_boss_room.gd`(재현 좌표 (630, 248) 부근 고정), 이후
  60게임분 재실행. INBOX 02:05/02:10/02:16 항목은 이 결과로 삭제하고
  새 질문을 올린다.
- [x] **막다른 보스방 방치 정지 수정(2026-09-07, INBOX 02:45 질문·02:50 답
  ①③④, 커밋 9e32e6d)** — 위에서 세운 가설대로 `_quest_mode_tick()`에
  통과 판정(`_quest_effective_goal_reached()`)보다 앞서 검사하는 분기를
  추가: `World.boss_chapter_of(GameState.current_map) > 0`이고 그 지역에
  살아있는 보스(`is_boss`, `health>0`, 새 헬퍼 `_quest_has_live_boss()`)가
  있으면 몹 킬 목표 달성 여부와 무관하게 거리 제한 없이 `auto_hunt=true`로
  전환한다(새 숫자 없음). `GameState.boss_defeated`(1장 전용 플래그)는
  보지 않음 - 보스는 재입장마다 `_spawn_boss()`로 리스폰되므로. 기존
  RETURN 단계 귀환 검사가 이 분기보다 앞이라 보스 처치 직후엔 재발동
  안 함. ②(2.5초 추격/6초 정지 진동 우려)는 이번 프로브에서 재현되지
  않아 선반영하지 않았다(관찰 시 대응 예정으로 남김).
  검증: `tests/check_autohunt_boss_room.gd` 신설(재현 좌표 (630,248)) -
  (i) cave_deep 잡몹 전멸·보스만 생존 시 `auto_hunt` 전환 및 실제 접근/
  보스 사망, (ii) 보스 처치 → RETURN 전환 → 다음 틱 village 귀환,
  (iii) 일반 지역(hill_ridge)에서는 이 분기가 안 걸림(회귀 없음) 3케이스
  전부 PASS, `run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
  **④ 60게임분 프로브 재실행 결과(`--fixed-fps 60`) - 이번엔 cave_deep
  보스방을 실제로 통과해 `stage2_reached=true`를 처음으로 달성했다:**

  | 지표 | 값 |
  | --- | --- |
  | `FINAL stage` | 4(귀환·2장 전환까지 완료) |
  | `passed` | true |
  | `stalled` | false |
  | `stage2_reached` | true |
  | `game_min` | 26.12 |
  | `wall_ms` | 20741 |
  | `deaths` | 1 |
  | `level` (종료 시점) | 11 |
  | cave_deep 보스 처치 시점 | game_min≈26.09(kills=218) |
  | 2장 전환(`village`, `chapter=2`) | game_min≈26.12 |

  cave_deep 진입(game_min=17.58)부터 보스 처치(26.09)까지 잡몹 그라인드
  왕복(dungeon↔cave_deep↔village)이 이어지다 보스만 남자 곧장 추격해
  처치, 그 직후 RETURN(stage 2→3)·마을 대화(3→4)·2장 전환까지 한 번에
  이어졌다 - §10.5의 연쇄 후퇴/왕복 없이 자연스럽게 통과. 우려했던
  "2.5초 추격/6초 정지" 블랙리스트 진동은 로그에 나타나지 않았다(cave_deep
  구간에 정지 표시 없음). 사망 1회는 game_min=5.35(hill_ridge, 이전
  바퀴들과 같은 초반 저레벨 다수 근접 사망 패턴, 물약1·골드1) - 14:20
  답의 "궁핍하면 싸운다" 판단대로 결함이 아니라 예상된 동작으로 기록만
  한다. **1장 전체가 처음으로 끝까지 통과됨 - INBOX 02:45/02:50 항목은
  이 결과로 삭제.**
- [x] **INBOX 10:05③ - `_quest_home_town()` 3·4·10장 귀환 실패 버그
  발견·수정(2026-09-07).** ①②는 이미 `QUEST_STAGE_KIND`(commit
  3e2f8ff)로 구현돼 있었으나(INBOX의 "미착수" 메모는 낡은 것), ③을
  확인하던 중 실제 결함을 찾음: `_quest_home_town()`이
  `World.chapter_of(t) == GameState.chapter` 정확히 일치하는 마을만
  찾는데, 3·4·10장은 설계상 마을이 없어(docs/STATUS.md:3113) `""`를
  반환 - RETURN 단계 귀환(`_quest_travel_home()`)과 물약 조기귀환이
  이 세 장에서 조용히 멈추는 버그였다. 고침: 정확히 일치하는 장이
  없으면 `chapter_of(t) <= GameState.chapter`인 마을 중 가장 최근
  것으로 대체(2·3·4장은 harbor 공유, 10장은 rift_camp 재사용 - 이미
  기존 주석이 "10장 피날레는 rift_camp에서 쏜다"고 전제하고 있던
  것과 일치). 새 숫자 없음. 검증: `tests/check_quest_home_town.gd`
  신설, 1~10장 전부 기대 마을과 일치 PASS, `run_validation.sh` 전체
  `PROJECT_VALIDATION_OK`. 10:05 항목의 나머지(①③ 각 검증 테스트
  보강, `check_quest_mode_all_chapters.gd` 다장 통과 검증)는 아직
  남아 있어 INBOX 항목 자체는 유지.
- [x] **INBOX 10:05(a) - "장별 독립 세팅" 대신 "1장부터 이어 달리는
  연속 시뮬레이션"으로 승인(감독 답, 2026-09-07 05:18) - `tests/
  auto_quest_probe.gd`를 1장에서 멈추지 않고 10장(최종장, `quest_stage
  >= 70`)까지 이어가도록 확장.** 격리 세팅에 필요한 "챕터별 권장
  레벨/장비" 상수가 기획서 어디에도 없어(규칙③, `game_state.gd` 전체
  grep 확인) 장별 독립 세팅은 여전히 못 만드므로, 그 값이 필요 없는
  연속 시뮬레이션 형태를 택했다. 변경: ① `BUDGET_FRAMES`를 게임
  60분(216000)→600분(2160000)으로 확대(실측상 게임 60분이 벽시계
  13~52초였으므로 벽시계는 실제 상한이 아니다), ② `STALL_FRAMES`를
  게임 5분(18000)→"퀘스트틱 600개"(21600, = 600×`PHYS_PER_QUEST_TICK`,
  지시 문구 "600틱"을 그대로 프레임 단위로 환산한 값, 새 숫자 아님),
  ③ `GameState.chapter` 변화마다 `CHAPTER_ENTER`로 (틱, 레벨, 장비
  weapon/armor/job/second_job/stats) 출력, ④ 종료 조건을
  `quest_stage>=4`(1장 완료)에서 `quest_stage>=70`(10장 최종장 보스
  처치 후 대사까지, `main.gd:1085`)로 변경. 벽시계 상한은 호출부에서
  `perl -e 'alarm(N); exec(...)'`로 건다(지시대로).
  **첫 실행 결과(`/tmp/auto_quest_probe_allchapters_0907.log`, 저장소
  밖, alarm 480초 중 실제 wall_ms=13479로 자연 종료):**

  | 지표 | 값 |
  | --- | --- |
  | `CHAPTER_ENTER` | chapter=1(tick=0)뿐 - chapter=2 전환 전에 정지 |
  | `FINAL stage` | 1 |
  | `passed` / `stalled` | false / true |
  | `game_min` (정지 시점) | 15.74 |
  | `level` | 8 |
  | `deaths` | 0 |
  | 정지 위치 | `map=glade pos=(555.31, 308.93) cell=(34,19)`, 근접
    소품 `rock_s cell=(32,19)` |

  **매 실행마다 정지 지점이 다른(비결정적) 기존 현상(10:05④ 실측
  메모, INBOX 02:05 질문 스레드)과 같은 부류로 판단** - 이번엔 hill이
  아니라 glade의 `rock_s` 근처에서 6분간 `hunt=true`인데 진행 없이
  멈췄다. 과거 4b2fcb5에서 "glade rock_s(cell 32,18) 정지는 재현 안
  됨"이라 적었던 것과 좌표(`cell 32,19`, 1칸 차이)·정황이 유사해 같은
  장애물 뭉치의 다른 진입 각도로 추정되나 확정은 아니다. **원인
  미확정 - 다음 바퀴가 `player.gd`의 glade `rock_s` 부근 회피 경로를
  hill (554.9,323.0)/(410.9996,300.924) 재현 방식과 같은 헤드리스
  프로브로 좁혀 조사한다.** 이 결과 자체가 (a)의 이번 바퀴 성과(장별
  진입 틱 표 + 어디까지 갔는지)이며, 새 결함으로 다루되 이미 알려진
  "회피 폭 < 장애물 폭" 부류와 다른 별도 조사가 필요한지부터 판단할
  것. 새 숫자 없음, 코드 변경은 `tests/auto_quest_probe.gd`만.
- [x] **위 STALL 원인 조사 + 부분 수정(2026-09-07, 커밋 16f6883).** 헤드리스
  프로브(`tests/auto_quest_probe.gd`와 같은 코드 경로를 좁혀 재현: glade에
  `pos=(536.1769, 308.9252)`에서 `auto_hunt=true`만 켜고 실제 spawn된 적을
  상대)로 재현한 결과, "회피 폭 < 장애물 폭"(hill 부류, 10:05④가 고친 것)과
  **다른 새 부류**였다: 장애물 뒤편에 적이 여러 마리 있으면
  `_auto_hunt_tick()`이 하나(A)를 `_AUTO_HUNT_GIVEUP_STUCK`초 뒤 포기·
  블랙리스트해도, 다음 틱 곧장 방향이 비슷한 다른 적(B)을 골라 같은
  장애물에 다시 막히고, `_AUTO_HUNT_BLACKLIST_TIME`(6초)이 지나면 A의
  블랙리스트가 풀려 다시 A로 - A↔B(혹은 여러 후보) 사이 핑퐁이 영원히
  이어졌다(재현 로그: seed=1, pos가 (490.9,307)/(522.9,323) 두 점 사이만
  왕복). 고침(둘 다 기존 로직 보강, 새 이동 시스템 없음):
  ① `_auto_hunt_tick()`이 포기할 때 그 목표와 같은 방향(45도 이내,
  `_AUTO_HUNT_GIVEUP_DIR_COS := 0.7`)의 다른 살아있는 적도 같이
  블랙리스트한다 - "막힌 방향 자체를 잠깐 접기"로 일반화, 새 자료구조
  없이 기존 `_auto_hunt_blacklist` 딕셔너리에 여러 id를 넣을 뿐.
  ② `_auto_avoid_obstacle()`이 반대 방향까지 최대 거리(escalation=4배)로
  재시도해도 또 막히면, 옆걸음을 그만 접고 목표 반대 방향으로
  `_AUTO_AVOID_RETREAT_TIME`(1초) 물러난다(`_auto_avoid_retreat_time`) -
  "옆이 아니라 사방이 막힌 구석"으로 보고 일단 빠져나온다.
  **검증(시드 1, 헤드리스 진단 스크립트, 커밋 안 함):** 고치기 전엔
  pos가 두 점을 영원히 왕복(10800틱 내내 진행 없음), 고친 뒤엔 그
  구석을 벗어나 지역을 가로질러 실제로 사냥을 이어가다 서쪽 끝
  `pos≈(34,120)`(모든 적 소탕)까지 도달 - 완전 해결 확인.
  `tests/check_autohunt_obstacle_stall.gd`에 이 좌표를 두 번째
  `REPRO_POSITIONS` 케이스로 추가, 시드 5개 중 3개(20260907~909)는
  `worst_streak<600`까지 완전히 풀렸다.
  **남은 결함(시드 20260910/911, 미해결):** 이 좌표는 `y=308.9` 선을
  따라 긴 담 형태의 장애물이 있고, 담을 넘는 방향의 폭 자체가 최대
  회피 거리(escalation 4배 = 72px)보다 넓어 위 ②(물러나기)로도 못
  넘는다 - 게다가 `_auto_track_stuck()`이 담을 따라 미끄러지는 잔진동
  (30% 문턱을 살짝 넘는 옆 이동)을 "진행"으로 오판해 escalation을 자꾸
  1.0으로 되돌려 물러나기 자체가 거의 발동하지 않는다(물러나기 발동
  문턱을 escalation≥2로 낮춰 재실험했으나 이 두 시드는 결과가
  똑같았다 - 담 자체를 넘는 회피가 아니라 다른 접근 필요). 이 둘은
  `tests/check_autohunt_obstacle_stall.gd`의 `SEEDS_HARD`로 표시해
  worst_streak 상한은 미검사(사냥 진행만 확인)로 남겨뒀다.
- [x] **INBOX 05:54④ 처리(2026-09-07) — SEEDS_HARD(910/911) 담 실측 + 고침
  시도 1회 실패 기록.** 위 항목의 `REPRO_POSITIONS[1]=(536.1769,308.9252)`
  담을 헤드리스 진단 스크립트(임시, 커밋 안 함)로 실측했다: 소품 3개가
  어긋나게 붙어 하나의 연속 장벽을 이룬다 —
  `x_range=[448,496] y=[280,304]` / `[496,528] y=[304,320]` /
  `[528,576] y=[312,336]`. 즉 x=448~576(폭 128px), y=280~336(56px)에
  걸친 **대각선 계단형** 장벽이지 단순 수평 담이 아니다. 최대 회피
  거리(`_AUTO_AVOID_CLEAR_DIST`18 × `_AUTO_AVOID_ESCALATION_MAX`4 =
  72px)와 비교하면 담을 등지고 동쪽으로 빠지는 가장 가까운 틈은
  player 위치(x=536)에서 약 40px(x=576까지)로 72px 이내지만, 서쪽으로는
  88px(x=448까지)로 72px을 넘는다 — **한쪽 방향은 이론상 회피
  거리 안에 있는데도 못 빠져나온다.**
  원인은 폭이 아니라 `_auto_avoid_obstacle()`의 escalation 리셋
  시점이었다: 옆걸음이 `_AUTO_AVOID_CLEAR_DIST*escalation`만큼
  "성공"(실제 이동)하면 escalation을 곧장 1.0으로 되돌리고 목표
  방향으로 복귀하는데, 이 담처럼 계단형이면 첫 18px 옆걸음이 담을
  등지고 미끄러진 것일 뿐 실제로 목표 방향이 뚫리지 않은 채 곧장 다시
  막힌다 — 그런데도 escalation은 이미 1.0으로 리셋된 뒤라 다음 시도도
  항상 18px부터 다시 시작해 72px까지 못 큰다.
  **고침 시도(1회, 되돌림):** 옆걸음 "성공" 시점의 즉시 리셋을 없애고,
  목표 방향 복귀가 `_auto_track_stuck()`에서 실제 진행으로 확인될
  때까지 escalation을 유지 → 복귀 직후 다시 막히면 그때 한 단계 더
  키우도록 고쳤다. `check_autohunt_obstacle_stall.tscn`으로 재검증한
  결과 **이미 풀려 있던 `REPRO_POSITIONS[0]`(rock_s, 시드
  20260907/908)가 오히려 worst_streak 1123/878로 악화**(고치기 전
  <600)돼 되돌렸다(`git checkout -- scripts/player.gd`) — "옆걸음
  성공 = 진행"으로 보던 기존 가정이 이 좌표의 다른 장애물 배치에서는
  실제로 필요한 조기 리셋이었던 것으로 보인다. 즉 **하나의 리셋
  조건으로 두 좌표를 동시에 만족시킬 수 없다** — SEEDS_HARD를 풀려면
  "이 담은 계단형이니 옆걸음 실패를 다르게 판정" 같은 이 담 전용 예외가
  필요해 보이는데, 특정 장애물 모양에 맞춘 예외는 새 장애물마다
  또 예외를 추가해야 하는 구조라 이번 바퀴에서는 손대지 않았다.
  **결론: 계단형 담 자체보다 회피 알고리즘의 "성공 판정" 설계 한계가
  근본 원인이며, 기존 옆걸음 방식 안에서는 한쪽 좌표를 안 건드리고
  다른 쪽만 고치는 게 안 됨을 확인했다.** SEEDS_HARD는 그대로 두고
  "사냥은 진행됨"만 계속 확인한다. **질문(감독에게): 이 담은 회피
  로직을 더 손대기보다 "포기 규칙 확장"(예: 옆걸음 escalation이 최대치에
  두 번 연속 도달하면 이 장애물 자체를 잠깐 우회 대상에서 제외하고 다른
  목표를 고르게) 쪽으로 접근하는 게 나아 보이는데, 이 방향으로 진행해도
  되는지 — 아니면 이 담은 지형(소품 배치) 쪽을 고쳐 애초에 계단형으로
  안 뭉치게 하는 게 나은지.**
  `bash tests/run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
- [x] **INBOX 06:03 결함 처리(2026-09-07) — #131이 이 5시드 표를 백그라운드로
  띄워 유실한 것을 동기로 다시 실행.** `perl -e 'alarm 300; exec @ARGV' godot
  --headless --path . --fixed-fps 60 res://tests/auto_quest_probe.tscn --
  --seed=N`(로그 `/tmp/auto_quest_probe_seed_N.log`, 저장소 밖)을 시드
  20260907~911 순서대로 포그라운드로 끝까지 돌려 기다렸다. **부수 발견:
  `--` 구분자 없이 `--seed=N`만 주면 `OS.get_cmdline_user_args()`가 못 읽어
  5회 전부 기본 시드(20260907)로 돈다** — 첫 시도가 이걸 놓쳐 5개 로그가
  전부 PROBE_SEED=20260907로 찍혀 있었고, `-- --seed=N`으로 다시 돌려
  바로잡았다. 이후 이 프로브를 부르는 모든 곳(이 문서·INBOX·다음 바퀴)은
  `--` 구분자를 반드시 넣을 것.

  | seed | STALL 지점 | chapter 도달 | game_min | deaths |
  |---|---|---|---|---|
  | 20260907 | `hill_ridge pos=(70.54, 124.93) cell=(4,7)` | 1 | 14.35 | 0 |
  | 20260908 | `hill_ridge pos=(51.34, 124.93) cell=(3,7)` | 1 | 17.04 | 1 |
  | 20260909 | `hill_ridge pos=(55.13, 124.93) cell=(3,7)` | 1 | 21.95 | 0 |
  | 20260910 | `hill_ridge pos=(51.58, 124.93) cell=(3,7)` | 1 | 15.86 | 0 |
  | 20260911 | `hill_ridge pos=(48.97, 124.93) cell=(3,7)` | 1 | 19.37 | 0 |

  5개 전부 `hill_ridge`의 같은 y선(124.9252, 위 §10.7 "y=308.9 긴 담"과
  같은 부류로 추정되는 x=48~70 사이 cell (3,7)/(4,7) 좁은 구간)에서
  멈췄다 — 회피 방향 RNG를 시드로 바꿔도 같은 곳에서 멈추므로 이번엔
  "비결정적 STALL"이 아니라 **hill_ridge cell(3~4,7) 자체가 결정적으로
  못 뚫는 지형**이라는 확증이다. 전부 stage=1, chapter=2 진입 0개 —
  10:05(a)의 "1~10장 연속 시뮬레이션" 검증은 이 지형을 고치기 전까지
  1장을 못 넘는다. **다음 우선순위: hill_ridge cell(3,7)/(4,7) 부근
  소품 배치를 `check_autohunt_obstacle_stall.gd` 패턴(재현 좌표 고정)으로
  좁혀 회피 폭 대 장애물 폭을 실측하고, 위 y=308.9 담과 같은 해법(더 넓은
  물러나기 등)으로 풀리는지부터 확인한다.**
  `bash tests/run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.
- [x] **#133 워치독 인수 — 중간보스 재입장 리스폰 결함 고침(2026-09-07)** —
  `_spawn_area_enemies()`가 `is_boss`만 재입장 보존하고 `is_midboss`는
  살아있어도 매번 치우고 풀피로 새로 깠다(후퇴 후 복귀하면 중간보스
  체력이 매번 리셋). `scripts/main.gd`에 `_preserved_midbosses`
  딕셔너리(area_id → Array)를 추가해, 자기 지역을 벗어난 중간보스는
  `queue_free()` 대신 "enemies" 그룹에서만 빼고 숨겨서(visible/
  process_mode/CollisionShape2D.disabled) 보관했다가 그 지역 재입장 시
  되돌린다 — "enemies" 그룹은 항상 지금 지역 몹만 있어야 한다는 기존
  불변식(`spawned_kinds()`/`has_midboss()` 등 그룹 전체를 세는 코드가
  여럿)을 지키기 위해 그룹에서는 완전히 뺐다가 되돌리는 방식을 씀(중간에
  "그냥 숨기고 그룹엔 남겨두는" 1차 시도는 마을 등 몹 없어야 할 지역에
  다른 지역 중간보스가 섞여 세어지는 회귀를 내서 되돌림). 새 회귀 검사
  `tests/check_midboss_persist_on_reentry.gd/.tscn`(①~⑥, `run_validation.sh`
  등록) 전부 PASS: 살아있는 중간보스는 인스턴스·체력 그대로 보존, 죽은
  자리는 재입장 시 새로 채워짐. `bash tests/run_validation.sh` 전체
  `PROJECT_VALIDATION_OK`.
  **5시드 재확인(중간보스 고침 반영 후, `-- --seed=N`, `perl alarm 300`
  순차 실행, 로그 `/tmp/auto_quest_probe_midboss_N.log` 저장소 밖):**

  | seed | STALL 지점 | chapter 도달 | game_min | deaths |
  |---|---|---|---|---|
  | 20260907 | `hill_ridge pos=(71.26, 124.93) cell=(4,7)` | 1 | 12.36 | 1 |
  | 20260908 | `hill_ridge pos=(51.16, 124.93) cell=(3,7)` | 1 | 12.05 | 2 |
  | 20260909 | `hill_ridge pos=(51.22, 124.93) cell=(3,7)` | 1 | 14.38 | 2 |
  | 20260910 | `glade pos=(522.9, 323.0) cell=(32,20)` | 1 | 21.37 | 1 |
  | 20260911 | `hill_ridge pos=(72.96, 124.93) cell=(4,7)` | 1 | 12.11 | 0 |

  중간보스 고침 자체는 확인됨 — 이전(고침 전) 5시드는 game_min 14~22에
  걸쳐 대부분 사망 0~1회로 정체됐던 것과 달리, 이번엔 레벨이 5~9까지
  오르고(경험치/골드 계속 증가) 훨씬 오래 진행되다가 멈춘다. **그러나
  hill_ridge cell(3,7)/(4,7) 담(위 §10.7 계단형 담 항목의 그 지형)은
  여전히 4/5시드를 그 자리에서 막는다** — 중간보스 문제와 담 STALL은
  서로 다른 결함이었고 담 쪽은 아직 안 풀렸다는 뜻. 지시대로 회피
  로직은 이번 바퀴에 손대지 않았다(계단형 담 "포기 규칙 확장 vs 지형
  재배치" 질문은 여전히 감독 답변 대기). stage=1, chapter=2 진입 0개는
  그대로.
  `bash tests/run_validation.sh` 전체 `PROJECT_VALIDATION_OK`.

  **AStarGrid2D 전환 후 5시드 재확인(INBOX 08:10 답 구현, `-- --seed=N`,
  `perl alarm 300` 순차, 로그 `/tmp/auto_quest_probe_astar_N.log`
  저장소 밖):** 위 계단형 담(hill_ridge cell 3,7/4,7)과 glade STALL을
  막던 5시드 전부 **300초 안에 STALL 없이 통과** — 이전엔 그 담·지형에서
  game_min 12~22 사이에 멈췄던 자리를 그냥 지나쳐 forest_w까지 진행됐다
  (300초 알람이 먼저 끊겨 FINAL은 못 봄, 즉 "그 담에서 막힌다"는
  현상 자체가 재현되지 않음).

  | seed | 300초 알람 시점 도달 상태 | 이전 STALL 지점 통과 여부 |
  |---|---|---|
  | 20260907 | map=hill_ridge kills=39 lv4 game_min=4.67 | 통과(이전 hill_ridge cell 4,7) |
  | 20260908 | map=forest_w kills=41 lv4 game_min=4.33 | 통과(이전 hill_ridge cell 3,7) |
  | 20260909 | map=hill_ridge kills=49 lv5 game_min=4.93 | 통과(이전 hill_ridge cell 3,7) |
  | 20260910 | map=forest_w kills=36 lv5 game_min=4.78 | 통과(이전 glade cell 32,20) |
  | 20260911 | map=forest_w kills=31 lv4 game_min=4.64 | 통과(이전 hill_ridge cell 4,7) |

  계단형 담 STALL은 이걸로 해소로 본다 — §10.7 "포기 규칙 확장 vs 지형
  재배치" 질문(07:14/07:47)은 AStarGrid2D 전환으로 우회됐으므로 더 이상
  유효하지 않다. 300초는 1장 완주에도 못 미치므로(게임 내 4~5분 진행에
  실측 300초 소모) 10장 전체 진행 여부는 이 프로브로는 아직 확인 못함 —
  `check_autohunt_obstacle_stall.tscn`(별도 결정적 재현 검사, 10분 소요
  예정)로 넘어간다.

- **INBOX 11:20 처리 — hunt-transit A* 전환(커밋 1a88299) 후 5시드
  재확인(2026-09-07, `--fixed-fps 60 auto_quest_probe.tscn -- --seed=N`,
  `perl alarm 60` 순차, 로그 `/tmp/aqp2_N.log` 저장소 밖):**

  | seed | chapter=2 진입 | tick | game_min | hill_ridge/dungeon 담 정지 |
  |---|---|---|---|---|
  | 20260907 | O | 88956 | 24.71 | 없음(60초 알람까지 통과, marsh/harbor/ruins_w 순환) |
  | 1 | O | 104328 | 28.98 | 없음 — 단, tick=218688(game_min=60.75) **marsh** cell(34,22)에서 새 STALL(auto_walk=true, velocity=(0.0002,72.0) 그대로) — hill_ridge/dungeon과 무관한 새 지형 |
  | 2 | O | 160488 | 44.58 | 없음(60초 알람까지 통과) |
  | 3 | O | 188604 | 52.39 | 없음(60초 알람까지 통과) |
  | 4 | O | 108108 | 30.03 | 없음(60초 알람까지 통과) |

  **hill_ridge cell(3,7)/(4,7), dungeon cell(42,10) 정지는 5/5 해소로
  확인됐다** — 이전(10:16 보정 처리 표)에는 seed=1/3/4가 hill_ridge에서,
  seed=2가 dungeon에서 막혔으나 이번엔 5개 전부 그 지형을 그냥 통과해
  chapter=2까지 진입했다. hunt-transit 분기의 A* 전환(1a88299)이 원인
  수정이었음이 이 넓은 시드 공간에서도 재확인됨.
  **새로 발견**: seed=1이 marsh cell(34,22)에서 STALL — hill_ridge/dungeon과
  다른 지형이라 이번 조각(11:20 지시 범위)에서는 고치지 않는다. 다음
  우선순위로 STATUS "다음에 할 것"에 남긴다.

- **INBOX 10:16 보정 처리 — `auto_quest_probe` 5시드(20260907, 1~4)
  60초 벽시계(`perl -e 'alarm 60'`) CHAPTER_ENTER chapter=2 표
  (2026-09-07)** — `--fixed-fps 60 res://tests/auto_quest_probe.tscn --
  --seed=N`을 시드별로 순차 실행(로그 `/tmp/aqp_N.log`, 저장소 밖).

  | seed | chapter=2 도달 | tick | game_min | level | weapon | armor | stats |
  |---|---|---|---|---|---|---|---|
  | 20260907 | O | 98604 | 27.39 | 11 | 낡은 검 | 여행자 옷 | {str:0,agi:0,vit:0,will:0} |
  | 1 | X | - | - | - | - | - | - |
  | 2 | X | - | - | - | - | - | - |
  | 3 | X | - | - | - | - | - | - |
  | 4 | X | - | - | - | - | - | - |

  **5/5가 아니다(1/5).** seed=20260907만 chapter=2 진입(이후 60초 알람
  만료 시점 game_min=61.94, stage=4, map=ruins_w, level=15, deaths=1까지
  계속 진행 중이었다 — STALL 없이 알람에 끊긴 것). 나머지 4개는 전부
  1장에서 STALL(600퀘스트틱=게임6분 무변화):
  - seed=1: `hill_ridge pos=(71.55,124.93) cell=(4,7)` tick=44319
    game_min=12.31 deaths=1 — 위 "계단형 담 STALL 5/5 해소" 표와 **같은
    지형**(hill_ridge cell 3~4,7)에서 다시 멈췄다.
  - seed=3: `hill_ridge pos=(51.02,124.93) cell=(3,7)` tick=43350
    game_min=12.04 deaths=1 — 역시 같은 지형.
  - seed=4: `hill_ridge pos=(50.78,124.93) cell=(3,7)` tick=44705
    game_min=12.42 deaths=2 — 역시 같은 지형.
  - seed=2: `dungeon pos=(677.00,163.08) cell=(42,10)` tick=157562
    game_min=43.77 deaths=3 — 다른 지형(hill_ridge 통과는 성공, dungeon
    진입 후 정체).

  **판단(기록만, 이번 조각은 고치지 않음 — 규칙: 한 바퀴 한 조각):**
  seed=1/3/4가 다시 걸린 hill_ridge cell(3,7)/(4,7)은 앞선 "계단형 담
  STALL 5/5 해소" 검증(bcbd10c, `check_autohunt_obstacle_stall.tscn`)이
  쓴 재현 좌표·회피 RNG 시드와 이 프로브의 `--seed=N`(플레이어 행동
  전반을 흔드는 전역 RNG)가 서로 다른 매개변수라, 그 검사가 잡는
  접근각·타이밍 밖에서는 AStarGrid2D 전환 후에도 여전히 못 뚫는 경우가
  남아 있다는 뜻으로 읽힌다 — "5/5 해소"가 이 넓은 시드 공간까지
  일반화된 것은 아니다. dungeon(seed=2) 정체는 새로운 지점이라 별도
  조사가 필요하다. 다음 바퀴 우선순위로 STATUS "다음에 할 것"에 남긴다.
