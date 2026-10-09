# Tanda

A voice-first Taglish memory for hiram, utang, and "nasaan ko nilagay". Runs entirely on an Android phone. See `TANDA_SPEC.md`.

## Build

Requires Flutter 3.47.x. Target: arm64 Android phone, Android 7.0+ (minSdk 24).

```
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (signed with the debug key). Copy it to the phone and open it to install (allow "Install unknown apps" for your file manager).

## Models (not in the APK)

Models are never bundled in the APK. There are two ways to get them onto the phone; both put the files in the app's private storage (no storage permission) and the app treats them identically (a file only counts as present if its size matches the table below).

**Option A, in-app download (needs internet once):** on the first-run check tap **Download models**. Nothing downloads until you tap the Download button, which shows the total size. Only missing or incomplete files are fetched, one at a time, with per-file and overall progress. Cancel at any time; if you cancel, close the app or lose the connection, tap Download again to resume from the saved `.part` file (HTTP Range). Each file is checked for its exact size and, where Hugging Face publishes one, its SHA-256 before it is marked ready. The required set (Whisper small, LLM, e5) is about 1.63 GB; keep ~1.8 GB free.

**Option B, manual import (no internet in the app):** download the files below into **Downloads** (browser or laptop), then tap **Import models** and select them (long-press to multi-select). Browser duplicates like `small-tokens (1).txt` are accepted.

Internet is used only by the optional downloader. After the models are present, the app works fully offline (airplane mode).

All URLs are pinned to a Hugging Face commit, so the files cannot change underneath the app.

| File | Bytes | SHA-256 verified | URL |
|---|---|---|---|
| `small-encoder.int8.onnx` | 112,442,483 | yes | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-encoder.int8.onnx |
| `small-decoder.int8.onnx` | 262,226,114 | yes | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-decoder.int8.onnx |
| `small-tokens.txt` | 816,730 | size only (not in LFS) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-tokens.txt |
| `qwen2.5-1.5b-instruct-q4_k_m.gguf` | 1,117,320,736 | yes | https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/91cad51170dc346986eccefdc2dd33a9da36ead9/qwen2.5-1.5b-instruct-q4_k_m.gguf |
| `model_int8.onnx` | 118,054,593 | yes | https://huggingface.co/Xenova/multilingual-e5-small/resolve/761b726dd34fb83930e26aab4e9ac3899aa1fa78/onnx/model_int8.onnx |
| `tokenizer.json` | 17,082,730 | yes | https://huggingface.co/Xenova/multilingual-e5-small/resolve/761b726dd34fb83930e26aab4e9ac3899aa1fa78/tokenizer.json |
| `base-encoder.int8.onnx` (optional fallback, import only) | 29,120,534 | yes | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-encoder.int8.onnx |
| `base-decoder.int8.onnx` (optional fallback, import only) | 130,672,026 | yes | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-decoder.int8.onnx |
| `base-tokens.txt` (optional fallback, import only) | 816,730 | size only | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-tokens.txt |

SHA-256 values are the Git LFS object IDs from the Hugging Face API at those commits (see `lib/core/model_locator.dart`). Import checks size only; the downloader checks size and SHA-256.

The LLM prompt and grammar are plain text in `assets/extract_prompt.txt` and `assets/extract.gbnf` (rebuild after editing). `dart run tool/llm_desktop_check.dart <path-to-gguf>` runs the 15 test sentences on a laptop to check JSON validity (laptop timings are not phone measurements).

**Optional alternative (adb):** push the files to `/sdcard/Android/data/ph.tanda.app/files/models/` and restart the app. Run the app once first so the folder exists.

## Debugging without logcat

The **Debug log** screen (article icon in the top bar) shows model load time, thread count, each transcription, and any error with stack trace. Tap **Copy** to paste it elsewhere. The previous session's log is kept, so a crash is visible on the next launch.

## Phone setup: vivo / Funtouch OS (do this before any demo)

Funtouch kills background apps aggressively, which would mean reloading the models. Turn this off for Tanda:

1. **Settings > Battery > Background power consumption management** (on some builds: **Battery > High background power consumption**): find **Tanda**, set it to **Allow** / **Don't restrict**.
2. **Settings > Apps > Tanda > Battery**: allow background activity.
3. **i Manager > App manager > Autostart**: enable Tanda (if this option is present).
4. In Recents, swipe down on the Tanda card to **lock** it so "clear all" doesn't kill it.

Menu names differ between Funtouch versions. The goal is the same: no battery restriction for Tanda.

## Disclosures

See `DISCLOSURES.md`. Measured numbers are in `MEASUREMENTS.md`.
