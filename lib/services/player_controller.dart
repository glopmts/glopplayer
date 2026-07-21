import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:glopplayer/services/music_library_service.dart';
import 'package:glopplayer/services/playback_persistence_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'audio_player_handler.dart';

class PlayerController extends ChangeNotifier {
  final MyAudioHandler _handler;
  final PlaybackPersistenceService _persistence = PlaybackPersistenceService();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _playlist = [];
  int _currentIndex = 0;
  int _loadToken = 0;
  bool _isPlaying = false;
  bool _suppressIndexStream = false; // NOVO
  Timer? _saveDebounce;

  PlayerController(this._handler) {
    _handler.player.currentIndexStream.listen((index) {
      if (_suppressIndexStream) return; // ignora eventos da troca em andamento
      if (index != null &&
          index >= 0 &&
          index < _playlist.length &&
          index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
      }
    });
    // salva posição quando o player avança (debounced)
    _handler.player.positionStream.listen((_) => _schedulePositionSave());
    // atualiza estado de reprodução
    _handler.player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
  }

  AudioPlayer get player => _handler.player;
  List<SongModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying; // NOVO
  SongModel? get currentSong =>
      _playlist.isEmpty ? null : _playlist[_currentIndex];
  bool get hasPlaylist => _playlist.isNotEmpty;

  List<SongModel> get songs => _playlist;

  // NOVO — helper pra comparar com uma música da lista
  bool isCurrentSong(SongModel song) {
    return currentSong != null && currentSong!.id == song.id;
  }

  bool isCurrentlyPlaying(SongModel song) {
    return isCurrentSong(song) && _isPlaying;
  }

  void _schedulePositionSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), _savePlaybackState);
  }

  Future<void> _savePlaybackState() async {
    if (_playlist.isEmpty) return;

    final refs = _playlist
        .where((song) => song.data.isNotEmpty)
        .map((song) => {'path': song.data})
        .toList();

    if (refs.isEmpty) return;

    await _persistence.save(
      songRefs: refs,
      currentIndex: _currentIndex,
      positionMs: _handler.player.position.inMilliseconds,
    );
  }

  Future<void> restoreLastSession() async {
    final data = await _persistence.load();
    if (data == null) return;

    final refsRaw = data['songs'] as List<dynamic>? ?? [];
    if (refsRaw.isEmpty) return;

    final paths = refsRaw
        .map((r) => (r as Map<String, dynamic>)['path'] as String)
        .toList();

    // Busca todas as músicas reais uma vez só
    final allSongs = await _audioQuery.querySongs();
    final byPath = {for (final s in allSongs) s.data: s};

    final restoredSongs = <SongModel>[];
    for (final path in paths) {
      final found = byPath[path];
      if (found != null) {
        restoredSongs.add(found);
      } else if (path.isNotEmpty) {
        // Não achou no MediaStore -> trata como arquivo externo
        restoredSongs
            .add(fakeSongModelFromExternalUri(Uri.file(path).toString()));
      }
    }

    if (restoredSongs.isEmpty) return;

    final savedIndex = (data['currentIndex'] as int?) ?? 0;
    final savedPositionMs = (data['positionMs'] as int?) ?? 0;
    final safeIndex = savedIndex.clamp(0, restoredSongs.length - 1);

    final token = ++_loadToken;
    _playlist = restoredSongs;
    _currentIndex = safeIndex;
    notifyListeners();

    await _handler.setSongs(restoredSongs, initialIndex: safeIndex);
    if (token != _loadToken) return;

    await _handler.seek(Duration(milliseconds: savedPositionMs));
  }
  // setPlaylist, playPause, next, previous, seek, playExternalFile
  // continuam iguais, só adiciona _savePlaybackState() no fim do setPlaylist:

  Future<void> setPlaylist(List<SongModel> songs,
      {int initialIndex = 0}) async {
    final token = ++_loadToken;
    _suppressIndexStream = true; // trava o stream durante a troca
    _playlist = songs;
    _currentIndex = initialIndex;
    notifyListeners();

    await _handler.setSongs(songs, initialIndex: initialIndex);
    if (token != _loadToken) return;

    _suppressIndexStream = false; // volta a confiar no stream só depois
    await _handler.play();

    _savePlaybackState();
  }

  Future<void> playPause() async {
    if (_handler.player.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seek(Duration position) => _handler.seek(position);

  void playSong(SongModel song) {
    // Implementation for playing a specific song
  }

  Future<void> playExternalFile(String uriString) async {
    final fakeSong = fakeSongModelFromExternalUri(uriString);
    await setPlaylist([fakeSong], initialIndex: 0);
  }
}
