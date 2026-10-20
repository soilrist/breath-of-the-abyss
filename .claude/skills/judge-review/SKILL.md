---
name: judge-review
description: 12인 심판(zero-12-judges) 재심사 — 12개 관점이 직전 판결문 대비 지금 커밋을 채점하고 문제를 심각한 순으로 낸다("심판들한테 검사받아", "12인 채점", "재심사"). 감독 전용, 하루 한 번(06시 무렵). 사람이 "지금 당장" 이라고 할 때만 임시 추가.
---

1. **횟수 확인.** `docs/ROADMAP.md` 규칙대로 하루 한 번. 오늘 `docs/REVIEW_<오늘>*.md` 가 이미 있으면 사람이 직접 요청한 경우만 돌린다.
2. **직전 판결문 고르기.** `ls docs/REVIEW_*.md` 의 가장 최근 것 = `prevDoc`. 첫 줄 "기준 커밋" = `base`. 점수판에서 심판별 최신 점수를 `prev` 로 뽑는다.
3. **인자 만들기.** 이 폴더 `judges.json` 각 항목에 `prev` 를 붙여 `judges` 로. 사람이 계기가 된 말을 했으면 `note` 에 그대로.
4. **실행.** Workflow 도구 `scriptPath: .claude/skills/judge-review/workflow.js`, `args: {prevDoc, base, note, judges}`. 심판은 Explore 12명, 읽기 전용(일꾼 작업 중이라 godot·테스트·git 변경 금지).
5. **판결문 쓰기.** `docs/REVIEW_<YYYY-MM-DD>[-HH].md` — 형식은 `docs/REVIEW_2026-10-20-19.md` 그대로: 기준 커밋·계기 / 점수판(직전·지금·한 줄) / 문제 심각한 순(여러 심판 공통이면 "N명 지적") / 처음 해 본 사람 말 3 / 감독 판단 INBOX 순서.
6. **INBOX 반영 → 커밋.** 감독 판단 순서대로 `결함(감독)`·`지시` 를 `inbox` 스킬 형식으로 추가. `git add` 판결문·INBOX 만 → `docs(review): 12인 심판 <평균 직전→지금>`.
7. **사람에게 보고.** 평균 점수 변화 + 가장 큰 문제 3개.

심판 관점을 바꾸려면 `judges.json` 만 고친다(순서 = 심판 번호, 옛 판결문과 번호가 맞아야 함).
