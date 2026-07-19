import 'dart:io';
import 'package:glopplayer/db/songs_db.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkCacheService {
  ArtworkCacheService._();
  static final ArtworkCacheService instance = ArtworkCacheService._();

  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Cache em memória: evita re-consultar o SQLite a cada rebuild do widget.
  final Map<int, String?> _memCache = {};
  // Evita disparar duas buscas concorrentes pro mesmo id (comum durante scroll rápido).
  final Map<int, Future<String?>> _inFlight = {};

  Future<String?> getArtworkPath(int songId) {
    if (_memCache.containsKey(songId)) {
      return Future.value(_memCache[songId]);
    }
    if (_inFlight.containsKey(songId)) {
      return _inFlight[songId]!;
    }

    final future = _resolve(songId);
    _inFlight[songId] = future;
    future.whenComplete(() => _inFlight.remove(songId));
    return future;
  }

  Future<String?> _resolve(int songId) async {
    final cachedPath = await SongsDb.getArtworkPath(songId);
    if (cachedPath != null && await File(cachedPath).exists()) {
      _memCache[songId] = cachedPath;
      return cachedPath;
    }

    final bytes = await _audioQuery.queryArtwork(
      songId,
      ArtworkType.AUDIO,
      format: ArtworkFormat.JPEG,
      size: 300, // já pede em resolução menor -> decode nativo mais leve
      quality: 80,
    );

    if (bytes == null || bytes.isEmpty) {
      _memCache[songId] = null;
      return null;
    }

    final dir = await getTemporaryDirectory();
    final artworkDir = Directory('${dir.path}/artwork_cache');
    if (!await artworkDir.exists()) {
      await artworkDir.create(recursive: true);
    }

    final file = File('${artworkDir.path}/$songId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    await SongsDb.saveArtworkPath(songId, file.path);

    _memCache[songId] = file.path;
    return file.path;
  }

  void clearMemCache() => _memCache.clear();
}
