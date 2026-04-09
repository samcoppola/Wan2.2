#!/bin/bash
# ============================================================
# Via Appia Antica — Wan2.2 I2V A14B, massima qualità
# ============================================================
# Modello richiesto:
#   python download.py i2v-a14b
# GPU minima: A100 40 GB (con --offload_model True --convert_model_dtype)
# GPU raccomandata: A100 SXM 80 GB  (nessun offload, più veloce)
# Tempo stimato: ~10-15 min su A100 80 GB
# ============================================================
set -e

cd /workspace/Wan2.2
source /root/.venv/bin/activate

IMAGE_PATH="./appia_strada.png"
if [ ! -f "$IMAGE_PATH" ]; then
    echo "ERROR: immagine non trovata in $IMAGE_PATH"
    echo "       Carica appia_strada.png nella root del repo."
    exit 1
fi

mkdir -p ./outputs

# ── Rilevamento VRAM ──────────────────────────────────────────────
# Se la GPU ha < 75 GB di VRAM libera, attiva l'offload su CPU.
VRAM_GB=$(python -c "import torch; print(int(torch.cuda.get_device_properties(0).total_memory / 1e9))" 2>/dev/null || echo "0")
echo "VRAM disponibile: ~${VRAM_GB} GB"

OFFLOAD_FLAGS=""
# I2V-A14B occupa ~78 GB di pesi: anche su A100 80 GB
# non resta abbastanza VRAM per le attivazioni a 720P.
# --offload_model True sposta i layer su CPU tra un forward e l'altro
# (più lento ma non va OOM). Sempre attivo per questo modello.
echo "  Attivo offload_model + t5_cpu + convert_dtype"
OFFLOAD_FLAGS="--offload_model True --t5_cpu --convert_model_dtype"

# ── Prompt ────────────────────────────────────────────────────────
# Conciso e focalizzato: Wan2.2 comprende bene i comandi camera motion.
# Mantenerlo sotto 150 parole per il T5 umt5-xxl (512 token limit).
# Il negative prompt in cinese è applicato automaticamente dal modello.

PROMPT="First-person slow forward walk along the Via Appia Antica, ancient Rome Imperial period. The camera moves steadily forward at eye level along the ancient basalt cobblestone road. The camera gently pans left and right, pausing to observe monumental Roman tombs, mausoleums and funerary monuments with columns, carved reliefs and marble statues lining both sides of the road. A few distant Roman figures in white tunics walk slowly ahead. Sparse vegetation: dry grass, low shrubs and tall Roman umbrella pine trees. Warm golden natural sunlight, soft shadows, slight dusty atmospheric haze. Cinematic depth of field. Ultra-realistic, photorealistic, historically accurate, no modern elements."

# ── Parametri massima qualità ─────────────────────────────────────
# --task i2v-A14B        : modello MoE 14B per I2V
# --size 1280*720        : area target 720P (l'aspect ratio segue l'immagine input)
# --frame_num 97         : 97 frames @ 16 fps = ~6 secondi (4n+1)
# --sample_steps 40      : default ottimale per I2V-A14B
# --sample_shift 5.0     : default del modello
# --sample_guide_scale 3.5: default per I2V-A14B (dual scale: low=3.5, high=3.5)
# --sample_solver unipc  : solver migliore per qualità

python generate.py \
    --task i2v-A14B \
    --size 1280*720 \
    --ckpt_dir ./Wan2.2-I2V-A14B \
    --image "$IMAGE_PATH" \
    --frame_num 81 \
    --sample_steps 40 \
    --sample_shift 5.0 \
    --sample_solver unipc \
    --save_file ./outputs/via_appia_wan22.mp4 \
    --prompt "$PROMPT" \
    $OFFLOAD_FLAGS

echo ""
echo "Done!"
echo "  Video: ./outputs/via_appia_wan22.mp4"
echo "  Frames: 81 @ 16 fps = ~5 secondi"
