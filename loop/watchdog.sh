#!/bin/bash
# 루프 감시 — launchd 가 15분마다 부른다 (ctl.sh on 이 등록).
# 루프가 꺼져 있는데 INBOX 에 루프 몫(결함·지시·답·보정·철회 열린 줄)이 남았으면 다시 켠다.
# 왜: 감독이 검수하느라 세워 두고 잊으면 그동안 일이 0 이 된다 (Snarehaven 2026-10-16 「왜 자꾸 루프를 끄냐」).
# 사람이 일부러 세울 땐 ctl.sh off·wrapup·kill — loop/HOLD 가 생겨 감시가 건드리지 않는다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 0
[ -f loop/HOLD ] && exit 0
if [ -f loop/.lock ] && kill -0 "$(cat loop/.lock)" 2>/dev/null; then exit 0; fi
n=$(grep -cE '^- \[ \] (결함|지시|답|보정|철회)\(' docs/feedback/INBOX.md 2>/dev/null)
[ "${n:-0}" -gt 0 ] || exit 0
mkdir -p logs
echo "$(date '+%F %T') 루프 꺼짐 + INBOX 루프 몫 ${n}줄 → 다시 켬" >> logs/watchdog.log
bash loop/ctl.sh on >> logs/watchdog.log 2>&1
