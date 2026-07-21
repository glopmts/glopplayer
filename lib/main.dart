import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:glopplayer/controllers/library_controller.dart';
import 'package:glopplayer/provider/playlist_provider.dart';
import 'package:glopplayer/provider/theme_provider.dart';
import 'package:glopplayer/screens/pages/local_library_screen.dart';
import 'package:glopplayer/screens/pages/theme_settings_screen.dart';
import 'package:glopplayer/theme/dynamic_color_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:glopplayer/widgets/tabs_navegation.dart';
import 'services/audio_player_handler.dart';
import 'services/player_controller.dart';

late MyAudioHandler audioHandler;
late PlayerController playerController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.glopplayer.channel.audio',
      androidNotificationChannelName: 'Reprodução de músicas Local',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  playerController = PlayerController(audioHandler); // <- FALTAVA ISSO

  runApp(const MyApp());
  playerController.restoreLastSession();
  _setupExternalAudioIntentListener();
}

void _setupExternalAudioIntentListener() {
  final appLinks = AppLinks();

  appLinks.uriLinkStream.listen((uri) {
    _handleReceivedUri(uri);
  }, onError: (err) => debugPrint('Erro na intent de áudio: $err'));

  appLinks.getInitialLink().then((uri) {
    if (uri != null) _handleReceivedUri(uri);
  });
}

void _handleReceivedUri(Uri uri) {
  playerController.playExternalFile(uri.toString());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: playerController), // única linha do PlayerController
        ChangeNotifierProvider(
            create: (_) => PlaylistProvider()..loadPlaylists()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LibraryController()),
      ],
      child: DynamicColorWrapper(
        builder: (context, lightTheme, darkTheme, mode) {
          return MaterialApp(
            title: 'GlopPlay',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: const MainTabScreen(),
            routes: {
              '/pages/theme_settings_screen': (context) =>
                  const ThemeSettingsScreen(),
              '/pages/local_library_screen': (context) =>
                  const LocalLibraryScreen(),
            },
          );
        },
      ),
    );
  }
}
