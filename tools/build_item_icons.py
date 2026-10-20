#!/usr/bin/env python3
"""장비 아이콘 61종을 CC0 에셋팩에서 만들어 assets/items/ 에 넣는다.

원본은 Dungeon Crawl Stone Soup 타일셋(CC0, 32x32 개별 파일) 하나만 쓴다.
한 팩으로 통일하면 화풍과 크기가 아이템끼리 어긋나지 않는다. 61종 전부
서로 다른 원본 그림을 쓴다.

처리 과정
  1. 팩을 assets/vendor/ 에 내려받아 캐시한다(대용량이라 Git에서는 제외).
  2. DCSS 그림에 구워진 검은 그림자를 벗긴다.
  3. 내용만 잘라내고, 24x24를 넘치면 박스 필터로 축소해 중앙에 놓는다.
  4. 세트 팔레트로 전면 재색칠한다. 원본 색조는 버리고 밝기만 남겨 램프에
     매핑하므로, 같은 세트 아이템이 한 벌로 보인다.
     천공 세트는 세로로 색조가 흐르는 무지갯빛을 쓴다.

사용:
    python3 tools/build_item_icons.py                # assets/items/ 에 생성
    python3 tools/build_item_icons.py --preview out  # 확대 미리보기도 저장
"""

import argparse
import colorsys
import json
import os
import sys
import urllib.request
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import (CLEAR, box_down, center_on, content_box, crop, read_png,  # noqa: E402
                   scale, write_png)

ICON = 24
VENDOR = "assets/vendor"
OUT = "assets/items"
# 세트/등급 팔레트의 유일한 출처. player.gd 도 같은 파일을 읽어 착용 시
# 부위별 캐릭터 색을 여기 색과 어긋나지 않게 맞춘다(PROMPT.md ③).
ITEM_PALETTES_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "data", "item_palettes.json")

PACK_URL = ("https://opengameart.org/sites/default/files/"
            "Dungeon%20Crawl%20Stone%20Soup%20Full.zip")
PACK_NAME = "dcss"
DCSS_ROOT = "Dungeon Crawl Stone Soup Full/"


# --- 팔레트 ------------------------------------------------------------------


def hex_rgb(code: str):
    code = code.lstrip("#")
    return (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16))


class Palette:
    """어두운 외곽선 → 그림자 → 기본 → 하이라이트로 이어지는 4단 램프."""

    def __init__(self, dark, shadow, base, light, rainbow=False):
        self.stops = [hex_rgb(dark), hex_rgb(shadow), hex_rgb(base), hex_rgb(light)]
        self.rainbow = rainbow

    def ramp(self, t: float, y_ratio: float = 0.0):
        """밝기 t(0~1)를 램프 색으로 바꾼다."""
        if self.rainbow:
            # 무지갯빛 금속. 위에서 아래로 색조가 한 바퀴 돌고, 밝은 부분이
            # 흰색으로 날아가지 않게 명도 상한을 둔다. 채도를 일정하게
            # 유지해야 24픽셀에서도 무지개로 읽힌다.
            hue = (y_ratio * 0.95 + 0.02) % 1.0
            sat = 0.52 + 0.16 * max(0.0, 1.0 - abs(t - 0.5) * 2.0)
            val = 0.34 + 0.58 * t
            r, g, b = colorsys.hsv_to_rgb(hue, min(1.0, sat), min(1.0, val))
            return (int(r * 255), int(g * 255), int(b * 255))
        span = len(self.stops) - 1
        pos = max(0.0, min(1.0, t)) * span
        i = min(span - 1, int(pos))
        f = pos - i
        a, b = self.stops[i], self.stops[i + 1]
        return tuple(int(round(a[j] + (b[j] - a[j]) * f)) for j in range(3))


def _load_palettes() -> dict:
    with open(ITEM_PALETTES_PATH, encoding="utf-8") as f:
        raw = json.load(f)
    return {key: Palette(p["dark"], p["shadow"], p["base"], p["light"],
                         rainbow=p.get("rainbow", False))
            for key, p in raw.items()}


PALETTES = _load_palettes()


# --- 이미지 처리 -------------------------------------------------------------


def strip_shadow(px):
    """DCSS 그림에 구워진 검은 그림자를 지운다.

    외곽선(1픽셀)과 눈구멍 같은 정상 디테일은 색이 있는 픽셀에 붙어 있고,
    그림자는 아이템 실루엣 바깥의 두꺼운 검정 덩어리다. 그래서 "색이 있는
    픽셀에 인접하지 않은 검정"만 지운다.
    """
    height = len(px)
    width = len(px[0])

    def is_black(q):
        return q[3] > 0 and q[0] < 26 and q[1] < 26 and q[2] < 26

    core = [[px[y][x][3] > 0 and not is_black(px[y][x]) for x in range(width)]
            for y in range(height)]

    out = [row[:] for row in px]
    for y in range(height):
        for x in range(width):
            if not is_black(px[y][x]):
                continue
            near_core = any(
                0 <= y + dy < height and 0 <= x + dx < width and core[y + dy][x + dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)
            )
            if not near_core:
                out[y][x] = CLEAR
    return out


def recolor(px, palette: Palette):
    """세트 팔레트로 전면 재색칠한다.

    원본의 색조는 버리고 밝기만 남겨 팔레트 램프에 매핑한다. 원본 색을
    살려두면(예: 금색 용갑옷) 세트 색 통일이 깨진다. 예외를 두지 않는 이유도
    같다 - 보석 몇 픽셀만 원색으로 남으면 잡티처럼 보인다.
    """
    box = content_box(px)
    top, bottom = (box[1], box[3]) if box else (0, len(px) - 1)
    span = max(1, bottom - top)

    out = []
    for y, row in enumerate(px):
        line = []
        for q in row:
            if q[3] == 0:
                line.append(CLEAR)
                continue
            _, _, val = colorsys.rgb_to_hsv(q[0] / 255, q[1] / 255, q[2] / 255)
            nr, ng, nb = palette.ramp(val, (y - top) / span)
            line.append((nr, ng, nb, q[3]))
        out.append(line)
    return out


def fit_icon(px):
    """내용만 잘라 24x24 안에 들어가게 축소하고 중앙에 놓는다."""
    box = content_box(px)
    if box is None:
        return [[CLEAR] * ICON for _ in range(ICON)]
    cropped = crop(px, box)
    height = len(cropped)
    width = len(cropped[0])
    longest = max(width, height)
    if longest > ICON:
        square = [[CLEAR] * longest for _ in range(longest)]
        oy, ox = (longest - height) // 2, (longest - width) // 2
        for y in range(height):
            for x in range(width):
                square[oy + y][ox + x] = cropped[y][x]
        cropped = box_down(square, ICON)
    return center_on(cropped, ICON)


# --- 소스 지정 ---------------------------------------------------------------
# 61종 전부 서로 다른 원본 그림을 쓴다. ("모양이 전부 달라야 한다")

def D(path):
    """DCSS 팩 안의 아이템 그림 경로."""
    return "item/" + path


ITEMS = {
    # ── 무기 17종 ────────────────────────────────────────────────
    "icon_sword_worn": (D("weapon/short_sword_1_new.png"), "common"),
    "icon_sword_iron": (D("weapon/long_sword_1_new.png"), "common"),
    "icon_bigsword_steel": (D("weapon/greatsword_1_new.png"), "rare"),
    "icon_sai_frost": (D("weapon/dagger_new.png"), "rare"),
    "icon_weapon_guardian": (D("weapon/katana_1.png"), "guardian_set"),
    "icon_weapon_abyss": (D("weapon/tsurugi.png"), "abyss_set"),
    "icon_weapon_frost": (D("weapon/spear_1.png"), "frost_set"),
    "icon_rapier_glacier": (D("weapon/rapier_1.png"), "epic"),
    "icon_weapon_dragon": (D("weapon/claymore.png"), "boss_set"),
    "icon_weapon_sentinel": (D("weapon/falchion_1_new.png"), "tower_easy_set"),
    "icon_weapon_judge": (D("weapon/blessed_blade.png"), "tower_normal_set"),
    "icon_weapon_end": (D("weapon/artefact/spwpn_sword_of_zonguldrok_new.png"),
                        "tower_hard_set"),
    "icon_weapon_hellfire": (D("weapon/artefact/spwpn_sword_of_cerebov_new.png"),
                             "tower_hell_set"),
    "icon_weapon_prism": (D("weapon/artefact/spwpn_sword_of_power_new.png"),
                          "tower_abyss_set"),
    "icon_bow_hunter": (D("weapon/ranged/shortbow_1.png"), "common"),
    "icon_bow_gale": (D("weapon/ranged/longbow_1.png"), "rare"),
    "icon_bow_soul": (D("weapon/artefact/urand_storm_bow.png"), "epic"),
    # ── 갑옷 15종 ────────────────────────────────────────────────
    "icon_armor_traveler": (D("armor/torso/robe_1_new.png"), "common"),
    "icon_armor_leather": (D("armor/torso/leather_armor_1.png"), "common"),
    "icon_armor_chain": (D("armor/torso/chain_mail_1.png"), "common"),
    "icon_armor_sentry": (D("armor/torso/ring_mail_1_new.png"), "rare"),
    "icon_armor_captain": (D("armor/torso/plate_mail_1.png"), "captain_set"),
    "icon_armor_snowcloak": (D("armor/torso/robe_2_new.png"), "epic"),
    "icon_armor_frost": (D("armor/torso/banded_mail_1.png"), "frost_set"),
    "icon_armor_abyss": (D("armor/torso/plate_mail_2.png"), "abyss_set"),
    "icon_armor_scale": (D("armor/torso/elven_scalemail.png"), "epic"),
    "icon_armor_dragon": (D("armor/torso/scale_mail_3.png"), "boss_set"),
    "icon_armor_sentinel": (D("armor/torso/chain_mail_2.png"), "tower_easy_set"),
    "icon_armor_judge": (D("armor/torso/banded_mail_2.png"), "tower_normal_set"),
    "icon_armor_end": (D("armor/torso/orcish_platemail.png"), "tower_hard_set"),
    "icon_armor_hellfire": (D("armor/torso/ring_mail_3.png"), "tower_hell_set"),
    "icon_armor_prism": (D("armor/torso/robe_3.png"), "tower_abyss_set"),
    # ── 투구 12종 ────────────────────────────────────────────────
    "icon_helmet_leather": (D("armor/headgear/cap_1.png"), "common"),
    "icon_helmet_iron": (D("armor/headgear/helmet_1.png"), "common"),
    "icon_helmet_sentry": (D("armor/headgear/helmet_1_visored.png"), "rare"),
    "icon_helmet_guardian": (D("armor/headgear/cap_2.png"), "guardian_set"),
    "icon_helmet_frost": (D("armor/headgear/helmet_art_1.png"), "frost_set"),
    "icon_helmet_captain": (D("armor/headgear/helmet_2.png"), "captain_set"),
    "icon_helmet_dragon": (D("armor/headgear/crested_helmet.png"), "boss_set"),
    "icon_helmet_sentinel": (D("armor/headgear/helmet_3_new.png"), "tower_easy_set"),
    "icon_helmet_judge": (D("armor/headgear/plumed_helmet.png"), "tower_normal_set"),
    "icon_helmet_end": (D("armor/headgear/helmet_4_visor.png"), "tower_hard_set"),
    "icon_helmet_hellfire": (D("armor/headgear/helmet_5.png"), "tower_hell_set"),
    "icon_helmet_prism": (D("armor/headgear/helmet_ego_1.png"), "tower_abyss_set"),
    # ── 장신구 13종 ──────────────────────────────────────────────
    "icon_trinket_copper": (D("ring/copper.png"), "common"),
    "icon_trinket_dusk": (D("amulet/cameo_orange.png"), "rare"),
    "icon_trinket_crystal": (D("amulet/crystal_white.png"), "rare"),
    "icon_trinket_sunken": (D("amulet/stone_2_blue.png"), "rare"),
    "icon_trinket_guardian": (D("amulet/crystal_green.png"), "guardian_set"),
    "icon_trinket_abyss": (D("amulet/eye_magenta.png"), "abyss_set"),
    "icon_trinket_captain": (D("amulet/celtic_red.png"), "captain_set"),
    "icon_trinket_dragon": (D("amulet/face_1_gold.png"), "boss_set"),
    "icon_trinket_sentinel": (D("ring/silver.png"), "tower_easy_set"),
    "icon_trinket_judge": (D("ring/gold.png"), "tower_normal_set"),
    "icon_trinket_end": (D("ring/ring_ruby.png"), "tower_hard_set"),
    "icon_trinket_hellfire": (D("ring/ring_topaz.png"), "tower_hell_set"),
    "icon_trinket_prism": (D("ring/opal.png"), "tower_abyss_set"),
    # ── 정령 인장 4종 ───────────────────────────────────────────
    "icon_spirit_forest": (D("amulet/penta_green.png"), "guardian_set"),
    "icon_spirit_wind": (D("amulet/eye_cyan.png"), "rare"),
    "icon_spirit_flame": (D("amulet/crystal_red.png"), "epic"),
    "icon_spirit_frostseal": (D("amulet/celtic_blue.png"), "frost_set"),
    # 5~10장 세트 24종 + 전설 필드 드랍 12종(감독 2026-09-10)
    "icon_primordial_sword": (D("weapon/ancient_sword.png"), "primordial_set"),
    "icon_primordial_armor": (D("armor/torso/shadow_dragon_scale_mail.png"), "primordial_set"),
    "icon_primordial_helmet": (D("armor/headgear/helmet_ego_2.png"), "primordial_set"),
    "icon_primordial_seal": (D("ring/artefact/urand_shadows_new.png"), "primordial_set"),
    "icon_reef_sword": (D("weapon/trishula.png"), "reef_set"),
    "icon_reef_armor": (D("armor/torso/blue_dragon_scale_mail_new.png"), "reef_set"),
    "icon_reef_helmet": (D("armor/headgear/helmet_4.png"), "reef_set"),
    "icon_reef_seal": (D("amulet/cameo_blue.png"), "reef_set"),
    "icon_prelate_sword": (D("weapon/golden_sword.png"), "prelate_set"),
    "icon_prelate_armor": (D("armor/torso/gold_dragon_armor_new.png"), "prelate_set"),
    "icon_prelate_helmet": (D("armor/headgear/helmet_art_2.png"), "prelate_set"),
    "icon_prelate_seal": (D("amulet/celtic_yellow.png"), "prelate_set"),
    "icon_warden_sword": (D("weapon/war_hammer.png"), "warden_set"),
    "icon_warden_armor": (D("armor/torso/silver_dragon_scale_mail_new.png"), "warden_set"),
    "icon_warden_helmet": (D("armor/headgear/helmet_2_etched.png"), "warden_set"),
    "icon_warden_seal": (D("ring/ring_black_onyx.png"), "warden_set"),
    "icon_reversal_sword": (D("weapon/artefact/spwpn_scythe_of_curses_new.png"), "reversal_set"),
    "icon_reversal_armor": (D("armor/torso/quicksilver_dragon_scale_mail.png"), "reversal_set"),
    "icon_reversal_helmet": (D("armor/headgear/helmet_ego_3.png"), "reversal_set"),
    "icon_reversal_seal": (D("amulet/artefact/urand_cekugob_new.png"), "reversal_set"),
    "icon_origin_sword": (D("weapon/artefact/spwpn_singing_sword.png"), "origin_set"),
    "icon_origin_armor": (D("armor/torso/crystal_plate_mail.png"), "origin_set"),
    "icon_origin_helmet": (D("armor/headgear/helmet_art_3.png"), "origin_set"),
    "icon_origin_seal": (D("amulet/artefact/urand_vitality.png"), "origin_set"),
    "icon_fd_pilgrim_helm": (D("armor/headgear/hat_2.png"), "legendary"),
    "icon_fd_remnant_ring": (D("ring/tourmaline.png"), "legendary"),
    "icon_fd_coral_plate": (D("armor/torso/pearl_dragon_armor.png"), "legendary"),
    "icon_fd_tide_amulet": (D("amulet/eye_green.png"), "legendary"),
    "icon_fd_lantern_crown": (D("armor/headgear/cornuthaum.png"), "legendary"),
    "icon_fd_faded_holysword": (D("weapon/elven_broadsword.png"), "legendary"),
    "icon_fd_overseer_plate": (D("armor/torso/plate_1.png"), "legendary"),
    "icon_fd_watchtower_seal": (D("ring/ring_sapphire.png"), "legendary"),
    "icon_fd_backflow_sword": (D("weapon/demon_blade.png"), "legendary"),
    "icon_fd_reverter_hood": (D("armor/headgear/hat_3.png"), "legendary"),
    "icon_fd_primal_plate": (D("armor/torso/ice_dragon_armor_new.png"), "legendary"),
    "icon_fd_primal_ring": (D("ring/diamond.png"), "legendary"),
}


# --- 팩 준비 -----------------------------------------------------------------


def ensure_pack() -> str:
    archive = os.path.join(VENDOR, PACK_NAME + ".zip")
    os.makedirs(VENDOR, exist_ok=True)
    if not os.path.exists(archive):
        print("내려받는 중: %s" % PACK_NAME)
        urllib.request.urlretrieve(PACK_URL, archive)
    return archive


def fetch(source: str, pack: zipfile.ZipFile):
    tmp = os.path.join(VENDOR, "_tmp.png")
    with open(tmp, "wb") as f:
        f.write(pack.read(DCSS_ROOT + source))
    px = read_png(tmp)
    os.remove(tmp)
    return strip_shadow(px)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--preview", default="", help="확대 미리보기 저장 경로")
    ap.add_argument("--scale", type=int, default=8)
    args = ap.parse_args()

    pack = zipfile.ZipFile(ensure_pack())
    made = 0
    for name, (source, palette_key) in ITEMS.items():
        px = fetch(source, pack)
        px = recolor(fit_icon(px), PALETTES[palette_key])
        write_png(os.path.join(args.out, name + ".png"), px)
        if args.preview:
            write_png(os.path.join(args.preview, "%s_x%d.png" % (name, args.scale)),
                      scale(px, args.scale))
        made += 1
    print("아이콘 %d개 생성 -> %s" % (made, args.out))


if __name__ == "__main__":
    main()
