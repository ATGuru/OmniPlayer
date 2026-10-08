# OmniPlayer — Flutter Project Structure
## AllTechGuru · Holographic Cyberpunk MP3 Player

Public for review. All other rights reserved. See [LICENSE](LICENSE).

---

## 📁 Directory Map

```
omniplayer/
├── pubspec.yaml                          ← All dependencies (Step 1 ✅)
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml           ← Permissions + audio service (Step 1 ✅)
└── lib/
    ├── main.dart                         ← App entry, Riverpod root, nav shell (Step 1 ✅)
    ├── core/
    │   ├── theme/
    │   │   └── app_theme.dart            ← Colors, text styles, ThemeData (Step 1 ✅)
    │   ├── audio/
    │   │   └── audio_handler.dart        ← just_audio + audio_service bridge (Step 1 ✅)
    │   └── database/
    │       ├── app_database.dart         ← Drift DB schema (Step 2 — NEXT)
    │       └── daos/
    │           ├── tracks_dao.dart       ← Track CRUD (Step 2)
    │           └── playlists_dao.dart    ← Playlist CRUD (Step 2)
    ├── models/
    │   └── track_model.dart              ← Track data model (Step 2)
    ├── services/
    │   └── library_scanner.dart          ← on_audio_query device scan (Step 2)
    ├── providers/
    │   ├── player_provider.dart          ← Riverpod player state (Step 3)
    │   └── library_provider.dart         ← Riverpod library state (Step 3)
    └── features/
        ├── player/
        │   ├── screens/
        │   │   └── player_screen.dart    ← Main player UI (Step 4)
        │   └── widgets/
        │       ├── holo_panel.dart       ← Glass panel widget (Step 4)
        │       ├── spectrum_ring.dart    ← CustomPainter vinyl ring (Step 4)
        │       ├── waveform_bar.dart     ← Animated bars visualizer (Step 4)
        │       ├── progress_bar.dart     ← Seek bar (Step 4)
        │       └── control_buttons.dart  ← Play/pause/skip controls (Step 4)
        └── library/
            ├── screens/
            │   └── library_screen.dart   ← Track list / queue (Step 4)
            └── widgets/
                └── track_tile.dart       ← Single track row (Step 4)
```

---

## 🚀 Setup Instructions

### 1. Create Flutter project
```bash
flutter create omniplayer --org com.atguru
cd omniplayer
```

### 2. Replace generated files with scaffold files
Copy all files from this scaffold into the project directory,
preserving the folder structure shown above.

### 3. Download fonts
Download from Google Fonts and place in `assets/fonts/`:
- Orbitron (Regular 400, Bold 700, Black 900)
- Rajdhani (Light 300, Regular 400, SemiBold 600, Bold 700)

### 4. Create asset directories
```bash
mkdir -p assets/fonts assets/images
```

### 5. Install dependencies
```bash
flutter pub get
```

### 6. Run code generation (Drift + Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 7. Run on device
```bash
flutter run
```

---

## ⚙️ Android SDK Requirements
- `minSdkVersion`: 21  (Android 5.0+)
- `targetSdkVersion`: 34 (Android 14)
- `compileSdkVersion`: 34

Add to `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

---

## 📋 Step Progress

- [x] **Step 1** — Project scaffold, dependencies, permissions, theme, audio handler
- [ ] **Step 2** — Drift DB, track model, library scanner (on_audio_query)
- [ ] **Step 3** — Riverpod providers for player state + library state
- [ ] **Step 4** — Full UI: PlayerScreen, LibraryScreen, all widgets
- [ ] **Step 5** — Polish, EQ (optional), release APK build

---

## 🎨 Design Tokens Quick Reference

| Token | Value | Use |
|-------|-------|-----|
| `voidBlack` | `#030508` | Background |
| `cyan` | `#00F5FF` | Primary accent, borders |
| `violet` | `#B400FF` | Secondary accent, gradients |
| `magenta` | `#FF00C8` | Tertiary, active states |
| `activeGreen` | `#00FF88` | Playing indicator |
| `Orbitron` | Font | Labels, data, headers |
| `Rajdhani` | Font | Body text, track names |
