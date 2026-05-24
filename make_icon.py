"""生成食物志 App Icon（方案C：书 + 叉子）"""
from PIL import Image, ImageDraw
import math, os, subprocess, shutil

SIZE = 1024
OUT  = "AppIcon.iconset"

# ── 颜色 ────────────────────────────────────────────────
BG_TOP    = (220, 120, 20)   # 暖橙
BG_BOT    = (180,  80,  8)   # 深琥珀
WHITE     = (255, 255, 255)
WHITE_DIM = (255, 255, 255, 210)

def make_icon(size: int) -> Image.Image:
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size / 1024  # 缩放因子

    # ── 背景：圆角矩形渐变 ───────────────────────────────
    r = int(180 * s)
    for y in range(size):
        t   = y / size
        r_c = int(BG_TOP[0] * (1-t) + BG_BOT[0] * t)
        g_c = int(BG_TOP[1] * (1-t) + BG_BOT[1] * t)
        b_c = int(BG_TOP[2] * (1-t) + BG_BOT[2] * t)
        draw.line([(0, y), (size, y)], fill=(r_c, g_c, b_c, 255))

    # 圆角遮罩
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size-1, size-1], radius=r, fill=255)
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)

    # ── 书（左侧）────────────────────────────────────────
    # 书区域：x 90-430，y 170-860（占左侧约40%宽度）
    bx1, bx2 = int(90*s), int(430*s)
    by1, by2 = int(170*s), int(860*s)
    bw = bx2 - bx1
    bh = by2 - by1

    # 书脊（中间竖线）
    spine_x = bx1 + bw // 2
    spine_w = int(22*s)

    # 左页
    draw.rounded_rectangle(
        [bx1, by1, spine_x - spine_w//2, by2],
        radius=int(14*s), fill=WHITE
    )
    # 右页
    draw.rounded_rectangle(
        [spine_x + spine_w//2, by1, bx2, by2],
        radius=int(14*s), fill=WHITE
    )
    # 书脊（略深）
    draw.rectangle(
        [spine_x - spine_w//2, by1, spine_x + spine_w//2, by2],
        fill=(255, 255, 255, 180)
    )

    # 页面上的横线（橙色，表示文字）
    line_color = (BG_TOP[0], BG_TOP[1], BG_TOP[2], 160)
    margin = int(24*s)
    lh = int(18*s)
    gap = int(34*s)
    y_start = by1 + int(55*s)
    for i in range(12):
        y = y_start + i * gap
        if y + lh > by2 - int(40*s): break
        # 左页线
        draw.rounded_rectangle(
            [bx1 + margin, y, spine_x - spine_w//2 - margin, y + lh],
            radius=lh//2, fill=line_color
        )
        # 右页线
        draw.rounded_rectangle(
            [spine_x + spine_w//2 + margin, y, bx2 - margin, y + lh],
            radius=lh//2, fill=line_color
        )

    # ── 筷子（右侧）──────────────────────────────────────
    # 两根筷子，略微向左倾斜（筷尖朝右上）
    # 筷子区域：x 520-870，顶到底留出边距
    cw       = int(26*s)    # 筷尾宽度
    cgap     = int(60*s)    # 两根间距（中心距）
    cx_center = int(680*s)  # 两根筷子中心
    cy_top   = int(120*s)   # 筷尖 y
    cy_bot   = int(880*s)   # 筷尾 y

    # 整体向右倾斜：筷尖比筷尾偏右
    tilt = int(50*s)

    for side in [-1, 1]:
        cx_bot = cx_center + side * cgap // 2          # 筷尾中心 x
        cx_top = cx_bot + tilt                          # 筷尖向右偏移

        top_w = max(int(cw * 0.45), 3)  # 筷尖细
        bot_w = cw                       # 筷尾粗

        pts = [
            (cx_top - top_w//2, cy_top),
            (cx_top + top_w//2, cy_top),
            (cx_bot + bot_w//2, cy_bot),
            (cx_bot - bot_w//2, cy_bot),
        ]
        draw.polygon(pts, fill=WHITE)

        # 筷尖圆头（很小的椭圆）
        draw.ellipse([
            cx_top - top_w//2, cy_top,
            cx_top + top_w//2, cy_top + top_w
        ], fill=WHITE)
        # 筷尾圆头（较大）
        draw.ellipse([
            cx_bot - bot_w//2, cy_bot - bot_w,
            cx_bot + bot_w//2, cy_bot
        ], fill=WHITE)

    return img


def save_iconset():
    os.makedirs(OUT, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for sz in sizes:
        icon = make_icon(sz)
        icon.save(f"{OUT}/icon_{sz}x{sz}.png")
        if sz <= 512:
            icon2 = make_icon(sz * 2)
            icon2.save(f"{OUT}/icon_{sz}x{sz}@2x.png")
    print(f"Saved {OUT}/")

save_iconset()
subprocess.run(["iconutil", "-c", "icns", OUT, "-o", "AppIcon.icns"], check=True)
print("AppIcon.icns created ✓")
