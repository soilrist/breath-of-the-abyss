export const meta = {
  name: 'zero-12-judges',
  description: '심연의 숨결 12인 심판 재심사 — 직전 판결문 대비 현재 커밋 점수, 문제점 위주',
  phases: [{ title: 'Judge', detail: '12개 관점 독립 심사(읽기 전용)' }],
}
// args: { prevDoc: 'docs/REVIEW_….md', base: '<직전 기준 커밋>', note: '사람 말(선택)', judges: [{name, lens, prev}] }
const SCHEMA = {
  type: 'object',
  properties: {
    score: { type: 'number', description: '0~10, 0.5 단위' },
    prev_score: { type: 'number' },
    improved: { type: 'array', items: { type: 'string' }, description: '직전 판결 이후 실제로 좋아진 점(파일:줄 근거), 최대 3' },
    still_broken: { type: 'array', items: { type: 'string' }, description: '지금 점수를 깎는 가장 큰 문제(파일:줄·캡처 근거), 최대 3, 심각한 순' },
    player_complaint: { type: 'string', description: '처음 해 본 플레이어가 할 법한 불만 한 문장(구어체)' },
    next_fix: { type: 'string', description: '점수를 가장 많이 올릴 다음 한 가지(구체적 파일·함수)' },
  },
  required: ['score', 'prev_score', 'improved', 'still_broken', 'player_complaint', 'next_fix'],
}
const note = args.note ? `사람(개발 의뢰인)이 방금 이렇게 말했다: "${args.note}" — 이 말을 관점에 맞게 반드시 확인하라.\n` : ''
const results = await parallel(args.judges.map((j, i) => () => agent(
`너는 Godot 4 게임 "심연의 숨결"(저장소 <저장소>, 320×240 피처폰 감성 액션 RPG, 레퍼런스 옛 피처폰 액션 RPG)의 12인 심판 중 #${i + 1} "${j.name}" 이다.
직전 판결문 ${args.prevDoc} 의 "심판 ${i + 1}" 줄·절을 먼저 읽어라 — 그때 점수 ${j.prev}/10 과 지적 사항이 있다.
그 뒤 지금 코드(HEAD)를 직접 읽고 같은 관점으로 다시 채점하라. 그 이후 커밋은 \`git log --oneline ${args.base}..HEAD\` 로 보고, 필요한 diff 는 \`git show <커밋>\` 로 본다. docs/STATUS.md 는 일꾼 기록이니 주장만 믿지 말고 코드로 확인.
관점: ${j.lens}
${note}코드만 보고 '있다'고 합격하지 마라. 보이는 것(연출·UI·맵·캐릭터)은 captures/ 아래 게임 캡처를 Read 로 직접 열어 보고, 어느 그림을 봤는지 근거에 적어라. 장르 상식(액션 RPG 를 처음 켠 사람이 기대하는 것)과 어긋나는 것을 우선으로 찾아라.
목적은 "뭐가 문제인지"를 사람에게 알려 주는 것이다. 칭찬보다 문제를 정확히, 심각한 순으로.
규칙: 읽기 전용. 파일을 고치거나 만들지 말고, git 상태를 바꾸는 명령·godot 실행·테스트 실행 금지(다른 일꾼이 지금 작업 중). 근거는 파일:줄 또는 캡처 파일명. 직전 지적이 실제로 고쳐졌는지 하나씩 확인하고, 고쳐지지 않았으면 점수를 올리지 마라. 10점은 상용 피처폰 RPG 명작 수준이다. 한국어로.`,
  { label: `심판${i + 1}:${j.name}`, phase: 'Judge', schema: SCHEMA, agentType: 'Explore' }
).then(r => r && { n: i + 1, name: j.name, ...r })))
return results.filter(Boolean)
