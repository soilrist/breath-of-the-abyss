# 심연의 숨결 (Zero Study RPG)

Godot 4 로 처음부터 만든 오리지널 2D 액션 RPG 입니다. AI 자율 개발 루프(Claude)가 사람의 지시를 받아 만들었습니다.

## 라이선스

- 코드: MIT (`LICENSE`)
- 에셋: 파일별 출처·라이선스는 `_Source/LICENSES.md` — 외부 에셋은 전부 CC0 1.0(Ninja Adventure·Dungeon Crawl Stone Soup), 폰트는 SIL OFL 1.1, 나머지는 이 프로젝트 제작.
- 캐릭터·지명·이야기는 모두 이 프로젝트 창작이며, 특정 상용 게임과 관련이 없습니다.

320×240 피처폰 감성의 완결형 2D 액션 RPG 학습 프로젝트입니다. 타이틀, 2개 챕터, 5개 지역, 일반 전투, 보스전, 성장, 장비, 인벤토리, 상점, 퀘스트, 저장·불러오기와 엔딩이 연결되어 있습니다.

## 조작

- 이동: WASD 또는 방향키
- 공격: J 또는 Space
- 범위 스킬: K
- 그림자 돌진: Q (2장 완료 후 해금)
- 회복약: L
- 대화·상호작용: E
- 인벤토리: I
- 저장·불러오기: F5/F6
- 일시정지: Esc

## 실행

- Godot 프로젝트: `<저장소>/project.godot`
- macOS 앱: `<저장소>.app`

## 검증

`tests/run_validation.sh`은 프로젝트 컴파일·시작 실행·필수 시스템 존재 여부를 검사합니다. `tests/build_macos.sh`은 macOS 앱을 만들고 서명을 검증합니다.

## 에셋 작업 범위

캐릭터 관련 원본은 `assets/characters/source/`에 모아 관리합니다. 이 프로젝트용으로 지정되지 않은 외부 ComfyUI 출력물은 사용하지 않습니다.

## 자율 개발 루프

한 바퀴 = 새 헤드리스 Claude 세션이 `loop/PROMPT.md` 대로 일하고 커밋한다. 대화는 이어 붙이지 않고, 기억은 `docs/` 문서가 대신한다.

| 파일 | 역할 |
|---|---|
| `loop/loop.sh` | 루프 본체. 무한 반복, 바퀴마다 새 세션, `loop/STOP` 있으면 현재 바퀴 후 종료 |
| `loop/env.sh` | 설정: 모델 · 바퀴당 비용 상한(USD) · 바퀴당 시간 상한 · 대기 · 최대 바퀴 수 · 점검 모드 |
| `loop/PROMPT.md` | 지시서 6절 (합격 기준 · 먼저 읽을 문서 · 규칙과 근거 · 한 바퀴 순서 · 커밋 순서 · 검사와 QA) |
| `loop/settings.json` | 루프 세션 전용 설정. claude.ai 로그인으로 직접 호출 |
| `loop/mcp.json` | 세션에 붙일 MCP 서버(godotMCP만). 데스크톱 앱의 MCP는 헤드리스 세션에 안 보이므로 여기 명시 |
| `loop/ctl.sh` | 켜기 / 끄기 / 상태 |
| `loop/com.zerostudyrpg.loop.plist` | launchd 등록 파일 (로그인 시 시작, 비정상 종료만 재시작, PATH 명시) |
| `docs/DESIGN.md` | 무엇을 만드는가 (거의 안 고침) |
| `docs/STATUS.md` | 어디까지 했고 다음은 뭔가 (한 바퀴마다 갱신) |
| `docs/feedback/INBOX.md` | 사람이 던지는 지시 (가장 먼저 처리, 끝나면 완료 표시만) |
| `logs/` | `loop-YYYY-MM-DD.log` 바퀴 요약 · `run-<시각>.log` 세션 출력 · `launchd.*.log` |

```bash
loop/ctl.sh on       # 켜기 — launchd 등록 + 즉시 시작 (STOP 제거)
loop/ctl.sh off      # 끄기 — STOP 파일 생성(현재 바퀴는 마침) + 등록 해제
loop/ctl.sh status   # 상태 — 등록 여부 · 프로세스 · 최근 로그
```

수동 시험 가동 (등록 없이 두 바퀴, 읽고 보고만):

```bash
LOOP_MAX_LOOPS=2 LOOP_DRY_RUN=1 LOOP_SLEEP_SEC=5 loop/loop.sh
```

`LOOP_MODEL`은 기본 `claude-sonnet-5`, 과부하 때는 `LOOP_FALLBACK_MODEL`(`claude-opus-5`)로 바꾼다.

이 CLI 버전(2.1.258)에는 턴 수 제한 옵션이 없어 바퀴당 상한은 비용(`LOOP_MAX_BUDGET_USD`)과 시간(`LOOP_MAX_SEC`)으로 건다.
