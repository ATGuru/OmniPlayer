import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider — access the global audio handler anywhere via Riverpod
final audioHandlerProvider = Provider<AudioHandler>((ref) {
  throw UnimplementedError('Override in main.dart ProviderScope');
});

/// ═══════════════════════════════════════════════
/// OMNIX AUDIO HANDLER
/// Bridges just_audio ↔ audio_service
/// Handles: background playback, lock screen controls,
///           notification media controls, headset buttons
/// ═══════════════════════════════════════════════
class OmniXAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  OmniXAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Forward player state → audio_service playback state
    _player.playbackEventStream.listen(_broadcastState);

    // When track ends, auto-advance queue
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Forward current index changes to mediaItem stream
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  /// Update notification queue metadata without touching the audio source.
  /// Call this whenever PlayerNotifier rebuilds the playback queue so that
  /// lock-screen / notification controls show the correct track info.
  void updateQueue(List<MediaItem> items) => queue.add(items);

  /// Load a list of tracks into the player queue
  Future<void> loadQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    queue.add(items);

    final sources = items.map((item) => AudioSource.uri(
      Uri.parse(item.id), // item.id = file path
      tag: item,
    )).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
    );
  }

  // ──────────────────────────────────────────────
  // BaseAudioHandler overrides
  // ──────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If more than 3s in: restart current track instead of going back
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    await play();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one  => LoopMode.one,
      AudioServiceRepeatMode.all  => LoopMode.all,
      _                           => LoopMode.off,
    };
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  // ──────────────────────────────────────────────
  // State broadcasting
  // ──────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle        => AudioProcessingState.idle,
        ProcessingState.loading     => AudioProcessingState.loading,
        ProcessingState.buffering   => AudioProcessingState.buffering,
        ProcessingState.ready       => AudioProcessingState.ready,
        ProcessingState.completed   => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // ──────────────────────────────────────────────
  // Convenience getters for UI
  // ──────────────────────────────────────────────

  AudioPlayer get player => _player;
  Duration get position  => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying     => _player.playing;
  int? get currentIndex  => _player.currentIndex;

  Stream<Duration> get positionStream   => _player.positionStream;
  Stream<Duration?> get durationStream  => _player.durationStream;
  Stream<bool> get playingStream        => _player.playingStream;
  Stream<int?> get currentIndexStream   => _player.currentIndexStream;
}
