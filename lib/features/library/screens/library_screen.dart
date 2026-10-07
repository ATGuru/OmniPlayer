import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../providers/providers.dart';
import '../widgets/album_panel.dart';
import '../widgets/track_tile.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/track_actions.dart';

// ═══════════════════════════════════════════════
// FILE TREE DATA MODEL
// ═══════════════════════════════════════════════

class FileTreeNode {
  final String name;
  final String fullPath;
  final bool isFolder;
  final Track? track;
  final List<FileTreeNode> children;

  const FileTreeNode({
    required this.name,
    required this.fullPath,
    required this.isFolder,
    this.track,
    this.children = const [],
  });
}

// Mutable scratch node used only during tree construction
class _MutableNode {
  final String name;
  final String fullPath;
  Track? track;
  final Map<String, _MutableNode> children = {};

  _MutableNode(this.name, this.fullPath);

  FileTreeNode freeze() {
    if (track != null) {
      return FileTreeNode(name: name, fullPath: fullPath, isFolder: false, track: track);
    }
    final kids = children.values.map((c) => c.freeze()).toList()
      ..sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return FileTreeNode(name: name, fullPath: fullPath, isFolder: true, children: kids);
  }
}

// ═══════════════════════════════════════════════
// LIBRARY CONTENT  (embeddable — no Scaffold)
// ═══════════════════════════════════════════════

class LibraryContent extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const LibraryContent({super.key, this.onClose});

  @override
  ConsumerState<LibraryContent> createState() => _LibraryContentState();
}

enum _LibraryView { files, albums, playlists }

class _LibraryContentState extends ConsumerState<LibraryContent> {
  final _search = TextEditingController();
  var _view = _LibraryView.files;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Track> _filter(List<Track> tracks) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return tracks;
    return tracks.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        t.album.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync  = ref.watch(tracksProvider);
    final scanState    = ref.watch(scanProvider);
    final scanNotifier = ref.read(scanProvider.notifier);

    return Container(
      color: OmniPlayerColors.deepVoid,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Text('LIBRARY', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13, letterSpacing: 4)),
                  const Spacer(),
                  tracksAsync.when(
                    data: (t) => Text(
                      '${t.length} TRACKS',
                      style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.violet.withOpacity(0.5)),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Icon(Icons.close, color: OmniPlayerColors.cyan.withOpacity(0.5), size: 20),
                    ),
                  ],
                ],
              ),
            ),

            // ── Scan button ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _ScanButton(
                isScanning: scanState.isScanning,
                scanned: scanState.scanned,
                total: scanState.total,
                onScan: () => scanNotifier.scan(),
              ),
            ),

            // ── Separator ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  _Tab(label: 'FILES', active: _view == _LibraryView.files, onTap: () => setState(() => _view = _LibraryView.files)),
                  const SizedBox(width: 8),
                  _Tab(label: 'ALBUMS', active: _view == _LibraryView.albums, onTap: () => setState(() => _view = _LibraryView.albums)),
                  const SizedBox(width: 8),
                  _Tab(label: 'PLAYLISTS', active: _view == _LibraryView.playlists, onTap: () => setState(() => _view = _LibraryView.playlists)),
                ],
              ),
            ),
            if (_view == _LibraryView.files)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search title, artist, album',
                    hintStyle: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                    prefixIcon: Icon(Icons.search, size: 18, color: OmniPlayerColors.cyan.withOpacity(0.5)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.2))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: OmniPlayerColors.cyan)),
                  ),
                ),
              ),
            if (scanState.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  scanState.error!,
                  style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.errorRed, fontSize: 13),
                ),
              ),

            Divider(height: 1, color: OmniPlayerColors.cyan.withOpacity(0.08)),

            // ── File tree ────────────────────────
            Expanded(
              child: _view == _LibraryView.playlists
                  ? const PlaylistPanel()
                  : _view == _LibraryView.albums
                      ? const AlbumPanel()
                      : tracksAsync.when(
                data: (tracks) {
                  final shown = _filter(tracks);
                  if (tracks.isEmpty) {
                    return _EmptyState(
                      onScan: () => scanNotifier.scan(),
                      message: scanState.error == 'Permission denied'
                          ? 'Audio permission is off. Tap SCAN DEVICE and allow music access.'
                          : null,
                    );
                  }
                  if (shown.isEmpty) {
                    return Center(child: Text('No matches', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted)));
                  }
                  if (_search.text.trim().isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: shown.length,
                      itemBuilder: (context, i) => TrackTile(
                        track: shown[i],
                        index: i,
                        allTracks: shown,
                        onSelected: widget.onClose,
                      ),
                    );
                  }
                  return _FileTree(tracks: shown, onTrackSelected: widget.onClose);
                },
                loading: () => const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.errorRed)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// FILE TREE WIDGET
// ═══════════════════════════════════════════════

class _FileTree extends ConsumerStatefulWidget {
  final List<Track> tracks;
  final VoidCallback? onTrackSelected;

  const _FileTree({required this.tracks, this.onTrackSelected});

  @override
  ConsumerState<_FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends ConsumerState<_FileTree> {
  late FileTreeNode _root;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(_FileTree old) {
    super.didUpdateWidget(old);
    if (old.tracks != widget.tracks) _rebuild();
  }

  void _rebuild() {
    _root = _buildTree(widget.tracks);
    // Auto-expand root so the first directory level is visible
    _expanded.add(_root.fullPath);
  }

  // ── Tree construction ────────────────────────

  FileTreeNode _buildTree(List<Track> tracks) {
    if (tracks.isEmpty) {
      return const FileTreeNode(name: 'LIBRARY', fullPath: '', isFolder: true);
    }

    final commonDir = _commonDirPrefix(tracks.map((t) => t.path).toList());
    final rootLabel = commonDir.isEmpty
        ? 'LIBRARY'
        : commonDir.split('/').where((s) => s.isNotEmpty).last.toUpperCase();
    final root = _MutableNode(rootLabel, commonDir);

    for (final track in tracks) {
      // Make path relative to the common directory
      var relative = track.path;
      if (commonDir.isNotEmpty && relative.startsWith('$commonDir/')) {
        relative = relative.substring(commonDir.length + 1);
      }
      final segments = relative.split('/').where((s) => s.isNotEmpty).toList();

      _MutableNode current = root;
      for (int i = 0; i < segments.length - 1; i++) {
        final seg = segments[i];
        final childPath = '${current.fullPath}/$seg';
        current.children.putIfAbsent(seg, () => _MutableNode(seg, childPath));
        current = current.children[seg]!;
      }

      // Leaf node — display the track title, keyed by filename
      if (segments.isNotEmpty) {
        final key = segments.last;
        final leaf = _MutableNode(
          track.title.isNotEmpty ? track.title : key,
          track.path,
        )..track = track;
        current.children[key] = leaf;
      }
    }

    return root.freeze();
  }

  String _commonDirPrefix(List<String> paths) {
    if (paths.isEmpty) return '';
    // Strip filenames to get directory paths
    final dirs = paths.map((p) {
      final i = p.lastIndexOf('/');
      return i > 0 ? p.substring(0, i) : '';
    }).toList();
    if (dirs.length == 1) return dirs.first;

    final parts = dirs.first.split('/');
    int common = parts.length;
    for (final dir in dirs.skip(1)) {
      final other = dir.split('/');
      int i = 0;
      while (i < common && i < other.length && parts[i] == other[i]) i++;
      common = i;
    }
    return parts.take(common).join('/');
  }

  // ── Collect all tracks under a node ──────────

  List<Track> _collectTracks(FileTreeNode node) {
    if (!node.isFolder && node.track != null) return [node.track!];
    final result = <Track>[];
    for (final child in node.children) {
      result.addAll(_collectTracks(child));
    }
    return result;
  }

  // ── Flatten visible nodes for ListView ───────

  void _flattenInto(FileTreeNode node, int depth, List<(FileTreeNode, int)> out) {
    for (final child in node.children) {
      out.add((child, depth));
      if (child.isFolder && _expanded.contains(child.fullPath)) {
        _flattenInto(child, depth + 1, out);
      }
    }
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final player   = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final db       = ref.read(databaseProvider);

    final visible = <(FileTreeNode, int)>[];
    _flattenInto(_root, 0, visible);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: visible.length,
      itemBuilder: (ctx, i) {
        final (node, depth) = visible[i];
        final isExpanded = _expanded.contains(node.fullPath);
        final isActive   = !node.isFolder && player.currentTrack?.id == node.track?.id;

        return _TreeRow(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          isActive: isActive,
          isPlaying: isActive && player.isPlaying,
          onTap: () {
            if (node.isFolder) {
              setState(() => isExpanded
                  ? _expanded.remove(node.fullPath)
                  : _expanded.add(node.fullPath));
            } else if (node.track != null) {
              notifier.playTrack(node.track!, widget.tracks);
              widget.onTrackSelected?.call();
            }
          },
          onLongPress: node.track == null
              ? null
              : () => showTrackActions(context, ref, node.track!),
          onMenu: () {
            if (node.isFolder) {
              final tracks = _collectTracks(node);
              if (tracks.isEmpty) return;
              showMoveTracksToAlbum(context, ref, tracks);
              return;
            }
            if (node.track != null) showTrackActions(context, ref, node.track!);
          },
          onEdit: () {
            if (node.isFolder) {
              final tracks = _collectTracks(node);
              showBatchEditDialog(context, db, node.name, tracks);
            } else if (node.track != null) {
              showTrackEditDialog(context, db, node.track!);
            }
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// TREE ROW
// ═══════════════════════════════════════════════

class _TreeRow extends StatelessWidget {
  final FileTreeNode node;
  final int depth;
  final bool isExpanded;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;
  final VoidCallback? onEdit;

  const _TreeRow({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    this.onLongPress,
    this.onMenu,
    this.onEdit,
  });

  String _fmt(int ms) {
    if (ms <= 0) return '';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const indentPerLevel = 14.0;
    const baseIndent     = 8.0;

    final rowColor = isActive
        ? OmniPlayerColors.cyan.withOpacity(0.07)
        : Colors.transparent;

    final leftBorder = isActive
        ? BorderSide(color: OmniPlayerColors.cyan, width: 2)
        : BorderSide.none;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(left: leftBorder),
        ),
        padding: EdgeInsets.only(
          left: baseIndent + depth * indentPerLevel,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          children: [
            // Chevron (folders) or spacer (files)
            SizedBox(
              width: 14,
              child: node.isFolder
                  ? Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      color: OmniPlayerColors.cyan.withOpacity(0.45),
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 3),

            // Node icon
            Icon(
              node.isFolder
                  ? (isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined)
                  : Icons.audio_file_outlined,
              size: 13,
              color: node.isFolder
                  ? OmniPlayerColors.violet.withOpacity(0.75)
                  : isActive
                      ? OmniPlayerColors.cyan
                      : OmniPlayerColors.cyan.withOpacity(0.3),
            ),
            const SizedBox(width: 6),

            // Name
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: node.isFolder
                    ? OmniPlayerTextStyles.rajdhaniSemi.copyWith(
                        fontSize: 13,
                        color: OmniPlayerColors.cyan.withOpacity(0.85),
                        letterSpacing: 0.3,
                      )
                    : OmniPlayerTextStyles.rajdhaniBody.copyWith(
                        fontSize: 13,
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                      ),
              ),
            ),

            // Duration (tracks only)
            if (!node.isFolder && node.track != null) ...[
              const SizedBox(width: 6),
              Text(
                _fmt(node.track!.duration),
                style: OmniPlayerTextStyles.orbitronMono.copyWith(
                  fontSize: 8,
                  color: OmniPlayerColors.cyan.withOpacity(isActive ? 0.6 : 0.25),
                ),
              ),
            ],

            // Playing indicator
            if (isPlaying) ...[
              const SizedBox(width: 6),
              Icon(Icons.graphic_eq, size: 12, color: OmniPlayerColors.activeGreen),
            ],

            if (onMenu != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_vert,
                    size: 14,
                    color: OmniPlayerColors.cyan.withOpacity(0.55),
                  ),
                ),
              ),
            ],

            // Edit button
            if (onEdit != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 11,
                    color: OmniPlayerColors.cyan.withOpacity(0.22),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// LIBRARY SCREEN  (legacy full-screen wrapper)
// ═══════════════════════════════════════════════

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      body: LibraryContent(),
    );
  }
}

// ═══════════════════════════════════════════════
// SCAN BUTTON
// ═══════════════════════════════════════════════

class _ScanButton extends StatelessWidget {
  final bool isScanning;
  final int scanned;
  final int total;
  final VoidCallback onScan;

  const _ScanButton({required this.isScanning, required this.scanned, required this.total, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isScanning ? null : onScan,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OmniPlayerColors.cyan.withOpacity(isScanning ? 0.5 : 0.25)),
          color: OmniPlayerColors.cyan.withOpacity(isScanning ? 0.08 : 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning) ...[
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  value: total > 0 ? scanned / total : null,
                  color: OmniPlayerColors.cyan,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                total > 0
                    ? 'SCANNING $scanned / $total'
                    : scanned > 0
                        ? 'FOUND $scanned FILES'
                        : 'SCANNING...',
                style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10),
              ),
            ] else ...[
              const Icon(Icons.radar, color: OmniPlayerColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text('SCAN DEVICE', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: OmniPlayerTextStyles.orbitronMono.copyWith(
          fontSize: 9,
          letterSpacing: 2,
          color: active ? OmniPlayerColors.cyan : OmniPlayerColors.cyan.withOpacity(0.35),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final String? message;
  const _EmptyState({required this.onScan, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music_outlined, size: 64, color: OmniPlayerColors.cyan.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO TRACKS', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12, color: OmniPlayerColors.cyan.withOpacity(0.4))),
          const SizedBox(height: 8),
          Text(
            message ?? 'Tap SCAN DEVICE to find your music',
            textAlign: TextAlign.center,
            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
          ),
        ],
      ),
    );
  }
}
