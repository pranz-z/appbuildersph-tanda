# Tanda — demo video and submission package

Prepared **10 October 2026, 08:31 Manila time**, against the working checkout at HEAD `5985c49`, including uncommitted and untracked implementation files. Deadline in `TANDA_SPEC.md`: **today, 10:00 AM Manila**. This package does not certify acceptance or submit anything.

## 1. Evidence and recording decision

**Story:** “Who borrowed my drill?” Show one fictional loan, user confirmation, and a question answered from that saved record. Use **typed capture and a typed question** for the primary take. Voice is implemented, but the repository has no completed phone acceptance record supporting a dependable voice demo. Typed capture still exercises local LLM extraction, review, SQLite persistence, and local retrieval. It does not demonstrate Whisper.

Inspected: `TANDA_SPEC.md`, `README.md`, `DISCLOSURES.md`, `GO_NOGO.md`, `MEASUREMENTS.md`, `test_sentences.md`, `SPEC_DEVIATIONS.md`, git history/status/diff, current screens/providers/database/Ask/answer/TTS code, assets/branding documentation, package configuration, and focused test sources. No dedicated completed phone-test report was found. A device screenshot and UI XML dumps are insufficient to establish intentional speech, playable citations, or offline acceptance; keep them out of the video because they may contain personal content.

Important evidence boundaries:

- `MEASUREMENTS.md` has no measurement rows; `GO_NOGO.md` and phone results in `test_sentences.md` are unfilled. Do not quote phone accuracy, speed, RAM, thermal results, five clean runs, or full offline success.
- Available local verification logs dated this morning record **162 tests passing**, **Flutter analyze: no issues**, and a successful arm64 release build. These are workstation results, not phone tests. Logs are not committed reports or a source-tree fingerprint; rerun if code changes.
- The current Ask implementation first retrieves confirmed SQLite rows using deterministic normalized matching. A single confident match can then use **optional local LLM phrasing** with ID/token validation and template fallback (`grounded_answer.dart`, `tanong_screen.dart`). This is newer than README's “answers are never generated” wording. Validation reduces unsupported output; it does not establish semantic correctness or fluency.
- Device TTS is now connected through `flutter_tts`. Its tests use doubles; installed voice behavior is unverified. Do **not** advertise spoken answers or rely on them in this video. Record narration separately and exclude phone media audio; if auto-speech starts, use Stop before proceeding. Do not imply that muting proves synthesis never ran.
- Embedding files can be downloaded/imported, but the production embedding provider is a fake and no embedding inference is connected. Do not say “three active AI models” or “hybrid semantic retrieval.”
- The checkout is dirty and includes untracked runtime files. A public repository containing only current HEAD would not reproduce the demonstrated app. Owner must publish the intended source snapshot before submission; this package makes no commits.

### Candidate artifact

`build/app/outputs/flutter-apk/Tanda-AppBuildersPH-2026-arm64-v8a-release.apk`

- SHA-256 read during this preparation: `641C5A9D7FA8FFBA3818761761E3B930A057432091523C0B3FFE27F0EA3777C6`.
- Version source: `0.1.0+1`; package `ph.tanda.app`. Release configuration uses the existing **debug signing key**, not a store release credential.
- This identifies a candidate artifact, not the APK installed on the vivo V30. Verify installed build and repeat the chosen flow before filming. No device test was performed for this package.

## 2. Preparation and data safety

1. Use an owner-approved **isolated demo installation/profile with no personal memories**, or an existing explicitly designated demo environment. No dedicated demo seed loader was found. Do not import fixtures, edit real records, clear existing app data, or uninstall the user's app to create a clean screen. If no safe demo environment exists, stop and obtain owner confirmation/provisioning first.
2. On that demo installation, create fictional content only through the normal review and explicit save flow. Keep exactly one open demo-drill loan so retrieval is unambiguous. Do not delete real records to achieve this. Repeated rehearsals can create similar records; reuse the designated demo record for Ask shots or use a separately approved clean demo environment for the next full take.
3. Set English and the preferred light/dark theme before filming. Match the actual current labels; do not add fake controls or response overlays. Models must already be present and loaded. Keep downloads/setup, diagnostics, logs and unrelated memory lists off camera.
4. Rehearse the precise description below. Confirm the extracted person/item/date and evidence are correct. If not, correct them visibly or use the honest fallback. Do not assume the model's output matches the proposed answer.
5. Check screen recording and microphone narration separately. Use Do Not Disturb, hide notification previews, remove personal status notifications, and check permission prompts before the take. Do not bypass Android microphone permission if filming voice. Keep comfortable text size and both primary actions reachable.

## 3. Submission video — exactly 60 seconds planned

Timing is **editorial allocation, not an inference benchmark**. Capture the real run first. Processing waits may be shortened with a visible “Processing wait shortened” label; never use a cut to imply a measured response time. Do not synthesize an answer screenshot. Narration is recorded separately; no TTS claim.

| Time / duration | Viewer sees | Exact narration / overlay | Operator action | Shot preparation |
|---|---|---|---|---|
| 00–07 / 7 s | Main Tanda screen, Grandma and Tell Tanda / Ask Tanda | Narration: “Who borrowed my drill? Everyday loans are easy to forget. Tanda helps me keep a memory I can check later.” Overlay: **Tanda — fictional demo record** | Hold on the main screen; no personal list visible. | Empty, approved demo view; models loaded; notifications hidden. |
| 07–18 / 11 s | Tell Tanda typed alternative and description | Narration: “I tell Tanda what happened. Here, I'm using the typed alternative.” Input: **Hiniram ni Demo Mira ang demo drill. Isosoli sa Sabado.** | Open Tell's typed input, enter that exact text, submit for review using the existing action. | Paste/type fictional text only in the approved demo installation. Know where the typed action sits. |
| 18–31 / 13 s | “Did Tanda hear that right?”, editable fields, transcript/evidence and save | Narration: “Tanda extracts the details locally. I check the transcript, edit the return-date wording, and explicitly save.” Overlay: **Review first. Save only after confirmation.** | Inspect lent-item/person/item. Normalize the due text between **Sabado** and **sa Sabado**, preserving the same fact. Tap **Yes, save it** and show actual success. | Verify that edit and evidence behavior in rehearsal. If the result is wrong, correct it honestly; allow more screen time by trimming the intro. |
| 31–39 / 8 s | Ask Tanda's editable text question | Narration: “Later, I ask: Sino may hawak ng demo drill ko?” | Select Ask Tanda, enter **Sino may hawak ng demo drill ko?**, tap Ask. | Exactly one matching confirmed demo record; keyboard must not obscure response. |
| 39–51 / 12 s | Actual answer, supporting saved transcript/citation | Narration: “The answer points back to the confirmed memory, so I can check what it is based on.” Overlay: **Answer + supporting memory** | Show the real response naming Demo Mira, then its transcript citation. If TTS starts, stop it; do not stage a playback action. | Fresh-test the exact query. Typed record has **no audio citation**; do not imply one exists. Reject unsupported generated wording rather than recording it as a success. |
| 51–60 / 9 s | Return to Grandma or hold readable citation, then simple end title | Narration: “Speech recognition and the language model run on the phone. Memories are stored locally. Model downloads need internet during setup.” End text: **Tanda · Remember everyday loans · #AppBuildersPH** | Hold steady; add title during editing. | These are implementation statements. Do not add an airplane badge unless the offline branch below passed. |

**Offline branch, only after a fresh same-build test:** relaunch with airplane mode enabled, Wi-Fi/mobile data off, models already loaded, and repeat the same text Ask successfully. Record this visibly. Replace the last shot with the real status bar plus answer and narration: **“After model setup, this saved-memory question worked in airplane mode on this phone.”** This claims only the observed question test, not a fully offline product or all-device traffic privacy. Do not show a zero byte counter as proof.

**Voice upgrade, only after intentional-speech rehearsal passes:** replace 07–18 with tap Tell Tanda, say **“Hiniram ni Demo Mira yung demo drill, ah, isosoli daw sa Sabado,”** then tap Stop. Narration: **“I tell Tanda what happened, in Taglish.”** Capture the actual listening/thinking states and review. Show AI-corrected speech separately from the unchanged raw Whisper transcript. To claim audio evidence, additionally rehearse and record playback of that saved clip; replace part of 39–51 with actual audible citation playback. Do not claim this upgrade from unit tests or a transcription screenshot.

## 4. Failure-safe takes

| Failure | Honest replacement shot and exact copy | Limit / decision |
|---|---|---|
| Mic permission, silence, noise or recognition failure | Show repeat prompt briefly, then typed alternative. Narration: **“If speech isn't clear, I can type the memory instead.”** | Do not describe the typed take as a successful voice test. Do not repeatedly save rehearsal copies. |
| Extraction fails twice | Show the existing manual-entry fallback with the original description. Fill the same fictional facts, review and explicitly confirm. Narration: **“If extraction fails, I enter the details myself and confirm them.”** | This demonstrates manual fallback, not successful AI extraction. Keep that qualification in the caption/submission if this is the selected take. |
| Optional answer phrasing fails | Use the actual deterministic fallback answer and its citation. Narration stays **“The answer points back to the confirmed memory.”** | Never claim fluent generation. If retrieval is ambiguous, show the real choices and select the intended record; if not found, show the real no-match state, not an edited success. |
| Connectivity unavailable / models absent | With models already installed, test the text path normally. If models are absent, stop filming model-dependent extraction; manual entry may be used only if the actual fallback works. | Do not silently switch to a laptop/cloud service or hide a download behind an “offline” claim. |
| Full flow still fails | Use a previously captured successful **same-build** clip only with visible **“Recorded demonstration”** labeling and truthful scope. Otherwise record the working subset and disclose the missing stage. | No fabricated screens. If no successful end-to-end evidence exists, the planned end-to-end video is not ready. |

## 5. Submission-form copy

**Project:** Tanda

**Short description:** Tanda is an Android memory aid for everyday Taglish notes about borrowed items, money, locations and promises. It uses on-device speech recognition and a local language model to prepare editable memory details. Users confirm before saving to SQLite, then ask questions against confirmed records and inspect the supporting transcript and available recording. Typed capture is available too.

**Why does this product benefit from running AI locally?**

These notes can describe household possessions, personal loans and family conversations. Running speech recognition and language-model inference on the phone avoids requiring a cloud inference request for those tasks; local SQLite keeps confirmed memories available to the local query path. That is useful where connectivity is unreliable and reduces dependence on per-request cloud services. The reviewed core path is local by architecture; full vivo V30 airplane-mode acceptance is not yet documented. This is not a guarantee about all device traffic, backups, third-party engines or every form of data exposure.

**Required owner fields — do not submit placeholders:**

- Team members: **Needs owner confirmation — registered names and team membership, matching the event website.** Do not list AI tools as human teammates or imply outside contributors assisted.
- Public GitHub repository: configured origin is `https://github.com/pranz-z/tanda`; **Needs owner confirmation — public unauthenticated access and the final demonstrated source snapshot, including currently untracked source/assets.**
- Demo video URL: **[VIDEO_URL]**; social post URL: **[POST_URL]**.
- Eligibility/provenance: **Needs owner confirmation — what existed before the build window, asset authorship/permission, complete tool list, and whether work meets event timing/team rules.** Git commit dates alone do not settle these questions.

### What runs locally / what needs internet

| Boundary | Current implementation and honest scope |
|---|---|
| On-device AI | Whisper small int8 through sherpa_onnx/ONNX Runtime; base fallback is supported. Qwen2.5-1.5B Q4_K_M through llamadart/llama.cpp for extraction/cleanup and optional answer phrasing. Actual installed variant requires fresh device confirmation. |
| Local application logic/data | Recording files, Drift SQLite confirmation, structured/token matching, deterministic answer fallback, open-loop sorting/totals, reminder drafting/copy, citation playback. These are code paths, not proof all phone tests passed. |
| Embeddings | e5 setup files exist; inference and hybrid retrieval are **not implemented**. Do not list as active local AI. |
| Device speech output | Android TTS is connected, selecting voices based on engine metadata. Actual engine, installed voice and offline synthesis are unverified; missing metadata is not strong proof of offline behavior. Excluded from demo claims. |
| Internet at setup | Optional explicit model downloads from Hugging Face/CDN; manual import is an alternative once files have been obtained. Models are not bundled in the APK. Build/package downloads and llamadart native-binary fetches also require developer setup connectivity. |
| Cloud/API runtime | No cloud inference or sync service found in reviewed application code. The downloader is the identified application HTTP caller. This is not a network audit of plugins, OS services or TTS engines. |

### Disclosures to attach to the form

Use `DISCLOSURES.md` for source URLs and pinned model revisions, with these current-checkout additions/corrections:

- **Models:** OpenAI Whisper small/base int8 ONNX exports by csukuangfj/sherpa-onnx (repository disclosure attributes Whisper MIT); Qwen/Qwen2.5-1.5B-Instruct-GGUF Q4_K_M (repository disclosure: Apache-2.0). Xenova/intfloat multilingual-e5-small int8 files are included in setup but **unused for inference** (original model disclosure: MIT; export-specific license tag absent). These are repository license statements, not a fresh license audit. Confirm applicable export/model terms before submission.
- **Framework/runtime:** Flutter/Dart, Android, llama.cpp via llamadart 0.10.0, sherpa_onnx 1.13.8/ONNX Runtime, SQLite via drift 2.35.1 and drift_flutter 0.3.1; Riverpod 3.4.3. CPU arm64 build configuration.
- **Other direct packages:** record 7.1.1, just_audio 0.10.6, **flutter_tts 4.2.5** (newer than disclosure document), connectivity_plus 7.3.2, permission_handler 13.0.2, path_provider 2.1.6, file_picker 13.1.0, wakelock_plus 1.8.1, uuid 4.6.0, path 1.9.1, http 1.6.0, crypto 3.0.7, Flutter/localizations SDK. Development: Flutter test/lints 6.0.0, drift_dev 2.35.1, build_runner 2.16.2. `pubspec.lock` supplies transitive dependency versions.
- **APIs/services:** Hugging Face/CDN for optional model download; GitHub/leehack llamadart-native for build-time native binaries. Android platform APIs for microphone, clipboard, UID traffic and TTS. No connected cloud inference/sync found. **Needs owner confirmation — actual Android TTS engine/voice provider and voice-data installation terms**, even though speech output is excluded from the video.
- **Existing code/assets:** Flutter-generated scaffold; prior planning/spec document; Caveat font with bundled SIL OFL 1.1 notice crediting Caveat Project Authors; supplied Grandma PNG layers/static artwork; supplied launcher portrait and generated Android icon sizes. **Needs owner confirmation — Grandma and launcher artwork creator/source/license, any generation tool, creation date, permission to redistribute, and which code/assets predate the event.** Do not say “no pre-existing assets.” Do not assume the portrait and kit share authorship.
- **AI development tools:** repository disclosures list Devin (Cognition) for IDE pair programming and Codex (OpenAI) for code/UI/documentation assistance. **Needs owner confirmation — complete tools/models used, any artwork-generation tools, and actual scope/timing of their use.** Do not invent Claude or outside human contributors.
- **Scope gaps:** no embedding/hybrid retrieval, no recorded full phone acceptance or performance measurements. README and older spec-deviation notes predate connected answer phrasing/TTS; disclose the current behavior described above rather than repeating their stale “templates only”/“visual speaking only” statements.

### X / LinkedIn caption

> Who borrowed my drill? Tanda turns everyday Taglish notes into memories you review, confirm and ask about later—with a supporting transcript. Speech recognition and the language model run on the phone; model downloads need internet at setup. This clip uses typed input. Built for #AppBuildersPH with Devin/Cognition and Codex assistance. Demo: [VIDEO_URL] · Code: [PUBLIC_REPO_URL] · [DEVIN_OR_COGNITION_TAG]

**Needs owner confirmation:** replace the tag placeholder with the organizer's appropriate actual account mention; verify public links. If the voice upgrade or manual fallback is used, replace “This clip uses typed input” with the precise observed scope. Add an airplane-mode sentence only after the specific fresh test passes. The owner posts; this package does not.

## 6. Claims checklist

“Verified” below means the stated evidence scope, **not automatically a phone pass**.

| Proposed statement | Status | Evidence / condition |
|---|---|---|
| Capture supports typed input, review and explicit confirmation | Verified in code | `tala_screen.dart`, `memory_persistence_test.dart`; fresh phone execution still required. |
| Confirmed memories use SQLite, including separate raw transcript and optional audio path | Verified in code | `app_database.dart` schema v2, migration/save APIs; typed capture passes no audio path. |
| Retrieval reads confirmed records; ambiguity and no-match are handled | Verified in code/tests inspected | `local_memory_ask.dart`, `tanong_ask_test.dart`; no-match is localized (Tagalog: “Wala akong nahanap.”). |
| Ask may phrase a single match using the local LLM, with template fallback | Verified in current code | `grounded_answer.dart`, `tanong_screen.dart`, `grounded_answer_test.dart`. No claim of reliably fluent/semantically perfect output. |
| Whisper and Qwen production providers are local | Verified in code | `providers.dart`, STT/LLM services; no claim that a specific phone run succeeded. |
| 162 automated tests passed; analyze was clean | Verified recorded workstation output | This morning's final-icon test/analyze logs inspected; not a phone result or a guarantee after later edits. |
| Voice capture, intelligibility rejection and audio citation work on vivo V30 | Requires a fresh test | Intentional speech, silence/noise, real nonempty clip, transcription, confirm, relaunch and audible playback. |
| This exact demo question retrieves the correct demo record | Requires a fresh test | Same APK, isolated demo data, actual visible answer and citation. |
| A saved-memory question works in airplane mode | Requires a fresh test | Relauch with setup complete, airplane mode and Wi-Fi/mobile data off; record observed result. |
| Full product works offline / five clean runs / phone accuracy or latency | Unverified | Blank measurements/go-no-go tables. Omit claims and numbers. |
| Embeddings/hybrid retrieval are active | Unverified / contradicted by code | Fake embedding provider; do not claim. |
| Spoken answers use an installed offline voice successfully | Requires a fresh test | TTS engine/voice metadata and synthesis need device validation; omit from video. |
| No data ever leaves the phone / zero device traffic / guaranteed privacy | Unverified | Not established by source or UID counters; do not claim. Question/draft recordings may remain on disk even without memory rows. |
| Public repository reproduces the candidate APK | Requires owner check | Dirty/untracked files and public accessibility; establish final snapshot/build association. |
| Asset rights, complete tool history and hackathon eligibility | Needs owner confirmation | Missing provenance/timing/registered-team evidence. |

## 7. Recording and final playback checklist

- [ ] Identify the demo device/build; do not present workstation tests as vivo results. Confirm correct candidate APK without uninstalling/clearing personal data.
- [ ] Approve isolated demo data environment; inspect every visible screen for personal names, transcripts, filenames and notification previews.
- [ ] Models fully loaded; battery/storage sufficient; no download or debug screen in the take. Avoid displaying diagnostics counters.
- [ ] Rehearse one exact capture → review/edit → explicit save → Ask → citation sequence. Record actual errors if using a fallback. For typed input, do not expect audio.
- [ ] Close/reopen and query the same saved demo record; note build/date/outcome. Repeat the full planned demo five clean times if feasible, as the spec asks; report actual count only. Do not create duplicate rows indiscriminately.
- [ ] Optional voice: test intentional speech and silence; verify recording/stop/transcription and actual saved-clip playback. Optional offline: run the precisely scoped airplane-mode test before claiming it.
- [ ] Screen recording legible, taps visible, portrait framing stable, keyboard dismissed for citation. Separate narration audible; phone TTS/media excluded unless intentionally verified and disclosed.
- [ ] Trim to about 60 seconds without concealing a failed step; label shortened waits and prerecorded demonstrations. Check all captions against actual output, not hoped-for output.
- [ ] Watch the final exported file from start to finish on a second player: readable review/confirmation and citation, no personal content, no misleading audio, no false speed/offline claims, no accidental debug exposure.
- [ ] Verify video and repository accessible while logged out; confirm social mention and hashtag, copy actual video/post URLs into the form, and check all owner fields. Owner submits before 10:00 AM Manila; no submission performed here.

## 8. Separate live Demo Day pitch — 5 minutes

This is **not** the submission-video script. Allocate time to usefulness (25%), local AI (25%), execution (20%), innovation (15%) and product/demo quality (15%) without claiming a score.

| Time | Content |
|---|---|
| 0:00–0:30 | Problem: a household loan forgotten; one person, one drill. Explain why a generic note is hard to find later. |
| 0:30–2:15 | Live rehearsed capture, review/correction and explicit save; typed primary, voice only if validated. Show progress honestly. |
| 2:15–3:00 | Ask the drill question and show transcript citation. Play saved audio only for a validated voice record. Show a no-match question only if rehearsed and it fits. |
| 3:00–3:45 | Architecture: local Whisper → Qwen extraction/validation → user confirmation → SQLite → structured retrieval → template/validated optional phrasing. Explicitly say embeddings are pending. |
| 3:45–4:30 | Why local: sensitive everyday context and reduced cloud dependency. If freshly verified, demonstrate the saved question in airplane mode. Otherwise state the test gap. Use only measured phone numbers, or none. |
| 4:30–5:00 | Boundaries/disclosures and close: setup downloads, asset/tool credits, missing acceptance evidence. Grandma and approachable review are UX choices, not AI accuracy proof. End on the useful answered question. |

### Likely questions for the 3-minute Q&A

1. **Why not notes or ChatGPT?** Confirmed structured records and inspectable supporting memories; no required cloud inference for core tasks. Do not claim superiority without evaluation.
2. **What actually runs locally?** Two active AI components; deterministic retrieval/storage; embeddings pending. Explain optional answer phrasing and fallback.
3. **Did you prove airplane-mode operation?** Give the exact observed build/test outcome, or say repository acceptance is unfilled. Never substitute architecture for observation.
4. **How do you prevent hallucinations?** Review before save, evidence checks, conservative matching/ambiguity, generated-answer validation and fallback. These are safeguards, not a guarantee; token validation cannot prove all relationships are correct.
5. **Can it recognize Filipino names and money reliably?** Show measured phone results only. The 15-sentence worksheet is currently blank; format validity is not accuracy.
6. **What happens when models fail or the mic is blocked?** Typed/manual fallback; unclear speech repeat prompt; no automatic confirmation. Show only tested fallback behavior.
7. **What leaves the phone?** Identified setup downloader traffic; no connected cloud inference/sync found. Qualify OS/TTS/plugin behavior and local retained audio; the meter is not a device-wide privacy proof.
8. **What's incomplete?** Embeddings/hybrid retrieval and documented phone acceptance; avoid implying every spec P0 is complete.
9. **How big/fast/hot is it?** Give only current measured device evidence. Models are separate from APK; no invented latency/RAM figures.
10. **Who built it, and what was reused?** Registered team, disclosed AI tools, scaffold/font/character/icon assets; unresolved provenance needs owner confirmation.

## Ready to record?

**Conditionally ready for a typed rehearsal; not yet evidence-ready for voice, spoken-answer, full-offline or performance claims.**

Blocking checks before the final take/submission:

1. Owner approves a non-personal demo installation and confirms asset rights, registered team, complete tool list and build-window eligibility.
2. On the actual installed candidate build, run the exact typed description → edit due wording → explicit save → close/reopen → exact Ask → correct transcript citation. Record date/build and observed outcome. If it fails, use a truthful fallback or stop the end-to-end claim.
3. Include voice/audio/offline shots only after their specific real-device tests pass. Otherwise keep the default typed script and architectural local-AI wording.
4. Ensure the public source includes the demonstrated dirty/untracked implementation, reconcile stale answer/TTS disclosures for submission, and establish the source/build association. Recheck `flutter test`, `flutter analyze`, and `git diff --check` if source changes; do not treat this documentation preparation as a fresh application validation run.
5. Review exported video and public URLs logged out; replace every owner/tag/URL placeholder and submit the complete form before **10:00 AM Manila today**. Do not spend the remaining submission window adding features.
