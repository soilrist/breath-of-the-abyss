# 캐릭터 스프라이트

전부 Ninja Adventure 에셋팩(CC0)에서 가져왔다. 배경 타일과 같은 팩이라 화풍과
픽셀 밀도가 맞는다. 확대·축소하지 않고 원본 크기 그대로 쓴다.

| 파일 | 원본 | 프레임 | 배치 |
|---|---|---|---|
| `hero.png` | `Character/SamuraiBlue/SpriteSheet.png` | 16×16 | 4열(하·상·좌·우) × 7행 |
| `npc_elder.png` | `Character/OldMan/SpriteSheet.png` | 16×16 | 위와 같음 |
| `npc_captain.png` | `Character/Knight/SpriteSheet.png` | 16×16 | 위와 같음 |
| `enemy_beast.png` | `Monster/Beast2/Beast2.png` | 16×16 | 4열 × 4행 |
| `enemy_knight.png` | `Character/NinjaMageBlack/SpriteSheet.png` | 16×16 | 4열 × 7행 |
| `boss_guardian.png` | `Boss/GiantBamboo/Idle.png` | 62×62 | 1행 × 6프레임, 방향 없음 |
| `boss_captain.png` | `Boss/GiantBlueSamurai/Idle.png` | 48×48 | 1행 × 12프레임, 방향 없음 |
| `mob_eye.png` | `Monster/Eye/Eye.png` | 16×16 | 4열 × 4행 |
| `mob_bear.png` | `Monster/Bear/SpriteSheet.png` | 16×16 | 4열 × 4행 |
| `mob_mollusc.png` | `Monster/Mollusc/Mollusc.png` | 16×16 | 4열 × 4행 |
| `mob_dragon.png` | `Monster/Dragon/SpriteSheet.png` | 16×16 | 4열 × 4행 |

7행 캐릭터 시트의 행 뜻: 0 대기, 1~4 걷기, 5 공격, 6 기타(사망·아이템·특수).
열 뜻: 0 아래, 1 위, 2 왼쪽, 3 오른쪽. 시트에 네 방향이 다 있으므로
좌우 반전(`flip_h`)을 쓰지 않는다. 예전 시트에서 나던 방향 반전 문제가 사라진다.

이전의 32×32 자체 제작 시트와 ComfyUI 원본은 화풍이 맞지 않아 전부 삭제했다.
필요하면 커밋 `4ca1663` 이전 기록에서 되찾을 수 있다.
