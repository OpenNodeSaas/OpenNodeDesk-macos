#!/usr/bin/env python3
"""生成 macOS 应用图标 AppIcon.icns。仅用标准库，无需 iconutil/PIL。

用法: python3 Resources/make_app_icon.py
产物: Resources/AppIcon.icns（Makefile 打包时自动拷入 .app）
"""
import math
import os
import struct
import zlib

TOP = (0.29, 0.56, 1.00)      # #4A8FFF
BOTTOM = (0.08, 0.23, 0.66)   # #143AA8
GLYPH = (1.0, 1.0, 1.0)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def sdf_round_rect(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ox = qx if qx > 0 else 0.0
    oy = qy if qy > 0 else 0.0
    return math.hypot(ox, oy) + min(max(qx, qy), 0.0) - r


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    t = (wx * vx + wy * vy) / (vx * vx + vy * vy)
    t = 0.0 if t < 0 else 1.0 if t > 1 else t
    return math.hypot(wx - t * vx, wy - t * vy)


def render(n):
    """返回 RGBA 行优先字节。"""
    S = float(n)
    inset = 0.0977 * S              # Big Sur 图标网格: 824/1024
    x0 = y0 = inset
    x1 = y1 = S - inset
    W = x1 - x0
    cx = cy = S / 2
    radius = 0.1807 * S

    half = 0.052 * W                # 笔画半宽
    shift = -0.008 * W              # 字形整体左移，视觉居中
    c0 = (cx - 0.28 * W + shift, cy - 0.17 * W)
    c1 = (cx - 0.015 * W + shift, cy)
    c2 = (cx - 0.28 * W + shift, cy + 0.17 * W)
    u0 = (cx + 0.075 * W + shift, cy + 0.17 * W)
    u1 = (cx + 0.295 * W + shift, cy + 0.17 * W)

    glyph_pts = ((c0, c1), (c1, c2), (u0, u1))
    shadow_off = 0.012 * S
    shadow_blur = 0.035 * S
    hlx, hly = cx, y0 + 0.10 * W

    out = bytearray(n * n * 4)
    i = 0
    for y in range(n):
        py = y + 0.5
        for x in range(n):
            px = x + 0.5

            rect_d = sdf_round_rect(px, py, cx, cy, W / 2, W / 2, radius)
            rect_a = clamp(0.5 - rect_d)

            # 渐变底
            t = clamp(0.75 * (py - y0) / W + 0.25 * (px - x0) / W)
            r = TOP[0] + (BOTTOM[0] - TOP[0]) * t
            g = TOP[1] + (BOTTOM[1] - TOP[1]) * t
            b = TOP[2] + (BOTTOM[2] - TOP[2]) * t

            # 左上高光
            hv = clamp(1.0 - math.hypot(px - hlx, py - hly) / (0.62 * W))
            hv = hv * hv * 0.10
            r, g, b = r + hv, g + hv, b + hv

            # 终端提示符 ">_"
            gd = min(seg_dist(px, py, a[0], a[1], bb[0], bb[1]) for a, bb in glyph_pts) - half
            ga = clamp(0.5 - gd)
            r += (GLYPH[0] - r) * ga
            g += (GLYPH[1] - g) * ga
            b += (GLYPH[2] - b) * ga

            # 轻微投影（让 Dock 中更有层次）
            sd = sdf_round_rect(px, py - shadow_off, cx, cy, W / 2, W / 2, radius)
            sh = clamp(1.0 - sd / shadow_blur) * 0.22 * (1.0 - rect_a)

            a = rect_a + sh * (1.0 - rect_a)
            if a > 0:
                r = clamp(r) * rect_a / a
                g = clamp(g) * rect_a / a
                b = clamp(b) * rect_a / a

            out[i] = int(clamp(r) * 255 + 0.5)
            out[i + 1] = int(clamp(g) * 255 + 0.5)
            out[i + 2] = int(clamp(b) * 255 + 0.5)
            out[i + 3] = int(clamp(a) * 255 + 0.5)
            i += 4
    return bytes(out)


def png(n, rgba):
    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = bytearray()
    stride = n * 4
    for y in range(n):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])
    return b"".join([
        b"\x89PNG\r\n\x1a\n",
        chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 6, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(bytes(raw), 9)),
        chunk(b"IEND", b""),
    ])


def main():
    root = os.path.dirname(os.path.abspath(__file__))
    # 每个 icns 槽位复用的 PNG 缓存
    cache = {}
    for size in (16, 32, 64, 128, 256, 512, 1024):
        cache[size] = png(size, render(size))

    slots = [
        (b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024),
        (b"ic11", 32), (b"ic12", 64), (b"ic13", 256), (b"ic14", 512),
        (b"icp4", 16), (b"icp5", 32), (b"icp6", 64),
    ]
    body = b"".join(tag + struct.pack(">I", len(cache[s]) + 8) + cache[s] for tag, s in slots)
    icns = b"icns" + struct.pack(">I", len(body) + 8) + body
    path = os.path.join(root, "AppIcon.icns")
    with open(path, "wb") as f:
        f.write(icns)
    print(f"==> {path} ({len(icns)} bytes)")

    # 自检: 结构、长度与内嵌 PNG 尺寸
    check = open(path, "rb").read()
    assert check[:4] == b"icns" and struct.unpack(">I", check[4:8])[0] == len(check)
    pos, seen = 8, {}
    while pos < len(check):
        tag = check[pos:pos + 4]
        size = struct.unpack(">I", check[pos + 4:pos + 8])[0]
        payload = check[pos + 8:pos + size]
        assert payload[:8] == b"\x89PNG\r\n\x1a\n", tag
        seen[tag] = struct.unpack(">I", payload[16:20])[0]
        pos += size
    assert seen == {t: s for t, s in slots}, seen

    # 512 预览，方便肉眼检查
    with open("/tmp/AppIcon-preview.png", "wb") as f:
        f.write(cache[512])
    print("==> /tmp/AppIcon-preview.png")


if __name__ == "__main__":
    main()
