import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puts the SIL Open Font License for the bundled typefaces on Flutter's
/// licenses page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Orbitron'],
      await rootBundle.loadString('assets/fonts/OFL-Orbitron.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Rajdhani'],
      await rootBundle.loadString('assets/fonts/OFL-Rajdhani.txt'),
    );
  });
}
