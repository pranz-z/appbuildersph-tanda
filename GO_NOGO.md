# Go/No-Go — Tanda on vivo V30 (12 GB)

Spec §14 gate. All runs on the real phone, **airplane mode on**, models
already installed. Fill in measured values only — no estimates. Paste raw
tables into `MEASUREMENTS.md` / `test_sentences.md` as you go.

**Run date/time:** ______ · **Build/APK:** ______ · **Commit:** ______

## Gate 1 — Speech (15 Taglish sentences)

Via **Settings → Diagnostics → Speech diagnostics**. Read each sentence in
`test_sentences.md` once at normal pace. Tap the copy icon, paste into
`test_sentences.md`.

- Names correct: ___ / 12 sentences with names  (pass: most)
- Amounts/dates correct: ___ / 12 sentences with amounts or dates  (pass: most)
- A 5–8 s clip transcribes in: ______ ms  (pass: a few seconds)

Result: PASS / FAIL

## Gate 2 — LLM extraction (same 15 transcripts)

Via **Settings → Diagnostics → Extraction diagnostics → "Run 15 test
sentences"**. Copy the report (it is already markdown).

- Schema-valid JSON: ___ / 15  (pass: ≥ 14)
- Evidence substring OK: ___ / 15
- Avg per-call: ______ ms · Max: ______ ms  (pass: acceptable for the card flow)

Result: PASS / FAIL

## Gate 3 — End to end (5 runs)

Time from finishing a recording (or submitting typed text) to the confirm
card being ready:

| Run | Capture→card |
|---|---|
| 1 | ______ s |
| 2 | ______ s |
| 3 | ______ s |
| 4 | ______ s |
| 5 | ______ s |

Pass: about 15 s or less, steady across runs (no climb from thermal/RAM).

Result: PASS / FAIL

## Supporting measurements (spec §12)

- Memory, all models loaded (`adb shell dumpsys meminfo ph.tanda.app` or
  Debug log VmRSS): ______
- Offline: full flow with airplane mode on: PASS / FAIL
- Resilience: switch apps / lock-unlock, no model reload, no data loss: PASS / FAIL
- Bytes sent by app after full session (Session diagnostics): ______ B

## Fixes before giving up (spec §14)

Whisper small ↔ base · smaller LLM (~1B) · regex-first extraction ·
shorter prompts/context. Plan A (LAN backend) is the last resort.

## Verdict

**GO / NO-GO** — decided at ______ on ______.

Notes:
