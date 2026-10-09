# Tanda

A voice-first Taglish memory for hiram, utang, and "nasaan ko nilagay". Runs entirely on an Android phone. See `TANDA_SPEC.md`.

## Build and run

Requires Flutter 3.47.x and an arm64 Android phone (minSdk 24) with USB debugging on.

```
flutter pub get
flutter run
```

## Phone setup: vivo / Funtouch OS (do this before any demo)

Funtouch kills background apps aggressively, which would mean reloading the models. Turn this off for Tanda:

1. **Settings > Battery > Background power consumption management** (on some builds: **Battery > High background power consumption**): find **Tanda**, set it to **Allow** / **Don't restrict**.
2. **Settings > Apps > Tanda > Battery**: allow background activity.
3. **i Manager > App manager > Autostart**: enable Tanda (if this option is present).
4. In Recents, swipe down on the Tanda card to **lock** it so "clear all" doesn't kill it.

Menu names differ between Funtouch versions. The goal is the same: no battery restriction for Tanda.

## Disclosures

See `DISCLOSURES.md`. Measured numbers are in `MEASUREMENTS.md`.
