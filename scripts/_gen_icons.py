# -*- coding: utf-8 -*-
"""一次性：logo.svg -> 各尺寸透明 PNG + Windows ICO。
svglib + reportlab(3.6 libart，无需 cairo) + Pillow。"""
import io, os, shutil
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM
from PIL import Image, ImageChops

SRC = r"C:\Users\Administrator\Desktop\logo.svg"
WIN_ICO = r"d:\wisdom\kage\windows\runner\resources\app_icon.ico"
MAC_DIR = r"d:\wisdom\kage\macos\Runner\Assets.xcassets\AppIcon.appiconset"
UI_DIR = r"d:\wisdom\kage\assets\images"

# 1) SVG -> 高分辨率白底 PNG
drawing = svg2rlg(SRC)
buf = io.BytesIO()
renderPM.drawToFile(drawing, buf, fmt="PNG", dpi=384)  # 768pt*384/72≈4096px
raw = Image.open(io.BytesIO(buf.getvalue())).convert("RGB")

# 2) 白底转透明：whiteness=min(r,g,b) 反相作 alpha（纯蓝 logo 保留）
r, g, b = raw.split()
whiteness = ImageChops.darker(ImageChops.darker(r, g), b)
alpha = ImageChops.invert(whiteness)
base = Image.merge("RGBA", (r, g, b, alpha)).resize((1024, 1024), Image.LANCZOS)
print("基准 PNG:", base.size, base.mode)

def sized(s):
    return base.resize((s, s), Image.LANCZOS)

# 3) UI 内 logo：复制 SVG（标题栏用 flutter_svg）
os.makedirs(UI_DIR, exist_ok=True)
shutil.copyfile(SRC, os.path.join(UI_DIR, "logo.svg"))
print("复制 SVG ->", os.path.join(UI_DIR, "logo.svg"))

# 4) Windows ICO：多尺寸（Pillow 自动从 base 缩放）
ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
base.save(WIN_ICO, format="ICO", sizes=ico_sizes)
print("写入", WIN_ICO, ico_sizes)

# 5) macOS 各尺寸 PNG（文件名不变）
for s in [16, 32, 64, 128, 256, 512, 1024]:
    p = os.path.join(MAC_DIR, f"app_icon_{s}.png")
    sized(s).save(p)
    print("写入", p)

print("DONE")
