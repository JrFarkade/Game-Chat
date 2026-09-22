import 'package:flutter/material.dart';
import '../models/sound_clip.dart';
import '../utils/constants.dart';

class SoundButton extends StatelessWidget {
  final SoundClip clip;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback? onStop;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const SoundButton({
    Key? key,
    required this.clip,
    required this.isPlaying,
    required this.onPlay,
    this.onStop,
    this.onRename,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPlaying ? AppColors.primary.withOpacity(0.3) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying ? AppColors.primary : AppColors.cardBorder,
          width: isPlaying ? 2 : 1,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isPlaying && onStop != null ? onStop : onPlay,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      isPlaying ? Icons.stop_circle : Icons.volume_up,
                      color: isPlaying ? AppColors.greenActive : AppColors.primary,
                      size: 24,
                    ),
                    if (clip.isCustom)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                        color: AppColors.surface,
                        onSelected: (val) {
                          if (val == 'rename' && onRename != null) onRename!();
                          if (val == 'delete' && onDelete != null) onDelete!();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: AppColors.redMuted)),
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
                const Spacer(),
                Text(
                  clip.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPlaying ? AppColors.greenActive : AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlaying ? 'PLAYING...' : (clip.isCustom ? 'Custom Sound' : 'Tap to Play'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isPlaying ? AppColors.greenActive : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
