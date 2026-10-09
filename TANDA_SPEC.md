# Tanda: Technical and Product Spec (v2, on-device Flutter)

> *Tanda* (Tagalog: "remember"). A voice-first memory for everyday life that runs entirely on your phone.
> AppBuildersPH Hackathon 2026, Local AI theme. Build window: Oct 9, 2:30 PM to Oct 10, 10:00 AM (hard deadline, no extensions).
> Target device: **vivo V30, 12 GB RAM (+12 GB extended RAM, treated as swap only), Android.**

---

## 0. What changed from v1

- App is a **fully on-device Flutter Android app**. No laptop, no Ollama, no Python, no server.
- Models are phone-sized: Whisper small (int8), a 1.5B to 2B LLM (Q4, grammar-constrained JSON), multilingual embeddings.
- **Code does the logic, the LLM only extracts and phrases.** Answers and reminders are validated by code and fall back to templates.
- Cloud **Group mode is the last, optional item (P2)**, behind a flag, off by default, and cut first if time runs short.
- Hard go/no-go on the real phone before building features, with a defined fallback (Plan A, section 19).

## 1. One-liner

Say what happened in plain Taglish ("Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado"). Tanda transcribes, structures, and stores it on your phone. Later, ask "Sino may hawak ng drill ko?" and get a cited answer with your own voice clip as proof. When someone is late returning something or paying you back, Tanda drafts a polite Taglish reminder so you don't have to feel awkward.

## 2. Target user and pain (one person, one pain)

**Person:** A busy young adult or parent in the Philippines who lends things and money to friends and relatives, and loses track.

**Lead pain (the demo is built around this):** *Hiram and utang.* "Who has my stuff, who owes me, and I'm too nahihiya to ask."

**Second act (shown briefly):** Item location ("Nasaan passport ko?") and personal promises.

**Out of scope on purpose:** Medical, legal, and other professional workflows. This is casual daily living.

## 3. Why local AI (must be answerable in the submission)

> *Why does this product benefit from running AI locally?*

1. **Privacy:** Voice recordings of home life, who owes you money, and where valuables are kept never leave the phone.
2. **Availability:** Works in brownouts, basement parking, jeepneys, and barangays with weak signal. Airplane mode is the default demo state.
3. **Cost and latency:** No data load, no per-request fees, response time doesn't depend on a network.
4. **Trust:** A visible locality meter shows what ran on-device and what, if anything, the app sent over the network.
5. **It's the phone:** The device that lends, borrows, and takes the voice notes is the device that runs the AI. No second machine.

## 4. Scope

### P0: must work five clean runs in a row (on the phone, airplane mode on)

| ID | Feature | Acceptance criteria |
|---|---|---|
| P0-1 | **Capture** | Hold-to-talk. Whisper transcribes on-device. Typed input always available as fallback. Audio clip saved. |
| P0-2 | **Extract** | LLM returns schema-valid JSON via GBNF grammar (kind, person, item, place, amount, due text, evidence). On invalid output: one retry, then fall back to manual form. |
| P0-3 | **Confirm card** | Editable fields. Transcript shown with evidence highlighted. Low-confidence fields flagged. Progress state while models run. Nothing saves without Confirm. |
| P0-4 | **Store** | SQLite row + audio path + embedding (BLOB). |
| P0-5 | **Ask** | Voice or text question. Hybrid retrieval (structured filter + embedding similarity). Answer cites memory IDs and shows a playable clip. |
| P0-6 | **Not-found behavior** | Below threshold and no structured match: "Wala akong nahanap." Never guess. LLM is not called. |
| P0-7 | **Nakabinbin (open loops)** | List of open lent items, lent money, promises, sorted by due date. "Mark as done". Per-person utang total computed by code. |
| P0-8 | **Draft reminder** | Per open loop, two tones: *malambing* and *diretso*. Template-first, LLM polish only if it passes validation. Editable and copyable. |
| P0-9 | **Locality meter** | Connectivity state, "bytes sent by app" counter, on-device counters (transcriptions, LLM calls, embeddings). |

### P1: only if P0 is solid and rehearsed

- In-app banner when a due date arrives
- Second tone set (po/opo formal)
- Weekly "who owes what" summary view

### P2: Group mode (cloud sync). **Last. Optional. Cut first.**

See section 18. Only start after P0 is frozen and 5 clean demo passes are done. It lives behind a flag, is off by default, and the main demo and video run with it off.

### Cut from the start

Photo/OCR, vision models, recurring reminders, OS notifications, audio file upload, mixed-dialect speech tuning (Ilocano, Kapampangan, etc.), SQL aggregate analytics, duplicate detection, iOS.

## 5. Architecture (all on the phone)

```
 Mic (hold-to-talk) ──► WAV 16 kHz mono (saved to app storage)
        │
        ▼
 Whisper small int8 via sherpa_onnx  ──►  transcript          [isolate]
        │
        ▼
 LLM 1.5B to 2B, Q4 GGUF via llama.cpp (FFI), GBNF JSON grammar   [isolate]
        │   extract: {kind, person, item, place, amount, due_date_text, evidence, uncertain_fields}
        ▼
 Code checks: evidence is a substring, amount regex cross-check, date resolved by code
        │
        ▼
 Confirm card (user edits / approves)
        │
        ▼
 SQLite (drift)  ◄── embedding (multilingual-e5-small, ONNX int8)
        │
   Ask ─┴─► structured filter + cosine similarity (Dart)
        │
        ▼
 Answer: code-built template; LLM phrasing only if validated  +  audio clip citation
```

**Principle:** The LLM extracts and phrases. Plain Dart code does retrieval thresholds, date logic, validation, and all arithmetic (for example, total utang per person). Numbers are never LLM-guessed. Heavy work runs in Dart isolates so the UI never freezes.

## 6. Models and stack (disclose every item in the submission)

| Component | Choice | Notes |
|---|---|---|
| App framework | Flutter (Dart), Android | Single codebase, four screens |
| Speech-to-text | Whisper `small` int8 via `sherpa_onnx`; fall back to `base` if too slow | Taglish names and amounts are the weak point. Test first. |
| LLM | 1.5B to 2B instruct, Q4 GGUF, via llama.cpp through FFI (Qwen-class or Gemma-class; pick at the spike) | **Use grammar-constrained (GBNF) JSON.** 3B is likely too slow on this CPU. |
| Embeddings | `multilingual-e5-small` int8 via ONNX Runtime | Use `query:` / `passage:` prefixes. English-only embeddings will hurt Taglish retrieval. |
| Storage | SQLite via `drift`; audio as files in app storage | Embeddings as BLOB, cosine in Dart |
| Audio | `record` (capture), `just_audio` (playback) | 16 kHz mono WAV for Whisper |
| Misc | `connectivity_plus`, `permission_handler`, `path_provider` | Meter and permissions |

Verify each Flutter package is actively maintained and builds for your Android target before committing. Write a thin wrapper around each so a plugin can be swapped.

**Device budget (vivo V30):** treat RAM as 12 GB, and the extended RAM as unusable for models. Keep the whole app under about 3 to 4 GB resident. Load models once at app start. Never reload per request.

**Models ship on the phone, not in the APK:** sideload with `adb push` into the app's external files folder. README tells judges where to download them.

**Disclosures to include in README:** all models above, all libraries and plugins, AI coding tools used (for example Codex, Claude, Devin), pre-existing code or assets (aim for none), APIs and cloud services (none at runtime unless Group mode ships).

## 7. Data model

```sql
CREATE TABLE memories (
  id            INTEGER PRIMARY KEY,
  uid           TEXT NOT NULL UNIQUE,    -- UUID, stable across devices (enables P2 sync)
  created_at    TEXT NOT NULL,           -- ISO 8601
  updated_at    TEXT NOT NULL,           -- ISO 8601, bumped on every edit
  kind          TEXT NOT NULL CHECK (kind IN
                  ('item_location','lent_item','lent_money','promise')),
  person        TEXT,                     -- who borrowed / owes / was promised
  item          TEXT,                     -- drill, passport, aircon service...
  place         TEXT,                     -- for item_location
  amount        REAL,                     -- for lent_money (PHP)
  due_date      TEXT,                     -- ISO date or NULL
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','done')),
  transcript    TEXT NOT NULL,
  evidence      TEXT,                     -- snippet from the transcript
  audio_path    TEXT,                     -- saved clip (never synced)
  embedding     BLOB,                     -- float32 vector
  confirmed     INTEGER NOT NULL DEFAULT 0,
  deleted       INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE meter_events (
  id         INTEGER PRIMARY KEY,
  ts         TEXT NOT NULL,
  event      TEXT NOT NULL CHECK (event IN ('transcribe','llm_call','embed','bytes_sent')),
  value      REAL NOT NULL DEFAULT 1
);
```

`uid`, `updated_at` and `deleted` cost almost nothing now and make P2 possible later. Group mode adds its own tables only if it ships.

## 8. LLM contracts

### 8.1 Extraction (GBNF-constrained JSON)

```json
{
  "kind": "lent_item | lent_money | item_location | promise",
  "person": "string | null",
  "item": "string | null",
  "place": "string | null",
  "amount": "number | null",
  "due_date_text": "string | null",
  "evidence": "exact substring of the transcript",
  "uncertain_fields": ["field names the model is unsure about"]
}
```

Rules:
- The grammar guarantees valid structure. Code still validates values.
- `evidence` must be a substring of the transcript. If not, mark the card low-confidence.
- Relative dates ("sa Sabado", "bago mag-Oct 20") are resolved to ISO dates **by code** using the current date. The card shows the resolved date for the user to confirm.
- Amounts are parsed from the transcript by regex as a cross-check. Disagreement flags the field. If the LLM is unreliable on amounts and dates, let regex be primary and the LLM fill the rest.
- Keep prompts short with a few Taglish few-shot examples. Short context keeps latency and RAM down.

### 8.2 Answering

Input: user question + top-k retrieved memories. Output: short Taglish answer + cited memory IDs.
- **Default answer is built by a code template** from the retrieved rows ("Si Kuya Jun ang may hawak ng drill mo, isosoli sa Sabado.").
- LLM phrasing is optional. Accept its output only if every name, item and amount in it appears in the retrieved rows. Otherwise use the template.
- If no memories are retrieved, return "Wala akong nahanap" **without calling the LLM**.

### 8.3 Reminder drafting

Input: one memory row + tone (`malambing` | `diretso`). Output: 1 to 3 sentence Taglish message.
- Start from a template per tone. The LLM may polish wording.
- Validate: includes the item or amount from the row, no new facts, no threats or shaming words, 3 sentences or fewer. If validation fails, use the template.

## 9. Retrieval and not-found logic

1. Parse the question for hints (person name, kind keywords such as "utang", "hiram", "nasaan").
2. Structured filter on `person`, `kind`, `status` when hints are present.
3. Embed the question (`query:` prefix) and compute cosine similarity against candidate rows (`passage:` prefix at store time).
4. Take top-k (k=3). If best score is below threshold **and** there is no structured match, return not-found.
5. Always show the audio clip and transcript for each cited memory.

**Threshold calibration:** e5-family models give compressed similarity scores (relevant and irrelevant pairs often both land high). Do **not** assume the old 0.45 value. Measure scores on your own 10-question test set (6 answerable, 4 not) and set the threshold between the two groups. Keep the structured filter as the main guard.

## 10. Locality meter

Shows, always visible:

- **Connectivity:** online / offline (`connectivity_plus`)
- **Bytes sent by the app:** label it exactly that. Do **not** claim a hard guarantee. The app makes no network calls by design, so the counter should stay at 0. Optionally read per-app transmit bytes via Android's `TrafficStats` through a platform channel as a second source.
- **On-device counters:** transcriptions, LLM calls, embeddings this session

**Proof that holds up on stage:** airplane mode on (status bar visible on the mirrored screen), meter at 0 bytes. If Group mode ships, it must show a clear "Sync: off" state, and the main demo runs with it off.

## 11. UI (four screens plus first-run check)

1. **Tala (Capture):** big hold-to-talk button, typed fallback, progress state, then the confirm card.
2. **Tanong (Ask):** text/voice box, answer card, citation chips, audio player.
3. **Nakabinbin:** open loops list with Done and Draft reminder buttons, per-person totals.
4. **Meter:** persistent footer or side panel.
5. **First-run check:** confirms model files are present and loaded, shows a clear error if not.

UX notes: large tap targets, Taglish labels with English hints, obvious empty state, every AI-filled field editable, never a frozen screen.

## 12. Test plan

Run in the first hours on the phone and again before feature freeze.

| Test | Method | Pass bar (report only what you measure) |
|---|---|---|
| Taglish transcription | 15 recorded sentences covering names, amounts, dates | Report raw count of names and amounts correct before any confirm-card edits |
| Extraction validity | Same 15 transcripts | Schema-valid JSON on at least 14 of 15 (grammar should make this near 100%) |
| Retrieval | 10 questions (6 answerable, 4 not) | All 4 unanswerable questions return "Wala akong nahanap" |
| Latency | Capture to confirm card, 5 runs | About 15 s or less, stable; report measured times per stage |
| Memory | `adb shell dumpsys meminfo` with all models loaded | Stays well within budget; report the number |
| Thermal repeat | 5 to 10 consecutive full passes | Latency doesn't climb badly; report it |
| Offline | Airplane mode, full flow | All P0 features work |
| Resilience | Switch apps and return; lock and unlock | App survives without reloading models or losing data |
| Demo repeatability | Full demo script | 5 clean passes in a row |

**Benchmark honesty:** the pitch and README show only numbers measured on your own phone, labeled "vivo V30, 12 GB". Fake benchmarks are grounds for disqualification.

## 13. Timeline (Oct 9, 2:30 PM to Oct 10, 10:00 AM)

| Time | Goal |
|---|---|
| 2:30 to 3:30 PM | Create repo, Flutter skeleton on the phone. **Start model downloads now while Wi-Fi is up.** Log which code is new. No code before 2:30 PM. |
| 3:30 to 6:00 PM | **Spike and go/no-go (section 14).** Whisper, llama.cpp with GBNF, and embeddings running on the phone in airplane mode. If it fails, switch to Plan A or an alternate idea (section 19). |
| 6:00 to 10:00 PM | Capture, extract, confirm, save, end to end with airplane mode on. |
| 10:00 PM to 1:00 AM | Ask with citations and audio playback, not-found behavior, Nakabinbin. |
| 1:00 to 2:30 AM | Locality meter, reminder drafting, UI polish, pre-seeded demo data. |
| 2:30 to 5:30 AM | Sleep (at least 3 hours if solo). |
| 5:30 to 6:15 AM | **Feature freeze (core).** 5 clean demo passes. Measure latency and memory. |
| 6:15 to 7:15 AM | **Optional: Group mode on a branch (P2).** Hard stop at 7:15. Merge only if it works, is off by default, and 3 clean passes still succeed with it off. Otherwise delete the branch and use a roadmap slide. |
| 7:15 to 8:00 AM | README: setup for judges, models, local vs internet, "why local", measured numbers. |
| 8:00 to 8:45 AM | Record about 1 minute demo video (Group mode off). Post on X or LinkedIn, tag Devin/Cognition, include #AppBuildersPH. |
| 8:45 to 9:15 AM | Make the repo **public**, verify, submit once. No edits or resubmission. |

Aim to submit by **9:15 AM**, not 9:59. If you are behind at 6:15 AM, skip P2 and spend the time on README and the video.

## 14. Go/no-go (hour 3, on the phone, airplane mode)

Using 15 Taglish sentences, all three must pass:

1. **Speech:** names and amounts are right in most sentences, and a 5 to 8 second clip transcribes in a few seconds.
2. **LLM:** valid JSON on at least 14 of 15 with the grammar, per-call time acceptable.
3. **End to end:** capture to confirm card about 15 seconds or less, steady across 5 runs.

Fixes before giving up: Whisper `small` to `base` (or the reverse), a smaller LLM (about 1B), regex-first extraction with the LLM only filling gaps, shorter prompts and context.

## 15. Roles (adjust to team size)

| Role | Owns |
|---|---|
| ML / native | Whisper, llama.cpp bindings, embeddings, isolates, meter |
| Flutter UI | Four screens, confirm card, audio player, progress states |
| Product / demo | Test sentences, Taglish prompt quality, README, video, pitch |

Solo or duo: merge roles, cut P1 entirely, and treat P2 as the first thing to drop.

## 16. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Whisper mishears names and amounts | Confirm card is mandatory, evidence highlighted, typed fallback, regex cross-check |
| 1.5B to 2B LLM gives bad JSON | GBNF grammar, one retry, manual form fallback, regex-first for amounts and dates |
| Latency too slow on the phone | Smaller models, short prompts, isolates, progress UI, load models once |
| Native plugin or FFI build problems | Do the spike first, wrap each plugin, keep Plan A ready |
| Phone overheats or Funtouch kills the app | Disable battery optimization for the app, thermal repeat test, case off, keep the screen awake during the demo |
| Network claim challenged | Label it "bytes sent by app", show airplane mode status bar and 0 bytes |
| Demo too dense | Lead with hiram/utang, item location is one quick moment |
| Live demo breaks | Pre-seeded demo data, backup video, rehearse 5 times, `scrcpy` over USB tested before Demo Day |
| Group mode muddies the privacy story | Off by default, never in the main demo, cut first |

## 17. Five-minute pitch (plus 3 min Q&A)

1. **0:00 to 0:30 Problem:** "Sino ba may hawak ng drill ko? Nasaan passport ko? Nahihiya akong maningil."
2. **0:30 to 3:30 Live (phone mirrored with `scrcpy`, airplane mode visible, meter at 0 bytes):**
   1. Speak a hiram memory, then confirm the card.
   2. Speak a utang memory.
   3. Ask "Sino may hawak ng drill ko?" and play the evidence clip.
   4. Ask something unanswerable ("Nasaan ang susi ko?") and show "Wala akong nahanap."
   5. Open Nakabinbin and draft a reminder (malambing).
3. **3:30 to 4:30 How it works:** three on-device models, plus your measured numbers labeled "vivo V30".
4. **4:30 to 5:00 Impact and what's next:** a memory of your home life that never leaves your phone. Roadmap: opt-in encrypted family sync, AI still on-device.

### Expected judge questions

- **Why not ChatGPT or a notes app?** Private voice recordings and money owed shouldn't leave the device, it works with no signal, and it gives audio evidence and polite reminders, not just notes.
- **Is it really offline?** Airplane mode plus the bytes-sent meter. No hard guarantee claimed.
- **What about wrong transcriptions?** Confirm card, and the audio is always one tap away.
- **What if it doesn't know?** It says so. The code path never calls the LLM without retrieved evidence.
- **Why a phone, not a laptop?** It's where people lend, borrow, and record. No server, no second device.
- **Can my family share it?** Roadmap: opt-in, encrypted, structured records only. (Or, if P2 shipped: show it briefly, off by default.)

## 18. P2: Group mode (cloud sync). Last and optional

**Goal:** a family or group shares utang and hiram records. Anyone can add or retrieve records, and the AI still runs on-device.

**Constraints (non-negotiable if built):**
1. **Off by default.** The main demo and the submission video run with it off.
2. **Sync rows only.** Person, item, place, amount, due date, status, kind. **Never audio. Never transcripts.**
3. **End-to-end encrypted** with a shared group key, so the cloud stores ciphertext. Without this, the privacy claim is false.
4. **Join by invite code.** Last-write-wins conflict handling using `updated_at`. Tombstones via `deleted`.
5. **Local database stays the source of truth.** The app works fully offline with sync off or unreachable.
6. **Visible state:** a "Sync: off / on" indicator in the meter, and bytes sent shown honestly when on.
7. **Disclose** the service (for example Supabase or Firestore) in the submission and README.
8. Embeddings are recomputed locally on the receiving device. Don't sync vectors.

**Definition of done (all required to merge):** two devices (or a device plus emulator) exchange one memory both ways, sync-off path unchanged, 3 clean demo passes with it off after merge. If any item fails by the hard stop, drop it.

## 19. Fallbacks

### Plan A: Flutter UI + Python backend over LAN (if the hour-3 spike fails)

Flutter app on the phone talks over a local hotspot or LAN to a laptop running Whisper, an LLM via Ollama, and embeddings. No internet needed. Be upfront in the pitch that the AI runs on the laptop. Pipeline logic, schema, validation and tests carry over unchanged.

### Alternate ideas (all reuse most of the pipeline)

- **Gastos Tapik:** voice-logged expenses with natural-language questions.
- **Tindahan Tala:** voice ledger for sari-sari stores.
- **Peke Ba?:** scam message shield (OCR plus rules plus LLM explanation).

## 20. Submission checklist (deadline Oct 10, 10:00 AM, one shot)

Submit on the Cerebral Valley event page: cerebralvalley.ai/e/appbuildersph-hackathon-2026

- [ ] Project name, short description, team members (match the official website list)
- [ ] **Public** GitHub repo with judge setup instructions (deployment isn't required): how to build the APK, where to download the models, how to `adb push` them
- [ ] Demo video, about 1 minute
- [ ] X or LinkedIn post URL (tag Devin/Cognition, include #AppBuildersPH)
- [ ] What runs locally (speech, LLM, embeddings, storage, retrieval)
- [ ] What requires internet (nothing at runtime; model download at setup only; Group mode only if shipped and off by default)
- [ ] Models used
- [ ] Technologies and frameworks
- [ ] APIs and cloud services (none at runtime unless Group mode shipped)
- [ ] Existing code and assets (disclose, aim for none)
- [ ] AI development tools used
- [ ] Answer: *Why does this product benefit from running AI locally?*

## 21. Rules to stay inside

- Substantially built during the hackathon. Disclose any pre-existing code or assets.
- No help from anyone outside your team. This is a disqualifying offense.
- No fake benchmarks. Report only what you measured, labeled "vivo V30, 12 GB".
- One project per team. Each person on one team only.
- Code freezes at 10:00 AM. Judges review the repo as of the deadline. The repo must be public by then.
- For finalists: someone must be on site at Cyberzone, SM Makati on Oct 10. Bring your own laptop for mirroring (Wi-Fi, power, HDMI and USB-C are provided). Finalists are announced at 1:00 PM.
- Questions during the build go to the official Telegram group chat.
