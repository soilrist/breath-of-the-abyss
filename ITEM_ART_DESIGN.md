# 아이템 아트 전면 교체 설계

## 배경

기존 장비 61종이 아이콘/손그림을 슬롯·부위별로 4~6장만 돌려썼다(예: 무기 6종
"hand" 그림에 실제 무기 17개가 몰림, 초월 등급 20종은 슬롯당 아이콘 1장씩만
5개 난이도가 공유). 이번 작업 목표는:

1. **아이템 61종이 전부 다른 모양**을 갖는다 (같은 그림 재사용 금지).
2. **세트 소속 아이템은 색상을 통일**해서 한눈에 "이 세트다"를 알아본다.
3. **천공(tower_abyss_set)은 무지개색**으로, 최상위 등급다운 존재감을 준다.

몬스터 쪽 중복(약 55종 중 32종 tint 재사용)은 이번 범위에서 **제외** —
아이템부터 먼저 끝낸다.

## 기술 메모 (왜 안전한가)

- `scripts/game_state.gd:weapon_hand()`(1053행)는 장비 딕셔너리의 `hand` 필드를
  그대로 문자열로 반환할 뿐이고, 이 값은 `res://assets/items/hand/<hand>.png`
  경로를 만드는 데만 쓰인다. 공격속도·사거리 등 스탯은 `atk/spd/hp` 등 별도
  필드로 이미 아이템마다 다르게 관리되므로 **`hand` 값을 바꿔도 게임 로직에는
  영향이 없다.**
- `scripts/main.gd:_item_icon()`(2874행)도 `ResourceLoader.exists()`로 파일이
  실제 있는지 확인 후 없으면 안전하게 대체 아이콘으로 떨어진다.
- 결론: **무기는 `hand` 값을 아이템마다 고유하게 바꾸고 그 이름의 그림 파일만
  새로 채우면 코드 수정이 사실상 필요 없다.** 방어구/투구/장신구/정령 인장은
  슬롯 공통 아이콘(`icon_<slot>.png`)만 있어서, 아이템별 전용 아이콘을 쓰려면
  `_item_icon()`에 "아이템별 지정 아이콘 우선 사용" 분기를 추가해야 한다 —
  이건 실제 그림이 도착하는 배치와 함께 진행한다(파일 없는 경로를 미리
  코드에 박아두지 않기 위함).
- `tests/check_item_icons.gd`는 특정 파일 경로(`icon_sword.png` 등)를 하드
  코딩해서 검사하므로, 이름을 바꾸는 만큼 테스트도 같이 갱신해야 한다.

## 진행 방식

1. 아래 표의 "신규 이름" 규격대로 ComfyUI에서 그림 생성 (16x16 Ninja
   Adventure 화풍 유지, 세트별 색상 지정, 천공은 무지개).
2. 생성물을 `assets/characters/source/`(원본 보관용, README에 이미 예약된
   경로)에 모은 뒤, 실제 사용 경로(`assets/items/...`)로 배치.
3. 배치가 도착하는 대로 해당 아이템들의 `hand`/아이콘 필드를 코드에서
   갱신 + `check_item_icons.gd` 테스트 갱신 + 회귀 테스트 재실행.
4. 세트 단위로 진행 권장(예: 천공 세트 4개 → 겁화 세트 4개 → ... → 비세트
   무기 8개 → 비세트 방어구/투구/장신구). 한 세트씩 끝나면 diff가 작아서
   검증하기 쉽다.

## 규격

| 종류 | 크기 | 비고 |
|---|---|---|
| 무기 손그림 (`items/hand/*.png`) | 6~16px (무기 실루엣 크기) | 인벤토리에 안 씀, 들고 있을 때만 |
| 무기 스윙 이펙트 (`items/hand_fx/*_swing.png`) | 120×192 | 공격 애니메이션 |
| 아이템 아이콘 (전부) | 24×24 | 인벤토리/장비창 표시용 |

---

## 세트 아이템 (색상 통일 대상)

### guardian_set — 초록 + 금장식 (숲의 수호자)
| 아이템 | 슬롯 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|---|
| 수호자의 검 | 무기(katana) | 에픽 | 심연의 파편과 공유 | `katana_guardian` | `icon_weapon_guardian` |
| 수호자의 투구 | 투구 | 에픽 | 일반 투구 아이콘 미사용(이미 전용) | - | `icon_helmet_guardian` |
| 숲의 심장 | 장신구 | 에픽 | 일반 장신구 아이콘과 공유 | - | `icon_trinket_guardian` |

### captain_set — 검정/오닉스 + 진홍 트림 (흑기사단장)
| 아이템 | 슬롯 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|---|
| 흑기사 갑주 | 방어구 | 에픽 | 일반 방어구 아이콘과 공유 | - | `icon_armor_captain` |
| 흑기사단장의 투구 | 투구 | 에픽 | 일반 투구 아이콘과 공유 | - | `icon_helmet_captain` |
| 단장의 견장 | 장신구 | 에픽 | 일반 장신구 아이콘과 공유 | - | `icon_trinket_captain` |

### frost_set — 하늘색/흰색 + 은장식 (얼음 군주)
| 아이템 | 슬롯 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|---|
| 서리왕관 | 투구 | 에픽 | 일반 투구 아이콘과 공유 | - | `icon_helmet_frost` |
| 빙결의 창 | 무기(lance) | 에픽 | lance 단독(문제 없음, 색상만 통일) | `lance_frost` | `icon_weapon_frost` |
| 서리군주의 갑주 | 방어구 | 에픽 | 일반 방어구 아이콘과 공유 | - | `icon_armor_frost` |

### abyss_set — 짙은 보라 + 검정 (심연의 군주)
| 아이템 | 슬롯 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|---|
| 정령의 부적 | 장신구 | 에픽 | 일반 장신구 아이콘과 공유 | - | `icon_trinket_abyss` |
| 심연의 파편 | 무기(katana) | 에픽 | 수호자의 검과 공유 | `katana_abyss` | `icon_weapon_abyss` |
| 심연의 갑주 | 방어구 | 에픽 | 일반 방어구 아이콘과 공유 | - | `icon_armor_abyss` |

### boss_set — 진홍 + 금 (용기사, 기존 색상 유지)
| 아이템 | 슬롯 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|---|
| 용각 투구 | 투구 | 신화 | 이미 전용(`icon_helmet_dragon`) | - | 유지 |
| 용린 갑주 | 방어구 | 신화 | 이미 전용(`icon_armor_dragon`) | - | 유지 |
| 용아 대검 | 무기(bigsword) | 신화 | **강철 대검과 손그림 공유** | `claymore_dragon` | 이미 전용(`icon_weapon_dragon`) |
| 용의 인장 | 장신구 | 신화 | 이미 전용(`icon_trinket_dragon`) | - | 유지 |

### tower_easy_set — 강철 은청색 (파수꾼)
| 아이템 | 슬롯 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|
| 파수꾼의 검 | 무기(rapier) | 타워 무기 5종 전부 공유 | `rapier_sentinel` | `icon_weapon_sentinel` |
| 파수꾼의 갑주 | 방어구 | 타워 방어구 5종 전부 공유 | - | `icon_armor_sentinel` |
| 파수꾼의 투구 | 투구 | 타워 투구 5종 전부 공유 | - | `icon_helmet_sentinel` |
| 파수꾼의 인장 | 장신구 | 타워 장신구 5종 전부 공유 | - | `icon_trinket_sentinel` |

### tower_normal_set — 금백색 광휘 (심판자)
| 아이템 | 슬롯 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|
| 심판자의 검 | 무기(rapier) | `rapier_judge` | `icon_weapon_judge` |
| 심판자의 갑주 | 방어구 | - | `icon_armor_judge` |
| 심판자의 투구 | 투구 | - | `icon_helmet_judge` |
| 심판자의 인장 | 장신구 | - | `icon_trinket_judge` |

### tower_hard_set — 짙은 진홍/검정 (종언)
| 아이템 | 슬롯 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|
| 종언의 검 | 무기(rapier) | `rapier_end` | `icon_weapon_end` |
| 종언의 갑주 | 방어구 | - | `icon_armor_end` |
| 종언의 투구 | 투구 | - | `icon_helmet_end` |
| 종언의 인장 | 장신구 | - | `icon_trinket_end` |

### tower_hell_set — 주황-검정 화염 (겁화)
| 아이템 | 슬롯 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|
| 겁화의 검 | 무기(rapier) | `rapier_hellfire` | `icon_weapon_hellfire` |
| 겁화의 갑주 | 방어구 | - | `icon_armor_hellfire` |
| 겁화의 투구 | 투구 | - | `icon_helmet_hellfire` |
| 겁화의 인장 | 장신구 | - | `icon_trinket_hellfire` |

### tower_abyss_set — 무지개(전 스펙트럼) (천공) ★최우선 후보
| 아이템 | 슬롯 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|
| 천공의 검 | 무기(rapier) | `rapier_prism` | `icon_weapon_prism` |
| 천공의 갑주 | 방어구 | - | `icon_armor_prism` |
| 천공의 투구 | 투구 | - | `icon_helmet_prism` |
| 천공의 인장 | 장신구 | - | `icon_trinket_prism` |

---

## 비세트 아이템 (색상 통일 불필요, 모양만 고유하면 됨 — 기존 등급색 참고 가능)

등급색 참고: 일반(회백) / 레어(파랑) / 에픽(보라) / 신화(빨강) — `game_state.gd`
`RARITY_COLORS`에 이미 정의됨.

### 무기 (8종)
| 아이템 | 등급 | 현재 공유 | 신규 손그림 | 신규 아이콘 |
|---|---|---|---|---|
| 낡은 검 | 일반 | 철검과 공유 | `sword_worn` | `icon_sword_worn` |
| 철검 | 일반 | 낡은 검과 공유 | `sword_iron` | `icon_sword_iron` |
| 사냥꾼의 활 | 일반 | 활 3종 아이콘 공유 | (활은 손그림 없음) | `icon_bow_hunter` |
| 강철 대검 | 레어 | 용아 대검과 공유 | `bigsword_steel` | `icon_bigsword_steel` |
| 서리 단검 | 레어 | 단독(색상만 새로) | `sai_frost` | `icon_sai_frost` |
| 질풍의 활 | 레어 | 활 3종 아이콘 공유 | - | `icon_bow_gale` |
| 영혼 사수의 활 | 에픽 | 활 3종 아이콘 공유 | - | `icon_bow_soul` |
| 빙하의 파편 | 에픽 | 타워 rapier 5종과 공유 | `rapier_glacier` | `icon_rapier_glacier` |

### 방어구 (6종)
| 아이템 | 등급 | 신규 아이콘 |
|---|---|---|
| 여행자 옷 | 일반 | `icon_armor_traveler` |
| 가죽 갑옷 | 일반 | `icon_armor_leather` |
| 사슬 갑옷 | 일반 | `icon_armor_chain` |
| 파수병 흉갑 | 레어 | `icon_armor_sentry` |
| 설원의 망토 | 에픽 | `icon_armor_snowcloak` |
| 용의 비늘 | 에픽 | `icon_armor_scale` |

### 투구 (3종)
| 아이템 | 등급 | 신규 아이콘 |
|---|---|---|
| 가죽 모자 | 일반 | `icon_helmet_leather` |
| 철 투구 | 일반 | `icon_helmet_iron` |
| 파수병 투구 | 레어 | `icon_helmet_sentry` |

### 장신구 (4종)
| 아이템 | 등급 | 신규 아이콘 |
|---|---|---|
| 구리 반지 | 일반 | `icon_trinket_copper` |
| 수정 목걸이 | 레어 | `icon_trinket_crystal` |
| 황혼의 부적 | 레어 | `icon_trinket_dusk` |
| 가라앉은 목걸이 | 레어 | `icon_trinket_sunken` |

### 정령 인장 (4종)
| 아이템 | 신규 아이콘 |
|---|---|
| 숲의 정령 인장 | `icon_spirit_forest` |
| 바람의 정령 인장 | `icon_spirit_wind` |
| 불꽃의 정령 인장 | `icon_spirit_flame` |
| 서리의 정령 인장 | `icon_spirit_frostseal` |

---

## 체크리스트 (진행 상태 표시용)

**2026-09-04 갱신: 아래 61종 전부 완료 확인(`scripts/game_state.gd`
`ITEM_ICONS`를 이 문서의 각 표와 `grep -n`으로 대조, 빠짐/충돌 0건 —
`tests/check_item_icons.gd`가 이 상태를 회귀 검사로 고정하고 있다).
그동안 이 체크리스트만 갱신이 안 돼 전부 미완료로 보였다.
(2026-09-04 추가 확인: "정령 인장 4종"만 마지막으로 `[ ]`로 남아 있던
것도 같은 이유였다 — `game_state.gd:783~786`이 EQUIPMENT에, `885~888`이
ITEM_ICONS에 이미 4종 전부 등록돼 있고 `check_item_icons.gd`가
`GameState.EQUIPMENT` 전체를 순회하므로 정령 인장도 이미 검사 대상에
포함돼 있었다. 코드 변경 없음, 체크박스만 정정.)**

- [x] tower_abyss_set (천공) 4종 — 무지개
- [x] tower_hell_set (겁화) 4종
- [x] tower_hard_set (종언) 4종
- [x] tower_normal_set (심판자) 4종
- [x] tower_easy_set (파수꾼) 4종
- [x] boss_set 무기(용아 대검) 손그림 1종
- [x] guardian_set 3종
- [x] captain_set 3종
- [x] frost_set 3종
- [x] abyss_set 3종
- [x] 비세트 무기 8종
- [x] 비세트 방어구 6종
- [x] 비세트 투구 3종
- [x] 비세트 장신구 4종
- [x] 정령 인장 4종

---

## 외부 에셋 라이선스 (2026-09-04, INBOX G에서 이관 — 삭제 전 보존)

- 규칙: 외부 에셋은 **CC0(또는 그에 준하는 재배포 허용)로 확인된 것만**
  저장소에 넣는다. 라이선스를 눈으로 확인하지 않은 팩은 커밋하지 않는다.
- **쓸 수 없다고 확인한 것**: Pixeltier 아이콘 팩(itch.io, $5)은 CC0가
  아니라 독점 라이선스이고 "아무리 많이 수정했어도 재배포 금지" 조항이
  있다. 이 저장소는 공개 GitHub이라 커밋 자체가 재배포에 해당한다.
- **쓸 수 있다고 확인한 것**: Dungeon Crawl Stone Soup 타일셋(CC0, PNG
  6029개 — 몸통갑옷 83·투구 29·부적 29·반지 43·무기 227·유물 84),
  OpenGameArt "16x16 Weapon RPG Icons"(CC0), 기존 Ninja Adventure(CC0).
  팩 원본 압축본은 `.gitignore`로 제외하고 `tools/build_item_icons.py`가
  다시 받는다. 결과물만 추적한다.
  **주의**: DCSS 타일셋은 아이템 아이콘용이며 16x16 4방향 캐릭터 시트가
  아니다 — 캐릭터 몸통/투구 실루엣 교체(INBOX O 조각 2)에는 그대로
  못 쓴다.
- **ComfyUI는 자율루프(launchd, 사람 맥)에서 쓸 수 있다.** 클라우드/웹
  세션(claude.ai)에서는 GPU·torch가 없어 못 쓴다 — 그 경우 CC0 팩에서
  가져오거나 사람에게 맡긴다.
  **절차(2026-09-05 복원)**: 로컬 ComfyUI Desktop(127.0.0.1:8188)이 떠
  있으면 `python3 tools/comfy_gen.py --prompt "..." --prefix <이름>
  --seed <n> [--count N] [--postprocess --out <경로> --size 64]`로
  생성한다. 워크플로 원본은 `docs/tools/comfy_zimage_workflow.json`(API
  형식, 모델 `z_image_turbo_bf16`+`qwen_3_4b`(lumina2)+`ae.safetensors`,
  1024², steps 8, cfg 1.0, `res_multistep/simple`) — `<<PROMPT>>`/
  `<<PREFIX>>`/seed만 바꿔 쓴다. 원본 PNG는 기본
  `assets/characters/source/comfy/`에 저장되고, `--postprocess`를 주면
  c263e14가 쓴 것과 같은 방식(네 모서리 색 평균을 배경으로 보고 투명화 →
  내용 크롭 → 지정 크기로 축소, `tools/comfy_gen.py`의
  `remove_corner_background`/`tools/pixel.py`의 `box_down` 재사용)으로
  후처리해 `--out` 경로에 저장한다.
- **몬스터 중복은 사람이 보류시켰다.** `scripts/enemy.gd`의 `KINDS`에
  몬스터·보스 ID가 55개인데 원본 텍스처는 23개뿐이고, 32개 ID가 `tint`만
  바꿔 다른 ID의 그림을 재사용한다. 10개 챕터 보스는 텍스처 4장을 나눠
  쓴다. 이 재사용은 의도된 것(`CHAPTER5_EXPANSION_DESIGN.md` 5절,
  `CHAPTER6_10_MASTERPLAN.md` 3절)이나, 사람이 "몬스터는 건드리지 말고
  아이템 우선순위로"라고 명시적으로 보류시켰다. **사람이 다시 열라고
  하기 전에는 손대지 말 것.**
