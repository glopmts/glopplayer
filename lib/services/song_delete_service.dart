import 'package:flutter/services.dart';

class SongDeleteService {
  static const MethodChannel _channel = MethodChannel(
      'com.glopblog.glopplayer/delete_song'); // <- mesmo canal do Kotlin

  /// Retorna true se o usuário confirmou e as músicas foram excluídas.
  /// Retorna false se o usuário cancelou o diálogo do sistema.
  /// Lança exceção em caso de erro inesperado (ex: ids inválidos).
  static Future<bool> deleteSongs(List<int> songIds) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'deleteSongs',
        {'ids': songIds},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Erro desconhecido ao excluir músicas');
    }
  }
}
