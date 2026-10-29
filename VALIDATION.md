# Release validation

Checks performed on Windows x64 on 2026-10-29:

- Both PowerShell scripts parse successfully.
- The official pinned PrismML Windows Vulkan archive downloaded successfully and
  matched its published SHA-256.
- An existing copy of the exact model matched the pinned Hugging Face LFS SHA-256.
- `Start-Ares.ps1 -CheckOnly` loaded the model, made an actual OpenAI-compatible
  chat-completion request, received `READY`, and stopped its server afterward.
- The 8K-context runtime smoke test reported 65/65 layers offloaded on an AMD
  Radeon RX 6800 with 16 GB VRAM. This is not a benchmark for a 12 GB GPU.
- Launch without setup fails with a setup instruction.
- Launch against an occupied port fails without stopping the existing listener.
- The upstream Hermes installer completed dependency installation, terminal/web
  builds, skills sync, and launcher publication in a separate Ares folder.
- Setup rerun applied the documented small-context compatibility patch and
  prepared the default 16K configuration successfully.
- `Start-Ares.ps1 -QueryFile` ran the real Hermes agent against the local model
  at 16K context. It called `write_file` to create a smoke-test file and
  `read_file` to verify it. The file contents were independently checked and the
  launcher exited successfully.

The full model download was not repeated: the test used `-ModelPath` with the
existing checksum-verified model. Fresh-machine behavior, other GPU vendors,
12 GB cards, long conversations, and every Hermes tool are not covered by these
checks. First-time installation depends on upstream services and their availability.

The initial online Hermes source checkout hit Windows long paths; Setup now
passes `core.longpaths=true` through process-scoped Git configuration. GitHub
rate limiting also affected the online check. The subsequent dependency-install
check uses a local Git checkout of the identical pinned commit as the source.
