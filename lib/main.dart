import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import 'core/theme/app_theme.dart';
import 'core/audio/audio_handler.dart';
import 'features/player/screens/player_screen.dart';

// Global audio handler instance — initialized once at startup
late AudioHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — player looks best vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Full immersive dark UI — status bar blends into void background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: OmniPlayerColors.voidBlack,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Boot background audio service — 12 s timeout guards against
  // Android foreground-service binding failures (silent on Android 14+).
  try {
    globalAudioHandler = await AudioService.init(
      builder: () => OmniPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.atguru.omniplayer.channel.audio',
        androidNotificationChannelName: 'OmniPlayer Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF00F5FF),
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
      ),
    ).timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint('[main] AudioService.init failed, running without service: $e');
    globalAudioHandler = OmniPlayerHandler();
  }

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(globalAudioHandler),
      ],
      child: const OmniPlayerApp(),
    ),
  );
}

class OmniPlayerApp extends StatelessWidget {
  const OmniPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniPlayer',
      debugShowCheckedModeBanner: false,
      theme: OmniPlayerTheme.dark(),
      home: const _HudShell(child: PlayerScreen()),
    );
  }
}

// ── Screen-level HUD ───────────────────────────
// Paints corner brackets + vignette above everything.
// Uses IgnorePointer so it never blocks touches.

class _HudShell extends StatelessWidget {
  final Widget child;
  const _HudShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HudPainter()),
          ),
        ),
      ],
    );
  }
}

class _HudPainter extends CustomPainter {
  static const _arm   = 20.0; // bracket arm length
  static const _thick =  2.0; // stroke width
  static const _inset =  0.0; // distance from true edge

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width, h = sz.height;
    final e = _inset;

    // ── Vignette ──────────────────────────────
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.38),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignette);

    // ── Corner brackets ───────────────────────
    final glowPaint = Paint()
      ..color = OmniPlayerColors.cyan.withOpacity(0.35)
      ..strokeWidth = _thick + 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final corePaint = Paint()
      ..color = OmniPlayerColors.cyan.withOpacity(0.90)
      ..strokeWidth = _thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final brightPaint = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final segs = [
      // Top-left
      (Offset(e, e),         Offset(e + _arm, e)),
      (Offset(e, e),         Offset(e, e + _arm)),
      // Top-right
      (Offset(w - e, e),     Offset(w - e - _arm, e)),
      (Offset(w - e, e),     Offset(w - e, e + _arm)),
      // Bottom-left
      (Offset(e, h - e),     Offset(e + _arm, h - e)),
      (Offset(e, h - e),     Offset(e, h - e - _arm)),
      // Bottom-right
      (Offset(w - e, h - e), Offset(w - e - _arm, h - e)),
      (Offset(w - e, h - e), Offset(w - e, h - e - _arm)),
    ];

    for (final (a, b) in segs) canvas.drawLine(a, b, glowPaint);
    for (final (a, b) in segs) canvas.drawLine(a, b, corePaint);
    for (final (a, b) in segs) canvas.drawLine(a, b, brightPaint);
  }

  @override
  bool shouldRepaint(_HudPainter old) => false;
}
