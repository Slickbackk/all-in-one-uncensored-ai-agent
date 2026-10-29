# All in One Uncensored AI Agent — Ares

Download Ares, install once, and start working with a local uncensored AI model
on your own computer. Ares combines **Hermes Agent**, **Bonsai 2 27B CRACK**,
and the **PrismML llama.cpp Vulkan runtime** into a Windows setup and launcher.

**Recommended minimum: a GPU with 12 GB VRAM.** 16 GB VRAM provides more headroom.

[**Download Ares for Windows**](https://github.com/Slickbackk/all-in-one-uncensored-ai-agent/releases/latest/download/Ares-Windows-v1.0.0.zip)
· [Releases](https://github.com/Slickbackk/all-in-one-uncensored-ai-agent/releases)

## Start in three steps

1. Download the ZIP above and **extract it completely** into a writable folder,
   such as `Documents\Ares`. Keep it there after setup.
2. Double-click **Setup-Ares.cmd**. First setup downloads the approximately
   **7.2 GB model**, the inference runtime, and Hermes dependencies. Internet is
   required for installation; allow time for the downloads and package builds.
3. Double-click **Start-Ares.cmd**. Wait for the model to load, then type your task
   in the terminal. Ask Ares to write code, edit files, or run local commands.

No paid inference API key is required. Model inference runs on your computer.
External actions, package downloads, and tools that access websites still need
internet. The ZIP is an installer/launcher bundle: model weights and third-party
dependencies are downloaded during setup rather than embedded in the ZIP.

## Hardware and software

| Component | Recommendation |
| --- | --- |
| OS | Windows 10/11, 64-bit x64 |
| GPU | **12 GB VRAM recommended minimum**; current Vulkan-capable driver |
| GPU vendors | AMD, NVIDIA, or Intel, subject to upstream Vulkan support |
| System RAM | 32 GB recommended |
| Free disk | Budget at least 25 GB for weights, tools, caches, and setup |
| Context | Starts at 16,384 tokens to limit memory use |

12 GB is this project's recommended starting point, not a benchmark or guarantee
for every card. Context size, driver, model buffers, and other GPU applications
affect memory use. The installer does not claim to verify VRAM capacity. The
launcher requires a detected Vulkan GPU; speed and full layer offload should be
checked in `data\logs`. This release targets Windows; it has no Linux/macOS installer.

## What you get

- A local model with the reduced-refusal behavior described by its publisher.
- Hermes file and terminal tools for working on local projects.
- A separate Ares data folder, with local settings, history, and logs.
- Optional browser chat via `powershell -ExecutionPolicy Bypass -File .\Start-Ares.ps1 -WebChat`.
  Browser chat is direct model chat; Hermes agent tools run through the normal launcher.

The word "uncensored" refers to the selected model's training/modification. It
does not promise a particular answer or perfect reliability. Ares does not add a
content-filter service. Hermes retains its own normal tool approval behavior.
The initial toolset is deliberately limited to file and terminal tools to fit the
context budget; this release does not bundle Telegram, Open WebUI, or vision setup.

## Existing model, settings, and troubleshooting

Already have the exact model? Avoid downloading it again:

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup-Ares.ps1 -ModelPath "D:\Models\Bonsai-2-27B-PQ2_0-CRACK.gguf"
```

The installer checks SHA-256 before using the file. The model stays at the supplied
path. For default installs, it is stored under `models\`.

- **Interrupted download:** rerun Setup; `.partial` downloads resume.
- **No Vulkan GPU:** install the GPU vendor's current graphics driver and reboot.
- **Missing VCRUNTIME/MSVCP DLL:** install Microsoft's x64 Visual C++ runtime:
  https://aka.ms/vs/17/release/vc_redist.x64.exe
- **Out of memory:** close GPU-heavy programs; reduce `context` in
  `data\settings.json` to 8192. Large tasks/tool prompts may need a larger context.
- **Port occupied:** change `port` in `data\settings.json`. The launcher synchronizes
  Hermes' endpoint and context with these values when starting the agent.
- **Model fails to load:** inspect `data\logs\*.stderr.log`. This PQ2_0 model uses
  the PrismML runtime; arbitrary stock llama.cpp/Ollama builds may not support it.
- **Folder moved:** rerun Setup to refresh absolute paths.
- **Hermes install fails:** keep the installer output, resolve its reported dependency
  problem, and rerun Setup. The upstream installer may add its launcher directory
  to your user PATH and installs its own Git/Python/tool dependencies as required.
- **Agent files:** start in `workspace\`. To work elsewhere, ask Ares to use an
  explicit project path. File and terminal tools execute with your Windows account's access.
- **Stop:** exit Hermes normally; Ares stops the model process it started.
- **Check inference:** `powershell -ExecutionPolicy Bypass -File .\Start-Ares.ps1 -CheckOnly`.
- **Uninstall:** remove the extracted Ares folder after closing it. If using an
  external model path, that model remains. Remove Ares' Hermes bin entry from your
  user PATH if upstream installation added it.

Keep `data\`, models, logs, and credentials private. Source and release archives
contain only the distributable scripts and documentation.

## Components and provenance

This repository is a setup/launcher integration, with credit to the original projects:

| Component | Source and pinned version |
| --- | --- |
| Hermes Agent | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent), commit `f8489405600c9a7d9d2f307dace086f18d7173ba` |
| Inference engine | [PrismML-Eng/llama.cpp](https://github.com/PrismML-Eng/llama.cpp), official `prism-b10826-c9c34bc` Windows Vulkan x64 release |
| Model | [dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF](https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF), revision `3d36486a5fb2a3868116b8f6e768179e2391d28d` |

Runtime ZIP SHA-256:
`f4d923da4c502837f94f0d6a438cf5e862df25ddc29c97ba6b200e9ef6bc16f0`

Model SHA-256:
`5b24ea3eebc3e0bccd05fb474eb88b10c57699d71a5db2f29485e3789a70d55d`

Launcher scripts are MIT licensed. Third-party components retain their upstream
licenses; the model card lists Apache-2.0. They are fetched from their original
publishers during setup. Read the model card and upstream documentation for
model behavior, runtime support, and component-specific terms.

The pinned Hermes build normally enforces a 64,000-token minimum. Setup applies
one documented compatibility change in Ares' own installed copy:
`agent/model_metadata.py`'s `MINIMUM_CONTEXT_LENGTH` becomes `8_192`. Ares defaults
to 16K with a limited toolset. This downstream customization is not an upstream
Hermes guarantee; large prompts may still exceed available context. Existing
Hermes installations are not patched. Updating Hermes may replace the patch;
rerun Setup only against the pinned version, or review compatibility before updating.

## Validation

See [VALIDATION.md](VALIDATION.md) for checks performed for this release and their limits.
