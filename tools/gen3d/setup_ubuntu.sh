#!/usr/bin/env bash
# Step 2 (inside Ubuntu 22.04 on WSL2):  bash setup_ubuntu.sh
#
# Installs the CUDA 12.4 toolkit for WSL, Miniconda, TRELLIS.2 and its CUDA
# extensions (the official setup.sh), into ~/gen3d. Takes 30-90 minutes the
# first time because several extensions are compiled.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="${GEN3D_ROOT:-$HOME/gen3d}"
mkdir -p "$ROOT"
cd "$ROOT"

echo "== GPUs visible from WSL =="
nvidia-smi || { echo "No GPU in WSL: update the Windows NVIDIA driver and run 'wsl --update'."; exit 1; }

echo "== System packages =="
sudo apt-get update
sudo apt-get install -y build-essential git wget curl ninja-build libgl1 libglib2.0-0 libegl1 ffmpeg

echo "== CUDA Toolkit 12.4 (WSL-Ubuntu build: no driver inside WSL) =="
if [ ! -d /usr/local/cuda-12.4 ]; then
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt-get update
  sudo apt-get install -y cuda-toolkit-12-4
fi
export CUDA_HOME=/usr/local/cuda-12.4
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
grep -q "cuda-12.4" ~/.bashrc || cat >> ~/.bashrc <<'EOF'
export CUDA_HOME=/usr/local/cuda-12.4
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
# RTX 3090 = compute capability 8.6: only build CUDA code for it (much faster)
export TORCH_CUDA_ARCH_LIST="8.6"
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
EOF
export TORCH_CUDA_ARCH_LIST="8.6"
nvcc --version

echo "== Miniconda =="
if [ ! -d "$HOME/miniconda3" ]; then
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
  bash miniconda.sh -b -p "$HOME/miniconda3"
  "$HOME/miniconda3/bin/conda" init bash
fi
# conda's own scripts use unset variables
set +u
# shellcheck disable=SC1091
source "$HOME/miniconda3/etc/profile.d/conda.sh"

echo "== TRELLIS.2 =="
if [ ! -d TRELLIS.2 ]; then
  git clone -b main https://github.com/microsoft/TRELLIS.2.git --recursive
fi
cd TRELLIS.2
# Building flash-attn and the other extensions uses a lot of RAM: limit jobs.
export MAX_JOBS="${MAX_JOBS:-4}"
# The official installer (creates the 'trellis2' conda env with PyTorch 2.6 + CUDA 12.4).
# shellcheck disable=SC1091
. ./setup.sh --new-env --basic --flash-attn --nvdiffrast --nvdiffrec --cumesh --o-voxel --flexgemm

conda activate trellis2
pip install "huggingface_hub[cli]" scipy

echo "== Quick check =="
python - <<'EOF'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
for i in range(torch.cuda.device_count()):
    p = torch.cuda.get_device_properties(i)
    print(f"GPU {i}: {p.name} {p.total_memory / 2**30:.1f} GB")
import trellis2, o_voxel  # noqa: F401
print("TRELLIS.2 imports OK")
EOF

echo
echo "Installed in $ROOT/TRELLIS.2 (conda env: trellis2)."
echo "Next: conda activate trellis2 && python $HERE/generate.py --help"
