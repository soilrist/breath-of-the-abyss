#!/usr/bin/env python3
"""주인공 v3 시트 생성 — 감독이 손으로 찍은 16x16 도트(사람 승인 2026-10-20).

hero.png 와 같은 틀(64x112): 4열 = 아래·위·왼쪽·오른쪽, 7행 = 대기 / 걷기 4 / 공격 / 기타.
그래서 게임 코드는 그대로 두고 파일만 바꿔 끼울 수 있다. 칼은 시트에 없다 —
게임이 손 무기(hand_fx)를 따로 겹쳐 그린다.

갑옷은 색만 바꾸지 않는다(사람 2026-10-20 "색만 바꾸지말고"): 모양 갈래(FAMILY)
11가지 — 천옷·가죽·사슬·흉갑+휘장·판금·망토·용비늘·성광(날개)·심연(뿔·룬)·겁화·심해 —
마다 몸통·어깨·치마 모양이 다르고, 그 위에 갑옷별 색(ARMOR)을 입힌다.
얼굴·머리는 모든 시트가 같다 → 갑옷을 입어도 같은 사람. 시트 색이 이미 칠해져 있으니
게임에서 modulate 는 흰색이어야 얼굴이 물들지 않는다.

    python3 tools/build_hero_sheet.py            # assets/characters/hero_v3*.png
    python3 tools/build_hero_sheet.py --check    # 시트 규격 자가 점검만
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "characters"

PAL = {
    'o': (38, 22, 36), 'O': (70, 30, 30),  # 외곽선(몸·머리)
    '1': (110, 40, 32), '2': (170, 70, 42), '3': (222, 118, 56), '4': (255, 190, 104),  # 머리
    'k': (186, 104, 88), 's': (240, 168, 126), 'S': (255, 216, 178), 'e': (28, 22, 52),  # 피부·눈
    'x': (16, 70, 84), 'y': (34, 150, 148), 'z': (130, 230, 206),  # 목도리
    'n': (32, 32, 78), 'N': (58, 80, 156), 'V': (110, 148, 226),  # 갑옷 어둠·중간·밝음
    'a': (150, 100, 40), 'A': (250, 206, 84),  # 장식(금테·룬·끈)
    'c': (60, 30, 40), 'C': (110, 50, 60),  # 망토·휘장 천
    'w': (190, 200, 220), 'W': (250, 250, 255),  # 털·깃털
    'L': (120, 74, 44), 'G': (250, 206, 84),  # 허리띠
    'p': (48, 40, 66), 'P': (84, 74, 108), 'b': (92, 52, 34), 'B': (140, 86, 50),  # 바지·신발
}

HAIR = [
    "......O..O......",
    "....OO4OO4OO....",
    "...O34434443O...",
    "..O2344444432O..",
    ".O12334443321O..",
    ".O12323332321O..",
]
HEAD_F = HAIR + [
    ".O12kSs2sSk21O..",
    ".O1ksesssesk1O..",
    "..OkseSsSeskO...",
    "...oksSSSsko....",
]
HEAD_B = HAIR + [
    ".O12233333221O..",
    ".O11223332211O..",
    "..O112222211O...",
    "...oO11111Oo....",
]
HEAD_S = [  # 오른쪽 보기. 왼쪽은 좌우 반전
    ".....O.O........",
    "....O4O4OO......",
    "...O3444443O....",
    "..O234444443O...",
    ".O1233444433O...",
    ".O12233333s2O...",
    ".O1122k2SsSO....",
    "..O112kssesO....",
    "..O11kksSsSo....",
    "...OOoksssko....",
]

# 모양 갈래. F/B/S = 몸통 10~13줄(정면·뒷면·옆) — 통째로 바꾼다.
# Fx/Bx/Sx = {줄: 덧그림} — '.' 은 밑그림 유지(어깨 뿔·날개·치마·망토 자락).
# B 가 없으면 F 에서 가슴 장식을 지운 것.
FAMILY = {
    'cloth': {
        'F': ["..oxyzzzzzyxo...", ".onNxyyyyyxNno..", ".osnNVyyyVNnso..", "..onLLLGLLLno..."],
        'B': ["..oxyyzzzyyxo...", ".onNNNNNNNNNno..", ".osnNNNNNNNnso..", "..onLLLLLLLno..."],
        'S': ["..zyoxyzzyo.....", "...onNNVNno.....", "...onNsVNno.....", "...oLLGLLo......"],
    },
    'leather': {  # 앞섶 X자 끈 조끼
        'F': ["..onNxzzzxNno...", ".onVNNAnANNVno..", ".osNVNnAnNVNso..", "..oLLLGLLLLLo..."],
        'S': ["...onxzzxo......", "...onNVANno.....", "...onNsANno.....", "...oLLGLLo......"],
    },
    'chain': {  # 사슬 목가리개 + 긴 사슬 치마
        'F': ["..oVNVNVNVNVo...", ".onNVNVNVNVNno..", ".osVNVNVNVNVso..", "..onLLLGLLLno..."],
        'Fx': {14: "..onVNVNVNVNo..."},
        'S': ["...oVNVNVo......", "...oNVNVNVo.....", "...oVNsNVNo.....", "...oLLGLLo......"],
        'Sx': {14: "...oVNVNVo......"},
    },
    'guard': {  # 둥근 어깨받이 + 흉갑 + 앞 휘장(c/A)
        'F': [".oVVoxzzzxoVVo..", ".oNNnVcAcVnNNo..", ".osnNVcAcVNnso..", "..onLLcAcLLno..."],
        'Fx': {14: ".....ocAco......"},
        'B': [".oVVoxyyyxoVVo..", ".oNNnNNNNNnNNo..", ".osnNNNNNNNnso..", "..onLLLLLLLno..."],
        'S': ["...oVVxzzo......", "...oNNcAcno.....", "...onNsAcno.....", "...oLLcALo......"],
        'Sx': {14: "......ocAo......"},
    },
    'plate': {  # 큰 어깨받이 + 가슴 보석 + 판금 치마
        'F': ["oVVVoNVVVNoVVVo.", "oNNNoNVAVNoNNNo.", ".oosnNVNVNnsoo..", "..onLLLGLLLno..."],
        'Fx': {9: ".oo.........oo..", 14: "..onVVNnNVVno..."},
        'B': ["oVVVoNNNNNoVVVo.", "oNNNoNNNNNoNNNo.", ".oosnNNNNNnsoo..", "..onLLLLLLLno..."],
        'S': ["..oVVVVVoNo.....", "..oNNANNoNVo....", "...onNsVNNo.....", "...oLLGLLo......"],
        'Sx': {14: "...oNVVNo......."},
    },
    'cape': {  # 털 깃(W/w) + 양옆으로 늘어진 망토(c/C)
        'F': [".oWwWwWwWwWwWo..", ".ocCnNVVVNnCco..", ".ocCsNVVVNsCco..", ".ocCnLLGLLnCco.."],
        'Fx': {14: ".ocC.......Cco..", 15: ".oo.........oo.."},
        'B': [".oWwWwWwWwWwWo..", ".ocCCCCCCCCCco..", ".ocCCCcCCCCCco..", ".ocCCCcCCCCCco.."],
        'Bx': {14: "..occccccccco..."},
        'S': [".oWwWWWWo.......", ".ocCnNVNno......", ".ocCnNsNno......", ".ocCLLGLLo......"],
        'Sx': {14: ".ocC............", 15: ".oo............."},
    },
    'dragon': {  # 비늘 무늬(엇갈림) + 어깨 가시
        'F': [".oVNVoxzzxoVNVo.", ".onVnVnVnVnVno..", ".osnVnVnVnVnso..", "..onLLLGLLLno..."],
        'Fx': {8: ".A...........A..", 9: ".oA.........Ao.."},
        'S': ["..oVNVoxzzo.....", "...onVnVnVo.....", "...oVnsnVno.....", "...oLLGLLo......"],
        'Sx': {9: "..A............."},
    },
    'holy': {  # 날개 어깨받이(W) + 금테(A) + 긴 겉옷 자락
        'F': ["oWWAoAVVVAoAWWo.", ".oonNVVAVVNnoo..", ".osnNVVAVVNnso..", "..oAAAAGAAAAo..."],
        'Fx': {8: "oW...........Wo.", 9: "oWW.........WWo.", 14: "..onVVVAVVVno..."},
        'S': ["oWWoAVAzzo......", ".oWonNVANno.....", "..oonNsANno.....", "...oAAGAAo......"],
        'Sx': {9: "oWW.............", 14: "...onVAVno......"},
    },
    'abyss': {  # 굽은 뿔 어깨 + 빛나는 룬(A) + 찢어진 자락
        'F': ["oNnNoxAAAxoNnNo.", ".onNnAnnnAnNno..", ".osnNnAAAnNnso..", "..onLLLALLLno..."],
        'Fx': {8: "oN...........No.", 9: ".oN.........No..", 14: "..on.N.n.N.no..."},
        'S': ["..oNoxAAo.......", "...onnAnno......", "...onNsAno......", "...oLLALLo......"],
        'Sx': {8: ".N..............", 9: ".oN.............", 14: "...o.N.no......."},
    },
    'flame': {  # 어깨에서 솟는 불꽃(a/A) + 용암 띠
        'F': [".oaNoxzzzxoNao..", ".onNVnaAanVNno..", ".osnNVnanVNnso..", "..onLLLALLLno..."],
        'Fx': {8: ".A...........A..", 9: ".aA.........Aa.."},
        'S': ["..oaNoxzzo......", "...onNaAno......", "...onVsano......", "...oLLALLo......"],
        'Sx': {9: "..A............."},
    },
    'sea': {  # 지느러미 어깨(A) + 조개 능선
        'F': ["oAAVoxzzzxoVAAo.", ".onVNNVNVNNVno..", ".osnVNNVNNVnso..", "..onLLLALLLno..."],
        'Fx': {9: ".AA.........AA.."},
        'S': ["..oAVoxzzo......", "...onVNVno......", "...onNsVno......", "...oLLALLo......"],
        'Sx': {9: "..A............."},
    },
}


def C(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def armor(fam, n, N, V, A=None, a=None, c=None, Cc=None, scarf=None):
    pal = {'n': C(n), 'N': C(N), 'V': C(V)}
    if A: pal['A'] = C(A)
    if a: pal['a'] = C(a)
    if c: pal['c'] = C(c)
    if Cc: pal['C'] = C(Cc)
    if scarf: pal.update(zip('xyz', map(C, scarf)))
    return fam, pal


# 갑옷 24벌 → 파일 접미사. 같은 갈래라도 색·장식색이 달라 한눈에 구별된다.
ARMOR = {
    '': ('cloth', {}),  # 여행자 옷
    '_leather': armor('leather', '#46281c', '#80502c', '#b87e46', A='#e8cc90'),  # 가죽 갑옷
    '_chain': armor('chain', '#3c4250', '#7c8698', '#c4ccd8'),  # 사슬 갑옷
    '_guard': armor('guard', '#4e5670', '#96a2ba', '#e0e8f4', A='#fad254', c='#1c3c8c', Cc='#3060c0'),  # 파수병 흉갑
    '_blackknight': armor('plate', '#1c1820', '#3c3644', '#6c6478', A='#e02838'),  # 흑기사 갑주
    '_snowcloak': armor('cape', '#284870', '#4c80b8', '#a0d0f0', c='#2c5490', Cc='#5a90d0'),  # 설원의 망토
    '_frost': armor('plate', '#3c6890', '#80b8e0', '#e4f8ff', A='#60e8ff'),  # 서리군주의 갑주
    '_dragonscale': armor('dragon', '#1c4a24', '#38803c', '#7cc860', A='#e8f0a0'),  # 용의 비늘
    '_dragon': armor('dragon', '#601818', '#b03024', '#f07040', A='#fad254'),  # 용린 갑주
    '_abyss': armor('abyss', '#2c1446', '#622c96', '#aa6eec', A='#5af0e0'),  # 심연의 갑주
    '_tower_guard': armor('holy', '#3a4c78', '#7890c8', '#d0dcf8', A='#c8d4e8'),  # 파수꾼의 갑주
    '_judge': armor('holy', '#7c6a4c', '#d8ccb0', '#fffaf0', A='#f0b830'),  # 심판자의 갑주
    '_end': armor('abyss', '#141014', '#38282c', '#604850', A='#ff3030', scarf=('#400810', '#a01818', '#ff4040')),  # 종언의 갑주
    '_hellfire': armor('flame', '#581008', '#b02810', '#f06020', A='#ffe060', a='#ff8820', scarf=('#401008', '#c04010', '#ffb040')),  # 겁화의 갑주
    '_sky': armor('holy', '#3070b0', '#68b0e8', '#e0f4ff', A='#fff0a0'),  # 천공의 갑주
    '_primal': armor('dragon', '#5a3a10', '#a87420', '#f0c050', A='#fff4c0'),  # 태초의 갑주
    '_deepsea': armor('sea', '#0c2c48', '#1c6080', '#40b0c0', A='#70f0d0', scarf=('#0c2c48', '#2080a0', '#90f0f0')),  # 심해의 갑주
    '_holy': armor('holy', '#906010', '#e0b030', '#fff4b0', A='#ffffff'),  # 성광의 갑주
    '_silence': armor('plate', '#24242c', '#50505c', '#8c8c9c', A='#b070ff'),  # 침묵의 갑주
    '_reversal': armor('abyss', '#0c3438', '#1c7070', '#40c0b0', A='#ff60d0', scarf=('#400c40', '#a02090', '#ff80e0')),  # 역행의 갑주
    '_origin': armor('abyss', '#202028', '#e8e8f0', '#ffffff', A='#40d0ff', scarf=('#101018', '#303040', '#f0f0ff')),  # 근원의 갑주
    '_coral': armor('guard', '#80304a', '#e06070', '#ffb0a8', A='#ffe0c0', c='#1c6070', Cc='#30a0a8'),  # 산호 흉갑
    '_plate': armor('plate', '#4e5670', '#96a2ba', '#e0e8f4', A='#40a0ff'),  # 감독관의 철갑
    '_ancient': armor('sea', '#3c2c18', '#6c5430', '#a88c58', A='#90e070', scarf=('#2c3c18', '#5c7c30', '#a0d060')),  # 원초의 갑주
}
# 게임 아이템 이름 → 시트(작업자가 data/item_body_skins.json 에 옮긴다)
ITEM_SHEET = {
    '가죽 갑옷': '_leather', '사슬 갑옷': '_chain', '파수병 흉갑': '_guard', '흑기사 갑주': '_blackknight',
    '설원의 망토': '_snowcloak', '서리군주의 갑주': '_frost', '용의 비늘': '_dragonscale', '용린 갑주': '_dragon',
    '심연의 갑주': '_abyss', '파수꾼의 갑주': '_tower_guard', '심판자의 갑주': '_judge', '종언의 갑주': '_end',
    '겁화의 갑주': '_hellfire', '천공의 갑주': '_sky', '태초의 갑주': '_primal', '심해의 갑주': '_deepsea',
    '성광의 갑주': '_holy', '침묵의 갑주': '_silence', '역행의 갑주': '_reversal', '근원의 갑주': '_origin',
    '산호 흉갑': '_coral', '감독관의 철갑': '_plate', '원초의 갑주': '_ancient',
}

LEGS_F = {
    'idle': ["...opPo.oPpo....", "...obBo.oBbo...."],
    'w1': ["...obBo.oPpo....", "...ooo..oBbo...."],
    'w2': ["...opPo.obBo....", "...obBo..ooo...."],
}
LEGS_S = {
    'idle': ["....opPPo.......", "....obBBo......."],
    'w1': ["...opo.oPo......", "..obbo.oBBo....."],
    'w2': ["....oPpo........", "....oBbBo......."],
    'lunge': ["...opo..oPo.....", "..obbo..oBBo...."],
}


def put(rows, y, s):
    """덧그림: '.' 자리는 밑그림을 남긴다."""
    rows[y] = ''.join(b if a == '.' else a for a, b in zip(s, rows[y]))


def back_of(front):
    """뒷면 = 정면에서 가슴 한가운데 장식(A·V·c)을 갑옷 중간색으로."""
    out = list(front)
    for y in (1, 2):
        out[y] = ''.join('N' if 4 <= x <= 10 and ch in 'AVcyz' else ch for x, ch in enumerate(out[y]))
    out[0] = out[0].replace('z', 'y')
    return out


def pose(fam, view, legs, attack=False):
    f = FAMILY[fam]
    if view == 'F':
        rows, body, extra = list(HEAD_F), f['F'], f.get('Fx', {})
    elif view == 'B':
        rows, body = list(HEAD_B), f.get('B') or back_of(f['F'])
        extra = f.get('Bx', {k: v for k, v in f.get('Fx', {}).items()})
    else:
        rows, body, extra = list(HEAD_S), f['S'], f.get('Sx', {})
    rows += list(body) + list(legs)
    for y, s in extra.items():
        put(rows, y, s)
    if attack and view == 'F':  # 두 팔을 배 앞으로 모아 칼자루를 쥔다(손 무기가 이 주먹에 붙는다)
        rows[12] = ''.join('n' if ch == 's' else ch for ch in rows[12])
        rows[12] = rows[12][:4] + 'NoSso' + rows[12][9:]
        rows[13] = rows[13][:5] + 'osso' + rows[13][9:]
    if attack and view == 'S':  # 팔을 앞으로 뻗는다(손 무기가 이 손끝에 붙는다)
        rows[12] = rows[12].replace('s', 'N')
        rows[11] = rows[11][:9] + 'Nsso' + rows[11][13:]
    return rows


def sprite(rows, pal, dy=0):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in pal and 0 <= y + dy < 16:
                px[x, y + dy] = pal[c] + (255,)
    return im


def column(direction, fam, pal):
    """한 방향의 7행(대기·걷기4·공격·기타)."""
    view = {'down': 'F', 'up': 'B'}.get(direction, 'S')
    legs = LEGS_S if view == 'S' else LEGS_F
    atk_legs = 'lunge' if view == 'S' else 'idle'
    walk = ['w1', 'idle', 'w2', 'idle']
    frames = [sprite(pose(fam, view, legs['idle']), pal)]
    # 걷기 2·4번째(두 발 모임)는 1px 위로 — 걸을 때 머리가 통통 튄다
    frames += [sprite(pose(fam, view, legs[k]), pal, -1 if i % 2 else 0) for i, k in enumerate(walk)]
    frames.append(sprite(pose(fam, view, legs[atk_legs], attack=view != 'B'), pal, 1 if view == 'F' else 0))
    frames.append(sprite(pose(fam, 'S', LEGS_S['idle']), pal).rotate(90, expand=False))  # 기타: 쓰러진 자세
    if direction == 'left':
        frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames[:6]] + frames[6:]
    return frames


def build(suffix):
    fam, over = ARMOR[suffix]
    pal = dict(PAL)
    pal.update(over)
    sheet = Image.new('RGBA', (64, 112), (0, 0, 0, 0))
    for col, d in enumerate(['down', 'up', 'left', 'right']):
        for row, f in enumerate(column(d, fam, pal)):
            sheet.alpha_composite(f, (col * 16, row * 16))
    return sheet


def check():
    for fam, f in FAMILY.items():
        for k in ('F', 'B', 'S'):
            if k in f:
                assert len(f[k]) == 4 and all(len(r) == 16 for r in f[k]), (fam, k)
        for k in ('Fx', 'Bx', 'Sx'):
            assert all(len(r) == 16 for r in f.get(k, {}).values()), (fam, k)
    for legs in (LEGS_F, LEGS_S):
        assert all(len(r) == 16 for v in legs.values() for r in v)
    assert set(ITEM_SHEET.values()) | {''} == set(ARMOR), '시트와 아이템 대응표가 어긋남'
    base = build('')
    for suffix in ARMOR:
        s = build(suffix)
        assert s.size == (64, 112)
        for col in range(4):  # 모든 칸에 그림이 있어야 한다
            for row in range(7):
                assert s.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16)).getbbox(), (suffix, col, row)
        # 얼굴은 갑옷과 무관하게 같아야 한다(같은 사람) — 어깨 뿔·날개가 닿는 양 끝 2칸은 뺀다
        assert s.crop((2, 0, 13, 8)).tobytes() == base.crop((2, 0, 13, 8)).tobytes(), suffix
    # 모양이 정말 달라야 한다: 갈래 대표끼리 알파(실루엣)가 달라야 한다
    reps = {}
    for suffix, (fam, _) in ARMOR.items():
        reps.setdefault(fam, suffix)
    shapes = {build(s).crop((0, 0, 16, 16)).getchannel('A').tobytes() for s in reps.values()}
    assert len(shapes) >= len(reps) - 3, f'실루엣 {len(shapes)}종 / 갈래 {len(reps)}'
    print(f'hero sheet check OK — 갑옷 {len(ARMOR)}벌, 모양 갈래 {len(FAMILY)}, 실루엣 {len(shapes)}종')


if __name__ == '__main__':
    check()
    if '--check' not in sys.argv:
        for suffix in ARMOR:
            p = OUT / f"hero_v3{suffix}.png"
            build(suffix).save(p)
            print('wrote', p.relative_to(ROOT))
