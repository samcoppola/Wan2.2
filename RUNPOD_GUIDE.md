# Wan 2.2 — Guida Personale RunPod

## Modello attuale: I2V-A14B

| Parametro | Valore |
|-----------|--------|
| Modello | `Wan2.2-I2V-A14B` (MoE 14B attivati) |
| Task | Image-to-Video |
| Risoluzione | 720P (`1280*720`) |
| Frame | 81 (~5s @ 16fps) |
| Steps | 40 |
| GPU richiesta | A100 SXM **80 GB** |
| Flag obbligatori | `--offload_model True --convert_model_dtype` |
| Peso su disco | ~97 GB |
| Network Volume | **200 GB** |

> **NO `--t5_cpu`** su A100 80GB — mette il T5 encoder (11GB) su CPU causando stalli di 20+ min.
> `--t5_cpu` è solo per GPU da 24GB (RTX 4090).

---

## Setup da zero (nuovo workspace)

### Step 1 — Crea il Network Volume
- RunPod → **Storage** → **New Network Volume**
- Size: **200 GB**
- Stessa region dove creerai i pod

### Step 2 — Pod CPU (download modelli, ~$0.05)
- Deploy → CPU pod (qualsiasi template)
- Attacca il Network Volume → `/workspace`
- Nel terminale:
```bash
export HF_TOKEN="hf_..."
cd /workspace
git clone https://github.com/samcoppola/Wan2.2.git
cd Wan2.2
export HF_HOME=/workspace/.hf_cache
python3.13 -m pip install -q huggingface_hub
python3.13 download.py i2v-a14b
```
- Aspetta ~40-80 min (97 GB). Quando finisce → **Stop** pod CPU.

### Step 3 — Pod GPU A100 SXM 80GB (setup dipendenze, ~20 min, una volta sola)
- Deploy → **A100 SXM 80GB**
- Template: `RunPod PyTorch 2.4` (CUDA 12.4)
- Attacca **stesso** Network Volume → `/workspace`
- Nel terminale:
```bash
cd /workspace/Wan2.2 && git pull
bash setup_runpod.sh
```
- Installa tutto inclusa flash_attn. Al termine crea `/workspace/.venv/setup_complete`.
- Carica `appia_strada.png` via **Jupyter Lab** in `/workspace/Wan2.2/`

### Step 4 — Genera
```bash
source /workspace/.venv/bin/activate
bash run_via_appia.sh
```
Output: `./outputs/via_appia_wan22.mp4`

---

## Riaprire un pod esistente (workspace già pronto)

```bash
touch /workspace/.venv/setup_complete   # evita reinstallazione
cd /workspace/Wan2.2 && git pull
source /workspace/.venv/bin/activate
bash run_via_appia.sh
```

---

## Tutti i modelli Wan 2.2

| Modello | Task | Risoluzione | GPU min | Disco |
|---------|------|-------------|---------|-------|
| **I2V-A14B** | Image→Video | 720P / 480P | 80 GB | ~97 GB |
| **T2V-A14B** | Text→Video | 720P / 480P | 80 GB | ~97 GB |
| **TI2V-5B** | Text+Image→Video | 720P @ 24fps | 24 GB | ~18 GB |
| **S2V-14B** | Speech+Image→Video | 720P / 480P | 80 GB | ~30 GB |
| **Animate-14B** | Character animation/replacement | 720P | 80 GB | ~30 GB |

### Scaricare altri modelli
```bash
python3.13 download.py i2v-a14b    # ~97 GB — già scaricato
python3.13 download.py ti2v-5b     # ~18 GB — leggero, gira su 4090
```

### TI2V-5B (budget, 4090 o A100 40GB)
```bash
python generate.py --task ti2v-5B --size 1280*704 \
    --ckpt_dir ./Wan2.2-TI2V-5B \
    --offload_model True --convert_model_dtype --t5_cpu \
    --image ./appia_strada.png \
    --prompt "..."
```

---

## Capacità di Wan 2.2

### Camera motion (punto di forza vs HunyuanVideo)
Wan 2.2 comprende descrizioni di camera motion nel prompt di testo:

| Movimento | Come scriverlo nel prompt |
|-----------|--------------------------|
| Dolly avanti | `camera slowly moves forward`, `slow dolly in` |
| Pan destra/sinistra | `camera pans right`, `camera turns to look left` |
| Tilt su/giù | `camera tilts up`, `looking down` |
| Walking POV | `first-person walking view`, `camera bobs gently with footsteps` |
| Orbita | `camera orbits around`, `circular camera movement` |
| Zoom | `slow zoom in`, `camera pulls back` |
| Sequenza | descrivila temporalmente: `first... then... finally...` |

> Wan 2.2 **non ha un sistema di camera control parametrico** (tipo CameraCtrl o RealDreamer) — il controllo avviene tramite linguaggio naturale nel prompt. Funziona bene per movimenti semplici e sequenze moderate.

### Altre capacità
- **MoE architecture**: due expert separati per low-noise e high-noise timesteps → qualità superiore
- **Complex motion**: addestrato su +83% più video rispetto a Wan 2.1
- **Cinematic aesthetics**: dati di training con label per lighting, composizione, color tone
- **TI2V-5B**: VAE ad alta compressione (16×16×4), supporta sia T2V che I2V a 720P@24fps
- **S2V**: genera video sincronizzato con audio/speech
- **Animate**: rimpiazza/anima personaggi seguendo il motion di un video di riferimento

### Differenze chiave vs HunyuanVideo 1.5
| Feature | HunyuanVideo 1.5 | Wan 2.2 I2V-A14B |
|---------|-----------------|-----------------|
| Camera motion | Limitato | Buono (prompt-based) |
| SR 1080p integrato | Sì (sr-1080p) | No (nativo 720P) |
| Prompt lingua | Cinese (rewrite) | Inglese/Cinese |
| VRAM necessaria | A100 40GB | A100 80GB |
| Modello leggero | — | TI2V-5B (24GB) |

---

## Problemi noti e soluzioni

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| GPU 0% per 20+ min | `--t5_cpu` su GPU grande | Rimuovere `--t5_cpu` |
| CUDA OOM | Solo `--offload_model` senza `--convert_model_dtype` | Aggiungere `--convert_model_dtype` |
| `Disk quota exceeded` | Download su storage condiviso senza Network Volume | Creare Network Volume 200GB |
| flash_attn cross-device error | TMPDIR su filesystem diverso da pip cache | `unset TMPDIR` oppure `PIP_CACHE_DIR=/workspace/.pip_cache` |
| torch CUDA mismatch | pip installa torch 2.11 (CUDA 13.0) su sistema CUDA 12.4 | `pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cu124` |
| venv perso al nuovo pod | venv era in `/root/.venv` (locale) | venv ora in `/workspace/.venv` (persiste) |

---

## Costi di riferimento RunPod

| Risorsa | Tipo | Costo/h |
|---------|------|---------|
| A100 SXM 80GB | GPU pod | ~$3.99 |
| A100 PCIe 40GB | GPU pod | ~$1.99 |
| CPU pod | Download | ~$0.02-0.05 |
| Network Volume 200GB | Storage | ~$0.03/h |

Generazione Via Appia (81 frame, 720P, offload): ~30-45 min → ~$2-3 a run.
