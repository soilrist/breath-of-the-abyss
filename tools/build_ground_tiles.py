#!/usr/bin/env python3
"""바닥 타일 v3 — 감독이 그린 16x16 바닥(사람 요청 2026-10-20 "배경아트 손 좀 봐라").

옛 바닥의 문제: 동굴·탑 27곳이 벽돌 벽(K)·벽돌 바닥(k)을 바닥으로 깔아 격자가 보이고,
눈(n)은 순백, 얼음(i)·물(w)은 단색 네모. 그래서 5줄을 새로 그린다.

    줄 0  k  던전 돌바닥 — 불규칙한 판석(벽돌 아님)
    줄 1  K  동굴·심연 바위 바닥 — 줄눈 없는 거친 바위
    줄 2  n  눈 — 푸른 그늘 결·반짝임
    줄 3  i  얼음 — 대각선 빛줄기·금
    줄 4  w  물 — 물결 반짝임

열 0 = 기본, 열 1~7 = 섞어 쓸 변형(world.gd GROUND_VARIANTS). 모든 칸은 상하좌우로
이어 붙여도 이음매가 없다(잡음 격자·보로노이 거리를 가장자리에서 감싸 계산).

    python3 tools/build_ground_tiles.py           # assets/tiles/TilesetGroundV3.png
    python3 tools/build_ground_tiles.py --check
"""
import random
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tiles" / "TilesetGroundV3.png"
T = 16
COLS = 8

PAL = {
    'k': [(44, 46, 60), (84, 88, 106), (104, 110, 128), (132, 138, 156)],  # 줄눈·어둠·중간·밝음
    'K': [(30, 26, 38), (52, 46, 62), (64, 58, 76), (88, 80, 102)],
    'n': [(166, 182, 212), (204, 216, 236), (232, 240, 250), (255, 255, 255)],
    'i': [(112, 168, 206), (156, 206, 232), (186, 226, 244), (240, 252, 255)],
    'w': [(36, 100, 170), (52, 132, 200), (70, 156, 216), (200, 240, 255)],
}
MOSS = (72, 104, 64)


def tdist(ax, ay, bx, by):
    dx = min(abs(ax - bx), T - abs(ax - bx))
    dy = min(abs(ay - by), T - abs(ay - by))
    return (dx * dx + dy * dy) ** 0.5


def noise(rng):
    """이음매 없는 값 잡음 0~1 (4x4 격자 보간, 가장자리 감쌈)."""
    g = [[rng.random() for _ in range(4)] for _ in range(4)]
    out = [[0.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            fx, fy = x / 4, y / 4
            x0, y0 = int(fx), int(fy)
            tx, ty = fx - x0, fy - y0
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)  # 부드럽게(격자 주름 없애기)
            a = g[y0 % 4][x0 % 4] * (1 - tx) + g[y0 % 4][(x0 + 1) % 4] * tx
            b = g[(y0 + 1) % 4][x0 % 4] * (1 - tx) + g[(y0 + 1) % 4][(x0 + 1) % 4] * tx
            out[y][x] = a * (1 - ty) + b * ty
    # 값 대신 순위(0~1)로 — '아래 30%' 가 언제나 칸 넓이의 30% 가 된다(한 줄로 몰리지 않음)
    order = sorted(v for r in out for v in r)
    return [[order.index(v) / (T * T - 1) for v in r] for r in out]


def flagstone(rng, pal, mortar=True):
    """판석: 토러스 보로노이 칸. 경계 = 줄눈, 칸 왼위 = 밝은 테."""
    pts = [(rng.uniform(0, T), rng.uniform(0, T)) for _ in range(4)]
    shade = [rng.choice((1, 2, 2)) for _ in pts]
    n = noise(rng)
    im = Image.new('RGB', (T, T))
    px = im.load()
    for y in range(T):
        for x in range(T):
            d = sorted((tdist(x, y, *p), i) for i, p in enumerate(pts))
            edge = d[1][0] - d[0][0]
            c = shade[d[0][1]]
            if n[y][x] > 0.7:
                c = min(3, c + 1)
            if mortar and edge < 1.0:
                c = 0
            elif mortar and edge < 2.0:
                # 줄눈 바로 아래·오른쪽은 그늘, 위·왼쪽은 밝게(입체)
                up = sorted((tdist(x, y - 1, *p), i) for i, p in enumerate(pts))
                c = 3 if up[0][1] != d[0][1] else c
            px[x, y] = pal[c]
    return im


def rock(rng, pal):
    """줄눈 없는 거친 바위 — 잡음 + 점 무늬."""
    n = noise(rng)
    im = Image.new('RGB', (T, T))
    px = im.load()
    for y in range(T):
        for x in range(T):
            v = n[y][x]
            px[x, y] = pal[2] if v > 0.62 else pal[1]
    for _ in range(3):
        x, y = rng.randrange(T), rng.randrange(T)
        px[x, y] = pal[3]
        px[(x + 1) % T, (y + 1) % T] = pal[0]
    return im


def snow(rng, pal):
    n = noise(rng)
    im = Image.new('RGB', (T, T))
    px = im.load()
    for y in range(T):
        for x in range(T):
            v = n[y][x]
            px[x, y] = pal[1] if v < 0.3 else pal[2]
    for _ in range(3):  # 반짝임
        px[rng.randrange(T), rng.randrange(T)] = pal[3]
    return im


def ice(rng, pal):
    n = noise(rng)
    im = Image.new('RGB', (T, T))
    px = im.load()
    off = rng.randrange(T)
    for y in range(T):
        for x in range(T):
            px[x, y] = pal[1] if n[y][x] < 0.35 else pal[2]
            if (x + y + off) % T in (0, 1) and n[y][x] > 0.4:  # 대각선 빛줄기
                px[x, y] = pal[3]
    return im


def water(rng, pal):
    n = noise(rng)
    im = Image.new('RGB', (T, T))
    px = im.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = pal[1] if n[y][x] < 0.45 else pal[2]
    for _ in range(2):  # 짧은 물결: 밝은 2~3px + 아래 어두운 1px
        x, y, L = rng.randrange(T), rng.randrange(T), rng.choice((2, 3))
        for i in range(L):
            px[(x + i) % T, y] = pal[3] if i else pal[2]
            px[(x + i) % T, (y + 1) % T] = pal[0]
    return im


def detail(im, kind, v, rng, pal):
    """변형 칸에만 얹는 작은 디테일."""
    px = im.load()
    if kind == 'k' and v in (2, 5):  # 금
        x, y = rng.randrange(3, 12), rng.randrange(3, 12)
        for i in range(4):
            px[x + i, y + (i % 2)] = pal[0]
    if kind == 'k' and v in (3, 6):  # 이끼
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 1), (1, 1)):
            px[x + dx, y + dy] = MOSS
    if kind in ('k', 'K') and v in (4, 7):  # 자갈
        for _ in range(2):
            x, y = rng.randrange(2, 14), rng.randrange(2, 14)
            px[x, y], px[x + 1, y], px[x, y + 1] = pal[3], pal[2], pal[0]
    if kind == 'n' and v in (2, 5):  # 눈 둔덕(그늘 반원)
        x, y = rng.randrange(3, 10), rng.randrange(4, 12)
        for i in range(5):
            px[x + i, y] = pal[0 if i in (0, 4) else 1]
        for i in range(1, 4):
            px[x + i, y - 1] = pal[3]
    if kind == 'i' and v in (2, 4, 6):  # 얼음 금
        x, y = rng.randrange(2, 10), rng.randrange(2, 10)
        for i in range(5):
            px[x + i, y + i // 2] = pal[0]
    if kind == 'w' and v in (3, 6):  # 둥근 물결
        x, y = rng.randrange(4, 11), rng.randrange(4, 11)
        for dx, dy in ((-2, 0), (2, 0), (-1, -1), (0, -1), (1, -1), (-1, 1), (0, 1), (1, 1)):
            px[x + dx, y + dy] = pal[3]
    return im


DRAW = {'k': flagstone, 'K': rock, 'n': snow, 'i': ice, 'w': water}
ROWS = ['k', 'K', 'n', 'i', 'w']


def build():
    sheet = Image.new('RGBA', (COLS * T, len(ROWS) * T))
    for r, kind in enumerate(ROWS):
        for v in range(COLS):
            rng = random.Random(f'{kind}{v}')
            im = DRAW[kind](random.Random(f'{kind}base'), PAL[kind]) if v == 0 else None
            if v:
                # 변형은 기본 칸 위에 디테일만 얹거나(짝수) 결을 새로 뽑는다(홀수) — 색 계열은 같다
                im = DRAW[kind](rng if v % 2 else random.Random(f'{kind}base'), PAL[kind])
                im = detail(im, kind, v, rng, PAL[kind])
            sheet.paste(im, (v * T, r * T))
    return sheet


def check():
    s = build()
    assert s.size == (COLS * T, len(ROWS) * T)
    for r, kind in enumerate(ROWS):
        allowed = set(PAL[kind]) | {MOSS}
        for v in range(COLS):
            t = s.crop((v * T, r * T, v * T + T, r * T + T)).convert('RGB')
            colors = {c for _, c in t.getcolors(256)}
            assert colors <= allowed, (kind, v, colors - allowed)  # 색 계열 밖 색 없음
            assert len(colors) >= 2, (kind, v)  # 단색 네모 금지
    print(f'ground tiles check OK — {len(ROWS)}종 x {COLS}변형')


if __name__ == '__main__':
    check()
    if '--check' not in sys.argv:
        build().save(OUT)
        print('wrote', OUT.relative_to(ROOT))
