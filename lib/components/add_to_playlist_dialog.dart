import 'package:flutter/material.dart';
import 'package:glopplayer/provider/playlist_provider.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

class AddToPlaylistDialog extends StatelessWidget {
  final SongModel song;

  const AddToPlaylistDialog({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();

    return AlertDialog(
      title: const Text('Adicionar à Playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: provider.playlists.isEmpty
            ? const Center(
                child: Text('Nenhuma playlist disponível'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: provider.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = provider.playlists[index];
                  final isInPlaylist =
                      playlist.songs.any((s) => s.songId == song.id);

                  return ListTile(
                    leading: Icon(
                      isInPlaylist ? Icons.check_circle : Icons.playlist_add,
                      color: isInPlaylist ? Colors.green : null,
                    ),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songs.length} músicas'),
                    onTap: isInPlaylist
                        ? null
                        : () async {
                            await context
                                .read<PlaylistProvider>()
                                .addSongToPlaylist(playlist.id, song);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '"${song.title}" adicionada à playlist'),
                                ),
                              );
                            }
                          },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showCreatePlaylistDialog(context);
          },
          child: const Text('Criar Nova'),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    // Implementar dialog de criação de playlist
  }
}
