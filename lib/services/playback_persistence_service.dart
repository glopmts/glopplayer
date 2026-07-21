import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPersistenceService {
  static const _key = 'last_playback_state';

  Future<void> save({
    required List<Map<String, dynamic>> songRefs,
    required int currentIndex,
    required int positionMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'songs': songRefs,
      'currentIndex': currentIndex,
      'positionMs': positionMs,
    };
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
