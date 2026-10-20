#!/usr/bin/env python3
"""손에 든 무기 그림과 스윙 시트를 만든다.

근접 무기 14종이 손그림 6장을 나눠 쓰고 있었다. 인벤토리 아이콘은
장비마다 달라졌는데(build_item_icons.py) 정작 전투 중에 들고 있는
그림은 "빙하의 파편"부터 "천공의 검"까지 6종이 전부 같았다.

시트 규격 (scripts/player.gd _update_hand 참고)
  - 프레임 56x56, 가로 5칸(HAND_PHASE_COUNT) x 세로 8칸(8방향) = 280x448
  - 프레임 가운데 = 플레이어 원점 → _hand.position 은 (0,0). 손 자리는 그림에 구워 넣는다(HAND)
  - 행 순서: 아래, 아래오른쪽, 오른쪽, 위오른쪽, 위, 위왼쪽, 왼쪽, 아래왼쪽
  - 0열 대기(손 쪽 아래로 든 칼), 1~2열 머리 뒤로 들어 올림, 3열 베기+궤적, 4열 마무리
  - 칼은 손잡이를 축으로 돌려 손에 붙인다(check() 가 모든 칸에서 확인)
  - 색조는 게임이 등급색으로 입히므로(_hand.modulate) 그림은 원래 색으로 둔다

원본 그림은 손잡이가 위, 칼날이 아래를 향하는 세로 그림이다. 기존 6장은
그대로 쓰고, 새 8종만 같은 팔레트로 그렸다.

사용:
    python3 tools/build_hand_sheets.py
"""

import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import CLEAR, content_box, crop, read_png, write_png  # noqa: E402

FRAME = 56  # 가운데 = 플레이어 원점. 긴 창(16px)을 머리 위로 들어도 안 잘림
PHASES = 5
OCTANTS = 8
HAND_DIR = "assets/items/hand"
FX_DIR = "assets/items/hand_fx"

# 기존 손그림에서 그대로 가져온 팔레트. 새 그림도 같은 색만 쓴다.
PALETTE = {
    "K": (20, 27, 27, 255),      # 외곽선
    "L": (242, 234, 241, 255),   # 칼날 밝은 면
    "M": (171, 194, 188, 255),   # 칼날 중간
    "D": (141, 151, 127, 255),   # 칼날 어두운 면
    "A": (255, 173, 93, 255),    # 코등이·자루끝 (주황)
    "G": (163, 117, 78, 255),    # 손잡이
    "g": (150, 83, 64, 255),     # 손잡이 어두운 쪽
    "R": (224, 57, 76, 255),     # 붉은 장식
    ".": CLEAR,
}

# 새로 그린 세로 원본 8종. 손잡이가 위, 칼날이 아래.
NEW_SPRITES = {
    # 낡은 검 - 아주 짧고 끝이 부러진 칼날
    "sword_worn": [
        ".KgK.",
        "KKGKK",
        ".KDK.",
        ".KMK.",
        ".KDK.",
        ".KKK.",
    ],
    # 심연의 파편 - 코등이 없이 곧게 뻗은 긴 양날, 고리 자루끝
    "tsurugi_abyss": [
        ".KKK..",
        "KgKgK.",
        ".KGK..",
        ".KLK..",
        ".KLK..",
        ".KLK..",
        ".KLK..",
        ".KLK..",
        ".KLK..",
        ".KMK..",
        "..K...",
    ],
    # 용아 대검 - 폭 넓은 날과 벌어진 코등이
    "claymore_dragon": [
        "KKLLLLKK",
        ".KAAAAK.",
        "..KGGK..",
        ".KLMMLK.",
        ".KLMMLK.",
        ".KLMMLK.",
        ".KLMMLK.",
        ".KLMMLK.",
        "..KMMK..",
        "...KK...",
    ],
    # 파수꾼의 검 - 한쪽 날, 끝이 넓어지는 팔치온
    "falchion_sentinel": [
        ".KAAK..",
        ".KGGK..",
        "KKMMKK.",
        ".KMLDK.",
        ".KMLDK.",
        ".KMLDDK",
        ".KMLDK.",
        "..KMDK.",
        "...KK..",
    ],
    # 심판자의 검 - 폭 넓은 십자 코등이와 붉은 보석
    "blessed_judge": [
        "...KGK...",
        "KKKKGKKKK",
        "KAAARAAAK",
        "KKKKLKKKK",
        "...KLK...",
        "...KLK...",
        "...KLK...",
        "...KLK...",
        "...KMK...",
        "....K....",
    ],
    # 종언의 검 - 톱니 날
    "serrated_end": [
        ".KAAK..",
        ".KGGK..",
        "KKMMKK.",
        ".KMDKK.",
        ".KMDK..",
        ".KMDKK.",
        ".KMDK..",
        ".KMDKK.",
        "..KDK..",
        "...KK..",
    ],
    # 겁화의 검 - 물결치는 화염 날
    "flame_hellfire": [
        ".KAAK..",
        ".KGGK..",
        "KKMMKK.",
        ".KMLK..",
        "..KMLK.",
        ".KMLK..",
        "..KMLK.",
        ".KMLK..",
        "..KMK..",
        "...K...",
    ],
    # 천공의 검 - 날개 모양 코등이
    "winged_prism": [
        "..KGK..",
        "KKAAAAKK",
        "KAKLLKAK",
        "..KLLK..",
        "..KLLK..",
        "..KLLK..",
        "..KLLK..",
        "..KLLK..",
        "..KLLK..",
        "..KMMK..",
        "...KK...",
    ],
    # 태초의 검 - 고리 자루끝, 곧게 뻗은 폭 넓은 날 (5장 보스)
    "primordial_edge": [
        "..KRK..",
        "..KGK..",
        "KKAAAKK",
        ".KLMDK.",
        ".KLMDK.",
        ".KLMDK.",
        ".KLMDK.",
        ".KLMDK.",
        ".KLMDK.",
        "..KMK..",
        "...K...",
    ],
    # 심해의 검 - 세 갈래 삼지창 (6장 보스)
    "reef_trident": [
        "...KgK...",
        "...KGK...",
        "...KGK...",
        ".KKKAKKK.",
        ".KLKLKLK.",
        ".KLKMKLK.",
        ".KMKMKMK.",
        ".KDKDKDK.",
        "..K.K.K..",
    ],
    # 성광의 검 - 넓은 주황 십자 코등이와 붉은 보석 자루 (7장 보스)
    "prelate_gold": [
        "...KAK...",
        "...KRK...",
        "...KGK...",
        "KAAAAAAAK",
        "..KKLKK..",
        "...KLK...",
        "...KLK...",
        "...KMK...",
        "...KMK...",
        "...KDK...",
        "....K....",
    ],
    # 침묵의 검 - 각진 머리를 단 전쟁망치 (8장 보스)
    "warden_hammer": [
        "...KgK...",
        "...KGK...",
        "...KGK...",
        "...KGK...",
        "KKKKKKKKK",
        "KLLLMDDDK",
        "KLLLMDDDK",
        "KMMMDDDDK",
        "KKKKKKKKK",
    ],
    # 역행의 검 - 거꾸로 휘어진 낫 (9장 보스)
    "reversal_scythe": [
        "..KgK.....",
        "..KGK.....",
        "..KGK.....",
        "..KGKKKK..",
        "..KALLLLK.",
        "..KKKMMLK.",
        "......KDK.",
        ".....KD.K.",
        "....KD....",
        "....K.....",
    ],
    # 근원의 검 - 붉은 보석 셋 박힌 노래하는 검 (10장 보스)
    "origin_singing": [
        "...KGK...",
        "...KGK...",
        ".KKAAAKK.",
        "..KLRLK..",
        "..KLLLK..",
        "..KLRLK..",
        "..KLLLK..",
        "..KLRLK..",
        "..KMMMK..",
        "..KDDDK..",
        "...KKK...",
    ],
    # 빛바랜 성검 - 폭 좁은 날과 둥근 코등이 (7장 필드 드랍)
    "faded_holysword": [
        "...KGK...",
        "...KGK...",
        "..KAAAK..",
        "...KLK...",
        "...KLK...",
        "...KLK...",
        "...KLK...",
        "...KMK...",
        "...KMK...",
        "...KDK...",
        "....K....",
    ],
    # 역류의 검 - 물결치듯 어긋난 양날 (9장 필드 드랍)
    "backflow_blade": [
        "...KgK...",
        "...KGK...",
        "..KAKAK..",
        "..KLDK...",
        "...KDLK..",
        "..KLDK...",
        "...KDLK..",
        "..KLDK...",
        "...KMMK..",
        "....KK...",
    ],
}

# 기존 손그림을 그대로 쓰는 무기: 새 이름 -> 기존 파일 이름
REUSED = {
    "sword_iron": "sword",
    "bigsword_steel": "bigsword",
    "dagger_frost": "sai",
    "katana_guardian": "katana",
    "lance_frost": "lance",
    "rapier_glacier": "rapier",
}


def from_map(rows):
    return [[PALETTE[ch] for ch in row] for row in rows]


# 몸 시트(hero_v3, 16x16, 플레이어 원점 = 그림 (8,12))에서 칼 쥔 손의 자리. 8방향 순서는 player.gd HAND_OCTANT.
# h = 손이 화면 오른쪽(+1)/왼쪽(-1). 대각선은 옆모습 손을 쓴다.
FACE = [90, 45, 0, -45, -90, -135, 180, 135]  # 바라보는 각(화면 y 아래, 0=오른쪽)
HAND = [(-7, 0), (2, 0), (2, 0), (2, 0), (5, 0), (-3, 0), (-3, 0), (-3, 0)]
SIDE = [-1, 1, 1, 1, 1, -1, -1, -1]
# 단계: 0 대기(칼 내려 듦) · 1 들어 올림 · 2 머리 뒤로 최대 · 3 베기(+궤적) · 4 마무리(아래로)
# 각 = (바라보는 각 기준 상대각, 손 이동 [앞, 위]) — docs/reference/art/hero_art_mock.gif 시안 순서
PHASE = [None, (-110, (-1, 3)), (-135, (-2, 4)), (0, (3, 1)), (50, (2, -1))]
SMEAR = (255, 250, 220)
# 정면(아래 보기)만 따로: 두 손이 배 앞 주먹(hero_v3 정면 공격, 원점 기준 (-1,2))에 모여 있고,
# 칼을 왼어깨 위로 들어 왼쪽 뒤로 젖혔다가, 몸 앞을 왼→오 가로로 크게 벤다(아래로 내리꽂으면 찌르기로 보인다).
# 궤적 = 몸 바로 앞(화면 아래)의 반달. (각, 손) — 단계 1~4
FRONT = [None, (235, (-2, 0)), (195, (-3, 1)), (10, (0, 3)), (335, (1, 2))]


def blade_angle(octant: int, phase: int) -> float:
    f, h = FACE[octant], SIDE[octant]
    if octant == 0 and phase:
        return FRONT[phase][0]
    if phase == 0:
        return 90 - 35 * h  # 손 쪽 아래로 비스듬히
    rel = PHASE[phase][0]
    if octant == 4 and rel < -95:
        rel = -95  # 뒷모습: 머리 뒤로 젖히면 칼이 몸 앞(아래)으로 내려와 버린다 → 옆으로만 젖힘
    return f + rel * h


def hand_at(octant: int, phase: int):
    x, y = HAND[octant]
    if octant == 0 and phase:
        return FRONT[phase][1]
    if phase:
        fwd, up = PHASE[phase][1]
        r = math.radians(FACE[octant])
        x += fwd * math.cos(r)
        y += fwd * math.sin(r) - up
    return x, y


def place(sheet, src, ox, oy, angle, hx, hy):
    """손잡이(위에서 2번째 줄 가운데)를 손 (hx,hy) 에 붙이고 칼날을 angle 쪽으로. 최근접 회전(픽셀 선명)."""
    h, w = len(src), len(src[0])
    px, py = (w - 1) / 2, 1.0
    t = math.radians(angle - 90)  # 원본 칼날은 아래(90도)를 향한다
    ca, sa = math.cos(t), math.sin(t)
    cx, cy = FRAME / 2 + hx, FRAME / 2 + hy
    for y in range(FRAME):
        for x in range(FRAME):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            sx = ca * dx + sa * dy + px + 0.5
            sy = -sa * dx + ca * dy + py + 0.5
            ix, iy = math.floor(sx), math.floor(sy)
            if 0 <= ix < w and 0 <= iy < h and src[iy][ix][3] > 0:
                sheet[oy + y][ox + x] = src[iy][ix]


def smear(sheet, ox, oy, a0, a1, hx, hy, length):
    """베기 궤적: 손을 중심으로 a0→a1 부채꼴 띠, 끝으로 갈수록 진하게."""
    lo, hi = min(a0, a1), max(a0, a1)
    cx, cy = FRAME / 2 + hx, FRAME / 2 + hy
    for y in range(FRAME):
        for x in range(FRAME):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            a = math.degrees(math.atan2(dy, dx))
            a = min((a + k for k in (-360, 0, 360)), key=lambda v: abs(v - (lo + hi) / 2))
            if lo <= a <= hi and length * 0.45 <= r <= length + 0.5 and sheet[oy + y][ox + x][3] == 0:
                t = (a - a0) / (a1 - a0)  # 0=시작 1=칼 있는 곳
                sheet[oy + y][ox + x] = SMEAR + (int(60 + 150 * t * (1.0 if r > length - 1.5 else 0.6)),)


def build_sheet(sprite):
    """세로 원본 하나로 스윙 시트(5단계 x 8방향, 프레임 FRAME). 프레임 가운데 = 플레이어 원점."""
    sheet = [[CLEAR] * (FRAME * PHASES) for _ in range(FRAME * OCTANTS)]
    length = len(sprite) - 1
    for octant in range(OCTANTS):
        for phase in range(PHASES):
            ox, oy = phase * FRAME, octant * FRAME
            hx, hy = hand_at(octant, phase)
            if phase == 3:
                smear(sheet, ox, oy, blade_angle(octant, 2), blade_angle(octant, 3), hx, hy, length)
            place(sheet, sprite, ox, oy, blade_angle(octant, phase), hx, hy)
    return sheet


def check(sheet):
    """떠 있는 칼 금지: 모든 칸에서 손 자리 1.5px 안에 칼 그림이 있다."""
    for octant in range(OCTANTS):
        for phase in range(PHASES):
            hx, hy = hand_at(octant, phase)
            cx, cy = phase * FRAME + FRAME / 2 + hx, octant * FRAME + FRAME / 2 + hy
            near = [sheet[y][x] for y in range(int(cy) - 2, int(cy) + 3) for x in range(int(cx) - 2, int(cx) + 3)
                    if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= 1.6 and sheet[y][x][3] == 255]
            assert near, ("손에서 떨어진 칼", octant, phase)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hand-dir", default=HAND_DIR)
    ap.add_argument("--fx-dir", default=FX_DIR)
    args = ap.parse_args()

    sources = {}
    for name, rows in NEW_SPRITES.items():
        sources[name] = from_map(rows)
    for name, old in REUSED.items():
        src = os.path.join(args.hand_dir, old + ".png")
        if not os.path.exists(src):
            # 원본이 이미 새 이름으로 바뀐 뒤라면(예: sword.png→sword_iron.png) 기존 결과물을 그대로 둔다.
            src = os.path.join(args.hand_dir, name + ".png")
        px = read_png(src)
        box = content_box(px)
        sources[name] = crop(px, box) if box else px

    for name, sprite in sorted(sources.items()):
        # 세로 원본도 남긴다. tests/shot_hand.gd 가 이 파일을 본다.
        write_png(os.path.join(args.hand_dir, name + ".png"), sprite)
        sheet = build_sheet(sprite)
        check(sheet)
        write_png(os.path.join(args.fx_dir, name + "_swing.png"), sheet)
    print("손그림 %d종 + 스윙 시트 %d장 생성" % (len(sources), len(sources)))


if __name__ == "__main__":
    main()
