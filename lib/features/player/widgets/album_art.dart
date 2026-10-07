import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';

/// Cover for the current song. Uses a saved path when one exists, and on
/// Android asks the media store once and keeps the bytes for that track id.
class AlbumArt extends StatefulWidget {
  final Track? track;
  final double size;

  const AlbumArt({super.key, required this.track, this.size = 112});

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  static final Map<String, int> _songIds = {};
  static var _idsLoaded = false;

  Uint8List? _bytes;
  int? _forId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track?.id != widget.track?.id ||
        oldWidget.track?.albumArtPath != widget.track?.albumArtPath) {
      _load();
    }
  }

  Future<void> _load() async {
    final track = widget.track;
    if (track == null) {
      if (mounted) setState(() { _bytes = null; _forId = null; });
      return;
    }
    final saved = track.albumArtPath;
    if (saved != null && await File(saved).exists()) {
      final bytes = await File(saved).readAsBytes();
      if (!mounted || widget.track?.id != track.id) return;
      setState(() { _bytes = bytes; _forId = track.id; });
      return;
    }
    if (!Platform.isAndroid) return;
    try {
      final query = OnAudioQuery();
      if (!_idsLoaded) {
        final songs = await query.querySongs(uriType: UriType.EXTERNAL);
        for (final song in songs) {
          _songIds[song.data] = song.id;
        }
        _idsLoaded = true;
      }
      final songId = _songIds[track.path];
      if (songId == null) return;
      final art = await query.queryArtwork(songId, ArtworkType.AUDIO, size: 400);
      if (!mounted || widget.track?.id != track.id) return;
      setState(() { _bytes = art; _forId = track.id; });
    } catch (e) {
      debugPrint('[AlbumArt] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _bytes != null && _forId == widget.track?.id;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: show
            ? Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : Icon(
                Icons.album_outlined,
                size: widget.size * 0.42,
                color: OmniPlayerColors.cyan.withOpacity(0.35),
              ),
      ),
    );
  }
}
