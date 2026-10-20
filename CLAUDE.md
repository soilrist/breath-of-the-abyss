# CLAUDE.md — 이 저장소에서 일하는 모든 AI가 먼저 읽는 한 장 (키트 v2.6.0)

> **짧게 유지한다 (200줄 이내).** 규칙 원문은 여기 적지 않는다 — 아래 문서 목록에서 지금 하는 일에 맞는 문서 **하나만** 연다.
> **규칙은 `docs/conventions/` 에만 적는다.** 이 파일·스킬·에이전트·PROMPT 와 내용이 다르면 **컨벤션 문서가 이긴다.**

## 프로젝트
- 게임: 심연의 숨결 — 320×240 피처폰 감성 2D 액션 RPG (1~10장, 탑 500층, 1·2차 전직) / 장르: 액션 RPG
- 엔진: Godot 4.7 GDScript · 엔진 프로젝트 위치 저장소 루트 — 엔진별 구체 규칙은 `docs/engines/godot.md`
- 그림·모델·소리 만드는 도구: ComfyUI(`assets/fx` 생성에 썼으나 워크플로 유실 — `HANDOFF.md` 참고)
- 레퍼런스 게임: 옛 피처폰 액션 RPG(피처폰 액션 RPG) — 놀이는 따르고 겉모습은 다르게
- 설계서 `docs/DESIGN.md` · 진행 `docs/STATUS.md` · 순서 `docs/ROADMAP.md`
- 사람의 지시: `docs/feedback/INBOX.md` (맨 위가 최우선)

## 반드시 지킬 것 (원칙만 — 자세한 건 괄호 속 문서)
1. 밸런스 숫자는 루프가 정하고 `docs/DESIGN.md` §6 에 값+근거를 적는다. 사람에게 묻지 않는다. `-1` 을 커밋에 남기지 않는다. (DataDriven)
2. 캡처는 검사다, 증거가 아니다. **1·2층 "통과"는 실제로 명령을 돌리고 그 출력을 STATUS 에 인용하고, `tools/jev.py evidence` 가 `SUPPORTED` 라고 했을 때만. 3층 "통과"는 게임 카메라 캡처를 실제로 열어 보고 어느 그림을 봤는지 적었을 때만.** 판단은 이름·문자열 패턴이 아니라 실제 결과로. (Verification)
2-2. 시험이 통과해도 플레이어가 못 쓰면 실패다. 보이거나 만지는 조각은 **처음 켠 사람 눈**으로 다섯 칸을 본다: 처음 하는 사람 · 목표 기기의 손 · 게임 카메라에서 보이나 · 장르 상식 · 갇힘 없음. (PlayerEye)
2-1. 레퍼런스 게임의 **놀이(시스템·콘텐츠 종류·조작 흐름)와 품질**은 따르고, **겉모습(배치·모양·색·캐릭터 얼굴·글·이름)은 우리 것으로 다르게** — 너무 똑같으면 소송. 보이는 것은 레퍼런스 시트 먼저, 자리표시 품질로 합격 찍지 않는다. (Reference 6절)
3. 자기가 바꾼 파일만 이름으로 지정해 커밋한다. (GitCommit)
4. 씬·에셋 파일을 텍스트로 함부로 고치지 않는다. 파일 이동·이름 변경은 에디터(또는 엔진 MCP 의 에셋 명령)로. 엔진별 구체 방법은 `docs/engines/<엔진>.md`. (FolderStructure)
5. 모르는 이름·폴더·형식은 지어내지 않고 해당 문서를 연다.
6. 혼자 정할지 물을지는 신호등으로: 🟢 정하고 진행 · 🟡 가정하고 `확인`(설계서에 없는 것은 항상 🟡) · 🔴 방향·돈·삭제·권리·규칙·사람만 할 수 있는 것은 `질문`. (Autonomy)
7. API 키·비밀번호를 코드·커밋에 넣지 않는다. 훅(`--no-verify`)을 우회하지 않는다.

## 함정 (이 프로젝트에서 실제로 넘어진 곳 — 20줄 이내)
> 규칙이 아니라 사실만 한 줄씩: "무엇을 하면 → 무엇이 깨진다 → 대신 이렇게". 감독이 사고기록(`docs/postmortems/`)에서 옮겨 적고, 더는 안 맞는 줄은 지운다 (DIRECTOR.md "규칙이 샐 때").
- `queue_free()` 는 프레임 끝에 처리됨 → 그룹으로 세는 대상이 한 프레임 더 남음 → 그룹에서 먼저 빼고 `queue_free()`
- 화면 오른쪽 x270 너머는 모바일 버튼 줄이 덮음 → 적·상자·이름표가 가려짐 → 배치는 x270 안쪽
- 지역 이동 시 몬스터·보스·바닥 물건 정리 누락 → 옛 지역 것이 새 지역에 남음 → 이동 경로를 새로 만들면 정리까지 확인
- `scripts/main.gd:444` 가 바로 위 레벨업 문구(`$HUD/Message.text`)를 덮어씀 → 레벨업 안내가 안 보임 → 메시지 순서 확인
- 테스트·캡처 전 `--import` 를 안 하면 `.godot/imported` 옛 캐시로 돈다 → 옛 그림·옛 결과 → `godot --headless --path . --import` 먼저 (`tests/run_validation.sh` 는 맨 앞에서 함)

## 너는 누구인가 (둘 중 하나)
- **감독 = 사람의 비서** (Code 탭 대화, `LOOP_LAP` 환경변수 없음) → `loop/DIRECTOR.md` 를 따른다. 사람 말을 알아듣고 INBOX 로 루프에게 시키고 검수·보고한다. 게임 코드는 직접 안 고친다. 사람이 "직접 고쳐줘"라고 명시하면 루프를 멈추고 계획 승인 후 수정 (DIRECTOR.md 예외 절).
- **루프 일꾼** (`LOOP_LAP` 환경변수 있음) → `loop/PROMPT.md` 순서만 따른다. 승인 대신 신호등 규칙. 멈추지 않는다.

## 작업 방식
- 코드·에셋을 만든 뒤 `tools/check_conventions.py` 를 돌린다. 감독은 추가로 `convention-checker` 에이전트로 점검할 수 있다(일꾼은 서브에이전트 금지).
- 새 코드가 필요할 때는 grep 보다 먼저 `graphify query "<찾는 것>"` 으로 기존 구조를 찾는다 (그래프 `graphify-out/` 이 있을 때 — 설치·갱신은 `docs/LOOP_KIT_README.md` 설치 규칙 7-1).
- 개념을 설명할 땐 일반 예시보다 이 프로젝트의 실제 스크립트를 예로 든다.

## 에디터 연결 (MCP)
공통 원칙은 조회 자유·변경 조건부·Play(PIE) 중 금지 — 셋 다 같다. 엔진별 MCP 플러그인 이름·정확한 조건은 `docs/engines/<엔진>.md` "에디터 연결 (MCP)" 절.

## 문서 목록 — 언제 읽나
| 지금 하는 일 | 열 문서 |
|---|---|
| 에셋 만들기·이름 짓기 | `docs/conventions/AssetNaming.md` |
| 파일 둘 곳 고르기·폴더 만들기·파일 옮기기 | `docs/conventions/FolderStructure.md` |
| 코드 작성·수정 | `docs/conventions/CodingStyle.md` |
| 엔진별 구체 방법(에셋 이름·코드·MCP 등) | `docs/engines/<엔진>.md` |
| 몬스터·아이템·스킬 등 콘텐츠 추가 | `docs/conventions/DataDriven.md` |
| 레퍼런스 게임 따라 만들기·UI/캐릭터 품질 | `docs/conventions/Reference.md` + `docs/reference/` 시트 |
| 커밋 | `docs/conventions/GitCommit.md` |
| 브랜치 만들기·합치기 | `docs/conventions/BranchStrategy.md` |
| 버전·변경기록 | `docs/conventions/Versioning.md` |
| 검사·캡처·QA | `docs/conventions/Verification.md` + `docs/checks/<엔진>.md` |
| 플레이어가 보거나 만지는 조각(조작·UI·장비·동작·맵) · 마일스톤 끝 | `docs/conventions/PlayerEye.md` |
| INBOX 읽기·쓰기 | `docs/conventions/InboxFormat.md` |
| 혼자 정할지 물을지 애매할 때 | `docs/conventions/Autonomy.md` |
| 기능 명세·버그·결정·사고기록 | `docs/templates/` 양식 복사 |

## 스킬 (작업 카드) — `.claude/skills/`
| 스킬 | 부르는 말 | 하는 일 |
|---|---|---|
| `kickoff` | "〔이런 게임〕 만들어", "〔기능〕 넣자" | 한마디 → 설계서·질문 묶음·로드맵 |
| `commit` | /commit, "커밋해줘" | 규칙대로 조각별 커밋 (직접 불렀을 때만 실행) |
| `new-script` | /new-script, "스크립트 만들어줘" | 계획 → 작성 → 검사 |
| `new-content` | /new-content, "몬스터/아이템 추가해줘" | SO 틀·데이터 에셋 추가, 숫자는 DESIGN §6 에 근거와 함께 |
| `new-visual` | "〔화면·모델·동작〕 만들어/고쳐", "조잡해" | 시트 → 만들기 → 게임 카메라 캡처 열어 대조 → 플레이어 눈 |
| `reference-sheet` | "영상 보고 동작 맞추기", "원본이랑 달라" | 레퍼런스 시트·동작 관찰표 (영상 프레임을 직접 보고 숫자로) |
| `inbox` | /inbox, "인박스에 적어줘" | INBOX 형식대로 지시·질문 추가 |
| `judge-review` | "심판들한테 검사받아", "12인 채점" | 12인 심판 재심사 워크플로 → 판결문 → INBOX (하루 1회) |
| `release` | /release, "main 에 올리자" | 합치기 조건 확인 → CHANGELOG → 태그 (승인 필수) |

## 검사 에이전트 — `.claude/agents/`
- `convention-checker` — 읽기 전용. 규칙 위반 표 + **점검한 규칙 목록**으로 보고.
