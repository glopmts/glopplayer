import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:glopplayer/components/songs_list.dart';
import 'package:glopplayer/screens/pages/album_songs_screen.dart';

import '../services/music_library_service.dart';
import '../services/player_controller.dart';
import 'player_screen.dart';

enum _LoadState { checking, needsPermission, loadingLibrary, ready, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicLibraryService _library = MusicLibraryService();

  _LoadState _state = _LoadState.checking;
  String? _errorMessage;
  List<SongModel> _songs = [];
  List<AlbumModel> _albums = [];

  @override
  void initState() {
    super.initState();
    _checkStatusOnly();
    _initPermissionFlow();
    _requestNotificationPermission();
  }

  Future<void> _checkStatusOnly() async {
    try {
      final granted = await _library.hasPermission;
      if (!mounted) return;
      if (granted) {
        setState(() => _state = _LoadState.loadingLibrary);
        _loadLibrary();
      } else {
        setState(() => _state = _LoadState.needsPermission);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initPermissionFlow() async {
    try {
      final granted = await _library.hasPermission;
      if (!mounted) return;

      if (granted) {
        await _loadLibrary();
        return;
      }

      // Ainda não tem permissão -> já dispara o pedido, sem esperar clique
      await _requestPermission();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _state = _LoadState.loadingLibrary);
    try {
      final granted = await _library
          .checkAndRequestPermission(retry: true)
          .timeout(const Duration(seconds: 20), onTimeout: () => false);

      if (!mounted) return;

      if (!granted) {
        setState(() => _state = _LoadState.needsPermission);
        return;
      }
      await _loadLibrary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  // Pede permissão para mostrar notificações (Android 13+/iOS)
  Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadLibrary() async {
    setState(() => _state = _LoadState.loadingLibrary);
    try {
      final results = await Future.wait([
        _library.fetchAllSongs(),
        _library.fetchAllAlbums(),
      ]).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      setState(() {
        _songs = results[0] as List<SongModel>;
        _albums = results[1] as List<AlbumModel>;
        _state = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _openPlayer(int index) {
    context.read<PlayerController>().setPlaylist(_songs, initialIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  void _openAlbum(AlbumModel album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumSongsScreen(album: album, library: _library),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.checking:
      case _LoadState.loadingLibrary:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case _LoadState.needsPermission:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Precisamos de permissão para acessar as músicas do aparelho.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Conceder permissão'),
                  ),
                ],
              ),
            ),
          ),
        );

      case _LoadState.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Não foi possível carregar a biblioteca.\n${_errorMessage ?? ""}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkStatusOnly,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
          ),
        );

      case _LoadState.ready:
        return Scaffold(
          appBar: AppBar(
            title: const Text('Minhas Músicas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLibrary,
                tooltip: 'Atualizar biblioteca',
              ),
              // IconButton(
              //   icon: const Icon(Icons.album),
              //   onPressed: () => _showAlbumsDialog(),
              //   tooltip: 'Ver álbuns',
              // ),
            ],
          ),
          body: MusicListItems(
            songs: _songs,
            onSongTap: _openPlayer,
          ),
        );

      case _LoadState.needsPermission:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Precisamos de permissão para acessar as músicas do aparelho.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Conceder permissão'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Abrir configurações do app'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
