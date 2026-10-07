import 'package:flutter/material.dart';
import '../../../core/audio/metadata_writer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';

// ── Public entry points ───────────────────────────────────────────────────────

Future<void> showTrackEditDialog(
    BuildContext context, AppDatabase db, Track track) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _TrackEditDialog(db: db, track: track),
  );
}

Future<void> showBatchEditDialog(
    BuildContext context, AppDatabase db, String folderName, List<Track> tracks) async {
  if (tracks.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _BatchEditDialog(db: db, folderName: folderName, tracks: tracks),
  );
}

// ── Single-track edit ─────────────────────────────────────────────────────────

class _TrackEditDialog extends StatefulWidget {
  final AppDatabase db;
  final Track track;
  const _TrackEditDialog({required this.db, required this.track});

  @override
  State<_TrackEditDialog> createState() => _TrackEditDialogState();
}

class _TrackEditDialogState extends State<_TrackEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;
  late final TextEditingController _genre;
  late final TextEditingController _trackNum;
  late final TextEditingController _lyrics;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title    = TextEditingController(text: widget.track.title);
    _artist   = TextEditingController(text: widget.track.artist);
    _album    = TextEditingController(text: widget.track.album);
    _genre    = TextEditingController(text: widget.track.genre ?? '');
    _trackNum = TextEditingController(
        text: widget.track.trackNumber?.toString() ?? '');
    _lyrics   = TextEditingController(text: widget.track.lyrics ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _genre.dispose();
    _trackNum.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title       = _title.text.trim();
    final artist      = _artist.text.trim();
    final album       = _album.text.trim();
    final genre       = _genre.text.trim();
    final lyricsText  = _lyrics.text.trim();
    final trackNumStr = _trackNum.text.trim();
    final trackNum    = trackNumStr.isEmpty ? null : int.tryParse(trackNumStr);
    // The library row is the source of truth and is marked tagsEdited so a
    // rescan cannot put the old file tags back. The file write is best-effort:
    // ffmpeg only replaces the original after it succeeds.
    try {
      await MetadataWriter.writeTag(
        widget.track.path,
        title:       title,
        artist:      artist,
        album:       album,
        genre:       genre,
        trackNumber: trackNum,
        lyrics:      lyricsText.isEmpty ? null : lyricsText,
      );
    } catch (e) {
      debugPrint('[EditDialog] file tag write failed: $e');
    }
    try {
      await widget.db.updateTrackMetadata(
          widget.track.id,
          title:             title,
          artist:            artist,
          album:             album,
          genre:             genre,
          changeGenre:       true,
          trackNumber:       trackNum,
          changeTrackNumber: true,
          lyrics:            lyricsText,
          changeLyrics:      true,
      );
    } catch (e) {
      debugPrint('[EditDialog] library update failed: $e');
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtDuration(int ms) {
    if (ms <= 0) return '';
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return _EditShell(
      title: 'EDIT TRACK',
      subtitle: _fmtDuration(widget.track.duration),
      saving: _saving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      fields: [
        _Field(label: 'TITLE',   ctrl: _title),
        _Field(label: 'ARTIST',  ctrl: _artist),
        _Field(label: 'ALBUM',   ctrl: _album),
        _Field(label: 'GENRE',   ctrl: _genre),
        _Field(label: 'TRACK #', ctrl: _trackNum, numeric: true),
        _Field(label: 'LYRICS',  ctrl: _lyrics,   multiline: true),
      ],
    );
  }
}

// ── Batch folder edit ─────────────────────────────────────────────────────────

class _BatchEditDialog extends StatefulWidget {
  final AppDatabase db;
  final String folderName;
  final List<Track> tracks;
  const _BatchEditDialog({required this.db, required this.folderName, required this.tracks});

  @override
  State<_BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<_BatchEditDialog> {
  final _artist = TextEditingController();
  final _album  = TextEditingController();
  final _genre  = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _artist.dispose();
    _album.dispose();
    _genre.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final artist = _artist.text.trim();
    final album  = _album.text.trim();
    final genre  = _genre.text.trim();
    if (artist.isEmpty && album.isEmpty && genre.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    // File writes are best-effort. The library rows are marked tagsEdited
    // even when ffmpeg cannot update a file.
    try {
      await Future.wait(widget.tracks.map((t) => MetadataWriter.writeTag(
        t.path,
        artist: artist.isEmpty ? null : artist,
        album:  album.isEmpty  ? null : album,
        genre:  genre.isEmpty  ? null : genre,
      )));
    } catch (e) {
      debugPrint('[EditDialog] batch file tag write failed: $e');
    }
    final ids = widget.tracks.map((t) => t.id).toList();
    try {
      await widget.db.batchUpdateTracks(
        ids,
        artist: artist.isEmpty ? null : artist,
        album:  album.isEmpty  ? null : album,
        genre:  genre.isEmpty  ? null : genre,
      );
    } catch (e) {
      debugPrint('[EditDialog] batch library update failed: $e');
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditShell(
      title: 'BATCH EDIT',
      subtitle: '${widget.folderName.toUpperCase()}  •  ${widget.tracks.length} TRACKS',
      saving: _saving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      note: 'Leave a field blank to keep existing values.',
      fields: [
        _Field(label: 'ARTIST', ctrl: _artist),
        _Field(label: 'ALBUM',  ctrl: _album),
        _Field(label: 'GENRE',  ctrl: _genre),
      ],
    );
  }
}

// ── Shared dialog shell ───────────────────────────────────────────────────────

class _EditShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String? note;

  const _EditShell({
    required this.title,
    required this.fields,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    this.subtitle,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: OmniPlayerColors.deepVoid,
            border: Border.all(color: OmniPlayerColors.cyan.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: OmniPlayerColors.cyan.withOpacity(0.08), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(title,
                      style: OmniPlayerTextStyles.orbitronLabel
                          .copyWith(fontSize: 12, letterSpacing: 4)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: OmniPlayerTextStyles.orbitronMono
                            .copyWith(fontSize: 9, color: OmniPlayerColors.violet.withOpacity(0.7))),
                  ],
                  const SizedBox(height: 20),
                  Divider(height: 1, color: OmniPlayerColors.cyan.withOpacity(0.12)),
                  const SizedBox(height: 20),

                  // Fields
                  ...fields,

                  // Note
                  if (note != null) ...[
                    const SizedBox(height: 12),
                    Text(note!,
                        style: OmniPlayerTextStyles.rajdhaniBody
                            .copyWith(fontSize: 11, color: OmniPlayerColors.cyan.withOpacity(0.35))),
                  ],

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _Btn(label: 'CANCEL', onTap: saving ? null : onCancel, muted: true),
                      const SizedBox(width: 12),
                      _Btn(label: saving ? '...' : 'SAVE', onTap: saving ? null : onSave),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field ─────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool numeric;
  final bool multiline;

  const _Field({
    required this.label,
    required this.ctrl,
    this.numeric = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: OmniPlayerTextStyles.orbitronMono
                  .copyWith(fontSize: 8, color: OmniPlayerColors.cyan.withOpacity(0.5))),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: numeric
                ? TextInputType.number
                : multiline
                    ? TextInputType.multiline
                    : TextInputType.text,
            maxLines: multiline ? 8 : 1,
            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
              fontSize: multiline ? 12 : 14,
              color: Colors.white.withOpacity(0.85),
              height: multiline ? 1.5 : null,
            ),
            cursorColor: OmniPlayerColors.cyan,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: multiline ? 12 : 9,
              ),
              filled: true,
              fillColor: OmniPlayerColors.cyan.withOpacity(0.04),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.55)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Button ────────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  const _Btn({required this.label, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? OmniPlayerColors.cyan.withOpacity(0.35)
        : OmniPlayerColors.cyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.5)),
          color: muted ? Colors.transparent : OmniPlayerColors.cyan.withOpacity(0.08),
        ),
        child: Text(label,
            style: OmniPlayerTextStyles.orbitronLabel
                .copyWith(fontSize: 9, color: color)),
      ),
    );
  }
}
