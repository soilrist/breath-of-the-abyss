"""PNG 읽기/쓰기와 확대·축소. 표준 라이브러리만 쓴다.

Pillow 같은 외부 의존성을 두지 않으려고 직접 구현했다. 에셋 빌드
스크립트(build_item_icons.py)가 이 모듈을 쓴다.
"""

import os
import struct
import zlib

CLEAR = (0, 0, 0, 0)


def read_png(path: str):
    """PNG를 RGBA 2차원 배열로 읽는다. 8비트 그레이/팔레트/트루컬러를 지원."""
    with open(path, "rb") as f:
        data = f.read()
    width, height = struct.unpack(">II", data[16:24])
    ctype = data[25]

    idat = b""
    palette = None
    trns = None
    i = 8
    while i < len(data):
        length = struct.unpack(">I", data[i:i + 4])[0]
        tag = data[i + 4:i + 8]
        block = data[i + 8:i + 8 + length]
        if tag == b"IDAT":
            idat += block
        elif tag == b"PLTE":
            palette = block
        elif tag == b"tRNS":
            trns = block
        i += 12 + length

    raw = zlib.decompress(idat)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = width * channels

    rows = []
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filt == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 255
        elif filt == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif filt == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif filt == 4:
            for x in range(stride):
                a = line[x - channels] if x >= channels else 0
                c = prev[x - channels] if x >= channels else 0
                b = prev[x]
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255

        row = []
        for x in range(width):
            if ctype == 6:
                row.append(tuple(line[x * 4:x * 4 + 4]))
            elif ctype == 2:
                row.append(tuple(line[x * 3:x * 3 + 3]) + (255,))
            elif ctype == 3:
                idx = line[x]
                r, g, b = palette[idx * 3:idx * 3 + 3]
                alpha = trns[idx] if trns and idx < len(trns) else 255
                row.append((r, g, b, alpha))
            elif ctype == 4:
                value = line[x * 2]
                row.append((value, value, value, line[x * 2 + 1]))
            else:
                value = line[x]
                row.append((value, value, value, 255))
        rows.append(row)
        prev = line
    return rows


def write_png(path: str, pixels) -> None:
    """RGBA 2차원 배열을 PNG로 저장한다."""
    height = len(pixels)
    width = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # 필터 타입 0 (None)
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def scale(pixels, factor: int):
    """최근접 이웃 확대. 미리보기용."""
    out = []
    for row in pixels:
        big = []
        for px in row:
            big.extend([px] * factor)
        out.extend([big] * factor)
    return out


def box_down(pixels, dst: int):
    """박스 필터 축소. 알파 가중 평균이라 외곽이 뭉개지지 않는다."""
    height = len(pixels)
    width = len(pixels[0])
    out = []
    for oy in range(dst):
        row = []
        y0, y1 = oy * height // dst, max(oy * height // dst + 1, (oy + 1) * height // dst)
        for ox in range(dst):
            x0, x1 = ox * width // dst, max(ox * width // dst + 1, (ox + 1) * width // dst)
            r = g = b = alpha = count = 0
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    px = pixels[yy][xx]
                    if px[3] > 0:
                        r += px[0] * px[3]
                        g += px[1] * px[3]
                        b += px[2] * px[3]
                        alpha += px[3]
                    count += 1
            if alpha == 0:
                row.append(CLEAR)
            else:
                row.append((r // alpha, g // alpha, b // alpha, min(255, alpha // count)))
        out.append(row)
    return out


def content_box(pixels):
    """불투명 픽셀이 차지하는 범위 (x0, y0, x1, y1). 비었으면 None."""
    xs, ys = [], []
    for y, row in enumerate(pixels):
        for x, px in enumerate(row):
            if px[3] > 0:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def crop(pixels, box):
    x0, y0, x1, y1 = box
    return [row[x0:x1 + 1] for row in pixels[y0:y1 + 1]]


def center_on(pixels, size: int):
    """size x size 투명 캔버스 중앙에 올린다. 넘치면 잘린다."""
    canvas = [[CLEAR] * size for _ in range(size)]
    height = len(pixels)
    width = len(pixels[0])
    ox = (size - width) // 2
    oy = (size - height) // 2
    for y in range(height):
        for x in range(width):
            px = pixels[y][x]
            ty, tx = oy + y, ox + x
            if px[3] > 0 and 0 <= ty < size and 0 <= tx < size:
                canvas[ty][tx] = px
    return canvas
