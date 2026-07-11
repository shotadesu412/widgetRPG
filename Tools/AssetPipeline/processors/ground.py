"""Ground System Processor。

ゲーム全体の共通ルールに従い、キャンバスへ配置する。

    Canvas    128x128
    Ground    Y = 112(足元をここに揃える)
    Pivot     Bottom Center 固定
    Safe Area 96x96(resize Processor が保証)
"""

from __future__ import annotations

from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Ground(Processor):
    """Bottom Center ピボットで Ground Y に足元を固定する。"""

    name = "ground"

    def process(self, ctx: AssetContext) -> AssetContext:
        cw, ch = self.config.canvas_width, self.config.canvas_height
        ground_y = self.config.ground_y

        sprite = ctx.image.convert("RGBA")
        w, h = sprite.size
        if w > cw or h > ground_y:
            # Safe Area 超過(アウトライン加算など)。Nearest で収める
            scale = min(cw / w, ground_y / h, 1.0)
            sprite = sprite.resize(
                (max(1, int(w * scale)), max(1, int(h * scale))),
                Image.Resampling.NEAREST,
            )
            w, h = sprite.size

        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        x = (cw - w) // 2
        y = ground_y - h
        canvas.paste(sprite, (x, y), sprite)

        ctx.note(
            self.name,
            canvas=(cw, ch),
            ground_y=ground_y,
            pivot="bottom_center",
            paste=(x, y),
            sprite=(w, h),
        )
        ctx.image = canvas
        return ctx
