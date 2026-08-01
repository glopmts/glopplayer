import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:glopplayer/controllers/library_controller.dart';
import 'package:glopplayer/provider/playlist_provider.dart';
import 'package:glopplayer/provider/theme_provider.dart';
import 'package:glopplayer/screens/pages/cache_management_screen.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final action = uri.host.isNotEmpty
        ? uri.host.toLowerCase()
        : uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first.toLowerCase()
            : '';

    switch (action) {
      case 'playpause':
        playerController.playPause();
        break;
      case 'next':
        playerController.next();
        break;
      case 'previous':
        playerController.previous();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: playerController),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()..loadPlaylists()),
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
              '/pages/cache_management_screen': (context) =>
                  const CacheManagementScreen(),
            },
          );
        },
      ),
    );
  }
}
