import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/theme/app_theme.dart';

void main() {
  group('OmniPlayerColors', () {
    test('voidBlack color is defined', () {
      expect(OmniPlayerColors.voidBlack, isNotNull);
      expect(OmniPlayerColors.voidBlack.value, equals(0xFF030508));
    });

    test('cyan color is defined', () {
      expect(OmniPlayerColors.cyan, isNotNull);
      expect(OmniPlayerColors.cyan.value, equals(0xFF00F5FF));
    });

    test('violet color is defined', () {
      expect(OmniPlayerColors.violet, isNotNull);
      expect(OmniPlayerColors.violet.value, equals(0xFFB400FF));
    });

    test('magenta color is defined', () {
      expect(OmniPlayerColors.magenta, isNotNull);
      expect(OmniPlayerColors.magenta.value, equals(0xFFFF00C8));
    });

    test('panelGlass getter returns transparent cyan', () {
      final glass = OmniPlayerColors.panelGlass;
      expect(glass.alpha, lessThan(255));
      expect(glass.red, equals(OmniPlayerColors.cyan.red));
      expect(glass.green, equals(OmniPlayerColors.cyan.green));
      expect(glass.blue, equals(OmniPlayerColors.cyan.blue));
    });
  });

  group('OmniPlayerTextStyles', () {
    test('orbitronTitle is defined', () {
      expect(OmniPlayerTextStyles.orbitronTitle, isNotNull);
      expect(OmniPlayerTextStyles.orbitronTitle.fontFamily, equals('Orbitron'));
      expect(OmniPlayerTextStyles.orbitronTitle.fontSize, equals(20));
    });

    test('orbitronLabel is defined', () {
      expect(OmniPlayerTextStyles.orbitronLabel, isNotNull);
      expect(OmniPlayerTextStyles.orbitronLabel.fontFamily, equals('Orbitron'));
      expect(OmniPlayerTextStyles.orbitronLabel.fontSize, equals(10));
    });

    test('rajdhaniBody is defined', () {
      expect(OmniPlayerTextStyles.rajdhaniBody, isNotNull);
      expect(OmniPlayerTextStyles.rajdhaniBody.fontFamily, equals('Rajdhani'));
      expect(OmniPlayerTextStyles.rajdhaniBody.fontSize, equals(14));
    });
  });

  group('OmniPlayerSpacing', () {
    test('spacing constants are defined', () {
      expect(OmniPlayerSpacing.xs, equals(4.0));
      expect(OmniPlayerSpacing.sm, equals(8.0));
      expect(OmniPlayerSpacing.md, equals(16.0));
      expect(OmniPlayerSpacing.lg, equals(24.0));
      expect(OmniPlayerSpacing.xl, equals(32.0));
      expect(OmniPlayerSpacing.xxl, equals(48.0));
    });

    test('screenPadding is defined', () {
      expect(OmniPlayerSpacing.screenPadding, isNotNull);
      expect(OmniPlayerSpacing.screenPadding.left, equals(20));
      expect(OmniPlayerSpacing.screenPadding.right, equals(20));
      expect(OmniPlayerSpacing.screenPadding.top, equals(16));
      expect(OmniPlayerSpacing.screenPadding.bottom, equals(16));
    });

    test('panelPadding is defined', () {
      expect(OmniPlayerSpacing.panelPadding, isNotNull);
      expect(OmniPlayerSpacing.panelPadding.left, equals(20));
      expect(OmniPlayerSpacing.panelPadding.top, equals(20));
      expect(OmniPlayerSpacing.panelPadding.right, equals(20));
      expect(OmniPlayerSpacing.panelPadding.bottom, equals(20));
    });
  });

  group('OmniPlayerTheme', () {
    test('dark theme is defined', () {
      final theme = OmniPlayerTheme.dark();
      expect(theme, isNotNull);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(OmniPlayerColors.voidBlack));
    });

    test('dark theme uses correct color scheme', () {
      final theme = OmniPlayerTheme.dark();
      expect(theme.colorScheme.primary, equals(OmniPlayerColors.cyan));
      expect(theme.colorScheme.secondary, equals(OmniPlayerColors.violet));
      expect(theme.colorScheme.tertiary, equals(OmniPlayerColors.magenta));
    });
  });
}
