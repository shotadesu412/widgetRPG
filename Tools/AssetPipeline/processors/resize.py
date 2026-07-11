"""リサイズ Processor。

Safe Area(既定 96x96)に収まるよう Nearest Neighbor のみで縮小する。
ドットの補間を発生させないため、他の補間方式は使わない。
"""

from __future__ import annotations

from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Resize(Processor):
    """Safe Area に収める(Nearest のみ)。"""

    name = "resize"

    def process(self, ctx: AssetContext) -> AssetContext:
        img = ctx.image
        safe = self.config.safe_area
        w, h = img.size

        scale = min(safe / w, safe / h)
        if scale >= 1.0 and not self.config.upscale_to_safe_area:
            ctx.note(self.name, skipped="fits safe area", size=img.size)
            return ctx

        new_size = (max(1, round(w * scale)), max(1, round(h * scale)))
        resample = Image.Resampling.NEAREST if self.config.nearest_resize else Image.Resampling.LANCZOS
        ctx.image = img.resize(new_size, resample)
        ctx.note(self.name, scale=round(scale, 3), size=new_size)
        return ctx
