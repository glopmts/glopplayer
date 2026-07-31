import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../screens/pages/player_screen.dart';
import '../services/player_controller.dart';
import 'artwork_thumbnail.dart';

class MusicWidgetCompact extends StatelessWidget {
  const MusicWidgetCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final song = controller.currentSong;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: song == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: song == null
                        ? Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.music_note,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : ArtworkThumbnail(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            borderRadius: 14,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song?.title ?? 'Nenhuma música tocando',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: song == null
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song?.artist ?? 'Toque uma música para começar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.skip_previous,
                        color:
                            song == null ? cs.onSurfaceVariant : cs.onSurface),
                    onPressed: song == null ? null : controller.previous,
                    tooltip: 'Anterior',
                  ),
                  IconButton(
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: song == null ? cs.onSurfaceVariant : cs.primary,
                    ),
                    iconSize: 36,
                    onPressed: song == null ? null : controller.playPause,
                    tooltip: controller.isPlaying ? 'Pausar' : 'Tocar',
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next,
                        color:
                            song == null ? cs.onSurfaceVariant : cs.onSurface),
                    onPressed: song == null ? null : controller.next,
                    tooltip: 'Próxima',
                  ),
                ],
              ),
              if (song != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<Duration>(
                          stream: controller.player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration =
                                controller.player.duration ?? Duration.zero;
                            final progress = duration.inMilliseconds > 0
                                ? position.inMilliseconds /
                                    duration.inMilliseconds
                                : 0.0;
                            return LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(cs.primary),
                              minHeight: 4,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
