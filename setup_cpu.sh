#!/bin/bash
# =============================================================================
# RunPod CPU Setup — clone + download Wan2.2  (NO GPU needed)
# =============================================================================
# Esegui su un pod CPU economico (~$0.02-0.05/h) prima di avviare la A100.
# Il Network Volume viene riempito qui; la A100 troverà già tutto pronto.
#
# Usage:
#   export HF_TOKEN="hf_..."
#   bash setup_cpu.sh
#
# Pod consigliato:
#   RunPod CPU pod — qualsiasi template con 4 vCPU / 16 GB RAM va bene
#   Network Volume: 150 GB montato su /workspace
#
# Tempo stimato: 40-80 min (dipende dalla velocità di rete RunPod)
# Costo stimato: ~$0.03-0.08 totali su CPU pod
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/Wan2.2"

echo "============================================================"
echo " Wan2.2 — CPU Setup (clone + download)"
echo "============================================================"

if [ -z "$HF_TOKEN" ]; then
    echo "ERROR: HF_TOKEN non impostato."
    echo "  export HF_TOKEN='hf_...'   (token Classic, read access)"
    exit 1
fi

# ── 1. Clone repo ─────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/3] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/Wan2.2.git
else
    echo "[1/3] Repo già presente, pull..."
    cd "$REPO_DIR"
    git pull
fi
cd "$REPO_DIR"

# ── 2. Installa huggingface_hub (basta per il download) ───────────
# Non creiamo il venv qui: flash_attn richiede CUDA disponibile.
# Il venv completo viene creato dopo su GPU con setup_runpod.sh.
echo ""
echo "[2/3] Installo huggingface_hub nel Python di sistema..."
python3 -m pip install -q huggingface_hub
echo "    OK."

# ── 3. Scarica il modello I2V-A14B (~52 GB) ───────────────────────
echo ""
echo "[3/3] Download Wan2.2-I2V-A14B (~52 GB)..."
echo "      Include: T5 umt5-xxl encoder, VAE, low_noise e high_noise transformers"
echo ""

python3 download.py i2v-a14b

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Download completato!"
echo "============================================================"
echo ""
echo "Prossimi passi:"
echo ""
echo "  1. Ferma questo pod CPU."
echo ""
echo "  2. Crea un pod A100 SXM 80 GB attaccando lo STESSO"
echo "     Network Volume (deve essere /workspace)."
echo "     Template: RunPod PyTorch 2.4 — CUDA 12.4"
echo ""
echo "  3. Sul pod A100:"
echo "     cd $REPO_DIR"
echo "     bash setup_runpod.sh      # crea venv + pip install (skip download)"
echo ""
echo "  4. Carica appia_strada.png via Jupyter o scp in:"
echo "     $REPO_DIR/appia_strada.png"
echo ""
echo "  5. Genera:"
echo "     cd $REPO_DIR && bash run_via_appia.sh"
echo "============================================================"
