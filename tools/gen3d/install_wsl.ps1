# Step 1 (Windows, PowerShell as Administrator):
#   Set-ExecutionPolicy -Scope Process Bypass; .\install_wsl.ps1
#
# Installs WSL2 with Ubuntu 22.04. TRELLIS.2 is only tested on Linux, and WSL2
# gives Linux full access to the RTX cards through the normal Windows driver.
# Do NOT install an NVIDIA driver inside Ubuntu: the Windows driver is shared.

$ErrorActionPreference = "Stop"

Write-Host "== Checking the NVIDIA driver on Windows ==" -ForegroundColor Cyan
try {
    nvidia-smi
} catch {
    Write-Host "nvidia-smi not found. Install the latest Game Ready or Studio driver from nvidia.com first, then rerun." -ForegroundColor Red
    exit 1
}

Write-Host "== Installing WSL2 + Ubuntu 22.04 ==" -ForegroundColor Cyan
wsl --update
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2

# Give WSL enough memory and swap for building CUDA extensions and loading
# the 4B model (adjust memory to about 3/4 of your RAM).
$cfg = "$env:USERPROFILE\.wslconfig"
if (-not (Test-Path $cfg)) {
    @"
[wsl2]
memory=24GB
swap=32GB
processors=8
"@ | Set-Content -Path $cfg -Encoding ASCII
    Write-Host "Wrote $cfg (edit memory/processors to match your PC)."
}

Write-Host ""
Write-Host "Done. Restart Windows if asked, open 'Ubuntu 22.04' from the Start menu," -ForegroundColor Green
Write-Host "create your Linux user, then run tools/gen3d/setup_ubuntu.sh inside Ubuntu." -ForegroundColor Green
