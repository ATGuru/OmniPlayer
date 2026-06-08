import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import 'core/theme/app_theme.dart';
import 'core/audio/audio_handler.dart';
import 'features/player/screens/player_screen.dart';
import 'features/library/screens/library_screen.dart';

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
      notificationColor: Color(0xFF00F5FF), // cyan glow in notification
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
    ),
  );

  runApp(
    // Riverpod root — wraps entire app
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
      home: const OmniXShell(),
    );
  }
}

/// Root shell with bottom nav — Player | Library
class OmniXShell extends StatefulWidget {
  const OmniXShell({super.key});

  @override
  State<OmniXShell> createState() => _OmniXShellState();
}

class _OmniXShellState extends State<OmniXShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PlayerScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniXColors.voidBlack,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _OmniXNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _OmniXNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _OmniXNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OmniXColors.voidBlack,
        border: Border(
          top: BorderSide(color: OmniXColors.cyan.withOpacity(0.15), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(icon: Icons.graphic_eq, label: 'PLAYER', index: 0, currentIndex: currentIndex, onTap: onTap),
            _NavItem(icon: Icons.library_music_outlined, label: 'LIBRARY', index: 1, currentIndex: currentIndex, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: active ? OmniXColors.cyan : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? OmniXColors.cyan : OmniXColors.cyan.withOpacity(0.25), size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 8,
                  letterSpacing: 2,
                  color: active ? OmniXColors.cyan : OmniXColors.cyan.withOpacity(0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
