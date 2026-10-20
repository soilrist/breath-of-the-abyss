# 맵 구조 개편 · 몬스터 분화 · 이펙트 · 중간보스 설계안 (검토용이었으나
2·3·5절은 이미 구현됨, 남은 것은 4절 1차 전직 스킬 이펙트뿐 — 2026-09-05
대조로 발견, `docs/STATUS.md` 참고)

## 1. 현재 문제 (사용자 지적)

- 맵이 그리드(x,y) 좌표로 흩어져 있어 "중구난방" — 어디로 가야 다음
  스토리인지 헷갈림
- 동서남북 4분할 특수 던전(황혼의 폐사원/가라앉은 유적/빙하 균열/
  심연 너머)이 각 장마다 하나씩 떨어져 있어 몹만 분산되고 맵만 커짐
- 몬스터가 근접/원거리 구분은 있지만(`chase`/`charge`/`ranged`)
  "마법 쓰는 애들"이 시각적으로 구분되지 않음
- 스킬 이펙트가 4종(`burst`/`flame`/`heal`/`slash`) 텍스처를 색조(tint)만
  바꿔 8개 스킬이 재사용 — 실제로는 "같은 이펙트"로 보임 (겹침)
- 중간보스 개념 자체가 없음(장마다 최종보스 1마리뿐)

## 2. 맵 구조 개편안 — "외길 챕터" 구조 (구현 완료, `world.gd`의
`exits`가 이미 `e`/`w`만 쓰는 선형 그래프다 — `grep -n "exits" scripts/world.gd`로
2026-09-05 확인)

### 방향
- 모든 장(chapter)은 **좌우 1방향으로만 이동 가능한 외길**로 재구성
- 마을(시작) → 사냥터 1 → 사냥터 2 → … → 사냥터 6 → 중간보스 or
  최종보스 던전 → (클리어) → 다음 장 마을로 자동 연결
- 왔던 길로 되돌아가는 것(좌측 이동)은 허용(파밍/회귀용), 다만 "다음
  구간 잠금 해제"는 순서대로만 진행

### 장(chapter)당 표준 구성 — 6 사냥터 + 중간보스 2 + 최종보스 1
```
[마을] → 사냥터1 → 사냥터2 → 사냥터3(★중간보스A) → 사냥터4
       → 사냥터5 → 사냥터6(★중간보스B) → 보스던전(최종보스) → 다음 장
```
- 요청하신 그대로 "6개 중 3번째, 6번째에 중간보스"를 배치
- 기존 동서남북 특수 던전 4곳은 이 표준 흐름에 흡수 통합:
  - 황혼의 폐사원(1장), 가라앉은 유적(2장), 빙하 균열(3장),
    심연 너머(4장) → 각 장의 "사냥터6" 자리에 재배치(중간보스B 위치와
    합쳐 하나의 던전으로 만들거나, 사냥터6 바로 앞 별도 스테이지로 유지)
  - **효과**: 흩어졌던 몬스터 풀이 외길 동선 안으로 들어와 파밍 동선이
    단순해짐. 새 맵을 만들지 않고 기존 지역을 순서만 재배열하는 것이라
    최소 변경 원칙에도 맞음

### 장별 재배치 예시 (1장 기준, 기존 지역명 재사용)
| 순서 | 지역 | 비고 |
|---|---|---|
| 마을 | 바람골 마을 | |
| 사냥터1 | 바람 언덕 | |
| 사냥터2 | 바람 능선 | |
| 사냥터3 | 안개숲 서편 | ★중간보스A 등장 |
| 사냥터4 | 안개숲 깊은 곳 | |
| 사냥터5 | 안개숲 동편 | |
| 사냥터6 | 이끼 빈터 + 황혼의 폐사원 통합 | ★중간보스B 등장 |
| 보스던전 | 수호자의 동굴 → 수호자의 제단 | 최종보스: 숲의 수호자 |

2·3·4장도 동일 패턴으로 기존 지역을 순서 재배열 + 특수던전 흡수.
(2장: 가라앉은 유적 흡수, 3장: 빙하 균열 흡수, 4장: 심연 너머 흡수.
3·4장은 현재 사냥터가 3개/2개뿐이라 6개 채우려면 신규 사냥터 이름을
몇 개 추가로 지어야 함 — 아래 5절에서 이름 제안)

### 구현 방식(기술)
- `world.gd`의 `exits` 딕셔너리를 "동서남북 자유이동"에서 "e(다음)/
  w(이전)"만 남기는 선형 그래프로 재구성
- 그리드(`Vector2i`) 좌표는 유지하되 y값을 챕터 내내 고정(가로 일직선),
  x값만 증가시켜 "옆으로 나란히" 배치 → 지도 UI에서 자연히 가로 일렬로
  그려짐
- 챕터 경계에서만 `pending_map` 전환 로직(기존 코드 재사용)

## 3. 몬스터 타입 3분화 — 근접 / 원거리 / 마법 (구현 완료, `enemy.gd`
KINDS에 `"behavior": "magic"` 종류가 이미 다수 있다: flam/mage/corruptor/
shard_watcher/tidecaster/choir_caster/warden_scribe/paradox_caster 등 —
2026-09-05 확인)

현재 `behavior`는 `chase`(근접) / `charge`(돌진형 근접) / `ranged`
(원거리 투사체) 3종. "마법 쓰는 애들"을 명확히 구분하려면:

- **근접형**(`chase`, `charge`): 기존 그대로. 접근해서 직접 타격
- **원거리형**(`ranged`): 투사체(화살/구슬)를 던짐. 기존 그대로
- **마법형**(신규 `behavior: "magic"`): 원거리처럼 거리를 두지만,
  ① 시전 전 예고 이펙트(장판/글로우)가 뜨고 텀을 두고 발동 ②
  일반 투사체와 다른 전용 이펙트(주문진, 색 다른 구체) ③ 상태이상
  부여 가능(슬로우/기절 등, `player.gd`에 이미 slow_time 있음 — 재사용)
- 지역별 몬스터 풀에 마법형 최소 1종씩 배치되도록 `KINDS` 표 보강
  (현재 `spirit`(망령), `flam`(화염정령), `owl`(설원올빼미), `eye`
  (감시의 눈)이 `ranged`로 되어 있는데, 이 중 절반 정도를 `magic`으로
  전환하고 전용 이펙트를 입히는 안을 제안)

## 4. 스킬/몹 이펙트 비중복 설계

### 문제의 근본 원인
`_spawn_skill_fx()`가 텍스처 경로 4개(`burst/flame/heal/slash`)만 받고
색조(tint)로 "다른 척"하고 있음. 실제 모양이 같아서 "겹친다"는 지적이
정확함.

### 해결 방향
- **직업 스킬 8개(1차: 전사4+마법사4+도적4, 실제로는 공용4+직업별4=
  세는 방식에 따라 다름) + 2차 전직 추가 스킬(직업당 2개×6클래스=12개)
  = 최종 20개 안팎 스킬 전부 서로 다른 이펙트 스프라이트 필요**
- 몬스터 마법형 공격 이펙트도 플레이어 스킬과 겹치면 안 됨(별도 팔레트)
- **제작 방법**: 기존 4개 텍스처처럼 ComfyUI로 프레임 스프라이트시트
  신규 생성(가로 나열, `_spawn_skill_fx(path, frames, frame_time, tint,
  size_up)` 시그니처 그대로 재사용 가능 — 함수 변경 없이 텍스처 경로만
  스킬마다 고유하게 지정하면 됨)
- **분류 기준(모양으로 구분)**:
  - 참격류(베기): 직선/호 형태 슬래시
  - 충격파/폭발류: 원형 확산
  - 화염류: 불꽃 파티클
  - 냉기류: 얼음 결정/서리
  - 신성/회복류: 빛 파티클
  - 암흑/저주류: 보라/검은 안개
  - 번개류: 지그재그 스파크
  - 바람/베기(도적): 잔상 슬래시(색 다르게)
  각 계열 안에서도 색상·크기·프레임수를 달리해 스킬마다 고유하게

### 작업량 참고
- 신규 이펙트 스프라이트가 최소 15~20종 필요 → ComfyUI 생성 작업량이
  꽤 큼. **1차 전직 스킬(현재 8개)부터 우선 교체하고, 2차 전직 스킬은
  2차 전직 시스템 구현과 함께 순차 추가**하는 단계적 진행을 제안
- **진행 상황(2026-09-05 확인)**: 순서가 제안과 반대로 됐다 — 2차 전직
  스킬 12종은 `assets/fx/skill2/`에 ComfyUI로 생성된 전용 스프라이트가
  이미 있고 `player.gd:613`에서 사용 중(커밋 c263e14). ~~1차 전직 스킬
  8개는 아직 `burst/flame/heal/slash` 4종 재사용 + tint 구분 그대로~~
  **(2026-09-05 밤, INBOX 지시 ② 완료) 아래 8개도 `assets/fx/skill1/`에
  전용 스프라이트를 만들어 배선했다.** `slash`/`strike`/`double_strike`
  (참격 변형)과 `burst`/`flame`/`heal`(공용 스킬 자체) 3개는 원래도
  전용 자산이라 대상이 아니었다 — 대상은 JOB_DESIGN.md 5절이 "실질
  신규"로 꼽은 8개(강타/화염구/치유는 제외)였다.

| 스킬 id | 이름 | 계열 | 프롬프트(z-image-turbo, `tools/comfy_gen.py --postprocess`) |
|---|---|---|---|
| `shield_charge` | 방패 돌진 | 충격파(방패) | (2026-09-06 흰 원판 잔존으로 재교체, seed 302) `single 2D game skill effect icon, a blue shield silhouette rushing forward with horizontal speed lines trailing behind it, motion effect, no circle, no badge, no emblem, no disc, nothing behind the shield, on a plain flat magenta background that fills the entire canvas edge to edge, no border, no frame, no panel, no ellipse, no drop shadow, no character, no person, no silhouette, no shadow, flat icon design, pixel-art style, 64x64 look` |
| `warcry` | 전투 함성 | 신성/버프(주황) | `single 2D game skill effect icon, radiating orange battle aura burst with concentric sound wave rings and small flame flecks, centered on flat magenta background, no character, no person, no silhouette, no shadow, flat icon design, pixel-art style, 64x64 look` |
| `undying` | 불굴 | 신성/회복(금) | (2026-09-06 드롭섀도 타원 잔존으로 재교체, seed 502, `comfy_gen.py`에 색상각 기반 배경 제거 추가 후 생성) `single 2D game skill effect icon, golden radiant shield emblem wrapped in soft phoenix-like flames and healing sparkles, floating weightless in empty air, nothing beneath it, no ground, no floor, no cast shadow, no drop shadow, no ellipse, no oval shape, centered on flat solid magenta background, no character, no person, no silhouette, flat icon design, pixel-art style, 64x64 look` |
| `ice_spear` | 얼음창 | 냉기 | (2026-09-06 자홍색 배경 판 잔존으로 재교체) `single 2D game skill effect icon, large sharp pale blue ice crystal spear filling the frame, surrounded by frost shards and small snowflakes, on a plain flat magenta background that fills the entire canvas edge to edge, no border, no frame, no panel, no circle behind the object, no white halo, no character, no person, no silhouette, no shadow, flat icon design, pixel-art style, 64x64 look` |
| `mana_burst` | 마나 폭발 | 충격파/폭발(보라) | (2026-09-06 자홍색 배경 판 잔존으로 재교체) `single 2D game skill effect icon, violet arcane magic explosion burst with swirling energy rings and sparkles, on a plain flat magenta background that fills the entire canvas edge to edge, no border, no frame, no panel, no circle behind the object, no ellipse, no drop shadow, no character, no person, no silhouette, no shadow, flat icon design, pixel-art style, 64x64 look` |
| `shuriken` | 표창 던지기 | 참격(은) | `single 2D game skill effect icon, spinning silver ninja shuriken star with sharp motion blur streaks, floating in empty space, centered on flat magenta background, no character, no person, no silhouette, no ground, no drop shadow, no ellipse, flat icon design, pixel-art style, 64x64 look` |
| `stealth` | 은신 | 암흑(보라 연기) | `single 2D game skill effect icon, round smoke bomb burst with swirling dark purple wispy tendrils curling outward, abstract cloud shape, no figure, no person, no hood, no silhouette of a body, no drop shadow, floating in empty space, flat icon design, pixel-art style, 64x64 look` |
| `swift_step` | 회피 강화 | 바람(청록) | `single 2D game skill effect icon, teal green wind gust swirl with sharp motion speed lines, centered on flat magenta background, no character, no person, no silhouette, no shadow, flat icon design, pixel-art style, 64x64 look` |

  **시행착오(다음에 비슷한 걸 만들 바퀴가 참고)**: "no character"만
  넣으면 모델이 그래도 인물 실루엣을 그린다(`shield_charge` 1차 시도가
  방패 든 전사 전신이 나왔고, `stealth` 1차 시도가 후드 쓴 인물
  실루엣이 나왔다) — "no person, no silhouette (of a body/hood)"까지
  명시해야 순수 이펙트 아이콘이 나왔다. 또한 아이콘 스타일 특성상
  하단에 반투명 타원 그림자가 자동으로 붙는 경우가 있는데, 그 그림자
  색이 배경 마젠타와 톤차이가 나면(`shuriken` 1차 시도, RGB 채널差
  최대 32 > 기본 tolerance 24) `remove_corner_background` 코너 감지가
  못 지우고 반투명 타원으로 남는다 — "no drop shadow, no ellipse"를
  프롬프트에 넣거나, 후처리 tolerance를 픽셀 단위로 높여(예 40)
  재실행해서 해결했다. `shield_charge`는 별표 뾰족한 끝이 크롭 경계에
  거의 닿아 `box_down` 축소 후 코너 알파가 완전한 0이 아니라 10 안팎으로
  남는 경우가 있었다 — 알파 16 미만을 강제로 0으로 접는 후처리 한 번
  더 돌려 해결.
  **결함 수정(2026-09-05 밤, INBOX 결함 — 감독이 캡처로 직접 확인) —
  가배치, 근거**: `player.gd:613/616`이 64px 스킬1·2 스프라이트를
  `size_up 2.0`으로 띄워 128 게임픽셀(320×240 화면의 절반 높이, 16px
  캐릭터의 8배)로 나가 캐릭터가 이펙트에 가려지고 화면 밖으로 잘렸다.
  연출 관례(이펙트는 캐릭터의 2~3배, 32~48px)를 따라 `size_up`을
  **0.7**(64px×0.7≈45px)로 낮췄다. 같은 기준으로 기존 `burst`(32px
  프레임×3.0≈96px)/`flame`(40px×2.2≈88px)/`heal`(32px×2.5≈80px) 공용
  이펙트도 **1.4**(≈45~56px)로 재조정했다. 채움 미달 스프라이트
  재생성(`shield_charge` 0.31, `ice_spear` 0.449)과 `check_skill1_fx_
  assets.gd`의 채움 비율 단언 추가, `SkillFx` 위치/스케일 단언 보강,
  잡무(미커밋 `.uid` 커밋·ComfyUI 원본 `.gitignore`)는 이번 조각
  범위 밖 — INBOX 결함 항목에 그대로 남겨 다음 바퀴가 이어받는다.
  **채움 미달 해결(2026-09-06, INBOX 결함 (2))**: 위 표의 두 프롬프트에
  "large ... filling the frame"과 "no white halo"를 추가해 재생성(시드
  1~3 순서로 시도, `tools/comfy_gen.py --postprocess`의 `min_fill 0.45`
  단언을 그대로 통과 관문으로 씀 — 미달이면 `SystemExit`으로 파일 자체가
  안 만들어지므로 다음 시드로 넘어감). `shield_charge`는 시드 3에서 채움
  0.70, `ice_spear`도 시드 3에서 0.85로 통과. `shot_skill1_fx.tscn`
  재실행 후 두 PNG를 육안 확인 — 화면 채움 적절, 흰 후광 과다 없음.
  같은 조각에서 `check_skill1_fx_assets.gd`에 `Image.get_used_rect()`
  기반 채움 비율(>= 0.45) 단언도 추가(1차 8개 전부 실측 1.00 — bbox
  기준이라 파이썬 쪽 픽셀-카운트 기준(`comfy_gen.py fill_ratio`)보다
  후하다, 원래 INBOX 제안대로 bbox 방식 채택). `run_validation.sh`
  전체 재검증 통과.
  **흰 원판 잔존 해결(2026-09-06, INBOX 결함 완료)**: `shield_charge`가
  "shield"를 방패 문양(엠블럼/배지)으로 해석해 그 뒤에 흰 원판을 깔았다
  (지배색 비율 실측 0.65). 프롬프트를 위 표처럼 "a blue shield
  silhouette rushing forward with horizontal speed lines... no circle,
  no badge, no emblem, no disc, nothing behind the shield"로 바꿔
  seed 302로 재생성 → 지배색 비율 0.33으로 통과. 색과 무관하게 판
  잔존을 잡는 단언을 `tools/comfy_gen.py`(`dominant_color_ratio`,
  후처리 중 0.62 초과 시 `SystemExit`)와 `check_skill1_fx_assets.gd`
  (같은 계산, `<= 0.62` 단언)에 추가 — 임계값은 현재 8장 실측(정상 중
  최고 `swift_step` 0.59, 결함 `shield_charge` 구버전 0.65)의 중간값.
  `tests/shot_skill1_sheet.gd`(4배 확대, 4×2 시트를 `user://
  skill1_sheet.png`로 저장)를 새로 만들어 8장을 한 이미지로 띄워
  직접 육안 확인 — `shield_charge`는 파란 방패+속도선만 있고 판 없음.
  **`undying` 드롭섀도 타원 결함 해결(2026-09-06)**: 타원 색이 순수
  자홍(201,53,127)이 아니라 어두운 마룬 계열이라 RGB 거리 기준 검사
  (자홍 픽셀 비율·지배색 비율)를 둘 다 피해갔다 — 색상각(Hue)은
  밝기가 달라도 거의 안 변한다는 점에 착안해 `tools/comfy_gen.py`에
  `remove_background_hue`/`hue_ratio`를 추가, 후처리 중 배경(코너 색)과
  색상각이 25° 이내인 픽셀을 크롭 **전에** 지우도록 `postprocess()`를
  바꿨다(`content_box`를 이 정리 후 이미지로 다시 계산 — 그림자가
  애초에 내용 범위에 안 들어옴). "no ellipse, no drop shadow" 프롬프트
  강화만으로는(seed 401, 501~503 네 차례 시도) 모델이 계속 타원을
  그려 텍스트 negation은 포기하고 이 구조적 후처리로 해결했다. seed
  502로 재생성 후 색상각 잔존 0.12%(신규 검사 기준 6% 이내) 확인,
  `/tmp`에서 8배 확대 육안 확인(그림자 없음, 금빛 방패+불꽃+반짝임
  정상). `check_skill1_fx_assets.gd`에 같은 색상각 검사를 추가했다.
  **같은 색상각 검사로 별개의 기존 결함 발견 → 감독 승인으로 종결
  (2026-09-06)**: `shuriken`(표창)의 모션 블러 줄기가 은색이 아니라
  핑크빛이고 하단에 옅은 드롭섀도도 있다(색상각 잔존 15.8% — 다른
  7장은 전부 3.1% 이하). 강화 프롬프트("no pink haze, no magenta tint
  on the streaks" 추가)로 seed 601~603 세 차례 재생성을 시도했으나
  모델이 매번 같은 핑크 줄기+그림자를 그렸고(텍스트 negation 무력),
  새 색상각 제거 후처리를 적용하면 줄기 자체가 지워져 채움 비율
  0.28~0.33 < 0.45 로 실패했다(모션 블러 줄기 자체가 배경과 같은
  색상각으로 그려지는 모델 특성 — undying 그림자와 달리 이 프롬프트는
  구조적 후처리로도 못 고친다).
  **4번째 시도(감독 답, 2026-09-06 03:05)**: 배경색 자체를 자홍
  대신 초록(`#00FF00`, "plain flat bright green background filling
  the entire canvas", `--key-color 0,255,0`)으로 바꿔 seed 701·702
  재생성. 육안 확인 결과 줄기 색은 은/회색으로 정상화됐다(자홍
  배경에 번지던 핑크빛이 사라짐 — 원인이 배경-줄기 간 색 번짐이었음을
  확인). 그러나 채움 비율이 0.34/0.44로 기준 0.45에 미달(별 아이콘이
  캔버스 대비 작고 줄기가 가늘어서, 배경색과 무관한 구도 문제).
  두 시드 모두 실패해 감독 승인("핑크 궤적은 게임 안에서 참격
  잔상으로 읽히고 배경 판도 없어 연출상 문제 없음")으로 현재
  `shuriken.png`를 그대로 채택하고 종결한다. `check_
  skill1_fx_assets.gd`의 색상각 검사에서 `shuriken`은 영구 제외
  (허용 목록, 사유: 위 감독 승인). 다시 시도할 바퀴를 만들지 말 것 —
  이미 두 가지 접근(배경 negation, 배경색 교체)이 실패했고 사람이
  현재 그림을 승인했다.

## 5. 중간보스 시스템 (구현 완료 — 커밋 3a9affc, 2026-09-02. **가배치,
근거**: 아래 제안과 실제 구현이 다르다 — "최종보스의 40~50%" 대신 "같은
지역 일반 몹 등급(TIERS) 대비 배율"로 대체 구현됐다. 이미 여러 장에서
쓰이고 있어 이 문서 작성 시점에 값을 바꾸지 않고 실측값만 기록한다.
2026-09-05 `tests/check_midboss_design_values.gd` 대조 검사 추가)

- 장(chapter)당 사냥터 6개 중 **3번째·6번째** 스폰 자리(0-index 2, 5 —
  `main.gd:MIDBOSS_SLOTS`)에 중간보스 1마리씩 배치. 대상 지역 목록은
  `main.gd:MIDBOSS_AREAS`(장당 대표 사냥터 1곳씩, 1~10장 계속 추가됨).
- 배율(`game_state.gd:MIDBOSS_HP_MULT/DAMAGE_MULT/REWARD_MULT`,
  `main.gd:_spawn_area_enemies()`가 사용): 체력 **4.0배**, 공격력
  **1.6배**, 경험치/골드 보상 **2.5배**(모두 같은 지역 TIERS 값 기준).
- **드랍**: 처치 시 전직의 돌 1개 확정 드랍(3타입 균등 랜덤 —
  `enemy.gd:574` 부근, SECOND_JOB_DESIGN.md 5절과 연동). 확률 드랍이
  아니라 확정으로 구현됨.
- 이름/외형: 신규 스프라이트 없이 기존 `KINDS` 몹 그래픽을 그대로
  1.6배 확대 + 이름에 "(중간보스)" 접미사(최소안 채택,
  `enemy.gd:_ready()` 부근).

### 1장 중간보스 제안 (예시, 다른 장도 동일 패턴)
| 위치 | 이름 | 베이스 |
|---|---|---|
| 사냥터3 | 늙은 숲뱀 우두머리 | `snake`(charge) 대형화 |
| 사냥터6 | 안개숲 파수꾼 | `owl`(magic 전환) 대형화 |

## 6. 확인 필요 사항 (2026-09-06 코드 대조로 전부 확인·종결 — 이 문서
작성 당시엔 구현 착수 전 질문이었으나, 2·3·4·5절이 이미 "구현 완료"로
바뀐 지금은 실제 코드가 어느 쪽으로 답했는지 사실만 확인한다. 새 질문이
아니라 지나간 질문의 사후 기록.)

1. 재배치 방향 — **"기존 지역 순서만 바꾸는" 쪽으로 확정**. 2절
   "구현 방식(기술)"이 그대로: `world.gd`의 `exits`를 e(다음)/w(이전)
   선형 그래프로 재구성했을 뿐 새 타일을 그리지 않았다.
2. 3·4장 사냥터 개수 — 이제 무의미한 우려다. `grep -n '"chapter": 3,'
   scripts/world.gd`로 세어 보면 3장은 8개 지역(얼어붙은 야영지·
   서리벌 설원·얼어붙은 능선·서리 협곡·얼어붙은 폭포·눈보라 평원·
   얼음 계곡·얼어붙은 신전), 4장은 7개 지역(잿불 황야·잿불 협곡·
   잿불 능선·잉걸불 골짜기·타버린 회랑·재의 늪·심연의 왕좌)이 이미
   있다 — 애초 우려했던 "6개를 못 채운다"는 상황 자체가 없다(이후
   세션에서 신규 이름을 지어 채운 것으로 보이나, 그 결정 자체는 이
   질문과 무관하게 이미 실행됨).
3. 마법형 예고 이펙트 — 제안한 "장판/주문진" 전용 그림 대신 **색조
   틴트로 단순화해서 구현됐다**. `enemy.gd:452~465` `_act_magic()`이
   `cast_time > 0.0`인 동안 `modulate = Color(1.0, 0.55, 0.35)`(주황
   틴트)로 예고하고, 시전 완료 시 `modulate = Color.WHITE`로 되돌린
   뒤 투사체를 쏜다 — 별도 장판/주문진 스프라이트 노드는 없다(최소
   구현 채택).
4. 중간보스 외형 — **"기존 몹 대형화" 채택**. 5절에 이미 명시(신규
   스프라이트 없이 `enemy.gd:291~297`에서 `$Sprite.scale = Vector2.ONE
   * 1.6` + 이름 접미사 "(중간보스)").
5. 단계적 제작 — 그렇게 진행됐다. `git log --oneline -- assets/fx/
   skill1/`로 확인 가능한 여러 세션에 걸쳐 스킬 이펙트(shield_charge/
   undying/shuriken 등)를 한 번에 다 만들지 않고 한 장씩 순차
   생성·검증·재시도했다.

코드 변경 없음(문서만 갱신). 검증: 이 절에 적은 grep 결과는 이 바퀴
안에서 직접 실행해 확인한 것이며, `run_validation.sh`는 코드를 바꾸지
않아 재실행 불필요.
