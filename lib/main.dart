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
    systemNavigationBarColor: OmniXColors.voidBlack,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Boot background audio service
  globalAudioHandler = await AudioService.init(
    builder: () => OmniXAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.atguru.omnix_audio.channel.audio',
      androidNotificationChannelName: 'OmniX Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF00F5FF),
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(globalAudioHandler),
      ],
      child: const OmniXApp(),
    ),
  );
}

class OmniXApp extends StatelessWidget {
  const OmniXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniX Audio',
      debugShowCheckedModeBanner: false,
      theme: OmniXTheme.dark(),
      home: const PlayerScreen(),
    );
  }
}
