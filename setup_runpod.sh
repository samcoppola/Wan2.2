#!/bin/bash
# =============================================================================
# RunPod GPU Setup — Wan2.2 I2V  (esegui sul pod A100 dopo setup_cpu.sh)
# =============================================================================
# Crea il venv Python, installa tutte le dipendenze inclusa flash_attn.
# I modelli dovrebbero già essere presenti sul Network Volume dopo setup_cpu.sh.
#
# Usage:
#   bash setup_runpod.sh
#
# Requisiti:
#   - Network Volume /workspace 200 GB con modelli già scaricati (setup_cpu.sh)
#   - GPU A100 SXM 80 GB (o 40 GB con offload auto)
#   - Template RunPod: PyTorch 2.4+ / CUDA 12.4 devel
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/Wan2.2"
VENV="/root/.venv"

# Usa /workspace come TMPDIR: il container / è solo ~5 GB,
# SAM-2 e flash_attn compilano file temporanei grandi.
export TMPDIR="$WORKSPACE/tmp"
mkdir -p "$TMPDIR"

echo "============================================================"
echo " Wan2.2 — RunPod GPU Setup"
echo "============================================================"

# ── 1. Clone / pull repo ──────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/5] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/Wan2.2.git
else
    echo "[1/5] Repo già presente, pull..."
    cd "$REPO_DIR"
    git pull
fi
cd "$REPO_DIR"

# ── 2. Crea venv Python 3.11 ──────────────────────────────────────
echo ""
echo "[2/5] Configuro Python virtual environment..."

if ! command -v python3.11 &>/dev/null; then
    apt-get update -q && apt-get install -y python3.11 python3.11-venv
fi

if [ ! -d "$VENV" ]; then
    python3.11 -m venv "$VENV"
fi
source "$VENV/bin/activate"

pip install --upgrade pip wheel setuptools -q

# ── 3. Installa PyTorch per CUDA 12.4 ────────────────────────────
# IMPORTANTE: requirements.txt specifica torch>=2.4.0 che prende l'ultima
# versione (compilata con CUDA 13.0). La installa prima specificando
# l'index cu124 così pip non la aggiorna.
echo ""
echo "[3/5] Installo PyTorch 2.5.1 per CUDA 12.4..."

WHLURL=https://download.pytorch.org/whl/cu124
pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url $WHLURL -q

echo "    PyTorch installato."

# ── 4. Installa dipendenze progetto ───────────────────────────────
echo ""
echo "[4/5] Installo dipendenze (requirements + s2v + animate + flash_attn)..."

# requirements.txt: escludi torch/torchvision/torchaudio (già installati) e flash_attn
grep -vE "^torch(vision|audio)?|flash_attn" requirements.txt > /tmp/req_base.txt
pip install -r /tmp/req_base.txt -q

# requirements_s2v.txt: dipendenze audio/video per WanS2V
pip install -r requirements_s2v.txt -q

# requirements_animate.txt: escludi SAM-2 (si installa separatamente sotto)
grep -v "sam2\|SAM-2" requirements_animate.txt > /tmp/req_anim.txt
pip install -r /tmp/req_anim.txt -q

# SAM-2: --no-build-isolation usa il torch già nel venv,
# evita di scaricare CUDA packages in /tmp (che è solo 5 GB)
echo "  Installo SAM-2 (build da git, ~3 min)..."
SAM2_URL=git+https://github.com/facebookresearch/sam2.git@0e78a118995e66bb27d78518c4bd9a3e95b4e266
pip install --no-build-isolation "$SAM2_URL" -q

# flash_attn: compilazione CUDA ~10 min, richiede torch già presente
echo "  Installo flash_attn (compilazione CUDA, ~10 min)..."
pip install flash_attn --no-build-isolation

echo "    Tutte le dipendenze installate."

# ── 5. Verifica struttura checkpoint ─────────────────────────────
echo ""
echo "[5/5] Verifico checkpoint I2V-A14B..."

"$VENV/bin/python" - <<'PYEOF'
import os

base = "/workspace/Wan2.2/Wan2.2-I2V-A14B"
required = [
    "models_t5_umt5-xxl-enc-bf16.pth",
    "Wan2.1_VAE.pth",
    "low_noise_model",
    "high_noise_model",
]

all_ok = True
for item in required:
    full = os.path.join(base, item)
    status = "OK" if os.path.exists(full) else "MISSING"
    if status == "MISSING":
        all_ok = False
    print(f"  [{status}] {item}")

if all_ok:
    print("\nTutti i checkpoint trovati. Pronto per I2V massima qualità!")
else:
    print("\nAlcuni file mancano — riesegui: python3.13 download.py i2v-a14b")
PYEOF

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Setup completato!"
echo "============================================================"
echo ""
echo "  1. Carica appia_strada.png in /workspace/Wan2.2/ via Jupyter Lab"
echo "  2. Genera:"
echo "     cd /workspace/Wan2.2 && bash run_via_appia.sh"
echo "  Output: ./outputs/via_appia_wan22.mp4"
echo "============================================================"
