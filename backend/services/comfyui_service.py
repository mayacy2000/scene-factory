import json
import uuid
import asyncio
import shutil
from pathlib import Path
import httpx
from config import settings


async def check_available() -> bool:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{settings.comfyui_base_url}/system_stats")
            return r.status_code == 200
    except Exception:
        return False


async def get_available_models() -> list[str]:
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(f"{settings.comfyui_base_url}/object_info/CheckpointLoaderSimple")
            data = r.json()
            return data.get("CheckpointLoaderSimple", {}).get("input", {}).get("required", {}).get("ckpt_name", [[]])[0]
    except Exception:
        return []


def build_t2i_workflow(
    prompt: str,
    negative_prompt: str = "",
    seed: int = -1,
    steps: int = 20,
    cfg_scale: float = 7.0,
    width: int = 768,
    height: int = 512,
    model: str = "v1-5-pruned-emaonly.safetensors",
    output_prefix: str = "storyboard",
) -> dict:
    if seed == -1:
        import random
        seed = random.randint(0, 2**32 - 1)

    return {
        "3": {
            "inputs": {
                "seed": seed,
                "steps": steps,
                "cfg": cfg_scale,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1.0,
                "model": ["4", 0],
                "positive": ["6", 0],
                "negative": ["7", 0],
                "latent_image": ["5", 0],
            },
            "class_type": "KSampler",
        },
        "4": {
            "inputs": {"ckpt_name": model},
            "class_type": "CheckpointLoaderSimple",
        },
        "5": {
            "inputs": {"width": width, "height": height, "batch_size": 1},
            "class_type": "EmptyLatentImage",
        },
        "6": {
            "inputs": {"text": prompt, "clip": ["4", 1]},
            "class_type": "CLIPTextEncode",
        },
        "7": {
            "inputs": {"text": negative_prompt or "blurry, low quality, distorted, ugly, bad anatomy", "clip": ["4", 1]},
            "class_type": "CLIPTextEncode",
        },
        "8": {
            "inputs": {"samples": ["3", 0], "vae": ["4", 2]},
            "class_type": "VAEDecode",
        },
        "9": {
            "inputs": {"filename_prefix": output_prefix, "images": ["8", 0]},
            "class_type": "SaveImage",
        },
    }


async def queue_prompt(workflow: dict) -> str:
    client_id = str(uuid.uuid4())
    payload = {"prompt": workflow, "client_id": client_id}
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(f"{settings.comfyui_base_url}/prompt", json=payload)
        r.raise_for_status()
        return r.json()["prompt_id"]


async def wait_for_job(prompt_id: str, timeout: int = 300) -> dict:
    deadline = asyncio.get_event_loop().time() + timeout
    async with httpx.AsyncClient(timeout=10) as client:
        while asyncio.get_event_loop().time() < deadline:
            r = await client.get(f"{settings.comfyui_base_url}/history/{prompt_id}")
            history = r.json()
            if prompt_id in history:
                job = history[prompt_id]
                if job.get("status", {}).get("completed"):
                    return job
            await asyncio.sleep(2)
    raise TimeoutError(f"ComfyUI job {prompt_id} timed out after {timeout}s")


def _parse_resolution(resolution: str) -> tuple[int, int]:
    parts = resolution.lower().replace("x", " ").replace("×", " ").split()
    if len(parts) == 2:
        try:
            return int(parts[0]), int(parts[1])
        except ValueError:
            pass
    presets = {
        "768x512": (768, 512),
        "512x512": (512, 512),
        "1024x576": (1024, 576),
        "1920x1080": (1920, 1080),
    }
    return presets.get(resolution, (768, 512))


PREFERRED_MODELS = [
    "dreamshaper_8.safetensors",
    "dreamshaper_XL.safetensors",
    "v1-5-pruned-emaonly-fp16.safetensors",
    "v1-5-pruned-emaonly.safetensors",
]


async def generate_storyboard_image(
    prompt: str,
    negative_prompt: str = "",
    seed: int = -1,
    steps: int = 20,
    cfg_scale: float = 7.0,
    resolution: str = "768x512",
    model: str | None = None,
    output_prefix: str = "storyboard",
) -> dict:
    """
    Submit a text-to-image job to ComfyUI and return info about the result.
    Returns: {"prompt_id": str, "seed": int, "status": "queued"|"mock"}
    """
    width, height = _parse_resolution(resolution)

    available_models = await get_available_models()
    if model and model in available_models:
        chosen_model = model
    else:
        chosen_model = next(
            (m for m in PREFERRED_MODELS if m in available_models),
            available_models[0] if available_models else "dreamshaper_8.safetensors",
        )

    import random
    actual_seed = seed if seed >= 0 else random.randint(0, 2**32 - 1)

    workflow = build_t2i_workflow(
        prompt=prompt,
        negative_prompt=negative_prompt,
        seed=actual_seed,
        steps=steps,
        cfg_scale=cfg_scale,
        width=width,
        height=height,
        model=chosen_model,
        output_prefix=output_prefix,
    )

    prompt_id = await queue_prompt(workflow)
    return {"prompt_id": prompt_id, "seed": actual_seed, "model": chosen_model, "status": "queued"}


async def get_output_images(prompt_id: str) -> list[str]:
    """Wait for job completion and return local file paths of output images."""
    job = await wait_for_job(prompt_id)
    outputs = job.get("outputs", {})
    paths: list[str] = []

    comfy_output = Path(settings.comfyui_output_dir)

    for node_id, node_output in outputs.items():
        for img in node_output.get("images", []):
            filename = img["filename"]
            subfolder = img.get("subfolder", "")
            src = (Path(comfy_output) / subfolder / filename) if subfolder else (comfy_output / filename)
            if src.exists():
                paths.append(str(src))

    return paths


async def copy_output_to_project(prompt_id: str, dest_folder: Path, prefix: str = "storyboard") -> list[str]:
    """Copy completed ComfyUI outputs to the project folder."""
    src_paths = await get_output_images(prompt_id)
    dest_folder.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for i, src in enumerate(src_paths):
        ext = Path(src).suffix
        dest = dest_folder / f"{prefix}_{i+1}{ext}"
        shutil.copy2(src, dest)
        copied.append(str(dest))
    return copied
