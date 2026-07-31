import 'dart:io';

import 'package:flutter/material.dart';
import 'package:glopplayer/db/library_database.dart';
import 'package:glopplayer/db/songs_db.dart';
import 'package:sqflite/sqflite.dart';

/// Tela de "Armazenamento e cache", pra gerenciar o que o app guarda
/// localmente: capas de álbum/artista em cache e o índice de arquivos já
/// escaneados da biblioteca. Cada categoria pode ser limpa individualmente,
/// ou tudo de uma vez com "Limpar tudo".
///
/// Importante: essa tela NUNCA mexe nas playlists do usuário nem nos
/// arquivos de música no dispositivo — só em dados de cache/índice que o
/// app recria sozinho quando necessário.
class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  bool _loading = true;

  int _artworkCount = 0;
  int _artworkBytes = 0;

  int _scannedCount = 0;

  bool _clearingArtwork = false;
  bool _clearingScanned = false;
  bool _clearingAll = false;

  bool get _isBusy => _clearingArtwork || _clearingScanned || _clearingAll;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    final artworkPaths = await _fetchArtworkPaths();
    var bytes = 0;
    for (final path in artworkPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          bytes += await file.length();
        }
      } catch (_) {
        // arquivo pode ter sido removido externamente, ignora
      }
    }

    final scannedCount = await _fetchScannedFilesCount();

    if (!mounted) return;
    setState(() {
      _artworkCount = artworkPaths.length;
      _artworkBytes = bytes;
      _scannedCount = scannedCount;
      _loading = false;
    });
  }

  // --- Leitura direta das tabelas de cache -------------------------------

  Future<List<String>> _fetchArtworkPaths() async {
    final db = await SongsDb.instance;
    final rows = await db.query('artwork_cache', columns: ['file_path']);
    return rows.map((r) => r['file_path'] as String).toList();
  }

  Future<int> _fetchScannedFilesCount() async {
    final db = await LibraryDatabase.instance.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM scanned_files');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- Ações de limpeza ----------------------------------------------------

  Future<void> _clearArtworkCache() async {
    setState(() => _clearingArtwork = true);
    try {
      final paths = await _fetchArtworkPaths();
      for (final path in paths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // se não conseguir apagar o arquivo físico, segue limpando o
          // registro do banco mesmo assim
        }
      }
      await SongsDb.clearAllArtwork();
      await _loadStats();
      if (!mounted) return;
      _showSnack(
          'Cache de capas limpo (${paths.length} ${_itemWord(paths.length)}).');
    } finally {
      if (mounted) setState(() => _clearingArtwork = false);
    }
  }

  Future<void> _clearScannedCache() async {
    setState(() => _clearingScanned = true);
    try {
      final count = _scannedCount;
      await LibraryDatabase.instance.clearLibrary();
      await _loadStats();
      if (!mounted) return;
      _showSnack('Índice de escaneamento limpo ($count ${_itemWord(count)}).');
    } finally {
      if (mounted) setState(() => _clearingScanned = false);
    }
  }

  Future<void> _clearAll() async {
    setState(() => _clearingAll = true);
    try {
      final artworkPaths = await _fetchArtworkPaths();
      for (final path in artworkPaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await SongsDb.clearAllArtwork();
      await LibraryDatabase.instance.clearLibrary();
      await _loadStats();
      if (!mounted) return;
      _showSnack('Todo o cache local foi limpo.');
    } finally {
      if (mounted) setState(() => _clearingAll = false);
    }
  }

  String _itemWord(int count) => count == 1 ? 'item' : 'itens';

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Diálogos de confirmação --------------------------------------------

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onTapClearArtwork() async {
    if (_artworkCount == 0 || _isBusy) return;
    final confirmed = await _confirm(
      title: 'Limpar cache de capas?',
      message: 'Isso remove $_artworkCount ${_itemWord(_artworkCount)} de capa '
          '(~${_formatBytes(_artworkBytes)}) salvos localmente. Elas serão '
          'baixadas/geradas novamente conforme você for navegando pelo app.',
      confirmLabel: 'Limpar',
    );
    if (confirmed) await _clearArtworkCache();
  }

  Future<void> _onTapClearScanned() async {
    if (_scannedCount == 0 || _isBusy) return;
    final confirmed = await _confirm(
      title: 'Limpar índice de escaneamento?',
      message:
          'Isso apaga o registro de $_scannedCount ${_itemWord(_scannedCount)} '
          'já escaneados. O próximo scan da biblioteca vai reprocessar tudo '
          'do zero — pode demorar mais que o normal.',
      confirmLabel: 'Limpar',
    );
    if (confirmed) await _clearScannedCache();
  }

  Future<void> _onTapClearAll() async {
    if ((_artworkCount == 0 && _scannedCount == 0) || _isBusy) return;
    final confirmed = await _confirm(
      title: 'Limpar todo o cache local?',
      message:
          'Isso apaga as capas em cache (~${_formatBytes(_artworkBytes)}) e o '
          'índice de escaneamento da biblioteca. Suas playlists e as músicas '
          'no armazenamento do aparelho NÃO são afetadas — apenas dados que o '
          'app recria automaticamente.',
      confirmLabel: 'Limpar tudo',
    );
    if (confirmed) await _clearAll();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Armazenamento e cache')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _SummaryCard(
                    artworkCount: _artworkCount,
                    artworkSizeLabel: _formatBytes(_artworkBytes),
                    scannedCount: _scannedCount,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Categorias',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CacheCategoryTile(
                    icon: Icons.image_outlined,
                    title: 'Capas de álbum e artista',
                    subtitle: _artworkCount == 0
                        ? 'Nenhuma capa em cache'
                        : '$_artworkCount ${_itemWord(_artworkCount)} • '
                            '${_formatBytes(_artworkBytes)}',
                    loading: _clearingArtwork,
                    enabled: _artworkCount > 0 && !_isBusy,
                    onClear: _onTapClearArtwork,
                  ),
                  const SizedBox(height: 12),
                  _CacheCategoryTile(
                    icon: Icons.library_music_outlined,
                    title: 'Índice de escaneamento da biblioteca',
                    subtitle: _scannedCount == 0
                        ? 'Nada indexado'
                        : '$_scannedCount ${_itemWord(_scannedCount)} indexados',
                    loading: _clearingScanned,
                    enabled: _scannedCount > 0 && !_isBusy,
                    onClear: _onTapClearScanned,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed:
                        (_artworkCount == 0 && _scannedCount == 0) || _isBusy
                            ? null
                            : _onTapClearAll,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _clearingAll
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onErrorContainer,
                            ),
                          )
                        : const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Limpar tudo'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Suas playlists e as músicas no armazenamento do '
                          'aparelho não são afetadas por essa limpeza.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Card de resumo no topo da tela, com os números gerais do cache.
class _SummaryCard extends StatelessWidget {
  final int artworkCount;
  final String artworkSizeLabel;
  final int scannedCount;

  const _SummaryCard({
    required this.artworkCount,
    required this.artworkSizeLabel,
    required this.scannedCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: 'Capas em cache',
              value: artworkSizeLabel,
              caption: '$artworkCount arquivos',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: scheme.outlineVariant,
          ),
          Expanded(
            child: _SummaryStat(
              label: 'Índice de scan',
              value: '$scannedCount',
              caption: scannedCount == 1 ? 'arquivo' : 'arquivos',
            ),
          ),
        ],
      ).let((row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Armazenamento usado por cache',
                style: textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              row,
            ],
          )),
    );
  }
}

/// Pequeno helper de extensão pra permitir compor o Row dentro do Column
/// acima sem precisar declarar uma variável intermediária.
extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Linha de uma categoria de cache, com botão de limpar individual.
class _CacheCategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final bool enabled;
  final VoidCallback onClear;

  const _CacheCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.enabled,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: enabled ? onClear : null,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                    ),
                    child: const Text('Limpar'),
                  ),
          ),
        ],
      ),
    );
  }
}
