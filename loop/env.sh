#!/bin/bash
# ─────────────────────────────────────────────
# 루프 설정 — 여기만 고치면 다음 바퀴부터 적용 (재시작 필요 없음)
# 사람이 직접 고칠 필요 없음: 감독에게 "30분마다로 바꿔줘" 라고 말하면 됨
# ─────────────────────────────────────────────

# 이 프로젝트 이름 (launchd 라벨·알림에 씀, 영어 소문자·하이픈)
LOOP_SLUG="${LOOP_SLUG:-zerostudyrpg}"
LOOP_LABEL="com.${LOOP_SLUG}.loop"

# 바퀴가 "끝난 뒤" 쉬는 시간(초). 평시 180 / 아낄 때 900 / 한도 빠듯하면 1800
# ZeroStudyRPG: 사람 세션과 같은 계정이라 한도 보호 (2026-09-07 사람 지시, 2026-10-19 유지)
LOOP_SLEEP_SEC=1800
# 2026-10-19 사람 지시 "1시까지는 쉬는시간 없애" → 10-20 00:20 사람이 자러 가며 "내일아침까지 너가혼자알아서 다 해야해"
#   → 10-20 00:25 사람이 다시 "오전1시까지는 바퀴 쉬는시간없다" — 01:00 까지만 쉬지 않음 (시각 지나면 저절로 1800 으로 돌아감)
[ "$(date +%Y%m%d%H)" -lt 2026102001 ] && LOOP_SLEEP_SEC=0

# 한 바퀴 최대 시간(초). 넘으면 끊고 다음 바퀴
# ZeroStudyRPG: 옛 LOOP_MAX_SEC=1800 을 이어받음
# 2026-10-20 감독: 1800 → 2700. #11·#14·#18 이 전체 검증(220여 조각) 도중 1860초대에서 끊겨 커밋 안 된 변경을 남기고 다음 바퀴가 이어받느라 한 바퀴씩 버림
LOOP_LAP_TIMEOUT_SEC=2700

# 모델: 소넷 우선, 과부하 시 오퍼스 (claude --fallback-model)
#   소넷→오퍼스는 LOOP_FALLBACK_MODEL 이 맡는다
#   (--fallback-model 은 과부하 때만 오퍼스로 바뀐다)
LOOP_MODEL="claude-sonnet-5"
LOOP_FALLBACK_MODEL="claude-opus-5"

# 노력 단계 (claude --effort): low / medium / high / xhigh / max. 비우면 claude 기본값
# 평소엔 medium, 직전 바퀴가 일한 커밋 없이 끝났을 때만 RETRY 값으로 올린다 (비우면 안 올림)
# 왜: 단계가 높을수록 토큰을 더 쓴다. 높은 단계는 "재시도 한 번을 줄여 줄 때"만 본전이다
LOOP_EFFORT="medium"
LOOP_EFFORT_RETRY="high"

# 가벼운 바퀴: 1(기본)이면 사람 전역 설정(개인 훅·전역 스킬·플러그인·전역 MCP)을 바퀴에 싣지 않는다
# 프로젝트 .claude/(스킬·설정)·CLAUDE.md 는 그대로, MCP 는 loop/mcp.json 에 적은 것만. 끄려면 0
# 왜: 루프가 안 쓰는 전역 설정이 바퀴의 모든 호출마다 다시 실린다. 줄었는지는 logs/context.csv · `loop/ctl.sh cost` 로 본다
# 주의: 일꾼이 써야 하는 스킬은 전역이 아니라 프로젝트 .claude/skills/ 에 둔다 (전역 것은 일꾼 눈에 안 보인다)
LOOP_LEAN=1
# 가벼운 바퀴에서 일꾼이 쓰는 기본 도구 (비우면 loop.sh 기본 12개). 엔진 MCP 도구는 여기 말고 loop/mcp.json
LOOP_TOOLS=""

# 바퀴 전 점검 명령 (비우면 건너뜀). 종료코드 0 이 아니면 그 바퀴는 claude 를 부르지 않고 쉰다
# 엔진 에디터·MCP 가 살아 있는지처럼 "이게 죽어 있으면 바퀴가 통째로 헛도는 것" 하나를 싸게 확인하는 명령을 감독이 넣는다
# 예) Unity 상주 에디터: 'pgrep -f "Unity.*-projectPath" >/dev/null'   예) 로컬 서버: 'curl -fsS localhost:8080/health >/dev/null'
# ZeroStudyRPG: tests/run_validation.sh 의 GODOT_BIN 기본 경로에 Godot 가 실제로 있는지 (2026-10-19 옛 경로가 사라져 있었음)
LOOP_PREFLIGHT_CMD='test -x "$(sed -n '"'"'s/^GODOT_BIN=\${GODOT_BIN:-\(.*\)}$/\1/p'"'"' tests/run_validation.sh)"'
LOOP_PREFLIGHT_SLEEP_SEC=600

# 한 바퀴 비용 상한(달러, 비우면 제한 없음) — claude --max-budget-usd
LOOP_MAX_BUDGET_USD=12

# 쓸 Claude 로그인. "default" = 기본 로그인 (CLAUDE_CONFIG_DIR 폴더를 적으면 그 로그인을 쓴다)
LOOP_ACCOUNTS="default"

# 구독 한도 폴백: 위 계정이 전부 "사용량 한도"일 때만 Anthropic API 키로 그 바퀴를 한 번 더 돈다 (다음 바퀴는 다시 구독부터)
# 키는 깃에 넣지 않는다. 키 한 줄만 든 파일(아래 경로) 또는 환경변수 FALLBACK_ANTHROPIC_API_KEY. 둘 다 없으면 예전처럼 쉰다
# ANTHROPIC_API_KEY 라는 이름은 쓰지 않는다 — 늘 세팅돼 있으면 claude 가 구독 대신 API 로 먼저 돈다
LOOP_API_KEY_FILE="$HOME/.claude-loop-api-key"
# API 바퀴 한 번의 비용 상한(달러, 비우면 LOOP_MAX_BUDGET_USD 만 적용)
LOOP_API_MAX_BUDGET_USD=""

# 헛바퀴(커밋 0) 연속 몇 번이면 경고 / 그 두 배면 스스로 멈춤
LOOP_MAX_IDLE=3
LOOP_IDLE_SLEEP_SEC=3600

# 모든 계정이 한도일 때 쉬는 시간(초)
# ZeroStudyRPG: 옛 LOOP_RATELIMIT_SLEEP_SEC=900 을 이어받음
LOOP_LIMIT_SLEEP_SEC=900

# 헤드리스 권한 — 위험 명령은 .claude/settings.json 의 deny 로 막혀 있음
LOOP_PERMISSION_FLAGS="--dangerously-skip-permissions"

# claude 실행 파일 (launchd 는 PATH 가 짧아서 직접 찾아 줌)
export PATH="$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
LOOP_CLAUDE_BIN="$(command -v claude || echo claude)"

# 시험용: 1 이면 claude 를 부르지 않고 흉내만 / 최대 바퀴 수(비우면 무한)
LOOP_DRY_RUN="${LOOP_DRY_RUN:-0}"
LOOP_MAX_LOOPS="${LOOP_MAX_LOOPS:-}"

# 한글 로그가 안 깨지게
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
