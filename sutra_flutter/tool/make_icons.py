# -*- coding: utf-8 -*-
"""生成「五十经藏」Android 启动图标（宣纸 + 朱砂印）。

输出：
  mipmap-*dpi/ic_launcher.png             传统方形图标（API 25 及以下）
  mipmap-*dpi/ic_launcher_foreground.png 自适应图标前景（API 26+）
背景色由 res/values/colors.xml 的 ic_launcher_background 提供。

用法： python tool/make_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

PAPER = (243, 233, 214)      # 宣纸
CINNABAR = (159, 43, 34)    # 朱砂
IVORY = (248, 240, 224)     # 印文
FONT = 'C:/Windows/Fonts/msyhbd.ttc'   # 微软雅黑粗体，含繁体「經」

DENSITY = {
    'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0,
    'xxhdpi': 3.0, 'xxxhdpi': 4.0,
}
SS = 4  # 超采样倍数，抗锯齿


def seal(size, box_ratio, glyph_ratio, transparent_bg):
    """画一枚朱砂方印，返回 RGBA 图。"""
    s = int(size * SS)
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0) if transparent_bg else PAPER + (255,))
    d = ImageDraw.Draw(img)

    side = s * box_ratio
    left = (s - side) / 2
    top = (s - side) / 2
    right, bottom = left + side, top + side
    radius = side * 0.09

    # 印面
    d.rounded_rectangle([left, top, right, bottom], radius=radius, fill=CINNABAR + (255,))
    # 印内细边框
    inset = side * 0.075
    d.rounded_rectangle(
        [left + inset, top + inset, right - inset, bottom - inset],
        radius=radius * 0.6, outline=IVORY + (255,), width=max(1, int(side * 0.016)))

    # 印文「經」
    font = ImageFont.truetype(FONT, int(side * glyph_ratio))
    text = '經'
    bb = d.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    # textbbox 带字体上沿留白，按视觉中心下移一点
    d.text(((s - tw) / 2 - bb[0], (s - th) / 2 - bb[1] - side * 0.015),
           text, font=font, fill=IVORY + (255,))

    return img.resize((int(size), int(size)), Image.LANCZOS)


def main():
    for folder, scale in DENSITY.items():
        out = os.path.join(RES, 'mipmap-' + folder)
        os.makedirs(out, exist_ok=True)

        legacy = int(48 * scale)
        seal(legacy, 0.74, 0.56, False).save(
            os.path.join(out, 'ic_launcher.png'), 'PNG', optimize=True)

        # 自适应图标画布为 108dp，内容须落在中央 66dp 安全区内
        fg = int(108 * scale)
        seal(fg, 0.52, 0.56, True).save(
            os.path.join(out, 'ic_launcher_foreground.png'), 'PNG', optimize=True)
        print('%-10s ic_launcher %dpx / foreground %dpx' % (folder, legacy, fg))


if __name__ == '__main__':
    main()
