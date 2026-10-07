import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/free_music/archive_client.dart';
import '../../services/free_music/catalog.dart';
import 'free_music_album_screen.dart';

/// Search and browse open netlabel releases. The catalog stays in the app.
class FreeMusicScreen extends StatefulWidget {
  const FreeMusicScreen({super.key});

  @override
  State<FreeMusicScreen> createState() => _FreeMusicScreenState();
}

class _FreeMusicScreenState extends State<FreeMusicScreen> {
  final _catalog = const FreeMusicCatalog();
  final _search = TextEditingController();
  final _albums = <CatalogAlbum>[];

  var _loading = true;
  var _loadingMore = false;
  var _page = 1;
  var _hasMore = false;
  String? _error;
  String _query = '';
  String? _genre;
  int? _decade;
  int? _year;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await _catalog.search(
        _query,
        page: page,
        genre: _genre,
        year: _year,
        decade: _decade,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _albums.clear();
        _albums.addAll(result.albums);
        _page = page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } on FreeMusicException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _submit(String value) {
    _query = value.trim();
    _load(reset: true);
  }

  void _pickGenre(String? label) {
    setState(() => _genre = label);
    _load(reset: true);
  }

  void _pickDecade(int? decade) {
    setState(() {
      _decade = decade;
      _year = null;
    });
    _load(reset: true);
  }

  void _pickYear(int year) {
    setState(() => _year = _year == year ? null : year);
    _load(reset: true);
  }

  List<int> _yearsInDecade(int decade) {
    final last = decade + 9 < DateTime.now().year ? decade + 9 : DateTime.now().year;
    return [for (var year = last; year >= decade; year--) year];
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
          'FREE MUSIC',
          style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13, letterSpacing: 3),
        ),
      ),
      body: Column(
        children: [
          _filterLabel('GENRE'),
          _chipRow([
            _FilterChip(label: 'All', selected: _genre == null, onTap: () => _pickGenre(null)),
            for (final genre in musicGenres)
              _FilterChip(
                label: genre.label,
                selected: _genre == genre.label,
                onTap: () => _pickGenre(_genre == genre.label ? null : genre.label),
              ),
          ]),
          _filterLabel('YEAR'),
          _chipRow([
            _FilterChip(label: 'Any', selected: _decade == null && _year == null, onTap: () => _pickDecade(null)),
            for (final decade in musicDecades)
              _FilterChip(
                label: '${decade}s',
                selected: _decade == decade,
                onTap: () => _pickDecade(_decade == decade ? null : decade),
              ),
          ]),
          if (_decade != null)
            _chipRow([
              for (final year in _yearsInDecade(_decade!))
                _FilterChip(
                  label: '$year',
                  selected: _year == year,
                  onTap: () => _pickYear(year),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _search,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Or type a title or artist',
                hintStyle: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                prefixIcon: Icon(Icons.search, size: 18, color: OmniPlayerColors.cyan.withOpacity(0.5)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_forward, size: 18, color: OmniPlayerColors.cyan.withOpacity(0.7)),
                  onPressed: () => _submit(_search.text),
                ),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.2))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: OmniPlayerColors.cyan)),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan));
    }
    if (_error != null && _albums.isEmpty) {
      return _Message(
        text: _error!,
        action: 'TRY AGAIN',
        onTap: () => _load(reset: true),
      );
    }
    if (_albums.isEmpty) {
      return const _Message(text: 'No releases match that search.');
    }
    return ListView.builder(
      itemCount: _albums.length + 1,
      itemBuilder: (context, index) {
        if (index == _albums.length) return _footer();
        final album = _albums[index];
        return ListTile(
          title: Text(
            album.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
          subtitle: Text(
            [
              album.creator,
              if (album.year != null) '${album.year}',
              album.license,
            ].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted, fontSize: 13),
          ),
          trailing: Icon(Icons.chevron_right, color: OmniPlayerColors.cyan.withOpacity(0.5)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FreeMusicAlbumScreen(album: album)),
          ),
        );
      },
    );
  }

  Widget _filterLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 9, letterSpacing: 2),
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _footer() {
    if (_error != null) {
      return _Message(text: _error!, action: 'TRY AGAIN', onTap: () => _load(reset: false));
    }
    if (!_hasMore) return const SizedBox(height: 24);
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
      );
    }
    return TextButton(
      onPressed: () => _load(reset: false),
      child: Text('MORE', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10, letterSpacing: 2)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? OmniPlayerColors.cyan : OmniPlayerColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? OmniPlayerColors.cyan : OmniPlayerColors.cyan.withOpacity(0.25)),
          color: selected ? OmniPlayerColors.cyan.withOpacity(0.14) : Colors.transparent,
        ),
        child: Text(label, style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: color, fontSize: 14)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onTap;
  const _Message({required this.text, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTap,
                child: Text(action!, style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
