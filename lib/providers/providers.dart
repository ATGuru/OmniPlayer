import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/resume_storage.dart';
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
  ScanState copyWith({bool? isScanning, int? scanned, int? total, Object? error = _keepError}) => ScanState(
    isScanning: isScanning ?? this.isScanning,
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    error: identical(error, _keepError) ? this.error : error as String?,
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

const _keepError = Object();
const _keepTrack = Object();

class PlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final int currentIndex;
  final bool shuffle;
  final AudioServiceRepeatMode repeatMode;
  final double volume;
  final String? error;

  const PlayerState({
    this.currentTrack, this.isPlaying=false, this.isLoading=false,
    this.position=Duration.zero, this.duration=Duration.zero,
    this.queue=const [], this.currentIndex=0, this.shuffle=false,
    this.repeatMode=AudioServiceRepeatMode.none, this.volume=1.0, this.error,
  });

  PlayerState copyWith({Object? currentTrack = _keepTrack, bool? isPlaying, bool? isLoading,
    Duration? position, Duration? duration, List<Track>? queue, int? currentIndex,
    bool? shuffle, AudioServiceRepeatMode? repeatMode, double? volume,
    Object? error = _keepError}) => PlayerState(
    currentTrack: identical(currentTrack, _keepTrack) ? this.currentTrack : currentTrack as Track?,
    isPlaying: isPlaying ?? this.isPlaying,
    isLoading: isLoading ?? this.isLoading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    queue: queue ?? this.queue,
    currentIndex: currentIndex ?? this.currentIndex,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
    volume: volume ?? this.volume,
    error: identical(error, _keepError) ? this.error : error as String?,
  );

  double get progressFraction {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player;
  final OmniPlayerHandler? _handler;
  final AppDatabase _db;
  final bool _isDesktop;
  int _positionTick = 0;
  int _pendingSeekMs = 0; // set by restoreResumeState, consumed on first play
  Future<void> _loadChain = Future<void>.value();
  bool _loadingTrack = false;
  bool _trackChosen = false;
  bool _autoAdvanceQueued = false;
  // ExoPlayer can report the previous track as ended while the next source loads.
  DateTime? _ignoreCompleteUntil;
  List<Track>? _unshuffled;
  final _random = Random();

  PlayerNotifier(this._player, this._handler, this._db, this._isDesktop)
      : super(const PlayerState()) {
    _handler?.onSkipNext = skipNext;
    _handler?.onSkipPrevious = skipPrevious;
    if (!_isDesktop) {
      Future.microtask(() async {
        try {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music());
        } catch (e) {
          debugPrint('[PlayerNotifier] audio session: $e');
        }
      });
    }
    _player.positionStream.listen((p) {
      state = state.copyWith(position: p);
      // Save position every 10 ticks (~10 s) while playing
      if (state.currentTrack != null && ++_positionTick % 10 == 0) {
        ResumeStorage.save(trackId: state.currentTrack!.id, positionMs: p.inMilliseconds);
      }
    });
    // just_audio_mpv emits Duration(days:365) as a placeholder before mpv probes
    // the real duration — filter it out so the UI never shows 525600:00.
    _player.durationStream.listen((d) {
      if (d != null && d.inDays < 364) state = state.copyWith(duration: d);
    });
    _player.playingStream.listen((p) => state = state.copyWith(isPlaying: p));
    _player.processingStateStream.listen((s) {
      final loading = s == ProcessingState.loading || s == ProcessingState.buffering;
      state = state.copyWith(isLoading: loading);
      if (s == ProcessingState.completed) _onTrackCompleted();
    });
  }

  // One source change at a time. play() is not part of this chain: on Android
  // that future stays open until the track ends.
  Future<void> _enqueue(Future<void> Function() action) {
    final run = _loadChain.then((_) async {
      _loadingTrack = true;
      try {
        await action();
      } catch (e, st) {
        debugPrint('[PlayerNotifier] $e\n$st');
        state = state.copyWith(isLoading: false, error: e.toString());
      } finally {
        _loadingTrack = false;
      }
    });
    _loadChain = run.then((_) {}, onError: (_, __) {});
    return run;
  }

  void _onTrackCompleted() {
    if (_loadingTrack || _autoAdvanceQueued) return;
    final until = _ignoreCompleteUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    _autoAdvanceQueued = true;
    _enqueue(() async {
      if (!_autoAdvanceQueued) return;
      _autoAdvanceQueued = false;
      await _advance(1);
    });
  }

  void _showTrack(Track track, int index, {List<Track>? queue}) {
    state = state.copyWith(
      currentTrack: track,
      currentIndex: index,
      queue: queue,
      position: Duration.zero,
      duration: track.duration > 0
          ? Duration(milliseconds: track.duration)
          : state.duration,
      error: null,
    );
  }

  Future<void> _kickPlayback() async {
    // pause/play reopens the PipeWire output on desktop. On Android, pause()
    // makes play() wait until STATE_ENDED, so the title update used to sit
    // behind that future for the whole song.
    if (_isDesktop) await _player.pause();
    unawaited(_player.play().then((_) {}, onError: (Object e, StackTrace st) {
      debugPrint('[PlayerNotifier] play error: $e\n$st');
    }));
  }

  Future<void> restoreResumeState() async {
    try {
      final saved = await ResumeStorage.load();
      if (saved == null || _trackChosen) return;

      final track = await _db.getTrackById(saved.trackId);
      if (track == null || _trackChosen || !await File(track.path).exists()) return;

      final allTracks = await _db.getAllTracks();
      if (_trackChosen) return;
      final valid = <Track>[];
      for (final t in allTracks) {
        if (_trackChosen) return;
        if (await File(t.path).exists()) valid.add(t);
      }
      if (valid.isEmpty || _trackChosen) return;

      // Don't touch the player — just populate UI state so the track info
      // and saved position are visible. Audio loads on first press of play.
      _pendingSeekMs = saved.positionMs;

      final idx = valid.indexWhere((t) => t.id == track.id);
      state = state.copyWith(
        currentTrack: track,
        queue: valid,
        currentIndex: idx < 0 ? 0 : idx,
        position: Duration(milliseconds: saved.positionMs),
        error: null,
      );
    } catch (e) {
      debugPrint('[PlayerNotifier] restoreResumeState error: $e');
    }
  }

  // Loads one track as a plain UriAudioSource.
  // just_audio_mpv's ConcatenatingAudioSource path is broken on Linux —
  // it sends loadfile with empty options and playlist-play-index as a string,
  // both of which mpv rejects with "invalid parameter". Loading a single URI
  // avoids both bugs. The queue is managed in Dart state instead.
  // Loads a track without starting playback. Caller decides when/how to play.
  Future<void> _loadSingle(Track track) async {
    await _handler?.updateQueue([MediaItem(
      id: track.path, title: track.title, artist: track.artist, album: track.album,
    )]);
    await _player.setAudioSource(AudioSource.uri(Uri.file(track.path)));
    // The ended event for the previous file can arrive after this load returns.
    _ignoreCompleteUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    await _db.incrementPlayCount(track.id);
    await ResumeStorage.save(trackId: track.id, positionMs: 0);
  }

  Future<void> playTrack(Track track, List<Track> queue) {
    _trackChosen = true;
    _autoAdvanceQueued = false;
    final tappedIndex = queue.indexWhere((t) => t.id == track.id);
    _showTrack(track, tappedIndex < 0 ? 0 : tappedIndex, queue: queue);
    return _enqueue(() async {
      final valid = <Track>[];
      for (final t in queue) {
        if (await File(t.path).exists()) valid.add(t);
      }

      if (valid.isEmpty) {
        state = state.copyWith(error: 'No valid files found');
        return;
      }

      final idx = valid.indexWhere((t) => t.id == track.id);
      final Track toPlay;
      if (idx >= 0) {
        toPlay = valid[idx];
      } else if (await File(track.path).exists()) {
        toPlay = track;
        valid.insert(0, track);
      } else {
        debugPrint('[PlayerNotifier] Selected track file not found: ${track.path}');
        toPlay = valid[0];
      }

      _pendingSeekMs = 0;
      final ordered = _queueForPlayback(valid, toPlay);
      final index = ordered.indexWhere((t) => t.id == toPlay.id);
      _showTrack(toPlay, index < 0 ? 0 : index, queue: ordered);
      await _loadSingle(toPlay);
      await _kickPlayback();
    });
  }

  List<Track> _queueForPlayback(List<Track> straight, Track current) {
    _unshuffled = List.of(straight);
    if (!state.shuffle) return straight;
    final rest = straight.where((t) => t.id != current.id).toList()..shuffle(_random);
    return [current, ...rest];
  }

  Future<void> togglePlayPause() {
    return _enqueue(() async {
      // First play after restore — audio hasn't been loaded yet.
      if (_player.processingState == ProcessingState.idle && state.currentTrack != null) {
        final track = state.currentTrack!;
        await _handler?.updateQueue([MediaItem(
          id: track.path, title: track.title, artist: track.artist, album: track.album,
        )]);
        await _player.setAudioSource(AudioSource.uri(Uri.file(track.path)));
        if (_pendingSeekMs > 0) {
          await _player.seek(Duration(milliseconds: _pendingSeekMs));
          _pendingSeekMs = 0;
        }
        _ignoreCompleteUntil = DateTime.now().add(const Duration(milliseconds: 800));
        await _kickPlayback();
        return;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        await _kickPlayback();
      }
    });
  }

  /// Pauses the library player only when it is already playing.
  /// Free Music preview uses this so a stream does not play over the queue.
  Future<void> pauseIfPlaying() {
    return _enqueue(() async {
      if (_player.playing) await _player.pause();
    });
  }

  Future<void> skipNext() {
    _trackChosen = true;
    _autoAdvanceQueued = false;
    return _enqueue(() => _advance(1));
  }

  int? _stepIndex(List<Track> q, int from, int direction) {
    if (q.isEmpty) return null;
    if (direction > 0 && state.repeatMode == AudioServiceRepeatMode.one) return from;
    if (direction > 0) {
      final candidate = from + 1;
      if (candidate >= q.length) {
        if (state.repeatMode != AudioServiceRepeatMode.all) return null;
        return 0;
      }
      return candidate;
    }
    if (from <= 0) {
      if (state.repeatMode == AudioServiceRepeatMode.all && q.length > 1) {
        return q.length - 1;
      }
      return 0;
    }
    return from - 1;
  }

  Future<void> _advance(int direction) async {
    final q = state.queue;
    if (q.isEmpty) return;
    var from = state.currentIndex;
    for (var attempt = 0; attempt < q.length; attempt++) {
      final next = _stepIndex(q, from, direction);
      if (next == null) return;
      final track = q[next];
      _showTrack(track, next);
      try {
        if (!await File(track.path).exists()) {
          throw Exception('Missing file');
        }
        await _loadSingle(track);
        await _kickPlayback();
        return;
      } catch (e) {
        debugPrint('[PlayerNotifier] skipping ${track.path}: $e');
        from = next;
        if (state.repeatMode == AudioServiceRepeatMode.one) break;
      }
    }
    state = state.copyWith(error: 'No playable tracks in the queue');
  }

  Future<void> playQueueIndex(int index) {
    _trackChosen = true;
    _autoAdvanceQueued = false;
    return _enqueue(() async {
      final q = state.queue;
      if (index < 0 || index >= q.length) return;
      final track = q[index];
      _showTrack(track, index);
      await _loadSingle(track);
      await _kickPlayback();
    });
  }

  Future<void> removeFromQueue(int index) {
    _trackChosen = true;
    return _enqueue(() async {
      final q = List<Track>.of(state.queue);
      if (index < 0 || index >= q.length) return;
      final wasCurrent = index == state.currentIndex;
      final removed = q.removeAt(index);
      _unshuffled = _unshuffled?.where((t) => t.id != removed.id).toList();
      if (q.isEmpty) {
        state = state.copyWith(queue: q, currentIndex: 0, currentTrack: null);
        await _player.stop();
        return;
      }
      var current = state.currentIndex;
      if (index < current) current -= 1;
      if (current >= q.length) current = q.length - 1;
      final track = q[current];
      _showTrack(track, current, queue: q);
      if (wasCurrent) {
        await _loadSingle(track);
        await _kickPlayback();
      }
    });
  }

  /// Stop this song and take it out of the queue. Used when the row is deleted.
  Future<void> dropTrack(int id) {
    _trackChosen = true;
    return _enqueue(() async {
      final q = state.queue.where((t) => t.id != id).toList();
      _unshuffled = _unshuffled?.where((t) => t.id != id).toList();
      if (state.currentTrack?.id != id) {
        final idx = state.currentTrack == null
            ? 0
            : q.indexWhere((t) => t.id == state.currentTrack!.id);
        state = state.copyWith(queue: q, currentIndex: idx < 0 ? 0 : idx);
        return;
      }
      try {
        await _player.stop();
      } catch (e) {
        debugPrint('[PlayerNotifier] dropTrack stop: $e');
      }
      state = state.copyWith(
        queue: q,
        currentIndex: 0,
        currentTrack: null,
        isPlaying: false,
        isLoading: false,
      );
    });
  }

  /// Stop playback before a file move so the open file can be renamed.
  Future<void> releaseFile(int id) {
    return _enqueue(() async {
      if (state.currentTrack?.id != id) return;
      try {
        await _player.stop();
      } catch (e) {
        debugPrint('[PlayerNotifier] releaseFile: $e');
      }
      state = state.copyWith(isPlaying: false, isLoading: false);
    });
  }

  Future<void> replaceTrack(Track updated) {
    return _enqueue(() async {
      final q = [for (final t in state.queue) t.id == updated.id ? updated : t];
      if (_unshuffled != null) {
        _unshuffled = [for (final t in _unshuffled!) t.id == updated.id ? updated : t];
      }
      final current = state.currentTrack?.id == updated.id ? updated : state.currentTrack;
      state = state.copyWith(queue: q, currentTrack: current);
    });
  }

  Future<void> skipPrevious() {
    _trackChosen = true;
    _autoAdvanceQueued = false;
    return _enqueue(() async {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        state = state.copyWith(position: Duration.zero);
        return;
      }
      await _advance(-1);
    });
  }

  Future<void> seek(double fraction) async {
    try {
      final ms = (fraction * state.duration.inMilliseconds).round();
      await _player.seek(Duration(milliseconds: ms));
    } catch (e, st) {
      debugPrint('[PlayerNotifier] seek error: $e\n$st');
    }
  }

  Future<void> toggleShuffle() async {
    final next = !state.shuffle;
    final current = state.currentTrack;
    if (next) {
      _unshuffled ??= List<Track>.of(state.queue);
      final rest = state.queue.where((t) => t.id != current?.id).toList()..shuffle(_random);
      final q = <Track>[if (current != null) current, ...rest];
      state = state.copyWith(shuffle: true, queue: q, currentIndex: current == null ? 0 : 0);
    } else {
      final base = _unshuffled ?? state.queue;
      final idx = current == null ? 0 : base.indexWhere((t) => t.id == current.id);
      state = state.copyWith(
        shuffle: false,
        queue: base,
        currentIndex: idx < 0 ? 0 : idx,
      );
    }
    try {
      await _player.setShuffleModeEnabled(false);
    } catch (e) {
      debugPrint('[PlayerNotifier] setShuffleModeEnabled: $e');
    }
  }

  Future<void> cycleRepeat() async {
    final next = switch (state.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all  => AudioServiceRepeatMode.one,
      _                           => AudioServiceRepeatMode.none,
    };
    // The player holds one file. LoopMode.all would repeat that file and the
    // queue would never advance. Repeat-all is handled in _advance.
    try {
      await _player.setLoopMode(
        next == AudioServiceRepeatMode.one ? LoopMode.one : LoopMode.off,
      );
    } catch (e) {
      debugPrint('[PlayerNotifier] setLoopMode: $e');
    }
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
    final notifier = PlayerNotifier(player, null, db, true);
    Future.microtask(() => notifier.restoreResumeState());
    return notifier;
  }

  // On mobile, share the handler's AudioPlayer so the UI and the
  // audio_service background handler always operate on the same instance.
  // Previously a second AudioPlayer was created here, which caused the
  // notification controls and the in-app controls to drive different players.
  final handler = ref.watch(audioHandlerProvider) as OmniPlayerHandler;
  final notifier = PlayerNotifier(handler.player, handler, db, false);
  Future.microtask(() => notifier.restoreResumeState());
  return notifier;
});
