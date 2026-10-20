#!/usr/bin/env python3
"""재료(강화석·보스의 파편·부적·전직의 돌·탑 결정·마법돌·정수) 아이콘 25종을
Ninja Adventure 팩(CC0, assets/vendor/ninja_adventure/source)에서 만들어
assets/items/mat_*.png 에 넣는다. 인벤토리 [재료] 탭 전용(감독 2026-09-10).

원본 그림은 4개(바위·보석·두루마리)뿐이라 build_item_icons.py 와 같은
방식으로 밝기만 남기고 재료마다 다른 색 램프로 전면 재색칠해 구분한다.

사용:
    python3 tools/build_material_icons.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_item_icons import Palette, fit_icon, recolor  # noqa: E402
from pixel import read_png, write_png  # noqa: E402

SRC = "assets/vendor/ninja_adventure/source/Ninja Adventure - Asset Pack/Items"
OUT = "assets/items"
ROCK, SCROLL = "Resource/Rock.png", "Scroll/Scroll.png"
RED, GREEN, PURPLE, YELLOW = ("Resource/GemRed.png", "Resource/GemGreen.png",
                              "Resource/GemPurple.png", "Resource/GemYellow.png")

# 이름 -> (원본, 램프: 외곽선/그림자/기본/하이라이트)
ICONS = {
    "mat_enhance": (ROCK, ("#23232e", "#4f5060", "#8a8c9e", "#d2d4e2")),
    "mat_fragment": (PURPLE, ("#130820", "#3a1660", "#6d2fa8", "#c58cf0")),
    "mat_ward": (SCROLL, ("#4a2e08", "#9a6a22", "#dcb862", "#fff2c4")),
    "mat_job_warrior": (ROCK, ("#3a0c0c", "#8a2020", "#d24040", "#ff9c8c")),
    "mat_job_mage": (ROCK, ("#0c1a3a", "#20408a", "#4070d2", "#9cc4ff")),
    "mat_job_rogue": (ROCK, ("#0c3a14", "#208a30", "#40c050", "#a0ffa8")),
    "mat_tower_easy": (GREEN, ("#0a2e14", "#1f7a34", "#3fc45a", "#b6ffc2")),
    "mat_tower_normal": (YELLOW, ("#3a2a04", "#9a7412", "#e8b820", "#fff0a0")),
    "mat_tower_hard": (PURPLE, ("#14101c", "#3c3050", "#6c5a88", "#c0b0d8")),
    "mat_tower_hell": (RED, ("#3a0a02", "#a02a08", "#f06020", "#ffd080")),
    "mat_tower_abyss": (GREEN, ("#082a3a", "#1a6c90", "#38b8e8", "#c0f4ff")),
    "mat_stone_ruby": (RED, ("#3a0810", "#9a1830", "#e83050", "#ff9cb0")),
    "mat_stone_jade": (GREEN, ("#0a2e1c", "#1f7a4c", "#3fc484", "#b6ffd8")),
    "mat_stone_amethyst": (PURPLE, ("#22083a", "#5a1c9a", "#9a44e8", "#dcaeff")),
    "mat_stone_topaz": (YELLOW, ("#3a3004", "#9a8412", "#e8d020", "#fffaa0")),
    "mat_stone_flame": (RED, ("#3a1402", "#a04008", "#f08020", "#ffe090")),
    "mat_stone_frost": (GREEN, ("#08303a", "#1a8090", "#48d0e0", "#d0ffff")),
    "mat_stone_dragoneye": (YELLOW, ("#2a0808", "#8a2810", "#e07020", "#ffd060")),
    # 5~10장 정수(세트 제작 재료). 그 장 세트 팔레트와 같은 색조.
    "mat_essence_primordial": (PURPLE, ("#1e0f3a", "#4c2a86", "#8a5cd6", "#d9c2ff")),
    "mat_essence_reef": (GREEN, ("#0a2e30", "#166e6c", "#2fb8b0", "#c2fff6")),
    "mat_essence_prelate": (YELLOW, ("#3a2a04", "#9a7414", "#e6b830", "#fff4b8")),
    "mat_essence_warden": (ROCK, ("#1c1c22", "#4a4a56", "#8c8c9c", "#e0e0ea")),
    "mat_essence_reversal": (PURPLE, ("#160a26", "#3c1a5e", "#6a34a6", "#c69cf0")),
    "mat_essence_origin": (RED, ("#3a0a2e", "#8c1c72", "#e040b8", "#ffd0f4")),
}


def main() -> None:
    for name, (source, ramp) in ICONS.items():
        px = read_png(os.path.join(SRC, source))
        px = recolor(px, Palette(*ramp))
        write_png(os.path.join(OUT, name + ".png"), fit_icon(px))
        print("wrote", name)


if __name__ == "__main__":
    main()
