import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final Map<int, Uri?> _artworkCache = {};

  AudioPlayer get player => _player;

  MyAudioHandler() {
    _init();
  }

  String _resolveSongUri(SongModel song) {
    final path = song.data;
    if (path.isNotEmpty) {
      return Uri.file(path).toString();
    }
    return song.uri ?? '';
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        debugPrint('ERRO DE REPRODUÇÃO: $e');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      },
    );

    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index >= 0 && index < items.length) {
        mediaItem.add(items[index]);
      }
    });
  }

  Future<Uri?> _artworkFileUri(SongModel song) async {
    final cacheKey = song.albumId ?? song.id;
    if (_artworkCache.containsKey(cacheKey)) {
      return _artworkCache[cacheKey];
    }
    try {
      final bytes = await _audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 300,
        quality: 90,
      );
      if (bytes == null || bytes.isEmpty) {
        _artworkCache[cacheKey] = null;
        return null;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/artwork_$cacheKey.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final uri = Uri.file(file.path);
      _artworkCache[cacheKey] = uri;
      return uri;
    } catch (_) {
      _artworkCache[cacheKey] = null;
      return null;
    }
  }

  Future<void> setSongs(List<SongModel> songs, {int initialIndex = 0}) async {
    final items = <MediaItem>[];
    final sources = <AudioSource>[];

    // 1. Monta a queue SEM esperar artwork — usa cache se já tiver, senão null por enquanto
    for (final song in songs) {
      final cacheKey = song.albumId ?? song.id;
      final cachedArt = _artworkCache[cacheKey]; // só olha cache, não busca
      final resolvedId = _resolveSongUri(song);

      final item = MediaItem(
        id: resolvedId,
        title: song.title,
        artist: song.artist ?? 'Artista desconhecido',
        album: song.album ?? 'Álbum desconhecido',
        duration: song.duration != null
            ? Duration(milliseconds: song.duration!)
            : null,
        artUri: cachedArt,
      );
      items.add(item);
      sources.add(AudioSource.uri(Uri.parse(item.id), tag: item));
    }

    queue.add(items);

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: initialIndex,
      );
    } catch (e) {
      debugPrint('ERRO AO CARREGAR PLAYLIST: $e');
      return;
    }

    if (items.isNotEmpty) {
      mediaItem.add(items[initialIndex]);
    }

    // 2. Toca IMEDIATAMENTE — não espera artwork nenhuma
    // (o play() em si fica a cargo de quem chamou setSongs, ex: PlayerController)

    // 3. Resolve artwork em background, sem bloquear nada
    _resolveArtworkInBackground(songs, items, initialIndex);
  }

  Future<void> _resolveArtworkInBackground(
    List<SongModel> songs,
    List<MediaItem> items,
    int initialIndex,
  ) async {
    // Prioriza a música atual primeiro (feedback visual mais rápido pro usuário)
    final order = [initialIndex, ...List.generate(songs.length, (i) => i)]
        .toSet() // remove duplicata do initialIndex
        .toList();

    for (final i in order) {
      final song = songs[i];
      final cacheKey = song.albumId ?? song.id;
      if (_artworkCache.containsKey(cacheKey)) continue; // já resolvido

      final artUri = await _artworkFileUri(song);
      if (artUri == null) continue;

      // Atualiza o MediaItem já existente na queue com a artwork nova
      final updated = items[i].copyWith(artUri: artUri);
      items[i] = updated;
      queue.add(List.of(items));

      // Se for a música tocando agora, atualiza a notificação também
      if (mediaItem.value?.id == updated.id) {
        mediaItem.add(updated);
      }
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
