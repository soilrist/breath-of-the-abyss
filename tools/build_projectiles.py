#!/usr/bin/env python3
"""스킬 투사체 그림 — 표창(회전 4칸)·독침.

표창 던지기·독침이 평타 화살 그림(assets/items/arrow.png)으로 날아가서
사람이 "표창이 아니라 화살이 날아간다"고 했다(2026-10-20 21:25).

    assets/items/proj_shuriken.png  12x12 프레임 4칸 가로(48x12). 0→3 순서로
        돌리면 시계 방향 회전(날 4개라 90도마다 같은 모양 → 22.5도씩 4칸).
        진행 방향과 무관하게 sprite.rotation 0 으로 두고 프레임만 돌린다.
    assets/items/proj_dart.png      12x5 한 장, 오른쪽을 향함 →
        sprite.rotation = direction.angle()

    python3 tools/build_projectiles.py          # 그리기 + 점검
    python3 tools/build_projectiles.py --check  # 점검만
"""
import math
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "items"
S = 12
K = (20, 27, 27, 255)       # 외곽선(손 무기와 같은 색)
L = (242, 234, 241, 255)    # 날 밝은 면
M = (171, 194, 188, 255)    # 날 중간
D = (90, 100, 96, 255)      # 날 그늘·가운데 구멍 테
CLEAR = (0, 0, 0, 0)


def inside(px, py, poly):
    hit = False
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[i - 1]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def shuriken(deg):
    """날 4개 바람개비 별. 날 한쪽은 밝게, 반대쪽은 그늘 → 돌 때 번쩍임이 돈다."""
    im = Image.new('RGBA', (S, S), CLEAR)
    px = im.load()
    c = (S - 1) / 2
    # 한 날(위쪽): 끝이 살짝 시계 방향으로 휜 연 모양 — 비대칭이라 회전이 읽힌다
    blade = [(0.3, -6.0), (2.6, -0.6), (0.0, 0.0), (-1.5, -1.8)]
    for y in range(S):
        for x in range(S):
            for k in range(4):
                a = math.radians(deg + 90 * k)
                # 화면 좌표를 날 좌표로 되돌림
                dx, dy = x - c, y - c
                bx = dx * math.cos(-a) - dy * math.sin(-a)
                by = dx * math.sin(-a) + dy * math.cos(-a)
                if inside(bx, by, blade):
                    px[x, y] = L if bx < 0.35 else M
            if math.hypot(x - c, y - c) < 1.1:
                px[x, y] = D
    # 외곽선: 투명 칸 중 상하좌우에 그림이 있으면 K
    src = im.copy().load()
    for y in range(S):
        for x in range(S):
            if src[x, y][3]:
                continue
            if any(0 <= x + ox < S and 0 <= y + oy < S and src[x + ox, y + oy][3]
                   for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = K
    return im


DART = [  # 오른쪽을 향한 독침: 깃(초록 어둠)·대(쇠)·끝(독 초록)
    "KK..........",
    "GgKKKKKKK...",
    "GGgMMMMLPPpK",
    "GgKKKKKKK...",
    "KK..........",
]
DART_PAL = {'K': K, 'M': M, 'L': L, 'G': (60, 150, 70, 255), 'g': (34, 90, 46, 255),
            'P': (150, 240, 110, 255), 'p': (90, 200, 80, 255), '.': CLEAR}


def build():
    sheet = Image.new('RGBA', (S * 4, S), CLEAR)
    for f in range(4):
        sheet.paste(shuriken(22.5 * f), (f * S, 0))
    dart = Image.new('RGBA', (12, 5), CLEAR)
    for y, row in enumerate(DART):
        for x, ch in enumerate(row):
            dart.putpixel((x, y), DART_PAL[ch])
    return sheet, dart


def check():
    sheet, dart = build()
    frames = [sheet.crop((f * S, 0, f * S + S, S)) for f in range(4)]
    for f, fr in enumerate(frames):
        n = sum(1 for p in fr.get_flattened_data() if p[3])
        assert 40 <= n <= 110, (f, n)  # 1배에서 점이 아니라 별로 보일 크기
        assert fr.getbbox()[0] >= 0 and fr.getpixel((0, 0))[3] == 0, f  # 모서리 비어 잘림 없음
    assert len({fr.tobytes() for fr in frames}) == 4  # 4칸 전부 달라야 도는 게 보인다
    print('projectiles check OK — 표창 4칸·독침 1장')


if __name__ == '__main__':
    check()
    if '--check' not in sys.argv:
        sheet, dart = build()
        sheet.save(OUT / 'proj_shuriken.png')
        dart.save(OUT / 'proj_dart.png')
        print('wrote assets/items/proj_shuriken.png, proj_dart.png')
