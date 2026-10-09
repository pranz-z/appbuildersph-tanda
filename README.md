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

The app uses no network at runtime and does not download anything itself. Download these once on the phone (or copy them over) into **Downloads**:

| File | Download |
|---|---|
| `small-encoder.int8.onnx` (112 MB) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-encoder.int8.onnx |
| `small-decoder.int8.onnx` (262 MB) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-decoder.int8.onnx |
| `small-tokens.txt` | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-tokens.txt |
| `base-encoder.int8.onnx` (29 MB, optional fallback) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-encoder.int8.onnx |
| `base-decoder.int8.onnx` (131 MB, optional fallback) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-decoder.int8.onnx |
| `base-tokens.txt` (optional fallback) | https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-tokens.txt |

Then in the app: **Import models** (shown on first run, or from the debug screen) > select the files (long-press to multi-select). The checklist shows which files are present. Files keep their exact names; browser duplicates like `small-tokens (1).txt` are accepted. Models are stored in the app's private internal storage (no storage permission needed).

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
