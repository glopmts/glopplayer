import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Mostra/atualiza uma notificação com barra de progresso enquanto a
/// biblioteca está sendo escaneada — mesma ideia do canal de notificação
/// já usado pelo MyAudioHandler, só que pra scan em vez de reprodução.
///
/// NOTA: a partir da v20.0.0 do flutter_local_notifications, initialize(),
/// show(), cancel(), zonedSchedule() etc. passaram de parâmetros
/// posicionais para NOMEADOS em todas as plataformas. Este arquivo já
/// segue essa API nova.
class LibraryScanNotificationService {
  LibraryScanNotificationService._internal();
  static final LibraryScanNotificationService instance =
      LibraryScanNotificationService._internal();

  static const _channelId = 'com.glopplayer.channel.scan';
  static const _channelName = 'Escaneamento de biblioteca';
  static const _notificationId = 9001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Notificação indeterminada — usada no começo, antes de saber o total
  /// de arquivos (ex: enquanto ainda está listando a pasta).
  Future<void> showIndeterminate(
      {String title = 'Escaneando biblioteca'}) async {
    await _ensureInitialized();
    await _plugin.show(
      id: _notificationId,
      title: title,
      body: 'Procurando arquivos de música...',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Progresso do scan da biblioteca local',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          showProgress: true,
          indeterminate: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Atualiza a notificação com progresso real (current/total).
  Future<void> updateProgress({
    required int current,
    required int total,
    String title = 'Escaneando biblioteca',
  }) async {
    await _ensureInitialized();
    await _plugin.show(
      id: _notificationId,
      title: title,
      body: '$current de $total músicas',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Progresso do scan da biblioteca local',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          showProgress: true,
          indeterminate: false,
          maxProgress: total <= 0 ? 1 : total,
          progress: current.clamp(0, total <= 0 ? 1 : total),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Notificação final, some sozinha depois de alguns segundos.
  Future<void> showCompleted({required int trackCount}) async {
    await _ensureInitialized();
    await _plugin.show(
      id: _notificationId,
      title: 'Biblioteca atualizada',
      body: '$trackCount música(s) na biblioteca',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Progresso do scan da biblioteca local',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: false,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> dismiss() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
  }
}
