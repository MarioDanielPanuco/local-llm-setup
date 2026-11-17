# Local LLM on a gaming PC

Run an AI model on your own graphics card with [llama.cpp](https://github.com/ggml-org/llama.cpp).
No account, no subscription, nothing leaves your PC.

You get:

- a chat page in your browser at <http://127.0.0.1:8080>
- an OpenAI-compatible API at `http://127.0.0.1:8080/v1` that other apps can use

## Requirements

- Windows 10/11, 64-bit
- A GPU with 8 GB+ of VRAM (NVIDIA recommended; AMD/Intel work through Vulkan)
- An up-to-date graphics driver
- About 15 GB of free disk space

## 1. Get the files

Download this repo (green **Code** button → **Download ZIP**, then unzip), or:

```powershell
git clone https://github.com/MarioDanielPanuco/local-llm-setup.git
```

Open PowerShell in the folder.

## 2. Install llama.cpp

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

This downloads the newest official llama.cpp build into `.\llama.cpp` and prints the GPUs it can see.
You should see your card listed, for example:

```
Available devices:
  CUDA0: NVIDIA GeForce RTX 5080 (16275 MiB, 14985 MiB free)
```

No GPU listed?

| Situation | Try |
|---|---|
| NVIDIA card | Update the driver, or `.\setup.ps1 -Backend cuda12` |
| AMD or Intel card | `.\setup.ps1 -Backend vulkan` |

Run `setup.ps1` again any time to update llama.cpp.

## 3. Start a model

```powershell
powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model ornith-ai/Ornith-1.5-9B-GGUF:Q8_0 --alias local
```

The first run downloads the model (about 10 GB) from Hugging Face. After that it starts in seconds.
When the log says the server is listening, open <http://127.0.0.1:8080> and chat.

Keep the PowerShell window open. Closing it, or pressing `Ctrl+C`, stops the model and frees your VRAM.

### Pick the size for your card

The part after the colon is the quantization: smaller = less VRAM, slightly lower quality.

| VRAM | Model argument | Download |
|---|---|---|
| 16 GB | `ornith-ai/Ornith-1.5-9B-GGUF:Q8_0` | 9.8 GB |
| 12 GB | `ornith-ai/Ornith-1.5-9B-GGUF:Q6_K` | 7.6 GB |
| 8 GB | `ornith-ai/Ornith-1.5-9B-GGUF:Q4_K_M` plus `-Ctx 8192` | 5.8 GB |

The other rows are estimates from file size. If the model is slow, it did not fit in VRAM; go one size down or lower `-Ctx`.

Any GGUF model on Hugging Face works the same way: `-Model <user>/<repo>:<quant>`.
A local file works too: `-Model .\models\something.gguf`.

### Options

| Option | Default | Meaning |
|---|---|---|
| `-Model` | required | Hugging Face repo or path to a `.gguf` file |
| `-Ctx` | `32768` | Context size in tokens. Bigger uses more VRAM |
| `-Port` | `8080` | Port to listen on |
| anything else | | Passed straight to `llama-server` (see `.\llama.cpp\llama-server.exe --help`) |

### Context size

Context size is how much text (in tokens, roughly ¾ of a word each) the model can keep in view at once:
your conversation so far, any files or search results, and its reply. Set it with `-Ctx`:

```powershell
powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model ornith-ai/Ornith-1.5-9B-GGUF:Q8_0 -Ctx 16384 --alias local
```

| `-Ctx` | Good for |
|---|---|
| `8192` | Short chats, 8 GB cards |
| `16384` | Normal chat |
| `32768` | Default. Long chats, web search, small coding tasks |
| `65536` | Coding agents and long documents, if you have VRAM to spare |
| `0` | The model's maximum. Often 256k+, which will not fit on a gaming card |

Bigger context uses more VRAM. If replies get very slow after raising it, it no longer fits; go back down or use a smaller quant.
When a conversation grows past the context size, the oldest part is dropped or the app reports an error, so start a new chat.

Check what the running server is using (look for `n_ctx`):

```powershell
curl.exe -s http://127.0.0.1:8080/v1/models
```

### More examples

Options can be combined in any order after `-Model`:

```powershell
# Different port
powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model ornith-ai/Ornith-1.5-9B-GGUF:Q8_0 -Port 8081 --alias local

# Smaller quant with a small context, for an 8 GB card
powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model ornith-ai/Ornith-1.5-9B-GGUF:Q4_K_M -Ctx 8192 --alias local

# A GGUF file you downloaded yourself
powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model .\models\my-model.gguf -Ctx 16384 --alias local
```

Downloads from gated repos, or faster downloads, need a Hugging Face token in the `HF_TOKEN` environment variable.

## 4. Use it from other apps

Any app that supports an "OpenAI-compatible" or "custom" endpoint can use the model:

| Setting | Value |
|---|---|
| Base URL | `http://127.0.0.1:8080/v1` |
| Model | `local` (the `--alias` you started with) |
| API key | anything; it is not checked |

Several apps can use it at the same time. Tested with three simultaneous requests.

## 5. Web search with Exa (optional)

Models only know what they were trained on. Giving them a search tool lets them look things up.
llama.cpp can connect to [MCP](https://modelcontextprotocol.io) tool servers, and [Exa](https://exa.ai) hosts one for web search.

> This part is **untested** with this setup, and llama.cpp marks its MCP support as experimental.
> The config below follows the [Exa MCP docs](https://docs.exa.ai/reference/exa-mcp).

1. Copy the example config:

   ```powershell
   Copy-Item mcp.example.json mcp.json
   ```

2. Start the server with it:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\serve.ps1 -Model ornith-ai/Ornith-1.5-9B-GGUF:Q8_0 --alias local --mcp-servers-config .\mcp.json
   ```

3. Ask something recent in the chat page, for example "search for today's top tech news".

Exa works without a key at a limited free rate. For your own limits, create a key at
<https://dashboard.exa.ai/api-keys> and add it to `mcp.json`:

```json
{
  "mcpServers": {
    "exa": {
      "url": "https://mcp.exa.ai/mcp",
      "headers": { "x-api-key": "YOUR_EXA_API_KEY" }
    }
  }
}
```

`mcp.json` is in `.gitignore` so the key is not uploaded by accident.

## Stopping the server

Any of these stops the model and frees your VRAM:

- Press `Ctrl+C` in the PowerShell window that is running `serve.ps1`.
- Close that PowerShell window.
- From any other PowerShell window:

  ```powershell
  Stop-Process -Name llama-server
  ```

Check whether it is still running (prints nothing if it is stopped):

```powershell
Get-Process llama-server -ErrorAction SilentlyContinue
```

Nothing starts automatically. After a stop or a reboot, the model stays off until you run `serve.ps1` again.

## Managing downloaded models

Models downloaded with `-Model <user>/<repo>` are stored in the Hugging Face cache, not in this folder:

```
%USERPROFILE%\.cache\huggingface\hub
```

Each model gets its own folder named `models--<user>--<repo>`.

**See what is downloaded and how big it is:**

```powershell
Get-ChildItem "$env:USERPROFILE\.cache\huggingface\hub" -Directory -Filter 'models--*' | ForEach-Object { '{0,8:N2} GB  {1}' -f ((Get-ChildItem $_.FullName -File -Recurse | Measure-Object Length -Sum).Sum / 1GB), $_.Name }
```

Example output:

```
    7.08 GB  models--Jackrong--DeepSeek-V4-Pro-Qwen3.5-9B-MTP-GGUF
    9.97 GB  models--ornith-ai--Ornith-1.5-9B-GGUF
```

**Delete a model** by removing its folder. Stop the server first if it is using that model.

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.cache\huggingface\hub\models--ornith-ai--Ornith-1.5-9B-GGUF"
```
## Local CLI Client 

```powershell
# Opens llama CLI client with the hf model mradermacher/DeepSeek-V4-Pro-Qwen3.5-9B-UNCENSORED-heretic-GGUF:Q8_0
.\llama-cli.ps1
```

This is permanent, but nothing is lost: starting the model again simply downloads it again.
You can also open the folder in Explorer (`explorer "$env:USERPROFILE\.cache\huggingface\hub"`) and delete folders there.

`.gguf` files you placed in `.\models` yourself are ordinary files; delete them like any other.

## Safety notes

- The server only listens on `127.0.0.1`, so only your own PC can reach it. Do not change `--host` unless you also set `--api-key`.
- Do not add `--tools` or `--agent`. Those let the model run shell commands and write files on your PC. Combined with web search, a malicious web page could steer the model into running commands.
- Text that comes back from web search is not checked by anyone. Treat the model's answers about it like any other web result.

## Troubleshooting

| Problem | Fix |
|---|---|
| "running scripts is disabled" | Use the `powershell -ExecutionPolicy Bypass -File ...` form shown above |
| Port 8080 already in use | Add `-Port 8081` and use that port in the URLs |
| Very slow replies | Model does not fit in VRAM. Use a smaller quant or lower `-Ctx`. Close games |
| Reply cuts off early | This model "thinks" before answering, which uses tokens. Raise the max-tokens setting in your app |
| Stop everything | Close the PowerShell window, or run `Stop-Process -Name llama-server` |

## What's in here

| File | Purpose |
|---|---|
| `setup.ps1` | Downloads llama.cpp |
| `serve.ps1` | Starts the model server |
| `mcp.example.json` | Example tool config for Exa search |
