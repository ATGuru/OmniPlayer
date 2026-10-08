# OmniPlayer

Free Android music player by Guru Morgan, AllTechGuru. No accounts, no ads, and no paywall.

OmniPlayer plays music stored on the phone. Scan reads songs that are already on the device. Free Music searches Creative Commons and public-domain netlabel MP3s on archive.org and can preview or save them inside the app. Create New Song opens https://lyricsintosong.com in the browser and sends nothing from the library with that link.

The Android application id is `com.atguru.omniplayer`.

## License

Public for review. All other rights reserved. See [LICENSE](LICENSE).

Orbitron and Rajdhani stay under the SIL Open Font License. The texts are [assets/fonts/OFL-Orbitron.txt](assets/fonts/OFL-Orbitron.txt) and [assets/fonts/OFL-Rajdhani.txt](assets/fonts/OFL-Rajdhani.txt). The About screen opens them on the licenses page.

`packages/just_audio_mpv` and `packages/mpv_dart` keep their own MIT licenses. Those packages are for desktop playback.

## Release build

A Play upload needs `android/key.properties`. Copy [android/key.properties.example](android/key.properties.example) and point it at the upload keystore. That file is gitignored. If it is missing, the release build stops instead of signing with the debug key.

Google Play requires a new phone app to target API 36. This project pins that floor.

```
flutter pub get
flutter build appbundle
```

Privacy policy: https://atguru.github.io/omniplayer-privacy/
