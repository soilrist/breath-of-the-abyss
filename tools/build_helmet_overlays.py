#!/usr/bin/env python3
"""투구 12종의 머리 오버레이(64x16, 4방향 x 16px)를 만든다.

INBOX O 조각 2 중 몸통(build 없이 파일 복사만 했음)과 달리 투구는
assets/vendor/ninja_adventure/(CC0)가 "투구만 뗀 오버레이" 파일을 안 주고
몸 전체 시트(64x112, 4방향 x 7행)뿐이라 머리 부분만 잘라내야 한다.

기존 helmet_overlay_basic/boss/tower.png 3장의 불투명 영역을 픽셀로
대조해 보면(각 16x16 칸에서) 아래/왼쪽/오른쪽 칸은 y=0..9(위쪽)만
차 있고, 위(뒤통수) 칸만 y=6..15(아래쪽)가 차 있다 — 캐릭터가 뒤를
보면 머리 그림이 칸 아래쪽으로 내려가 그려지는 이 팩 공통 규칙과
일치한다. 새 투구도 같은 창(window)으로 원본 캐릭터 시트의 idle
행(0행)에서 그대로 잘라 덮어씌운다 — 새로 그리지 않고 이미 CC0로
확인된 캐릭터 그림을 재사용한다.

사용:
    python3 tools/build_helmet_overlays.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import CLEAR, crop, read_png, write_png  # noqa: E402

FRAME = 16
COLUMNS = 4
VENDOR_DIR = (
    "assets/vendor/ninja_adventure/source/Ninja Adventure - Asset Pack/"
    "Actor/Character"
)
OUT_DIR = "assets/characters"

# 열 순서(0=아래, 1=위, 2=왼쪽, 3=오른쪽)는 기존 helmet_overlay_*.png와
# player.gd _facing_column()이 이미 쓰던 순서 그대로(코드 변경 없음).
# 위(뒤통수, 열1)만 칸 아래쪽이 차므로 다른 창을 쓴다.
HEAD_WINDOW = {0: (0, 10), 1: (6, 16), 2: (0, 10), 3: (0, 10)}

# 아이템 이름 -> 캐릭터 시트 폴더. 세트가 있는 투구는 같은 세트 갑옷이
# 이미 골라 둔 캐릭터(data/item_body_skins.json)와 맞춰 같은 시트를 쓴다.
ITEMS = {
    "가죽 모자": "Villager",
    "철 투구": "FighterWhite",
    "파수병 투구": "GladiatorBlue",
    "서리왕관": "RobotGrey",
    "수호자의 투구": "SamuraiBlue",
    "흑기사단장의 투구": "Knight",
    "용각 투구": "SkeletonDemon",
    "파수꾼의 투구": "KnightGold",
    "심판자의 투구": "Sultan",
    "종언의 투구": "Master",
    "겁화의 투구": "RedGladiator",
    "천공의 투구": "Tengu",
}


def build_one(character: str, out_name: str) -> None:
    src_path = os.path.join(VENDOR_DIR, character, "SpriteSheet.png")
    sheet = read_png(src_path)
    canvas = [[CLEAR] * (FRAME * COLUMNS) for _ in range(FRAME)]
    for column in range(COLUMNS):
        tile = crop(sheet, (column * FRAME, 0, column * FRAME + FRAME - 1, FRAME - 1))
        y0, y1 = HEAD_WINDOW[column]
        for y in range(FRAME):
            if not (y0 <= y < y1):
                continue
            for x in range(FRAME):
                canvas[y][column * FRAME + x] = tile[y][x]
    write_png(os.path.join(OUT_DIR, out_name), canvas)


def main() -> None:
    for item, character in ITEMS.items():
        out_name = "helmet_shape_%s.png" % _slug(character)
        build_one(character, out_name)
        print(item, "->", out_name)


def _slug(character: str) -> str:
    # CamelCase -> snake_case (예: RedGladiator -> red_gladiator)
    result = []
    for i, ch in enumerate(character):
        if ch.isupper() and i > 0:
            result.append("_")
        result.append(ch.lower())
    return "".join(result)


if __name__ == "__main__":
    main()
