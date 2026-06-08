import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/database/app_database.dart';
import '../core/audio/audio_handler.dart';
import '../services/library_scanner.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final libraryScannerProvider = Provider<LibraryScanner>((ref) {
  return LibraryScanner(ref.watch(databaseProvider));
});

final tracksProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(databaseProvider).watchAllTracks();
});

final favoritesProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(databaseProvider).watchFavorites();
});

class ScanState {
  final bool isScanning;
  final int scanned;
  final int total;
  final String? error;
  const ScanState({this.isScanning=false, this.scanned=0, this.total=0, this.error});
  ScanState copyWith({bool? isScanning, int? scanned, int? total, String? error}) => ScanState(
    isScanning: isScanning ?? this.isScanning,
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    error: error ?? this.error,
  );
}

class ScanNotifier extends StateNotifier<ScanState> {
  final LibraryScanner _scanner;
  ScanNotifier(this._scanner) : super(const ScanState());
  Future<void> scan() async {
    state = state.copyWith(isScanning: true, scanned: 0, total: 0, error: null);
    final result = await _scanner.scanLibrary(
      onProgress: (scanned, total) => state = state.copyWith(scanned: scanned, total: total),
    );
    state = state.copyWith(isScanning: false, scanned: result.tracksFound, error: result.error);
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref.watch(libraryScannerProvider));
});

class PlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final int currentIndex;
  final bool shuffle;
  final AudioServiceRepeatMode repeatMode;
  final double volume;
  final String? error;

  const PlayerState({
    this.currentTrack, this.isPlaying=false, this.position=Duration.zero,
    this.duration=Duration.zero, this.queue=const [], this.currentIndex=0,
    this.shuffle=false, this.repeatMode=AudioServiceRepeatMode.none,
    this.volume=1.0, this.error,
  });

  PlayerState copyWith({Track? currentTrack, bool? isPlaying, Duration? position,
    Duration? duration, List<Track>? queue, int? currentIndex, bool? shuffle,
    AudioServiceRepeatMode? repeatMode, double? volume, String? error}) => PlayerState(
    currentTrack: currentTrack ?? this.currentTrack,
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    queue: queue ?? this.queue,
    currentIndex: currentIndex ?? this.currentIndex,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
    volume: volume ?? this.volume,
    error: error ?? this.error,
  );

  double get progressFraction {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player;
  final OmniXAudioHandler? _handler;
  final AppDatabase _db;
  final bool _isDesktop;

  PlayerNotifier(this._player, this._handler, this._db, this._isDesktop)
      : super(const PlayerState()) {
    _player.positionStream.listen((p) => state = state.copyWith(position: p));
    _player.durationStream.listen((d) { if (d != null) state = state.copyWith(duration: d); });
    _player.playingStream.listen((p) => state = state.copyWith(isPlaying: p));
    _player.currentIndexStream.listen((i) {
      if (i != null && i < state.queue.length) {
        state = state.copyWith(currentTrack: state.queue[i], currentIndex: i);
      }
    });
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) skipNext();
    });
  }

  Future<void> playTrack(Track track, List<Track> queue) async {
    try {
      final index = queue.indexWhere((t) => t.id == track.id);
      final safeIndex = index < 0 ? 0 : index;

      // Build sources — skip any file that doesn't exist
      final validPairs = <MapEntry<int, Track>>[];
      for (int i = 0; i < queue.length; i++) {
        final f = File(queue[i].path);
        if (await f.exists()) validPairs.add(MapEntry(i, queue[i]));
      }

      if (validPairs.isEmpty) {
        state = state.copyWith(error: 'No valid files found');
        return;
      }

      // Find new index of selected track in filtered list
      final newIndex = validPairs.indexWhere((e) => e.value.id == track.id);
      final safeNewIndex = newIndex < 0 ? 0 : newIndex;
      final validTracks = validPairs.map((e) => e.value).toList();

      final sources = ConcatenatingAudioSource(
        children: validTracks.map((t) =>
          AudioSource.uri(Uri.file(t.path))
        ).toList(),
      );

      // Sync audio_service notification queue so lock-screen / notification
      // controls display the correct track metadata on mobile.
      await _handler?.updateQueue(validTracks.map((t) => MediaItem(
        id: t.path,
        title: t.title,
        artist: t.artist,
        album: t.album,
      )).toList());

      await _player.setAudioSource(sources, initialIndex: safeNewIndex);
      await _player.play();
      await _db.incrementPlayCount(track.id);

      state = state.copyWith(
        currentTrack: track,
        queue: validTracks,
        currentIndex: safeNewIndex,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> togglePlayPause() async {
    try {
      _player.playing ? await _player.pause() : await _player.play();
    } catch (_) {}
  }

  Future<void> skipNext() async {
    try {
      if (_player.hasNext) await _player.seekToNext();
    } catch (_) {}
  }

  Future<void> skipPrevious() async {
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    } catch (_) {}
  }

  Future<void> seek(double fraction) async {
    try {
      final ms = (fraction * state.duration.inMilliseconds).round();
      await _player.seek(Duration(milliseconds: ms));
    } catch (_) {}
  }

  Future<void> toggleShuffle() async {
    final next = !state.shuffle;
    await _player.setShuffleModeEnabled(next);
    state = state.copyWith(shuffle: next);
  }

  Future<void> cycleRepeat() async {
    final next = switch (state.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all  => AudioServiceRepeatMode.one,
      _                           => AudioServiceRepeatMode.none,
    };
    await _player.setLoopMode(switch (next) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _                          => LoopMode.off,
    });
    if (!_isDesktop) await _handler?.setRepeatMode(next);
    state = state.copyWith(repeatMode: next);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  Future<void> toggleFavorite() async {
    if (state.currentTrack != null) {
      await _db.toggleFavorite(state.currentTrack!.id);
    }
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final db = ref.watch(databaseProvider);
  final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  if (isDesktop) {
    final player = AudioPlayer();
    ref.onDispose(() => player.dispose());
    return PlayerNotifier(player, null, db, true);
  }

  // On mobile, share the handler's AudioPlayer so the UI and the
  // audio_service background handler always operate on the same instance.
  // Previously a second AudioPlayer was created here, which caused the
  // notification controls and the in-app controls to drive different players.
  final handler = ref.watch(audioHandlerProvider) as OmniXAudioHandler;
  return PlayerNotifier(handler.player, handler, db, false);
});
