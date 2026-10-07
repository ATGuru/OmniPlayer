import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/free_music/archive_client.dart';
import '../../services/free_music/catalog.dart';
import '../../services/free_music/downloader.dart';

class FreeMusicAlbumScreen extends ConsumerStatefulWidget {
  final CatalogAlbum album;
  const FreeMusicAlbumScreen({super.key, required this.album});

  @override
  ConsumerState<FreeMusicAlbumScreen> createState() => _FreeMusicAlbumScreenState();
}

class _FreeMusicAlbumScreenState extends ConsumerState<FreeMusicAlbumScreen> {
  final _catalog = const FreeMusicCatalog();
  final _preview = ja.AudioPlayer();
  List<CatalogTrack> _tracks = const [];
  String? _license;
  final _saved = <String>{};
  String? _activeFile;
  double? _progress;
  var _loading = true;
  String? _error;
  var _cancelled = false;
  String? _previewFile;
  var _previewBusy = false;
  var _previewPlaying = false;
  var _previewGen = 0;
  Future<void> _previewChain = Future<void>.value();
  StreamSubscription<ja.PlayerState>? _previewSub;

  bool get _desktopPreview {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _previewSub = _preview.playerStateStream.listen((event) {
      if (!mounted || event.playing == _previewPlaying) return;
      setState(() => _previewPlaying = event.playing);
    });
    _load();
  }

  @override
  void dispose() {
    _cancelled = true;
    _previewGen++;
    _previewSub?.cancel();
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final release = await _catalog.release(widget.album);
      if (!mounted) return;
      final downloader = FreeMusicDownloader(catalog: _catalog, db: ref.read(databaseProvider));
      final saved = <String>{};
      for (final track in release.tracks) {
        if (await downloader.isSaved(track)) saved.add(track.fileName);
      }
      if (!mounted) return;
      setState(() {
        _tracks = release.tracks;
        _license = release.license;
        _saved.addAll(saved);
        _loading = false;
      });
    } on FreeMusicException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save(CatalogTrack track) async {
    if (_activeFile != null || _saved.contains(track.fileName)) return;
    setState(() {
      _activeFile = track.fileName;
      _progress = null;
    });
    try {
      final downloader = FreeMusicDownloader(catalog: _catalog, db: ref.read(databaseProvider));
      await downloader.save(
        track,
        onProgress: (received, total) {
          if (!mounted || _activeFile != track.fileName) return;
          setState(() => _progress = total > 0 ? received / total : null);
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted) return;
      setState(() {
        _saved.add(track.fileName);
        _activeFile = null;
        _progress = null;
      });
    } on FreeMusicException catch (e) {
      if (!mounted || e.message == 'cancelled') return;
      setState(() {
        _activeFile = null;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _enqueuePreview(Future<void> Function() action) {
    final run = _previewChain.then((_) => action());
    _previewChain = run.catchError((Object e, StackTrace st) {
      debugPrint('[FreeMusic] preview: $e\n$st');
    });
    return run;
  }

  /// Streams [track] in this screen. Nothing is written to storage.
  Future<void> _togglePreview(CatalogTrack track) {
    return _enqueuePreview(() async {
      if (_previewFile == track.fileName && _preview.playing) {
        await _preview.pause();
        return;
      }
      final gen = ++_previewGen;
      try {
        if (!mounted) return;
        await ref.read(playerProvider.notifier).pauseIfPlaying();
        if (!mounted || gen != _previewGen) return;
        final sameSource = _previewFile == track.fileName &&
            _preview.processingState != ja.ProcessingState.idle;
        if (!sameSource) {
          setState(() {
            _previewFile = track.fileName;
            _previewBusy = true;
          });
          // No request headers: just_audio would proxy them through cleartext,
          // and this app does not allow cleartext traffic.
          await _preview.setUrl(track.downloadUrl);
          if (!mounted || gen != _previewGen) return;
          setState(() => _previewBusy = false);
        } else if (_preview.processingState == ja.ProcessingState.completed) {
          await _preview.seek(Duration.zero);
        }
        if (!mounted || gen != _previewGen) return;
        await _startPreview(gen);
      } catch (e, st) {
        debugPrint('[FreeMusic] preview: $e\n$st');
        if (!mounted || gen != _previewGen) return;
        setState(() {
          _previewFile = null;
          _previewBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview could not play. Check your connection.')),
        );
      }
    });
  }

  /// Starts playback without awaiting play(). On Android that future stays
  /// pending until the song ends once pause() has been used.
  Future<void> _startPreview(int gen) async {
    if (_desktopPreview) {
      try {
        await _preview.pause();
      } catch (e) {
        debugPrint('[FreeMusic] preview pause: $e');
      }
    }
    if (!mounted || gen != _previewGen) return;
    unawaited(_preview.play().then((_) {}, onError: (Object e, StackTrace st) {
      if (!mounted || gen != _previewGen) return;
      debugPrint('[FreeMusic] preview play: $e\n$st');
      setState(() {
        _previewFile = null;
        _previewBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview could not play. Check your connection.')),
      );
    }));
  }

  Future<void> _stopPreview() {
    return _enqueuePreview(() async {
      _previewGen++;
      _previewFile = null;
      _previewBusy = false;
      try {
        await _preview.stop();
      } catch (e) {
        debugPrint('[FreeMusic] preview stop: $e');
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _play(CatalogTrack track) async {
    await _stopPreview();
    if (!mounted) return;
    final downloader = FreeMusicDownloader(catalog: _catalog, db: ref.read(databaseProvider));
    final db = ref.read(databaseProvider);
    final saved = <Track>[];
    Track? current;
    for (final item in _tracks) {
      if (!_saved.contains(item.fileName)) continue;
      if (!mounted) return;
      final file = await downloader.fileFor(item);
      final row = await db.getTrackByPath(file.path);
      if (row == null) continue;
      saved.add(row);
      if (item.fileName == track.fileName) current = row;
    }
    if (current == null || saved.isEmpty) return;
    await ref.read(playerProvider.notifier).playTrack(current, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      appBar: AppBar(
        backgroundColor: OmniPlayerColors.voidBlack,
        foregroundColor: OmniPlayerColors.cyan,
        elevation: 0,
        title: Text(
          widget.album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12, letterSpacing: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        children: [
                          Text(
                            '${widget.album.creator}  ·  ${_license ?? widget.album.license}',
                            textAlign: TextAlign.center,
                            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap a song to preview it. Download is the only button that saves a file.',
                            textAlign: TextAlign.center,
                            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
                              color: OmniPlayerColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _tracks.isEmpty
                          ? Center(
                              child: Text(
                                'This release has no MP3s.',
                                style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _tracks.length,
                              itemBuilder: (context, index) => _row(_tracks[index]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(CatalogTrack track) {
    final saved = _saved.contains(track.fileName);
    final active = _activeFile == track.fileName;
    final previewing = _previewFile == track.fileName;
    final details = [
      if (track.trackNumber != null) '${track.trackNumber}',
      if (track.durationMs > 0) _clock(track.durationMs),
      if (track.sizeBytes > 0) _size(track.sizeBytes),
    ].join('  ·  ');
    return ListTile(
      onTap: saved ? () => _play(track) : () => _togglePreview(track),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(
          color: previewing ? OmniPlayerColors.cyan : Colors.white.withOpacity(0.9),
        ),
      ),
      subtitle: Text(
        '${track.artist}${details.isEmpty ? '' : '  ·  $details'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!saved) _previewButton(track, previewing),
          if (active)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                color: OmniPlayerColors.cyan,
              ),
            )
          else if (saved)
            IconButton(
              tooltip: 'Play saved copy',
              visualDensity: VisualDensity.compact,
              onPressed: () => _play(track),
              icon: Icon(Icons.play_arrow, color: OmniPlayerColors.cyan.withOpacity(0.9)),
            )
          else
            IconButton(
              tooltip: 'Save',
              visualDensity: VisualDensity.compact,
              onPressed: _activeFile == null ? () => _save(track) : null,
              icon: Icon(Icons.download_outlined, color: OmniPlayerColors.magenta.withOpacity(0.8)),
            ),
        ],
      ),
    );
  }

  Widget _previewButton(CatalogTrack track, bool previewing) {
    if (previewing && _previewBusy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2, color: OmniPlayerColors.cyan),
        ),
      );
    }
    final playing = previewing && _previewPlaying;
    return IconButton(
      tooltip: playing ? 'Pause preview' : 'Preview',
      visualDensity: VisualDensity.compact,
      onPressed: () => _togglePreview(track),
      icon: Icon(
        playing ? Icons.pause_circle_outline : Icons.headphones,
        color: OmniPlayerColors.cyan.withOpacity(0.9),
      ),
    );
  }

  String _clock(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
