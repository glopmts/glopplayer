import 'package:on_audio_query_forked/on_audio_query.dart';

class MusicLibraryService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Trechos de caminho (em minúsculas) que indicam que o áudio NÃO é uma
  /// música real, mesmo que a flag `isMusic` do MediaStore diga o contrário
  /// (isso acontece bastante em ROMs customizadas, ex: MIUI).
  ///
  /// Propositalmente NÃO inclui "whatsapp audio" nem "telegram audio" —
  /// essas pastas misturam notas de voz com músicas compartilhadas de
  /// verdade, então excluir a pasta inteira jogaria fora música legítima.
  static const List<String> _excludedPathFragments = [
    '/whatsapp voice notes/',
    '/whatsapp business/media/whatsapp voice notes/',
    '/telegram/telegram voice/',
    '/call recordings/',
    '/callrecordings/',
    '/voice recorder/',
    '/voicerecorder/',
    '/sounds/notifications/',
    '/notifications/',
    '/ringtones/',
    '/alarms/',
    '/record/',
    '/recordings/',
  ];

  Future<bool> checkAndRequestPermission({bool retry = false}) {
    return _audioQuery.checkAndRequest(retryRequest: retry);
  }

  Future<bool> get hasPermission => _audioQuery.permissionsStatus();

  /// Considera "música real" quando:
  /// 1. As flags do MediaStore não marcam como ringtone/notificação/alarme/podcast/audiobook
  /// 2. `isMusic` não é explicitamente `false`
  /// 3. O caminho do arquivo não bate com nenhuma pasta conhecida de
  ///    gravações/notas de voz (defesa extra contra flags erradas do MIUI)
  bool _isRealMusic(SongModel song) {
    if (song.isRingtone == true) return false;
    if (song.isNotification == true) return false;
    if (song.isAlarm == true) return false;
    if (song.isPodcast == true) return false;
    if (song.isAudioBook == true) return false;
    if (song.isMusic == false) return false;

    final path = song.data.toLowerCase();
    for (final fragment in _excludedPathFragments) {
      if (path.contains(fragment)) return false;
    }

    return true;
  }

  Future<List<SongModel>> fetchAllSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs.where(_isRealMusic).toList();
  }

  /// Álbuns "reais" são derivados a partir das músicas já filtradas: um
  /// álbum só aparece se tiver pelo menos 1 música que passou no filtro de
  /// `_isRealMusic`. Isso evita, por exemplo, um "álbum" fantasma criado
  /// pelo MediaStore a partir de uma pasta de notas de voz.
  Future<List<AlbumModel>> fetchAllAlbums() async {
    final albums = await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final realSongs = await fetchAllSongs();
    final validAlbumIds =
        realSongs.map((s) => s.albumId).whereType<int>().toSet();

    return albums.where((a) => validAlbumIds.contains(a.id)).toList();
  }

  /// Também filtra aqui — sem isso, abrir um álbum "misto" (ex: uma pasta
  /// que tem 1 música real + 1 nota de voz salva por engano) mostraria a
  /// nota de voz junto com as faixas.
  Future<List<SongModel>> fetchSongsFromAlbum(int albumId) async {
    final songs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
    );
    return songs.where(_isRealMusic).toList();
  }
}
