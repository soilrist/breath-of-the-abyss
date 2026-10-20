# 에셋 출처·라이선스

코드(`scripts/`·`tests/`·`tools/` 등)는 저장소 맨 위 `LICENSE`(MIT)를 따른다.
에셋은 아래 표의 라이선스를 따른다. "원본 일치"는 2026-10-20 감독이 저장소 파일과
`assets/vendor/` 원본 팩의 MD5 를 직접 비교해 똑같은 파일 수를 센 것이다.
원본 팩(`assets/vendor/`)은 저장소에 넣지 않는다 — 다시 만들 때는 아래 출처에서 받는다.

| 파일/묶음 | 도구·모델·출처 | 라이선스 | 상업 이용 | 확인 날짜 |
|---|---|---|---|---|
| `assets/audio/music/` 18곡, `assets/audio/sfx/` 14종 | Ninja Adventure Asset Pack (Pixel-boy·AAA, itch.io) 원본 그대로 — 원본 일치 32/32 | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/characters/` 원본 44장 (주인공 옛 시트·NPC·적·보스) | Ninja Adventure Asset Pack 원본 그대로 — 원본 일치 44 (목록 `assets/characters/README.md`) | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/characters/helmet_*` 등 가공 43장 | Ninja Adventure 시트에서 잘라 만듦 (`tools/build_helmet_overlays.py`) + 감독이 그린 주인공 v3 (`tools/build_hero_sheet.py`) | CC0 1.0 원본 + 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/faces/` 16장 | Ninja Adventure Asset Pack 원본 그대로 — 원본 일치 16/16 | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/tiles/` 8장 | Ninja Adventure Asset Pack 원본 그대로 — 원본 일치 8/8 | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/tiles/TilesetGroundV3.png` | 감독이 그린 바닥 타일 (`tools/build_ground_tiles.py`) | 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/fx/` 원본 4장, `assets/icons/skills/` 원본 4장 | Ninja Adventure Asset Pack 원본 그대로 — 원본 일치 4+4 | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/items/icon_*` 장비 아이콘 120장 | 대부분 Dungeon Crawl Stone Soup 타일셋 (OpenGameArt) 재색칠 (`tools/build_item_icons.py`). `icon_armor·misc·smith·weapon` 4장은 Ninja Adventure 원본 그대로, `icon_tower_*` 는 감독이 그림 | CC0 1.0 원본 + 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/items/` 바닥 물건 6장 (`arrow·chest·gold·key·potion·stone`) | Ninja Adventure Asset Pack 원본 그대로 — 원본 일치 6/6 | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/items/mat_*` 재료 아이콘 24장 | Ninja Adventure 그림 4장 재색칠 (`tools/build_material_icons.py`) | CC0 1.0 | 가능 | 2026-10-20 |
| `assets/items/hand/`·`hand_fx/` 손 무기·스윙 44장 | 감독이 그림 (`tools/build_hand_sheets.py`) | 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/items/proj_*` 표창·독침 | 감독이 그림 (`tools/build_projectiles.py`) | 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/fx/skill1/` 8장, `assets/fx/skill2/` 12장 | ComfyUI + Tongyi-MAI/Z-Image-Turbo 모델로 생성 (프롬프트·시드 `MAP_MOB_FX_DESIGN.md` §4 표, 커밋 c263e14·35d00e5) | 모델 가중치 Apache 2.0 (Hugging Face 모델 카드 `license: apache-2.0` 직접 확인), 생성물은 이 프로젝트 것 | 가능 | 2026-10-20 |
| `assets/icons/*.svg`·`jobs/`·`skills/*.svg` | 이 저장소에서 손으로 쓴 SVG | 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/ui/` 타이틀·스플래시·`assets/icons/app_icon.png` | 감독이 제작 (커밋 a1595b9) | 이 프로젝트 제작 | 가능 | 2026-10-20 |
| `assets/fonts/NotoSansKR-Game.ttf` | Google Noto Sans KR 일부 영역만 남김 (`assets/fonts/README.md`) | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | 가능 (폰트 단독 판매 금지) | 2026-10-20 |

## 원본 팩 받는 곳
- Ninja Adventure Asset Pack — https://pixel-boy.itch.io/ninja-adventure-asset-pack (CC0)
- Dungeon Crawl Stone Soup 32x32 타일 — https://opengameart.org/content/dungeon-crawl-32x32-tiles (CC0)
- Noto Sans KR — https://fonts.google.com/noto/specimen/Noto+Sans+KR (OFL 1.1)
