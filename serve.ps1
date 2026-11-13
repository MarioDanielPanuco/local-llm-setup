# Start llama-server on the RTX 5080 with an OpenAI-compatible API.
#
#   .\serve.ps1 -Model <hf-user>/<repo>[:quant]     # download from Hugging Face (cached)
#   .\serve.ps1 -Model .\models\some-model.gguf     # local GGUF file
#
# API:    http://127.0.0.1:8080/v1
# Web UI: http://127.0.0.1:8080
#
# Set $env:HF_TOKEN beforehand for gated repos / higher download rate limits.
# Extra llama-server flags can be appended, e.g.  .\serve.ps1 -Model ... --api-key secret

param(
    [Parameter(Mandatory = $true)][string]$Model,
    [int]$Port = 8080,
    [int]$Ctx = 32768,      # 0 = model's trained context size (can be 256k+ and exhaust VRAM)
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra
)

$server = Join-Path $PSScriptRoot 'llama.cpp\llama-server.exe'

if (Test-Path -LiteralPath $Model) {
    $modelArgs = @('-m', (Resolve-Path -LiteralPath $Model).Path)
} else {
    $modelArgs = @('-hf', $Model)
}

& $server @modelArgs `
    --host 127.0.0.1 --port $Port `
    -ngl 999 `
    -c $Ctx `
    @Extra
