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
| Qwen2.5-1.5B-Instruct, Q4_K_M GGUF (official Qwen quantization) | `qwen2.5-1.5b-instruct-q4_k_m.gguf` (1,117,320,736 bytes) | https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF | Apache-2.0 |
| multilingual-e5-small (intfloat), int8 ONNX export by Xenova | `model_int8.onnx` (118,054,593 bytes), `tokenizer.json` | https://huggingface.co/Xenova/multilingual-e5-small (original: https://huggingface.co/intfloat/multilingual-e5-small) | MIT (original model card); Xenova repo carries no separate license tag |

e5 files are imported and checked but not yet loaded by the app (embedding phase pending).

Models are not in the APK. Two ways to install them: (1) the optional in-app downloader ("Download models"), which fetches the files from the Hugging Face URLs pinned to the commits listed in README.md, only after the user taps Download; or (2) manual import with the system file picker ("Import models"). adb push is a further optional alternative. Whisper source commits: small `8f3c18b358db4d1f2fc1eae49d75cd20989e4309`, base `bb53ee204431c90d314c1cc08d28d23e5b7927cc` (the csukuangfj repos carry no license tag; Whisper itself is MIT). Qwen commit `91cad51170dc346986eccefdc2dd33a9da36ead9`. e5 (Xenova) commit `761b726dd34fb83930e26aab4e9ac3899aa1fa78`.

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
| http | 1.6.0 | Optional model downloader (Range resume). Was already a transitive dependency; now direct. |
| crypto | 3.0.7 | SHA-256 verification of downloaded models. Was already transitive; now direct. |
| file_picker | 13.1.0 | System file picker for importing model files (no network) |
| llamadart | 0.10.0 | llama.cpp binding (GGUF inference with GBNF grammar, in a worker isolate). Its build hook downloads prebuilt llama.cpp binaries from https://github.com/leehack/llamadart-native at **build time only**; configured for Android arm64 CPU backend only. MIT. |
| drift_dev (dev) | 2.35.1 | drift code generation |
| build_runner (dev) | 2.16.1 | Code generation runner |
| flutter_lints (dev) | 6.0.0 | Lints (Flutter template default) |

## APIs and cloud services

Hugging Face (huggingface.co and its CDN), **only** for the optional, user-started model download. The app requests the `INTERNET` permission for this alone. No other network calls: speech, LLM, embeddings, storage and retrieval run on the phone, and the app works in airplane mode once models are present. Manual import needs no internet in the app at all.

## AI development tools

- Devin (Cognition), pair programming in the IDE.
