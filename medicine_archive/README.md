# Medicine Archive

An Android app (Flutter) that keeps a list of medicines for each person in
the family. Photograph a medicine box, check the name and quantity the app
read, and save it under the right profile.

## What it does

- **Profiles:** create one per person (just a name).
- **Scan box:** takes a photo with the camera, reads the text on the phone
  with Google ML Kit (nothing is sent online), and guesses the name (the
  biggest text, plus the dosage such as "500 mg") and the pack size ("20
  compresse", "24 tablets", "100 ml").
- **Check before saving:** the guess always opens in a form to fix. If the
  label can't be read, the same form lets you type it.
- **Photo deleted:** the photo file is deleted right after reading, whether
  reading worked or not. Only the name and quantity you save are kept.
- **Encrypted:** everything is saved in one file encrypted with AES-256-GCM.
  The key is created on first launch and kept in Android's Keystore-backed
  secure storage, so it never leaves the phone. Android backups are off.

## Run

```bash
cd medicine_archive
flutter pub get
flutter run            # with an Android phone or emulator connected
```

Needs Android 6.0 (API 23) or newer. Each CI run also builds a debug APK
you can download from the run's artifacts (`medicine-archive-debug-apk`).

## Browser preview

`lib/demo/demo_main.dart` runs the same screens in a browser, with the
camera, ML Kit and the encrypted file stood in for (sample boxes go through
the real `LabelParser`; data stays in memory):

```bash
flutter run -d chrome -t lib/demo/demo_main.dart
```

## Develop (TDD)

Tests were written before the code, in `test/`:

- `data/`: the repository and the encrypted file (wrong key and tampered
  file are rejected, nothing readable on disk)
- `scan/`: the label parser and the photo scanner (photo deleted)
- `ui/`: the screens, with a fake camera and scanner

```bash
flutter test
flutter analyze
```

## Code map

- `lib/data/`: models, `ArchiveRepository`, `EncryptedFileStore`, key storage
- `lib/scan/`: `LabelParser`, `PhotoScanner`, ML Kit reader
- `lib/ui/`: profiles list, profile (medicines) screen, medicine form
- `design/`: the design brief (Dieter Rams principles) the UI follows
