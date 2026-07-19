import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'audio_player_handler.dart';

class PlayerController extends ChangeNotifier {
  final MyAudioHandler _handler;

  List<SongModel> _playlist = [];
  int _currentIndex = 0;
  int _loadToken = 0;
  bool _isPlaying = false;

  PlayerController(this._handler) {
    _handler.player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
      }
    });
    _handler.player.playingStream.listen((playing) {
      if (playing != _isPlaying) {
        _isPlaying = playing;
        notifyListeners();
      }
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

  Future<void> setPlaylist(List<SongModel> songs,
      {int initialIndex = 0}) async {
    final token = ++_loadToken;
    _playlist = songs;
    _currentIndex = initialIndex;
    notifyListeners();

    await _handler.setSongs(songs, initialIndex: initialIndex);
    if (token != _loadToken) return;
    await _handler.play();
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
}
