import asyncio
import textwrap
import shutil
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_BOLD_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


async def check_ffmpeg() -> bool:
    proc = await asyncio.create_subprocess_exec(
        "ffmpeg", "-version",
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
    )
    await proc.communicate()
    return proc.returncode == 0


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD_PATH if bold else FONT_PATH
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def _burn_caption(src_path: str, caption: str, dest_path: Path, img_w: int, img_h: int):
    """Draw caption text onto a copy of the image and save to dest_path."""
    img = Image.open(src_path).convert("RGB").resize((img_w, img_h), Image.LANCZOS)
    draw = ImageDraw.Draw(img)

    # Parse speaker label from "Speaker: text" format
    label = ""
    body = caption.strip()
    if ":" in caption:
        parts = caption.split(":", 1)
        if len(parts[0].split()) <= 4:
            label = parts[0].strip().upper()
            body = parts[1].strip()

    font_label = _load_font(15, bold=True)
    font_body = _load_font(15)

    max_chars = max(30, img_w // 10)
    wrapped_lines = []
    for para in body.split("\n"):
        wrapped_lines.extend(textwrap.wrap(para.strip(), max_chars) or [""])

    line_h = 20
    padding = 10
    box_h = padding * 2 + (len(wrapped_lines) * line_h) + (22 if label else 0)
    box_y = img_h - box_h - 12

    # Semi-transparent black background
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ov_draw = ImageDraw.Draw(overlay)
    ov_draw.rectangle(
        [padding, box_y, img_w - padding, img_h - 12],
        fill=(0, 0, 0, 170),
    )
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    y = box_y + padding
    if label:
        draw.text((img_w // 2, y), label, font=font_label, fill=(255, 220, 50), anchor="mt")
        y += 22

    for line in wrapped_lines:
        draw.text((img_w // 2, y), line, font=font_body, fill=(255, 255, 255), anchor="mt")
        y += line_h

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(dest_path), "PNG")


async def render_preview(
    shots: list[dict],
    output_path: Path,
    resolution: str = "768x512",
    fps: int = 24,
    crossfade: float = 0.5,
    show_captions: bool = False,
) -> dict:
    """
    Assemble storyboard images into an MP4 with Ken Burns zoom, crossfade transitions,
    and optional caption overlays burned in via Pillow.

    Each shot dict: {"image_path": str, "duration": float, "caption": str (optional)}
    """
    w, h = map(int, resolution.split("x"))
    n = len(shots)
    if n == 0:
        raise ValueError("No shots with images to render")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    tmp_dir = Path(tempfile.mkdtemp(prefix="sf_video_"))
    try:
        # Pre-process images: burn captions if needed
        processed_shots = []
        for i, item in enumerate(shots):
            caption = item.get("caption", "") if show_captions else ""
            if caption and caption.strip():
                dest = tmp_dir / f"frame_{i:03d}.png"
                _burn_caption(item["image_path"], caption, dest, w, h)
                image_path = str(dest)
            else:
                image_path = item["image_path"]
            processed_shots.append({**item, "image_path": image_path})

        inputs = []
        for item in processed_shots:
            clip_dur = item["duration"] + crossfade
            inputs += ["-loop", "1", "-t", str(clip_dur), "-i", item["image_path"]]

        filter_parts = []
        for i, item in enumerate(processed_shots):
            dur_frames = int(item["duration"] * fps)
            filter_parts.append(
                f"[{i}:v]"
                f"scale={w * 2}:{h * 2}:force_original_aspect_ratio=increase,"
                f"crop={w * 2}:{h * 2},"
                f"scale={w}:{h},"
                f"zoompan="
                f"z='min(zoom+0.0008,1.3)':"
                f"x='iw/2-(iw/zoom/2)':"
                f"y='ih/2-(ih/zoom/2)':"
                f"d={dur_frames}:"
                f"s={w}x{h}:"
                f"fps={fps}"
                f"[v{i}]"
            )

        if n == 1:
            filter_parts.append("[v0]null[out]")
        else:
            offset = 0.0
            current = "v0"
            for i in range(1, n):
                offset += shots[i - 1]["duration"] - crossfade
                out_label = "out" if i == n - 1 else f"x{i}"
                filter_parts.append(
                    f"[{current}][v{i}]"
                    f"xfade=transition=fade:duration={crossfade:.3f}:offset={max(offset, 0):.3f}"
                    f"[{out_label}]"
                )
                current = out_label
                offset += crossfade

        filter_complex = ";".join(filter_parts)

        cmd = [
            "ffmpeg", "-y",
            *inputs,
            "-filter_complex", filter_complex,
            "-map", "[out]",
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-pix_fmt", "yuv420p",
            "-r", str(fps),
            "-movflags", "+faststart",
            str(output_path),
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(stderr.decode(errors="replace")[-2000:])

        total_duration = sum(s["duration"] for s in shots)
        return {
            "path": str(output_path),
            "duration_seconds": total_duration,
            "shot_count": n,
        }
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)
