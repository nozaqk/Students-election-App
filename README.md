# Student Election — Android app (Flutter / Dart)

A native Android app, written in **Dart with Flutter**, for students to follow and vote in their
institution's elections. It is a complete rebuild of the Student Election web app with the same
design and the same features, plus the phone-only capabilities (Bluetooth presence verification
and background notifications) built directly into the app instead of a WebView bridge.

Backend: `https://students-election-system.onrender.com` (overridable at build time, see below).

## Features

| Area | What the student gets |
|---|---|
| **Sign in / Create account / Reset password** | Index-number + password sign-in. Two-step account creation and password reset with an emailed 6-character code (10-minute expiry). Sessions last 11 hours and are stored encrypted on the phone. |
| **Home** | Welcome banner, the single most important election ("Happening now") and a shortcut to all elections. |
| **News** | One announcement card per election with the server's headline, body and voting window. |
| **Election** | Every election ranked by importance (open → paused → upcoming → ended → published → withdrawn). Live status pills, countdown to opening, "you have voted" notices. |
| **Election detail** | Status, description, countdown, positions and candidates with photos, programme and expandable manifestos. Refreshes every 10 s. |
| **Voting** | Presence verification (BLE scan for the ESP32 polling-node beacon, strongest nodes first, server decides), single-use authorisation with a visible expiry timer, ballot with one-or-many selection and abstention per position, review step, receipt. Handles `NODE_REJECTED`, `AUTH_EXPIRED`, `AUTH_USED`, `ALREADY_VOTED`. Elections that do not require presence skip straight to the ballot. |
| **Results** | Published results with turnout, vote bars, winners (★), ties and abstentions. |
| **Settings** | Account details; edit name, level and semester; About; sign out (with confirmation). |
| **Bluetooth badge** | Header badge: **red** = Bluetooth off (tap to be prompted to turn it on), **yellow** = on, **green** = polling-device signal in range. Probes every 10 s while the app is open. |
| **Notifications** | After sign-in the app obtains a limited feed token and checks the server every ~15 min in the background (WorkManager) — new election, voting open/paused/ended, results published, schedule changes. The first check only records state so students are not flooded. Stops on sign-out or when the token is revoked. |
| **Design** | Same palette, type scale, cards, pills, buttons, notices and bottom menu as the web app; automatic light/dark theme; no landscape. |

## Project layout

```
lib/
  main.dart                  app entry: restore session, init notifications, run
  app.dart                   root widget: theme, sign-in ⇄ shell switch, start/stop phone features
  config.dart                API_URL (dart-define), session lifetime, refresh interval
  api/                       HTTP client, error type, encrypted session store, data models
  state/                     live overview feed (10 s polling, lifecycle-aware), importance ranking
  native/                    beacon parser, BLE scanner + probe, Bluetooth badge monitor,
                             permissions, background notification worker
  screens/                   auth, shell (header + tabs), home, news, elections, settings,
                             election/ (detail, vote flow, results)
  theme/                     colour palette (ThemeExtension) and Material theme
  widgets/                   cards, pills, buttons, notices, countdown, avatar, candidate tiles
test/                        unit + widget tests (beacon parser, ranking, models, API client,
                             notification worker, countdown, election card)
scripts/                     setup.sh · check.sh · run.sh · build_apk.sh (shell tooling)
android/                     Flutter host project (manifest, Gradle, launch theme, icons)
.github/workflows/           CI: analyse + test, build APK, publish the "latest" release
```

## Getting started

Requirements: Flutter 3.22+ (stable), Android SDK 34, JDK 17.

```bash
./scripts/setup.sh                 # flutter pub get, local.properties, flutter doctor
./scripts/run.sh                   # run on a connected phone/emulator (debug)
./scripts/check.sh                 # format check, flutter analyze, flutter test
./scripts/build_apk.sh             # release APK → election-app.apk
```

Point the app at another backend with `API_URL`:

```bash
API_URL=https://staging.example.edu ./scripts/build_apk.sh
# or directly:
flutter build apk --release --dart-define=API_URL=https://staging.example.edu
```

Release signing: create `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`,
`keyPassword`). Without it release builds are signed with the debug key, which still installs for
side-loading.

## Continuous integration

`.github/workflows/android-release.yml` runs on every push to `main`:

1. **Analyse and test** — `./scripts/check.sh` (formatting, `flutter analyze`, `flutter test`).
2. **Build APK** — `./scripts/build_apk.sh --release`, uploads `election-app.apk` as an artifact and
   replaces the single GitHub release named **latest** with it. Set the repository variable
   `API_URL` to change the backend baked into the APK.

## How presence verification works

1. The student taps **Vote Now → Verify my location**.
2. The app asks for the *Nearby devices* permission (Android 12+) or *Location* (Android 11 and
   below), checks that Bluetooth is on, and scans for BLE advertisements with company id `0xFFFF`
   and payload version `1`:
   `ver(1) | beaconId(4, BE) | bootNonce(4) | counter(4, BE) | mac(8)`.
3. Up to three distinct beacons are returned, strongest first and with the freshest counter per
   node. The app **does not verify the MAC** — it holds no key. It posts each claim to
   `POST /student/elections/{id}/presence` until the server accepts one (`NODE_REJECTED` moves on to
   the next).
4. The server answers with a single-use authorisation and expiry. The ballot must be submitted
   before it expires; selections are kept if the student has to verify again.

## Security notes

- HTTPS only (`network_security_config.xml`), no cleartext, system CAs only.
- The sign-in token lives in `flutter_secure_storage` (encrypted shared preferences) with an expiry
  and is sent only as a bearer header. A `401` clears it immediately.
- Background notifications use a separate, limited token that can only read the notification feed.
- App data is excluded from Android backup and device transfer.
- Votes are never stored on the phone; the receipt proves *that* a student voted, not *how*.
