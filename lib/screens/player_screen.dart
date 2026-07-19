import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/player_controller.dart';
import '../widgets/artwork_thumbnail.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final song = controller.currentSong;

    if (song == null) {
      return const Scaffold(
          body: Center(child: Text('Nenhuma música selecionada')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tocando Agora'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Uint8List?>(
          future: song.getArtwork(),
          builder: (context, snapshot) {
            // Se tiver artwork, usa ele; senão, usa uma imagem padrão
            final artworkData = snapshot.data;

            return BackgroundBlur(
              image: artworkData != null
                  ? Image.memory(artworkData, fit: BoxFit.cover)
                  : Image.asset('assets/default_album.jpg', fit: BoxFit.cover),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    // Capa do álbum
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: ArtworkThumbnail(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        borderRadius: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${song.artist ?? "Artista desconhecido"} • ${song.album ?? "Álbum desconhecido"}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),

                    // Barra de progresso
                    StreamBuilder<Duration>(
                      stream: controller.player.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration =
                            controller.player.duration ?? Duration.zero;
                        final maxMillis = duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0;
                        final value = position.inMilliseconds
                            .clamp(0, maxMillis.toInt())
                            .toDouble();

                        return Column(
                          children: [
                            Slider(
                              value: value,
                              max: maxMillis,
                              onChanged: (v) => controller
                                  .seek(Duration(milliseconds: v.toInt())),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Controles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: controller.previous,
                        ),
                        const SizedBox(width: 16),
                        StreamBuilder<PlayerState>(
                          stream: controller.player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            final processingState =
                                snapshot.data?.processingState;

                            if (processingState == ProcessingState.loading ||
                                processingState == ProcessingState.buffering) {
                              return const SizedBox(
                                width: 64,
                                height: 64,
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            return IconButton(
                              iconSize: 64,
                              icon: Icon(playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled),
                              onPressed: controller.playPause,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next),
                          onPressed: controller.next,
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Extension corrigido
extension SongModelExtension on SongModel {
  Future<Uint8List?> getArtwork() async {
    try {
      final audioQuery = OnAudioQuery();
      // A sintaxe correta para o on_audio_query_forked
      final artwork = await audioQuery.queryArtwork(
        id, // primeiro parâmetro: o ID da música
        ArtworkType.AUDIO, // segundo parâmetro: o tipo
      );
      return artwork;
    } catch (e) {
      print('Erro ao carregar artwork: $e');
      return null;
    }
  }
}

extension on SongModel {
  get artwork =>
      null; // Placeholder for artwork data, replace with actual implementation if needed
}

class BackgroundBlur extends StatelessWidget {
  final Widget child;
  final Image? image;
  final double blurAmount;
  final double opacity;

  const BackgroundBlur({
    super.key,
    required this.child,
    this.image,
    this.blurAmount = 20,
    this.opacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo gradiente como fallback
        if (image == null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
          ),

        // Imagem com blur
        if (image != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurAmount,
                sigmaY: blurAmount,
              ),
              child: image!,
            ),
          ),

        // Overlay escuro
        Container(
          color: Colors.black.withOpacity(opacity),
        ),

        // Conteúdo
        child,
      ],
    );
  }
}
