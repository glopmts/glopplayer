import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import '../services/artwork_cache_service.dart';

/// Mostra a capa de uma música, álbum ou playlist preenchendo todo o espaço
/// disponível (BoxFit.cover), com suporte a cache e otimizações de performance.
class ArtworkThumbnail extends StatefulWidget {
  final int id;
  final ArtworkType type;
  final double borderRadius;
  final double? width;
  final double? height;
  final IconData placeholderIcon;
  final BoxFit fit;

  const ArtworkThumbnail({
    super.key,
    required this.id,
    required this.type,
    this.borderRadius = 8,
    this.width,
    this.height,
    this.placeholderIcon = Icons.music_note,
    this.fit = BoxFit.cover,
  });

  @override
  State<ArtworkThumbnail> createState() => _ArtworkThumbnailState();
}

class _ArtworkThumbnailState extends State<ArtworkThumbnail>
    with AutomaticKeepAliveClientMixin {
  late Future<Uint8List?> _artworkFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _artworkFuture = _getCachedArtwork();
  }

  @override
  void didUpdateWidget(covariant ArtworkThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.type != widget.type) {
      _artworkFuture = _getCachedArtwork();
    }
  }

  // Cache estático para evitar múltiplas requisições
  static final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?> _getCachedArtwork() async {
    final key = '${widget.type}-${widget.id}';

    // Primeiro, tenta buscar do cache de arquivos
    final filePath =
        await ArtworkCacheService.instance.getArtworkPath(widget.id);
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return bytes;
        }
      } catch (_) {
        // Fallback para queryArtwork
      }
    }

    // Se não encontrou no cache de arquivos, busca via OnAudioQuery
    if (!_cache.containsKey(key)) {
      _cache[key] = OnAudioQuery().queryArtwork(
        widget.id,
        widget.type,
        format: ArtworkFormat.JPEG,
        size: _getArtworkSize(),
        quality: 85,
      );
    }
    return _cache[key]!;
  }

  int _getArtworkSize() {
    // Ajusta o tamanho da arte baseado nas dimensões solicitadas
    final maxDimension = widget.width ?? widget.height ?? 400;
    if (maxDimension <= 200) return 200;
    if (maxDimension <= 400) return 400;
    if (maxDimension <= 600) return 600;
    return 800;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pixelSize = _getPixelSize();

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: _getPlaceholderColor(context),
        child: FutureBuilder<Uint8List?>(
          future: _artworkFuture,
          builder: (context, snapshot) {
            // Tratamento de estados
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPlaceholder(context, isWaiting: true);
            }

            if (snapshot.hasError) {
              return _buildPlaceholder(context, error: snapshot.error);
            }

            final bytes = snapshot.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(
                bytes,
                key: ValueKey(bytes.hashCode),
                fit: widget.fit,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildPlaceholder(context),
              );
            }

            return _buildPlaceholder(context);
          },
        ),
      ),
    );
  }

  int? _getPixelSize() {
    if (widget.width == null && widget.height == null) return null;
    final maxDimension = widget.width ?? widget.height ?? 0;
    if (maxDimension > 0) {
      return (maxDimension * MediaQuery.of(context).devicePixelRatio).round();
    }
    return null;
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    bool isWaiting = false,
    Object? error,
  }) {
    return Container(
      color: _getPlaceholderColor(context),
      alignment: Alignment.center,
      child: isWaiting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            )
          : Icon(
              widget.placeholderIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: _getIconSize(),
            ),
    );
  }

  Color _getPlaceholderColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Se o tipo for PLAYLIST, usa uma cor diferente
    if (widget.type == ArtworkType.PLAYLIST) {
      return scheme.surfaceContainerHighest.withOpacity(0.7);
    }
    return scheme.surfaceContainerHighest;
  }

  double _getIconSize() {
    final maxDimension = widget.width ?? widget.height ?? 80;
    if (maxDimension <= 40) return 20;
    if (maxDimension <= 60) return 30;
    if (maxDimension <= 80) return 40;
    return 50;
  }
}
