# Download the newest official llama.cpp Windows build into .\llama.cpp
#
#   .\setup.ps1                    # auto: CUDA 13 if an NVIDIA GPU is found, otherwise Vulkan
#   .\setup.ps1 -Backend cuda12    # older NVIDIA drivers
#   .\setup.ps1 -Backend vulkan    # AMD / Intel GPUs
#
# Re-run any time to update to the newest build.
# Source: https://github.com/ggml-org/llama.cpp/releases (official binaries only).

param(
    [ValidateSet('auto', 'cuda13', 'cuda12', 'vulkan')][string]$Backend = 'auto',
    [string]$InstallDir = (Join-Path $PSScriptRoot 'llama.cpp')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on

if ($Backend -eq 'auto') {
    $hasNvidia = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)
    $Backend = if ($hasNvidia) { 'cuda13' } else { 'vulkan' }
    Write-Host "Backend: $Backend (auto-detected)"
}

# Asset name patterns. CUDA builds also need the matching CUDA runtime zip.
$patterns = switch ($Backend) {
    'cuda13' { '^llama-.*-bin-win-cuda-13\.[\d.]+-x64\.zip$', '^cudart-llama-bin-win-cuda-13\.[\d.]+-x64\.zip$' }
    'cuda12' { '^llama-.*-bin-win-cuda-12\.[\d.]+-x64\.zip$', '^cudart-llama-bin-win-cuda-12\.[\d.]+-x64\.zip$' }
    'vulkan' { '^llama-.*-bin-win-vulkan-x64\.zip$' }
}

# The "latest" release can be a placeholder without binaries, so take the
# newest release that actually has the files we need.
$releases = Invoke-RestMethod 'https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=10' -Headers @{ 'User-Agent' = 'llama-setup-script' }
$release = $null
$assets = @()
foreach ($r in $releases) {
    $found = foreach ($p in $patterns) { $r.assets | Where-Object { $_.name -match $p } | Select-Object -First 1 }
    if (@($found).Count -eq @($patterns).Count) { $release = $r; $assets = @($found); break }
}
if (-not $release) { throw "No recent llama.cpp release has a '$Backend' Windows build. Check https://github.com/ggml-org/llama.cpp/releases" }

Write-Host "Release: $($release.tag_name)"
$tmp = Join-Path ([IO.Path]::GetTempPath()) "llama-setup-$($release.tag_name)"
New-Item -ItemType Directory -Force $tmp, $InstallDir | Out-Null

foreach ($a in $assets) {
    $zip = Join-Path $tmp $a.name
    Write-Host ("Downloading {0} ({1:N0} MB)" -f $a.name, ($a.size / 1MB))
    Invoke-WebRequest $a.browser_download_url -OutFile $zip
    if ((Get-Item $zip).Length -ne $a.size) { throw "Size mismatch for $($a.name) - download incomplete, run again." }
    Expand-Archive -Force $zip $InstallDir
}
Remove-Item -Recurse -Force $tmp

$server = Join-Path $InstallDir 'llama-server.exe'
Write-Host ''
& $server --version
Write-Host ''
& $server --list-devices
Write-Host ''
Write-Host 'Done. If no GPU is listed above, update your graphics driver (or try -Backend cuda12 / vulkan).'
