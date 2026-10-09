# Disclosures

Kept current during the build. Everything here was added during the hackathon window (Oct 9, 2:30 PM to Oct 10, 10:00 AM).

## Pre-existing code or assets

- None. The project was generated with `flutter create` (Flutter 3.47.6 template) during the build window.
- `TANDA_SPEC.md` (planning doc, no code) was written by the team before coding started.

## Models

| Model | Files | Source | License |
|---|---|---|---|
| OpenAI Whisper small (int8 ONNX export by sherpa-onnx / k2-fsa) | `small-encoder.int8.onnx`, `small-decoder.int8.onnx`, `small-tokens.txt` | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small (also in https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models) | Whisper: MIT (OpenAI) |
| Fallback: Whisper base (same export) | `base-encoder.int8.onnx`, `base-decoder.int8.onnx`, `base-tokens.txt` | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base | MIT |

Still planned: 1.5B to 2B instruct Q4 GGUF (llama.cpp), multilingual-e5-small int8 (ONNX).

## Flutter / Dart packages (exact pinned versions)

| Package | Version | Purpose |
|---|---|---|
| sherpa_onnx | 1.13.8 | On-device speech-to-text (Whisper) runtime; ships ONNX Runtime for Android arm64 |
| record | 7.1.1 | Microphone capture (16 kHz mono WAV) |
| just_audio | 0.10.6 | Playback of saved clips |
| drift | 2.35.1 | SQLite ORM |
| drift_flutter | 0.3.1 | Opens drift DB on Flutter; bundles SQLite via `sqlite3` |
| connectivity_plus | 7.3.2 | Online/offline state for the locality meter |
| permission_handler | 13.0.2 | Microphone permission |
| path_provider | 2.1.6 | App storage paths for audio, DB, models |
| flutter_riverpod | 3.4.3 | State management / service injection |
| wakelock_plus | 1.8.1 | Keeps screen awake during demo |
| uuid | 4.6.0 | Stable `uid` per memory |
| path | 1.9.1 | Path joining |
| drift_dev (dev) | 2.35.1 | drift code generation |
| build_runner (dev) | 2.16.1 | Code generation runner |
| flutter_lints (dev) | 6.0.0 | Lints (Flutter template default) |

## APIs and cloud services

None at runtime. The app makes no network calls by design.

## AI development tools

- Devin (Cognition), pair programming in the IDE.
