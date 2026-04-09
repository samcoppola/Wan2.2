#!/usr/bin/env python3
"""
Wan2.2 — Model Download Manager

Usage:
    python download.py <model> [<model> ...]

Available models:
    i2v-a14b   I2V MoE A14B: T5 + VAE + dual expert transformers (~52 GB)
               Best quality — supports camera motion — requires 80 GB VRAM (single GPU)
               or 40 GB with offload flags.

    ti2v-5b    TI2V 5B: T5 + high-compression VAE + model (~18 GB)
               Budget option — runs on 24 GB VRAM — 720P @ 24 fps.

Examples:
    python download.py i2v-a14b             # max quality I2V  (~52 GB)
    python download.py ti2v-5b              # lighter I2V      (~18 GB)

Environment:
    HF_TOKEN   HuggingFace Classic token (read access is enough)
               export HF_TOKEN="hf_..."
"""
import os
import sys

os.environ["HF_HUB_DISABLE_XET"] = "1"
from huggingface_hub import snapshot_download

HF_TOKEN = os.environ.get("HF_TOKEN")
if not HF_TOKEN:
    print("ERROR: HF_TOKEN not set.")
    print("       Run: export HF_TOKEN='hf_...'")
    sys.exit(1)

# Each model downloads into its own directory at the repo root,
# matching the --ckpt_dir convention expected by generate.py.
MODELS = {
    "i2v-a14b": {
        "desc": "I2V MoE A14B — T5 (umt5-xxl) + VAE + low_noise + high_noise experts (~52 GB)",
        "repo": "Wan-AI/Wan2.2-I2V-A14B",
        "local_dir": "./Wan2.2-I2V-A14B",
        "check_file": "./Wan2.2-I2V-A14B/low_noise_model",
    },
    "ti2v-5b": {
        "desc": "TI2V 5B — T5 + high-compression VAE (16×16×4) + model (~18 GB)",
        "repo": "Wan-AI/Wan2.2-TI2V-5B",
        "local_dir": "./Wan2.2-TI2V-5B",
        "check_file": "./Wan2.2-TI2V-5B",
    },
}


def is_downloaded(path):
    return os.path.exists(path) and len(os.listdir(path)) > 1


def download_model(name):
    if name not in MODELS:
        print(f"ERROR: Unknown model '{name}'.")
        print(f"Available: {', '.join(MODELS.keys())}")
        sys.exit(1)

    m = MODELS[name]
    print(f"\n{'='*60}")
    print(f"  {name}  —  {m['desc']}")
    print(f"{'='*60}")

    if is_downloaded(m["check_file"]):
        print(f"  Already present ({m['check_file']}) — skipping.")
        return

    print(f"  Downloading from HuggingFace: {m['repo']} ...")
    os.makedirs(m["local_dir"], exist_ok=True)
    snapshot_download(
        repo_id=m["repo"],
        local_dir=m["local_dir"],
        token=HF_TOKEN,
        local_dir_use_symlinks=False,
    )
    print(f"  Done → {m['local_dir']}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    for model_name in sys.argv[1:]:
        download_model(model_name)

    print("\nAll requested models downloaded.")
