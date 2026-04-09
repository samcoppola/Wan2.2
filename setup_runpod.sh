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
#   - Network Volume /workspace con i modelli già scaricati (setup_cpu.sh)
#   - GPU con CUDA disponibile (A100 SXM 80 GB raccomandato)
#   - Template RunPod: PyTorch 2.4+ / CUDA 12.4 devel
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/Wan2.2"
VENV="/root/.venv"

echo "============================================================"
echo " Wan2.2 — RunPod GPU Setup"
echo "============================================================"

# ── 1. Clone / pull repo ──────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/4] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/Wan2.2.git
else
    echo "[1/4] Repo già presente, pull..."
    cd "$REPO_DIR"
    git pull
fi
cd "$REPO_DIR"

# ── 2. Crea venv Python 3.11 ──────────────────────────────────────
echo ""
echo "[2/4] Configuro Python virtual environment..."

if ! command -v python3.11 &>/dev/null; then
    apt-get update -q && apt-get install -y python3.11 python3.11-venv
fi

if [ ! -d "$VENV" ]; then
    python3.11 -m venv "$VENV"
fi
source "$VENV/bin/activate"

pip install --upgrade pip -q

# ── 3. Installa dipendenze ────────────────────────────────────────
echo ""
echo "[3/4] Installo dipendenze (requirements.txt + flash_attn)..."

# Installa le dipendenze base prima (torch 2.4+ dovrebbe essere già nel template,
# ma reinstallare non fa danni — requirements.txt lo gestisce)
pip install -r requirements.txt

# flash_attn deve essere installata con --no-build-isolation
# perché richiede torch già installato nell'ambiente
echo "  Installo flash_attn (pochi minuti, compila da sorgente)..."
pip install flash_attn --no-build-isolation

echo "    Dipendenze installate."

# ── 4. Verifica struttura checkpoint ─────────────────────────────
echo ""
echo "[4/4] Verifico checkpoint I2V-A14B..."

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
    print("\nAlcuni file mancano — riesegui: python download.py i2v-a14b")
PYEOF

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Setup completato!"
echo "============================================================"
echo ""
echo "Prossimi passi:"
echo ""
echo "  1. Carica appia_strada.png in:"
echo "     $REPO_DIR/appia_strada.png"
echo "     (via Jupyter file browser o scp)"
echo ""
echo "  2. Genera (I2V massima qualità, ~10-15 min su A100 80 GB):"
echo "     cd $REPO_DIR && bash run_via_appia.sh"
echo ""
echo "  Output: ./outputs/via_appia_wan22.mp4"
echo "============================================================"
