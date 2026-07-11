"""AI Asset Pipeline — AI生成画像をゲーム用アセットへ自動加工する開発支援ツール。

使い方:
    python3 main.py run                          # input/ 全カテゴリを処理
    python3 main.py run --category characters    # カテゴリ指定
    python3 main.py run --files path/to/img.png --category characters
    python3 main.py palette --input <dir> --size 32 --out palette/common_32.json
    python3 main.py analyze --input <dir> --name dark_fantasy
    python3 main.py sheet --input output/characters --pattern "akuma_*" --out output/sheets/akuma.png

ゲーム本体(Swift)とは独立した Python ツール。設定は config.json のみ。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from models.config import PipelineConfig  # noqa: E402
from models.context import AssetContext  # noqa: E402
from processors import build_pipeline  # noqa: E402
from utils.color import rgb_to_hex  # noqa: E402
from utils.log import setup_logging  # noqa: E402

CATEGORIES = ("characters", "backgrounds", "ui")


def load_preset(category: str) -> dict:
    """presets/<category>.json を読み込む。"""
    path = ROOT / "presets" / f"{category}.json"
    if not path.exists():
        raise FileNotFoundError(f"プリセットがありません: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def process_file(src: Path, category: str, config: PipelineConfig, preset: dict, logger) -> Path | None:
    """1ファイルをパイプラインに通して output へ保存する。"""
    ctx = AssetContext(
        image=Image.open(src).convert("RGBA"),
        source=src,
        category=category,
        config=config,
    )
    for processor in build_pipeline(preset["processors"], config):
        ctx = processor(ctx)

    out_dir = ROOT / "output" / category
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{ctx.stem}.png"
    ctx.image.save(out_path)

    if config.generate_preview:
        scale = max(1, config.preview_scale)
        preview_dir = ROOT / "output" / "previews"
        preview_dir.mkdir(parents=True, exist_ok=True)
        big = ctx.image.resize(
            (ctx.image.width * scale, ctx.image.height * scale),
            Image.Resampling.NEAREST,
        )
        big.save(preview_dir / f"{ctx.stem}@{scale}x.png")

    if config.export_xcassets:
        export_imageset(ctx.image, ctx.stem, Path(config.export_xcassets), logger)

    logger.info("%s → %s %s", src.name, out_path.relative_to(ROOT), dict_summary(ctx.meta))
    return out_path


def export_imageset(image: Image.Image, stem: str, xcassets: Path, logger) -> None:
    """Xcode の .xcassets に imageset として書き出す(Swift側へ直結)。"""
    if not xcassets.is_absolute():
        xcassets = (ROOT / xcassets).resolve()
    imageset = xcassets / f"{stem}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    image.save(imageset / f"{stem}.png")
    contents = {
        "images": [{"idiom": "universal", "filename": f"{stem}.png"}],
        "info": {"author": "xcode", "version": 1},
    }
    (imageset / "Contents.json").write_text(
        json.dumps(contents, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    logger.info("  ↳ xcassets: %s", imageset)


def dict_summary(meta: dict) -> str:
    """ログ用にmetaを1行へ要約する。"""
    parts = []
    for key, info in meta.items():
        if isinstance(info, dict) and "skipped" in info:
            continue
        parts.append(key)
    return f"({' > '.join(parts)})" if parts else ""


def cmd_run(args: argparse.Namespace, logger) -> int:
    base = PipelineConfig.load(ROOT / args.config)
    categories = [args.category] if args.category else list(CATEGORIES)

    failed = 0
    for category in categories:
        preset = load_preset(category)
        config = base.with_overrides(preset.get("overrides", {}))
        config.validate()

        if args.files:
            files = [Path(f).expanduser().resolve() for f in args.files]
        else:
            files = sorted((ROOT / "input" / category).glob("*.png"))
        if not files:
            logger.info("[%s] 入力なし(input/%s/*.png)", category, category)
            continue

        logger.info("[%s] %d 件を処理(processors: %s)", category, len(files), " → ".join(preset["processors"]))
        for src in files:
            try:
                process_file(src, category, config, preset, logger)
            except Exception as exc:  # 1枚の失敗で全体を止めない
                failed += 1
                logger.error("%s: %s", src.name, exc)
    return 1 if failed else 0


def cmd_palette(args: argparse.Namespace, logger) -> int:
    """共通パレットを生成して palette/ に保存する。"""
    import numpy as np

    files = sorted(Path(args.input).expanduser().resolve().rglob("*.png"))
    if not files:
        logger.error("PNG が見つかりません: %s", args.input)
        return 1
    samples = []
    for f in files:
        arr = np.array(Image.open(f).convert("RGBA"))
        opaque = arr[arr[:, :, 3] > 0][:, :3]
        if len(opaque):
            samples.append(opaque)
    merged = np.concatenate(samples)
    strip = Image.fromarray(merged.reshape(1, -1, 3), "RGB")
    quantized = strip.quantize(colors=args.size, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    raw = quantized.getpalette()[: args.size * 3]
    used = sorted(set(np.asarray(quantized).ravel().tolist()))
    palette = np.array(raw, dtype=np.uint8).reshape(-1, 3)[used]

    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    colors = [rgb_to_hex(tuple(c)) for c in palette]
    out.write_text(json.dumps({"size": len(colors), "colors": colors}, indent=2), encoding="utf-8")

    # スウォッチ画像も保存(目視確認用)
    sw = Image.new("RGB", (len(colors) * 8, 8))
    for i, c in enumerate(palette):
        sw.paste(Image.new("RGB", (8, 8), tuple(c)), (i * 8, 0))
    sw.save(out.with_suffix(".png"))
    logger.info("共通パレット %d 色 → %s", len(colors), out.relative_to(ROOT))
    return 0


def cmd_analyze(args: argparse.Namespace, logger) -> int:
    """既存アセットからスタイルプロファイルを生成する。"""
    from models.style_profile import StyleProfile

    files = sorted(Path(args.input).expanduser().resolve().rglob("*.png"))
    if not files:
        logger.error("PNG が見つかりません: %s", args.input)
        return 1
    profile = StyleProfile.analyze(files, name=args.name, palette_size=args.size)
    out = ROOT / "palette" / f"style_{args.name}.json"
    profile.save(out)
    logger.info("スタイルプロファイル(%d 素材) → %s", profile.source_count, out.relative_to(ROOT))
    logger.info("  明るさ %.1f±%.1f / 彩度 %.2f / ドット密度 %.2f / 輪郭 %s",
                profile.brightness_mean, profile.brightness_std,
                profile.saturation_mean, profile.dot_density, profile.outline_color)
    return 0


def cmd_sheet(args: argparse.Namespace, logger) -> int:
    """処理済みPNGからスプライトシート+JSONを生成する。"""
    from processors.spritesheet import generate_sheet

    src = Path(args.input).expanduser()
    if not src.is_absolute():
        src = ROOT / src
    files = sorted(src.glob(args.pattern))
    if not files:
        logger.error("該当なし: %s/%s", src, args.pattern)
        return 1
    out = Path(args.out)
    if not out.is_absolute():
        out = ROOT / out
    meta = generate_sheet(files, out, columns=args.columns)
    logger.info("シート %d フレーム → %s(+.json)", len(meta["frames"]), out.relative_to(ROOT))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="AI Asset Pipeline")
    parser.add_argument("--verbose", action="store_true", help="デバッグログを出す")
    sub = parser.add_subparsers(dest="command")

    p_run = sub.add_parser("run", help="input/ の画像をパイプライン処理する")
    p_run.add_argument("--config", default="config.json")
    p_run.add_argument("--category", choices=CATEGORIES)
    p_run.add_argument("--files", nargs="*", help="input/ を使わず指定ファイルを処理")

    p_pal = sub.add_parser("palette", help="共通パレットを生成する")
    p_pal.add_argument("--input", required=True)
    p_pal.add_argument("--size", type=int, default=32, choices=(16, 32, 64, 128))
    p_pal.add_argument("--out", default="palette/common_32.json")

    p_ana = sub.add_parser("analyze", help="既存アセットからスタイルプロファイルを作る")
    p_ana.add_argument("--input", required=True)
    p_ana.add_argument("--name", default="dark_fantasy")
    p_ana.add_argument("--size", type=int, default=32)

    p_sheet = sub.add_parser("sheet", help="スプライトシートとJSONを生成する")
    p_sheet.add_argument("--input", default="output/characters")
    p_sheet.add_argument("--pattern", default="*.png")
    p_sheet.add_argument("--columns", type=int, default=4)
    p_sheet.add_argument("--out", required=True)

    args = parser.parse_args()
    logger = setup_logging(args.verbose)

    if args.command == "palette":
        return cmd_palette(args, logger)
    if args.command == "analyze":
        return cmd_analyze(args, logger)
    if args.command == "sheet":
        return cmd_sheet(args, logger)
    if args.command in (None, "run"):
        if args.command is None:
            args = parser.parse_args(["run"])
        return cmd_run(args, logger)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
