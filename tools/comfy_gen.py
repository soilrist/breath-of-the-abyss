#!/usr/bin/env python3
"""ComfyUI(z-image-turbo) 워크플로로 이미지를 생성하고, 필요하면 코너 색
자동감지로 배경을 투명화해 정사각형으로 축소한다. 표준 라이브러리만 쓴다
(urllib/json) — Pillow 등 외부 의존성 없음.

전제: ComfyUI 서버(기본 127.0.0.1:8188)가 이미 떠 있어야 한다.
워크플로 원본: docs/tools/comfy_zimage_workflow.json (<<PROMPT>>/<<PREFIX>>
치환 + seed 주입).

사용법:
  python3 tools/comfy_gen.py --prompt "..." --prefix probe --seed 1
  python3 tools/comfy_gen.py --prompt "..." --prefix skill1_fireball \
      --seed 1 --postprocess --out assets/fx/skill1/fireball.png
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW_PATH = os.path.join(REPO_ROOT, "docs", "tools", "comfy_zimage_workflow.json")
DEFAULT_SERVER = "127.0.0.1:8188"
DEFAULT_OUT_DIR = os.path.join(REPO_ROOT, "assets", "characters", "source", "comfy")


def load_workflow(prompt: str, prefix: str, seed: int) -> dict:
    with open(WORKFLOW_PATH, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("<<PROMPT>>", prompt).replace("<<PREFIX>>", prefix)
    workflow = json.loads(text)
    workflow["prompt"]["8"]["inputs"]["seed"] = seed
    return workflow


def submit(server: str, workflow: dict) -> str:
    body = json.dumps({"prompt": workflow["prompt"]}).encode("utf-8")
    req = urllib.request.Request(
        f"http://{server}/prompt", data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    return result["prompt_id"]


def wait_for_result(server: str, prompt_id: str, timeout: float = 180.0) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        with urllib.request.urlopen(f"http://{server}/history/{prompt_id}", timeout=30) as resp:
            history = json.loads(resp.read().decode("utf-8"))
        entry = history.get(prompt_id)
        if entry and entry.get("outputs"):
            return entry
        time.sleep(1.0)
    raise TimeoutError(f"ComfyUI 응답 대기 시간 초과(prompt_id={prompt_id})")


def fetch_image(server: str, filename: str, subfolder: str, image_type: str) -> bytes:
    query = urllib.parse.urlencode(
        {"filename": filename, "subfolder": subfolder, "type": image_type}
    )
    with urllib.request.urlopen(f"http://{server}/view?{query}", timeout=30) as resp:
        return resp.read()


def save_bytes(path: str, data: bytes) -> None:
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def corner_background(pixels):
    """네 모서리 색 평균을 배경색으로 본다."""
    height = len(pixels)
    width = len(pixels[0])
    corners = [pixels[0][0], pixels[0][width - 1], pixels[height - 1][0], pixels[height - 1][width - 1]]
    return [sum(c[i] for c in corners) // 4 for i in range(3)]


def _close(px, ref, tolerance: int) -> bool:
    return all(abs(px[i] - ref[i]) <= tolerance for i in range(3))


def _hue(px):
    """0~360도 색상각. 무채색(흰 반짝임 등)이면 None(색상각이 불안정해
    잘못 걸러낼 수 있어 제외)."""
    r, g, b = px[0], px[1], px[2]
    mx, mn = max(r, g, b), min(r, g, b)
    delta = mx - mn
    if delta < 8 or mx == 0:
        return None
    if mx == r:
        h = 60 * (((g - b) / delta) % 6)
    elif mx == g:
        h = 60 * (((b - r) / delta) + 2)
    else:
        h = 60 * (((r - g) / delta) + 4)
    return h % 360


def _hue_distance(h1: float, h2: float) -> float:
    d = abs(h1 - h2) % 360
    return min(d, 360 - d)


def remove_background_hue(pixels, bg_rgb, tolerance: float = 25.0):
    """배경과 같은 색상 계열(드롭섀도 등)을, 밝기/채도가 달라 RGB 거리
    검사(remove_corner_background)는 통과해도 색상각이 배경과 같으면
    지운다. 예: undying 결함 — 어두운 마룬(169,43,85)은 순수 자홍
    배경(200,60,104)과 RGB 거리가 tolerance(24)를 넘어 안 지워지지만
    색상각은 거의 같다(약 340°대, 1°차)."""
    bg_hue = _hue(bg_rgb)
    if bg_hue is None:
        return pixels
    out = []
    for row in pixels:
        new_row = []
        for px in row:
            if px[3] > 0:
                h = _hue(px)
                if h is not None and _hue_distance(h, bg_hue) <= tolerance:
                    new_row.append(pixel.CLEAR)
                    continue
            new_row.append(px)
        out.append(new_row)
    return out


def hue_ratio(pixels, ref_rgb, tolerance: float = 25.0) -> float:
    """불투명 픽셀 중 ref_rgb 와 색상각이 가까운 비율(배경과 같은 색
    계열의 그림자 등 간접 잔존을 잡는다 — magenta_ratio 의 RGB 거리
    기준보다 밝기 변화에 강하다)."""
    ref_hue = _hue(ref_rgb)
    if ref_hue is None:
        return 0.0
    total = 0
    matched = 0
    for row in pixels:
        for px in row:
            if px[3] > 0:
                total += 1
                h = _hue(px)
                if h is not None and _hue_distance(h, ref_hue) <= tolerance:
                    matched += 1
    return matched / total if total else 0.0


def remove_corner_background(pixels, backgrounds, tolerance: int = 24):
    """배경 후보색들(모서리 색, 필요하면 키 색) 중 하나와 비슷한 색을 전부
    투명화한다. 모델이 키 색을 캔버스 전체가 아니라 가운데 판으로만 그려
    모서리 색이 달라지는 경우, 키 색도 후보에 넣으면 그 판까지 걷어낸다."""
    def close(px):
        return any(_close(px, bg, tolerance) for bg in backgrounds)

    return [[pixel.CLEAR if close(px) else px for px in row] for row in pixels]


def expand_box(box, width, height, frac: float = 0.04):
    x0, y0, x1, y1 = box
    dx = max(1, round((x1 - x0 + 1) * frac))
    dy = max(1, round((y1 - y0 + 1) * frac))
    return max(0, x0 - dx), max(0, y0 - dy), min(width - 1, x1 + dx), min(height - 1, y1 + dy)


def clear_outside(pixels, box):
    """bbox 밖 픽셀은 전부 투명 처리한다(배경 노이즈가 크롭 뒤에도 안 남게)."""
    x0, y0, x1, y1 = box
    for y, row in enumerate(pixels):
        for x in range(len(row)):
            if not (x0 <= x <= x1 and y0 <= y <= y1):
                row[x] = pixel.CLEAR
    return pixels


def fill_ratio(pixels) -> float:
    total = 0
    opaque = 0
    for row in pixels:
        for px in row:
            total += 1
            if px[3] > 0:
                opaque += 1
    return opaque / total if total else 0.0


def magenta_ratio(pixels, key_color) -> float:
    """자홍 배경판 잔존을 직접 잰다(불투명 비율은 shield_charge 결함 0.70
    < undying 정상 0.76 처럼 결함과 정상을 못 가려 폐기했다)."""
    total = sum(len(row) for row in pixels)
    magenta = sum(1 for row in pixels for px in row if px[3] > 0 and _close(px, key_color, 30))
    return magenta / total if total else 0.0


def dominant_color_ratio(pixels) -> float:
    """색과 무관하게 '판' 잔존을 잡는다 — 불투명 픽셀을 16단계로 양자화해
    가장 흔한 단일 색이 차지하는 비율을 잰다(평평한 판은 한 색이 지배하고,
    이펙트는 그라데이션이라 흩어진다). 임계값은 기존 8장 실측으로 정했다:
    정상 자산 중 가장 높은 값이 swift_step 0.59(단색 바람 줄기), 결함
    shield_charge(흰 원판)는 0.65 — 그 사이 0.62를 기준으로 삼는다."""
    from collections import Counter

    opaque = [px for row in pixels for px in row if px[3] > 0]
    if not opaque:
        return 0.0
    counts = Counter((px[0] // 16, px[1] // 16, px[2] // 16) for px in opaque)
    return counts.most_common(1)[0][1] / len(opaque)


def postprocess(
    raw_path: str,
    out_path: str,
    size: int,
    min_fill: float = 0.45,
    max_magenta: float = 0.02,
    max_dominant: float = 0.62,
    max_hue: float = 0.06,
    key_color=(201, 53, 127),
) -> None:
    pixels = pixel.read_png(raw_path)
    height = len(pixels)
    width = len(pixels[0])
    bg = corner_background(pixels)
    tolerance = 24
    backgrounds = [bg] + ([key_color] if key_color else [])

    cleaned = remove_corner_background(pixels, backgrounds, tolerance)
    # undying 드롭섀도 결함(2026-09-06): RGB 거리로 못 걷어낸 배경과 같은
    # 색상각의 그림자를 여기서 마저 지운다. bbox 를 이 단계 *이후*에
    # 잡아야 그림자가 애초에 내용 범위로 들어오지 않는다.
    cleaned = remove_background_hue(cleaned, bg)

    box = pixel.content_box(cleaned)
    if box is None:
        raise SystemExit(f"배경 제거 실패: 내용 없음 ({raw_path})")
    x0, y0, x1, y1 = box
    if (x1 - x0 + 1) >= width * 0.9 and (y1 - y0 + 1) >= height * 0.9:
        raise SystemExit(f"배경 제거 실패: bbox가 원본의 90% 이상이라 노이즈로 판단 ({raw_path})")
    box = expand_box(box, width, height)

    clear_outside(cleaned, box)
    cropped = pixel.crop(cleaned, box)
    result = pixel.box_down(cropped, size)

    ratio = fill_ratio(result)
    if ratio < min_fill:
        raise SystemExit(f"채움 비율 부족 {ratio:.2f} < {min_fill} ({raw_path})")

    mratio = magenta_ratio(result, key_color)
    if mratio > max_magenta:
        raise SystemExit(f"자홍 배경 잔존 {mratio:.2f} > {max_magenta} ({raw_path})")

    dratio = dominant_color_ratio(result)
    if dratio > max_dominant:
        raise SystemExit(f"단색 판 잔존(지배색 비율 {dratio:.2f} > {max_dominant}) ({raw_path})")

    # 기준 0.06: 정상 자산 중 색상각 잔존이 가장 컸던 swift_step 실측
    # 0.031(초록-배경 경계 앤티앨리어싱)과, 결함으로 확인된 shuriken 실측
    # 0.158(핑크빛 모션 블러 줄기+그림자, 재생성 3회로도 못 고침 — INBOX
    # 참고) 사이 값이다.
    hratio = hue_ratio(result, key_color)
    if hratio > max_hue:
        raise SystemExit(f"배경 색상각 잔존(그림자 등) {hratio:.2f} > {max_hue} ({raw_path})")

    pixel.write_png(out_path, result)


def generate_one(server, prompt, prefix, seed, out_dir, do_postprocess, out_override, size, key_color=(201, 53, 127)):
    workflow = load_workflow(prompt, prefix, seed)
    prompt_id = submit(server, workflow)
    entry = wait_for_result(server, prompt_id)
    images = entry["outputs"]["10"]["images"]
    saved = []
    for image in images:
        data = fetch_image(server, image["filename"], image.get("subfolder", ""), image.get("type", "output"))
        raw_path = os.path.join(out_dir, f"{prefix}_{seed}.png")
        save_bytes(raw_path, data)
        saved.append(raw_path)
        if do_postprocess:
            target = out_override or (os.path.splitext(raw_path)[0] + f"_{size}.png")
            postprocess(raw_path, target, size, key_color=key_color)
            saved.append(target)
    return saved


def check_fill_ratio(paths, min_fill: float = 0.45) -> int:
    """이미 후처리된 PNG들의 불투명 채움 비율을 검사한다(재생성 없이)."""
    ok = True
    for path in paths:
        pixels = pixel.read_png(path)
        ratio = fill_ratio(pixels)
        status = "OK" if ratio >= min_fill else "FAIL"
        if ratio < min_fill:
            ok = False
        print(f"{status} {path}: 채움 {ratio:.2f} (기준 >= {min_fill})")
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="ComfyUI(z-image-turbo)로 이미지 생성 + 배경 투명화/축소 후처리")
    parser.add_argument("--prompt")
    parser.add_argument("--prefix")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--count", type=int, default=1, help="seed부터 순서대로 N장 생성")
    parser.add_argument("--server", default=DEFAULT_SERVER)
    parser.add_argument("--out-dir", default=DEFAULT_OUT_DIR, help="원본 PNG 저장 폴더")
    parser.add_argument("--postprocess", action="store_true", help="코너 색 자동감지 배경 투명화 + --size 축소")
    parser.add_argument("--out", default=None, help="후처리 결과 저장 경로(--count 1에서만 사용)")
    parser.add_argument("--size", type=int, default=64)
    parser.add_argument(
        "--key-color",
        default="201,53,127",
        metavar="R,G,B",
        help="프롬프트가 요구한 배경색(기본 201,53,127 = 이 프로젝트 스킬 이펙트 프롬프트가 공통으로 쓰는 자홍색)."
        " 모서리 색과 별개로 이 색도 배경으로 보고 투명화하고, 후처리 뒤 잔존 비율도 이 색 기준으로 잰다"
        "(모델이 배경을 캔버스 전체가 아니라 가운데 판으로 그려 모서리가 다른 색이 되는 경우 대비)",
    )
    parser.add_argument("--check", nargs="+", metavar="PNG", help="생성 없이 기존 PNG들의 채움 비율만 검사하고 끝낸다")
    args = parser.parse_args()

    if args.check:
        return check_fill_ratio(args.check)

    if not (args.prompt and args.prefix and args.seed is not None):
        parser.error("--prompt/--prefix/--seed는 --check 없이는 필수다")

    if args.count > 1 and args.out:
        parser.error("--out은 --count 1에서만 쓴다")

    parts = [int(v) for v in args.key_color.split(",")]
    if len(parts) != 3:
        parser.error("--key-color는 R,G,B 형식이어야 한다")
    key_color = tuple(parts)

    for i in range(args.count):
        seed = args.seed + i
        paths = generate_one(
            args.server, args.prompt, args.prefix, seed, args.out_dir, args.postprocess, args.out, args.size,
            key_color,
        )
        for path in paths:
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
