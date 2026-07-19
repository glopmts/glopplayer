import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glopplayer/components/add_to_playlist_dialog.dart';
import 'package:glopplayer/utils/format_utils.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/player_controller.dart';
import '../widgets/artwork_thumbnail.dart';
import '../screens/player_screen.dart';

class MusicListItems extends StatefulWidget {
  final List<SongModel> songs;
  final Function(int index)? onSongTap;

  const MusicListItems({
    super.key,
    required this.songs,
    this.onSongTap,
  });

  @override
  State<MusicListItems> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListItems> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  static const int _pageSize = 50;
  static const double _itemHeight = 72;
  int _visibleCount = _pageSize;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final total = _filteredSongs.length;
      if (_visibleCount < total) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
        });
      }
    }
  }

  List<SongModel> get _filteredSongs {
    if (_query.isEmpty) return widget.songs;
    final q = _query.toLowerCase();
    return widget.songs.where((song) {
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _visibleCount = _pageSize;
      });
    });
  }

  void _playSong(BuildContext context, List<SongModel> songs, int index) {
    if (widget.onSongTap != null) {
      widget.onSongTap!(index);
      return;
    }
    context.read<PlayerController>().setPlaylist(songs, initialIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSongs;
    final visible = filtered.take(_visibleCount).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar música ou artista...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              // fillColor: Colors.grey.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: widget.songs.isEmpty
              ? const Center(
                  child: Text('Nenhuma música encontrada no aparelho'))
              : filtered.isEmpty
                  ? const Center(
                      child: Text('Nenhum resultado para essa busca'))
                  : ListView.builder(
                      controller: _scrollController,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries:
                          false, // já fazemos manualmente abaixo
                      cacheExtent: 500,
                      itemExtent: _itemHeight,
                      itemCount: visible.length +
                          (visible.length < filtered.length ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= visible.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final song = visible[index];
                        return RepaintBoundary(
                          key: ValueKey(song.id),
                          child: _SongTile(
                            song: song,
                            onTap: () => _playSong(
                                context, filtered, filtered.indexOf(song)),
                            onMoreTap: () => _showSongOptions(context, song),
                            key: null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showSongOptions(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Tocar agora'),
              onTap: () {
                Navigator.pop(context);
                _playSong(context, [song], 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Adicionar à playlist'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AddToPlaylistDialog(song: song),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Detalhes da música'),
              onTap: () {
                Navigator.pop(context);
                _showSongDetails(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSongDetails(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Artista: ${song.artist ?? "Desconhecido"}'),
            const SizedBox(height: 8),
            Text('Álbum: ${song.album ?? "Desconhecido"}'),
            const SizedBox(height: 8),
            Text(
                'Duração: ${formatDuration(Duration(milliseconds: song.duration ?? 0))}'),
            const SizedBox(height: 8),
            Text('Gênero: ${song.genre ?? "Desconhecido"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

/// Item isolado — só rebuilda quando o próprio estado (isCurrent/isPlaying)
/// dessa música muda, não quando qualquer outra coisa muda no player.
class _SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _SongTile({
    required super.key,
    required this.song,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerController, ({bool isCurrent, bool isPlaying})>(
      selector: (_, controller) => (
        isCurrent: controller.isCurrentSong(song),
        isPlaying: controller.isCurrentlyPlaying(song),
      ),
      builder: (context, state, _) {
        return ListTile(
          leading: Opacity(
            opacity: state.isCurrent ? 1.0 : 0.6,
            child: SizedBox(
              width: 48,
              height: 48,
              child: ArtworkThumbnail(
                id: song.id,
                type: ArtworkType.AUDIO,
                borderRadius: 6,
              ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: state.isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : null,
              fontWeight: state.isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${song.artist ?? "Artista desconhecido"} • ${song.album ?? "Álbum desconhecido"}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isCurrent)
                Icon(
                  state.isPlaying
                      ? Icons.volume_up
                      : Icons.pause_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMoreTap,
              ),
            ],
          ),
          onTap: onTap,
        );
      },
    );
  }
}
